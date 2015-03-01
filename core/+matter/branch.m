classdef branch < base & event.source
    %BRANCH Summary of this class goes here
    %   Detailed explanation goes here
    %
    %
    %   - set flow rate and also partial ratios? Or do via normal .update
    %     command in solver, which is executed properly in direction of the
    %     flow rate? Call .update on FLOWS, with partial mass (or they get
    %     the partial mass from the flow before them?
    %     --> this.oIn.aoFlows(1) or this.oOut.aoFlows(2), depending on Fr,
    %         if positive, the former, negative, the latter!
    %   - EXME I/F -> special matter.branchEXME < matter.branch, only has 
    %     to change the setConnected / setDisconnected methods; no aoFlows,
    %     chSetFRs etc -> no flow in that branch! only one exme!
    %     -> can add several if branches from subsystems there!
    %     => JUST THIS CLASS, check if csProcs empty in constructor and
    %        right side actually a store, AND if port is called 'default',
    %        then allow for several branches to dock on the left side; no
    %        setFRs returned (automatically, empty), return right phase
    %        completely normally as always.
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the parent matter container
        oContainer;
        
        % Created from the store/interface names provided to the
        % createBranch method on matter.container (store1_port1__ifName, or
        % store1_port1__otherStore_somePort)
        sName;
        
        % Names for left/right (cell with 1/2, can be accessed like
        % [ aoBranches.csNames ] --> cell with names, two rows, n cols
        csNames = { ''; '' };
        
        % Interfaces left/right?
        abIf = [ false; false ];
        
        % When branch fully connected, contains references to the EXMEs at
        % the end of the branch (also if several branches coupled, will be
        % automatically set for branch on the left side
        %coPhases = { matter.phase.empty(1, 0); matter.phase.empty(1, 0) };
        %coPhases = { []; [] };
        coExmes = { []; [] };
        
        % Connected branches on the left (index 1, branch in subsystem) or
        % the right (index 2, branch in supsystem) side?
        coBranches = { matter.branch.empty(1, 0); matter.branch.empty(1, 0) };
        
        % Flows belonging to this branch
        aoFlows = matter.flow.empty();
        
        % Array with f2f processors in between the flows
        aoFlowProcs = matter.procs.f2f.empty();
        
        % Amount of flows / procs
        iFlows = 0;
        iFlowProcs = 0;
        
        % Current flow rate on branch
        fFlowRate = 0;
        
        bSealed = false;
        
        % Does the branch need an update of e.g. a flow rate solver? Can be
        % set e.g. through a flow proc that changed some internal state.
        bOutdated = false;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to the protected flow method setData, used to
        % update values within the flow objects array
        hSetFlowData;
        
        % If the RIGHT side of the branch is an interface (i.e. i/f to the
        % parent system), store its index on the aoFlows here to make it
        % possible to remove those connections later!
        iIfFlow;
        
        
        % Callback function handle; called when a new branch is connected
        % here on the right side to tell the branch on the left side, if
        % one exists, to update its flow rate handles and right phase
        hUpdateConnectedBranches;
        
        % Get flow rate handles and phase from right side branch (passes
        % that through if another branch on its right side)
        hGetBranchData;
        
        % Callback to tell the right side branch to disconnect from this
        % branch here
        hSetDisconnected;
        
        % Callback from the interface flow seal method, can be used to
        % disconnect the if flow and the according f2f proc in the supsys
        hRemoveIfProc;
        
        % Flow rate handler - only one can be set!
        oHandler;
    end
    
    methods
        function this = branch(oContainer, sLeft, csProcs, sRight)
            % Can be called with either stores/ports or interface names
            % (all combinations possible). Connections are always done from
            % subsystem to system.
            %
            %TODO
            %   - check if if flows already exist, error!
            %   - does store.getPort have a throw if port not found? Else
            %     throw here.
            
            this.oContainer = oContainer;
            this.csNames    = strrep({ sLeft; sRight }, '.', '__');
            this.sName      = [ this.csNames{1} '___' this.csNames{2} ];
            
            
            oFlow = [];
            
            %%%% HANDLE LEFT SIDE
            
            
            % Interface on left side?
            if isempty(strfind(sLeft, '.'))
                this.abIf(1) = true;
                
            else
                % Create first flow, get matter table from oData (see @sys)
                oFlow = matter.flow(this.oContainer.oData.oMT, this);
                
                % Add flow to index
                this.aoFlows(end + 1) = oFlow;
                
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sLeft, '.');
                
                
                % Get store name from parent
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get EXME port/proc ...
                oPort = this.oContainer.toStores.(sStore).getPort(sPort(2:end));
                
                % ... and add flow
                oPort.addFlow(oFlow);
                
                % Add as a normal proc
                %this.aoFlowProcs(end + 1) = oPort;
                
                % Get phase from flow and add to index
                %this.coPhases{1} = oPort.oPhase;
                this.coExmes{1} = oPort;
            end
            
            
            
            
            %%%% CREATE FLOWS FOR PROCS
            
            % Loop f2f procs
            for iI = 1:length(csProcs)
                sProc = csProcs{iI};
                
                if ~isfield(this.oContainer.toProcsF2F, sProc)
                    this.throw('branch', 'F2F proc %s not found on system this branch belongs to!', sProc);
                end
                
                
                % IF flow - FIRST proc - NO FLOW! That will be done when
                % the branch is actually connected to another one (to be
                % more exact, another branch connects to this here).
                if ~this.abIf(1) || (iI ~= 1)
                    % Connect to previous flow (the 'left' port of the proc
                    % goes to the 'out' port of the previous flow)
                    this.oContainer.toProcsF2F.(sProc).addFlow(oFlow);
                end
                
                % Create flow
                oFlow = matter.flow(this.oContainer.oData.oMT, this);
                this.aoFlows(end + 1) = oFlow;
                
                % Connect the new flow - 'right' of proc to 'in' of flow
                % Because of the possibility that the proc is not connected
                % to an in flow (if branch - in flow not yet known), we
                % explicitly provide the port to connect the flow to
                this.aoFlowProcs(end + 1) = this.oContainer.toProcsF2F.(sProc).addFlow(oFlow, 2);
            end
            
            
            
            %%%% HANDLE RIGHT SIDE
            
            
            
            % Interface on right side?
            if isempty(strfind(sRight, '.'))
                
                this.abIf(2) = true;
                this.iIfFlow = length(this.aoFlows);
                
            else
                % Split to store name / port name
                [ sStore, sPort ] = strtok(sRight, '.');
                
                
                % Get store name from container
                if ~isfield(this.oContainer.toStores, sStore), this.throw('branch', 'Can''t find provided store %s on parent system', sStore); end;
                
                % Get Port ...
                oPort = this.oContainer.toStores.(sStore).getPort(sPort(2:end));
                
                % ... and add flow IF not empty, could be if on the left,
                % no procs --> no oFlow, the IF flow from the subsystem
                % will connect to this EXME directly.
                %TODO still problem if no proc, and left IF to right store.
                %     That would basically be a exmeIFport to subsystems,
                %     so implement that (several subs can dock), see above
                if ~isempty(oFlow)
                    oPort.addFlow(oFlow);
                end
                
                % Get phase from flow and add to index
                this.coExmes{2} = oPort;
            end
            
            
            
            this.iFlows     = length(this.aoFlows);
            this.iFlowProcs = length(this.aoFlowProcs);
        end
        
        
        function connectTo(this, sInterface)
            % The sBranch parameter has to point to a valid interface name
            % for subsystems of a branch in the parent system, i.e. on the
            % 'left' side of the branch.
            % Write the aoFlows from the other branch, and the oPhase/oFlow
            % (end flow) to this branch here, store indices to be able to
            % remove the references later.
            %
            %TODO Check connectTo branch - is EXME? Then some specific
            %     handling of the connection to EXME ... see above
            
            % Find matching interface branch
            % See container -> connectIF, need to get all left names of
            % branches of parent system, since they depict the interfaces
            % to subsystems
            %subsref([ this.oContainer.oParent.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }}))
            iBranch = find(strcmp(...
                subsref([ this.oContainer.oParent.aoBranches.csNames ], struct('type', '()', 'subs', {{ 1, ':' }})), ...
                sInterface ...
            ), 1);
            
            
            if isempty(iBranch)
                this.throw('connectTo', 'Can''t find an interface branch %s on the parent system', sInterface);
            
            elseif ~this.abIf(2)
                this.throw('connectTo', 'Right side of this branch is not an interface, can''t connect to anyone!');
            
            elseif ~isempty(this.coBranches{2})
                this.throw('connectTo', 'Branch already connected to su*p*system (parent system) branch!');
                
            end
            
            this.coBranches{2} = this.oContainer.oParent.aoBranches(iBranch);
            
            % Maybe other branch doesn't like us, to try/catch
            try
                [ this.hGetBranchData, this.hSetDisconnected ] = this.coBranches{2}.setConnected(this, @this.updateConnectedBranches);
            
            % Error - reset the coBRanches
            catch oErr
                this.coBranches{2} = [];
                
                rethrow(oErr);
            end
            
            
            % Connect the interface flow here to the first f2f proc in the
            % newly connected branch - but first check if it has flow
            % procs, if not check for right exme!
            if this.coBranches{2}.iFlowProcs == 0
                % RIGHT one - can't have a left exme!
                oProc = this.coBranches{2}.coExmes{2};
            else
                oProc = this.coBranches{2}.aoFlowProcs(1);
            end
            
            oProc.addFlow(this.aoFlows(this.iIfFlow));
            
            % Now, if the left side of this branch is a store, not an
            % interface, gather all the data from connected branches; if it
            % is an interface and is connected, call update method there
            this.updateConnectedBranches();
        end
        
        function [ hGetBranchData, hSetDisconnected ] = setConnected(this, oSubSysBranch, hUpdateConnectedBranches)
            if ~this.abIf(1)
                this.throw('setConnected', 'Left side of this branch is not an interface!');
            
            elseif ~isempty(this.coBranches{1})
                this.throw('setConnected', 'Branch already connected to subsystem branch!');
                
            %elseif ~any(this.oContainer.oParent.aoBranches == oSubSysBranch)
            %elseif ~this.oContainer.isChild(oSubSysBranch.oContainer) || ~any(this.oContainer.getChild(oSubSysBranch.oContainer).aoBranches == oSubSysBranch)
            elseif oSubSysBranch.oContainer.oParent ~= this.oContainer
                this.throw('setConnected', 'Connecting branch does not belong to a subsystem of this system!');
                
            elseif ~isa(oSubSysBranch, 'matter.branch')
                this.throw('setConnected', 'Branch ~isa matter.branch!');
                
            elseif oSubSysBranch.coBranches{1} ~= this
                this.throw('setConnected', 'Branch coBranches{1} (left branch) not pointing to this branch!');
                
            end
            
            % Set left branch and update function handle
            this.coBranches{1}            = oSubSysBranch;
            this.hUpdateConnectedBranches = hUpdateConnectedBranches;
            
            % Return handles to get data and disconnect
            hGetBranchData   = @this.getBranchData;
            hSetDisconnected = @this.setDisconnected;
        end
        
        
        
        function disconnect(this)
            % Can only deconnect the connection to an interface branch on
            % the PARENT system (= supsystem).
            
            if ~this.abIf(2)
                this.throw('connectTo', 'Right side of this branch is not an interface, can''t connect to anyone!');
            
            elseif isempty(this.coBranches{2})
                this.throw('connectTo', 'No branch connected on right side!');
                
            end
            
            
            % Disconnect here
            oOldBranch         = this.coBranches{2};
            this.coBranches{2} = [];
            
            % Call disconnect on the branch - if it fails, need to
            % reset the coBranches
            try
                this.hSetDisconnected();
                
            catch oErr
                this.coBranches{2} = oOldBranch;
                
                rethrow(oErr);
            end
            
            % Remove function handles
            this.hGetBranchData   = [];
            this.hSetDisconnected = [];
            
            
            % Remove flow connection of if flow
            this.hRemoveIfProc();
            
            
            % If left side is NOT an interface (i.e. store), remove the
            % stored references on flows, procs, func handles
            if ~this.abIf(1)
                % Index of "out of system" entries
                iF = this.iIfFlow + 1;
                
                this.aoFlows    (iF:end) = [];
                %this.chSetFRs   (iF:end) = [];
                % One flow proc less than flows
                this.aoFlowProcs((iF - 1):end) = [];
                
                % Phase shortcut, also remove
                %this.coPhases{2} = [];
                this.coExmes{2} = [];
                
                this.iFlows     = length(this.aoFlows);
                this.iFlowProcs = length(this.aoFlowProcs);
            end
        end
        
        
        
        
        
        
        
        function setOutdated(this)
            % Can be used by phases or f2f processors to request recalc-
            % ulation of the flow rate, e.g. after some internal parameters
            % changed (closing a valve).
            
            % Only trigger if not yet set
            if ~this.bOutdated
                this.bOutdated = true;

                % Trigger outdated so e.g. the branch solver can register a
                % postTick callback on the timer to recalc flow rate.
                this.trigger('outdated');
            end
        end
        
        
        function setFlowRate = registerHandlerFR(this, oHandler)
            % Only one handler can be registered
            %   and gets a fct handle to the internal setFlowRate method.
            %   One solver obj per branch, atm no possibility for de-
            %   connect that one.
            %TODO Later, either check if solver obj is
            %     deleted and if yes, allow new one; or some sealed methods
            %     and private attrs on the basic branch solver class, and
            %     on setFRhandler, the branch solver provides fct callback
            %     to release the solver -> deletes the stored fct handle to
            %     the setFlowRate method of the branch. The branch calls
            %     this fct before setting a new solver.
            
            
            if ~isempty(this.oHandler)
                this.throw('registerHandlerFR', 'Can only set one handler!');
            end
            
            this.oHandler = oHandler;
            setFlowRate   = @this.setFlowRate;
        end
        
    
        function oExme = getInEXME(this)
            %oExme = this.coExmes{sif(this.aoFlows(1).fFlowRate < 0, 2, 1)};
            oExme = this.coExmes{sif(this.fFlowRate < 0, 2, 1)};
        end
        
        
        
        
        function update(this)
            %TODO just get the matter properties from the inflowing EXME
            %     and set (arPartialMass, MolMass, Heat Capacity)?
        end
    end
    
    
    % Methods provided to a connected subsystem branch
    methods (Access = protected)
        
        function setFlowRate(this, fFlowRate, afPressure, afTemp)
            % Set flowrate for all flow objects
            
            if this.abIf(1), this.throw('setFlowRate', 'Left side is interface, can''t set flowrate on this branch object'); end;
            
            % Connected phases have to do a massupdate
            for iE = sif(this.fFlowRate >= 0, 1:2, 2:1)
                this.coExmes{iE}.oPhase.massupdate();
            end
            
            
            
            this.fFlowRate = fFlowRate;
            this.bOutdated = false;
            
            % Update data in flows
            this.hSetFlowData(this.aoFlows, this.getInEXME(), fFlowRate, afPressure, afTemp);
        end
    
        
        
        function updateConnectedBranches(this)
            % Get func handles fr / phase from 
            
            if ~this.abIf(2)
                this.throw('updateConnectedBranches', 'Right side not an interface, can''t get data from no branches.');
            end
            
            % If we're "in between" (branches connected on left and right)
            % just call the left branch update method
            if this.abIf(1)
                if ~isempty(this.coBranches{1})
                    this.hUpdateConnectedBranches();
                end
                
            else
                % Get set fr func callbacks and phase on the right side of
                % the overall branch, write right phase to cell
                %[ chSetFRs, this.coPhases{2} ] = this.getBranchData(this);
                [ this.coExmes{2}, aoFlows, aoFlowProcs ] = this.hGetBranchData();
                
                
                % Only do if we got a right phase, i.e. the (maybe several)
                % connected branches connect two stores
                if ~isempty(this.coExmes{2})
                    % Just select to this.iIfFlow, maytbe chSetFrs was
                    % already extended previously
                    %this.chSetFRs = [ this.chSetFRs(1:this.iIfFlow) chSetFRs ];
                    this.aoFlows  = [ this.aoFlows(1:this.iIfFlow) aoFlows ];
                    
                    % One flow proc less than flows
                    this.aoFlowProcs = [ this.aoFlowProcs(1:(this.iIfFlow - 1)) aoFlowProcs ];
                    
                    this.iFlows     = length(this.aoFlows);
                    this.iFlowProcs = length(this.aoFlowProcs);
                end
                
                % Since the subsystem branch is already sealed, we have to
                % do it manually here for the new members of this sealed
                % branch. This seal stuff doesn't make sense...
                for iI = 1:this.iFlows
                    if ~this.aoFlows(iI).bSealed
                        this.aoFlows(iI).seal(false, this);
                    end
                end
                
                for iI = 1:this.iFlowProcs
                    if ~this.aoFlowProcs(iI).bSealed
                        this.aoFlowProcs(iI).seal(this);
                    end
                end
            end
        end
        
        function setDisconnected(this)
            % Remove connected left (subsystem) branch
            
            if ~this.abIf(1)
                this.throw('setDisconnected', 'Left side not an interface');
                
            elseif isempty(this.coBranches{1})
                this.throw('setDisconnected', 'Left side not connected to branch');
            
            elseif this.coBranches{1}.coBranches{2} == this
                this.throw('setDisconnected', 'Left side branch still connected to this branch');
            
            end
            
            
            this.coBranches{1}            = [];
            this.hUpdateConnectedBranches = [];
        end
        
        %function [ chSetFRs oRightPhase aoFlows aoFlowProcs ] = getBranchData(this)
        function [ oRightPhase, aoFlows, aoFlowProcs ] = getBranchData(this)
            % if coBranch{2} set, pass through. add own callbacks to cell,
            % leave phase untouched
            
            if ~this.abIf(1) || isempty(this.coBranches{1})
                this.throw('getBranchData', 'Left side no interface / not connected');
            end
            
            % Branch set on the right
            if ~isempty(this.coBranches{2})
                [ oRightPhase, aoFlows, aoFlowProcs ] = this.hGetBranchData();
                
                %chSetFRs = [ this.chSetFRs chSetFRs ];
                aoFlows  = [ this.aoFlows aoFlows ];
                
                aoFlowProcs = [ this.aoFlowProcs aoFlowProcs ];
                
            % No branch set on the right side, but got an interface on that
            % side, so return empty for the right phase!
            elseif this.abIf(2)
                %chSetFRs    = this.chSetFRs;
                oRightPhase = [];
                
            else
                %chSetFRs = this.chSetFRs;
                %oRightPhase = this.coPhases{2};
                oRightPhase = this.coExmes{2};
                
                aoFlows     = this.aoFlows;
                aoFlowProcs = this.aoFlowProcs;
            end
        end
    end
    
    
    
    methods (Sealed = true)
        function seal(this)
            % Seal aoFlows, get FR func handle
            
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            if this.abIf(1)
                % If this branch has an interface on the left side, it is a
                % supersystem branch with an interface to a subsystem. The
                % subsystem will already have sealed all of the flows and
                % procs, so we can just skip it here. 
                return;
            end
            
            for iI = 1:length(this.aoFlows)
                % If last flow and right interface, provide true as param,
                % which means that the .seal() returns a remove callback
                % which allows us to deconnect the flow from the f2f proc
                % in the "outer" system (supsystem).
                if this.abIf(2) && (this.iIfFlow == iI)
                    %[ this.chSetFRs{iI}, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
                    [ this.hSetFlowData, this.hRemoveIfProc ] = this.aoFlows(iI).seal(true);
                
                % Only need the callback reference once ...
                elseif iI == 1
                    this.hSetFlowData = this.aoFlows(iI).seal();
                else
                    %this.chSetFRs{iI} = 
                    this.aoFlows(iI).seal();
                end
            end
            
            for iI = 1:length(this.aoFlowProcs)
                this.aoFlowProcs(iI).seal(this);
            end
            
            
            this.bSealed = true;
        end
    end
    
end

