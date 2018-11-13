classdef branch < base & event.source
    %BRANCH Basic solver branch class
    %   This is the base class for all thermal flow solvers in V-HAB, all
    %   other solver branch classes inherit from this class. 
    %
    properties (SetAccess = private, GetAccess = private)
        setBranchHeatFlow;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = public)
        oBranch;
        fHeatFlow = 0;
        
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
        
        % Handle to bind an update to the corresponding post tick. Simply
        % use XXX.hBindPostTickUpdate() to register an update. Solvers
        % should ONLY be updated in the post tick!
        hBindPostTickUpdate;
        
        bResidual = false;
        
        % See matter.branch, bTriggerSetFlowRate, for more!
        bTriggerUpdateCallbackBound = false;
        bTriggerRegisterUpdateCallbackBound = false;
    end
    
    
    methods
        function this = branch(oBranch, sSolverType)
            
            if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
                this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
                                     'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
            end
            
            this.oBranch = oBranch;
            this.oMT     = oBranch.oMT;
            
            if nargin >= 3 && ~isempty(sSolverType)
                this.sSolverType = sSolverType;
                
            end
            
            % Branch allows only one solver to take control
            this.setBranchHeatFlow = this.oBranch.registerHandlerHeatFlow(this);
            
            this.setTimeStep = this.oBranch.oTimer.bind(@this.executeUpdate, inf, struct(...
                'sMethod', 'executeUpdate', ...
                'sDescription', 'ExecuteUpdate in solver which does updateTemperature and then registers .update in post tick!', ...
                'oSrcObj', this ...
            ));
            
            % If the branch triggers the 'outdated' event, need to
            % re-calculate the heat flow!
            this.oBranch.bind('outdated', @this.executeUpdate);
        end
        
        
        
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            if strcmp(sType, 'update')
                this.bTriggerUpdateCallbackBound = true;
            
            elseif strcmp(sType, 'register_update')
                this.bTriggerRegisterUpdateCallbackBound = true;
            
            end
        end
    end
    
    methods (Access = private)
        function executeUpdate(this, ~)
            if ~base.oLog.bOff, this.out(1, 1, 'executeUpdate', 'Call updateTemperature on both branches, depending on flow rate %f', { this.oBranch.fHeatFlow }); end
            
            if this.oBranch.fHeatFlow >= 0
                aiExmes = 1:2;
            else
                aiExmes = 2:-1:1;
            end
            for iE = aiExmes
                this.oBranch.coExmes{iE}.oCapacity.registerUpdateTemperature();
            end
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            if this.bRegisteredOutdated
                return;
            end
            
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update', struct('iPostTickPriority', this.iPostTickPriority));
            end

            if ~base.oLog.bOff, this.out(1, 1, 'registerUpdate', 'Registering .update method on post tick prio %i for solver for branch %s', { this.iPostTickPriority, this.oBranch.sName }); end
            
            this.bRegisteredOutdated = true;
            this.hBindPostTickUpdate();
        end
        
        
        function syncedUpdateCall(this)
            % Prevent loops
            if ~this.bUpdateTrigger
                this.update();
            end
        end
        
        function update(this, fHeatFlow, afTemperatures)
            % Inherited class can overload .update and write this.fFlowRate
            % and subsequently CALL THE PARENT METHOD by
            % update@solver.matter.base.branch(this);
            
            
            if ~base.oLog.bOff, this.out(1, 1, 'update', 'Setting heat flow %f for branch %s', { fHeatFlow, this.oBranch.sName }); end
            
            this.fLastUpdate = this.oBranch.oTimer.fTime;
            
            if nargin >= 2

                % If mass in inflowing tank is smaller than the precision
                % of the simulation, set flow rate and delta pressures to
                % zero
                if fHeatFlow >= 0
                    oIn = this.oBranch.coExmes{1}.oCapacity.oPhase;
                else
                    oIn = this.oBranch.coExmes{2}.oCapacity.oPhase;
                end

                if tools.round.prec(oIn.fMass, oIn.oStore.oTimer.iPrecision) == 0
                    fHeatFlow = 0;
                    afTemperatures = zeros(1, this.oBranch.iConductors);
                end

                this.fHeatFlow = fHeatFlow;

            end
            
            this.bRegisteredOutdated = false;
            
            % No temperatures given? Just make sure we have the variable
            % 'afPressures' set, the parent class knows what to do. Note
            % that this is only allowed if now matter bound mass transfer
            % occurs
            if nargin < 3
                afTemperatures = [];
            end
            
            this.fHeatFlow = fHeatFlow;
            
            this.setBranchHeatFlow(this.fHeatFlow, afTemperatures);
            
            this.bUpdateTrigger = true;
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update');
            end
            
            this.bUpdateTrigger = false;
        end
    end
end
