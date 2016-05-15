classdef branch < base & event.source
    %BRANCH Basic solver branch class
    %   This is the base class for all matter flow solvers in V-HAB, all
    %   other solver branch classes inherit from this class. 
    %
    %TODO
    %   - fFlowRate protected, not prive, and add setter?
    %   - check - setTimeStep means solver .update() method is executed by the
    %     timer during the 'normal' update call for e.g. phases etc.
    %     If a phase triggers an solver .update, that happens in the post tick
    %     loop.
    %     Any problems with that? Possible that solver called multiple times at
    %     a tick - shouldn't be a problem right?

    properties (SetAccess = private, GetAccess = private)
        %TODO how to serialize function handles? Do differently in the
        %     first place, e.g. with some internal 'passphrase' that is
        %     generated and returned on registerHandlerFR and checked on
        %     setFlowRate?
        setBranchFR;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        oBranch;
        fFlowRate = 0;
        
        fLastUpdate = -10;
        
        
        % Branch to sync to - if that branch is executed/updated, also
        % update here!
        oSyncedSolver;
        bUpdateTrigger = false;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        bRegisteredOutdated = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Solving mechanism supported by the solver
        sSolverType;
        
        % Cached solving objects (from [procs].toSolver.hydraulic)
        aoSolverProps;
        
        % Reference to the matter table
        % @type object
        oMT;
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Update method is bound to this post tick priority. Some solvers
        % might need another priority to e.g. ensure that first, all other
        % branches update their flow rates.
        iPostTickPriority = -2;
    end
    
    
    methods
        function this = branch(oBranch, fInitialFlowRate, sSolverType)
            
            if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
                this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
                                     'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
            end
            
            this.oBranch = oBranch;
            this.oMT     = oBranch.oMT;
            
            if nargin >= 3 && ~isempty(sSolverType)
                this.sSolverType = sSolverType;
                
                % Cache the solver objects for quick access later
                %TODO re-cache if e.g. branch re-connected to another IF!
                this.aoSolverProps = solver.matter.base.type.(this.sSolverType).empty(0, size(this.oBranch.aoFlowProcs, 2));
                
                for iP = 1:length(this.oBranch.aoFlowProcs)
                    if ~isfield(this.oBranch.aoFlowProcs(iP).toSolve, this.sSolverType)
                        this.throw('branch:constructor', 'F2F processor ''%s'' does not support the %s solving method!', this.oBranch.aoFlowProcs(iP).sName, this.sSolverType);
                    end

                    this.aoSolverProps(iP) = this.oBranch.aoFlowProcs(iP).toSolve.(this.sSolverType);
                end
            end
            
            
            
            % Branch allows only one solver to take control
            this.setBranchFR = this.oBranch.registerHandlerFR(this);
            
            % Use branches container timer reference to bind for time step
            %CHECK nope, Infinity, right?
            %this.setTimeStep = this.oBranch.oTimer.bind(@(~) this.update(), inf);
            %this.setTimeStep = this.oBranch.oTimer.bind(@(~) this.registerUpdate(), inf);
            
            %TODO check - which one?
            %this.setTimeStep = this.oBranch.oTimer.bind(@(~) this.registerUpdate(), inf);
            this.setTimeStep = this.oBranch.oTimer.bind(@this.executeUpdate, inf, struct(...
                'sMethod', 'executeUpdate', ...
                'sDescription', 'ExecuteUpdate in solver which does massupdate and then registers .update in post tick!', ...
                'oSrcObj', this ...
            ));
            
            % Initial flow rate?
            if (nargin >= 2) && ~isempty(fInitialFlowRate)
                this.fFlowRate = fInitialFlowRate;
            end
            
            % If the branch triggers the 'outdated' event, need to
            % re-calculate the flow rate!
            %CHECK-160514
            %this.oBranch.bind('outdated', @this.registerUpdate);
            this.oBranch.bind('outdated', @this.executeUpdate);
        end
        
        
%         function syncToSolver(this, oSolver)
%             % 
%             %
%             %TODO
%             % Allow several synced solvers!!
%             
%             if ~isempty(this.oSyncedSolver)
%                 this.throw('syncToSolver', 'Cannot set another synced solver');
%             end
%             
%             this.oSyncedSolver = oSolver;
%             this.oSyncedSolver.bind('update', @(~) this.syncedUpdateCall());
%         end
    end
    
    methods (Access = private)
        function executeUpdate(this, ~)
            this.out(1, 1, 'executeUpdate', 'Call massupdate on both branches, depending on flow rate %f', { this.oBranch.fFlowRate });
            
            for iE = sif(this.oBranch.fFlowRate >= 0, 1:2, 2:-1:1)
                this.oBranch.coExmes{iE}.oPhase.massupdate();
            end
            
            %CHECK-160514
            %this.update();
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function registerUpdate(this, ~)
            %CHECK-160514
            %if this.bRegisteredOutdated, return; end;
            if this.bRegisteredOutdated, return; end;

            this.trigger('register_update', struct('iPostTickPriority', this.iPostTickPriority));
            
            this.out(1, 1, 'registerUpdate', 'Registering .update method on post tick prio %i for solver for branch %s', { this.iPostTickPriority, this.oBranch.sName });
            
            %keyboard();
            this.oBranch.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
            this.bRegisteredOutdated = true;
        end
        
        
        function syncedUpdateCall(this)
            % Prevent loops
            if ~this.bUpdateTrigger
                this.update();
            end
        end
        
        function update(this, fFlowRate, afPressures)
            % Inherited class can overload .update and write this.fFlowRate
            % and subsequently CALL THE PARENT METHOD by
            % update@solver.matter.base.branch(this);
            % (??)
            
            %TODO 13
            %   - names of solver packates? matter/basic/...?
            %   - also afPressures, afTemperatures for setBranchFR?
            %   - some solvers need possibility to preset flows with the
            %       molar mass, ..
            %       => NOT NOW! Solver just uses old values, and has to
            %       make sure that a short time step (0!!) is set when the
            %       flow rate direction changed!!
            %       -> setFlowRate automatically updates all!
            
            this.out(1, 1, 'update', 'Setting flow rate %f for branch %s', { fFlowRate, this.oBranch.sName });
            
            this.fLastUpdate = this.oBranch.oTimer.fTime;
            
            if nargin >= 2

                % If mass in inflowing tank is smaller than the precision
                % of the simulation, set flow rate and delta pressures to
                % zero
                oIn = this.oBranch.coExmes{sif(fFlowRate >= 0, 1, 2)}.oPhase;

                if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                    fFlowRate = 0;
                    afPressures = zeros(1, this.oBranch.iFlowProcs);
                end

                this.fFlowRate = fFlowRate;

            end
            
            this.bRegisteredOutdated = false;
            
            % No pressure given? Just make sure we have the variable
            % 'afPressures' set, the parent class knows what to do. In this
            % case it will distribute the pressure drops equally onto all 
            % flows.
            if nargin < 3
                afPressures = [];
            end
            
            this.setBranchFR(this.fFlowRate, afPressures);
            
            %TODO Add a comment here to tell the user what this is actually
            %good for. I'm assuming this is only here to call a synced
            %solver? 
            this.bUpdateTrigger = true;
            this.trigger('update');
            this.bUpdateTrigger = false;
        end
    end
end
