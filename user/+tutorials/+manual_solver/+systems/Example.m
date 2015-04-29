classdef Example < vsys
    %EXAMPLE Example simulation for the manual solver in V-HAB 2.0
    %   Two tanks filled with gas and a pipe in between. The flow rate is 
    %   manually changed every 100 seconds in the exec function of this 
    %   system. Additionally a dummy heater element is included which
    %   manually changes the flow temperature every 100 seconds. 
    
    properties
        oBranch;        % A branch object that we can manipulate while the system is running
        bHighFlowRate;  % A Boolean variable to indicate if the flow rate is currently high or low
        fFlowRate;      % A float variable indicating the current flow rate in kg/s
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 1);
            
            % Creating a store, volume 1000 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 1000));
            
            % Adding a phase to the store 'Tank_1', 1000 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1000);
            
            % Creating a second store, volume 1000 m^3
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 1000));
            
            % Adding a phase to the store 'Tank_2', 1000 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1000);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, length 1 m, diameter 0.1 m
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe', 1, 0.1));
            this.addProcF2F(components.flow_peltier(this.oData.oMT, 'Heater', 0));
            
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe','Heater'}, 'Tank_2.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Add branch to manual solver
            this.oBranch = solver.matter.manual.branch(oBranch);
            
            this.bHighFlowRate = false;
            this.fFlowRate     = 0.5;
            
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it calls its parent's exec function
            exec@vsys(this);
            % Since we've added the branch between the two tanks to the manual solver inside of this
            % vsys-object, we can access its setFlowRate method to manually set and change the flow
            % rate of the branch. Here we change between two flow rate every 100 seconds.
            % Additionally, we change the temperature difference that the
            % heater produces. 
             
            if ~(mod(this.oData.oTimer.fTime, 100))         % Have 100s passed?
                if this.bHighFlowRate                       % Is the flow rate currently high? 
                    this.fFlowRate = 0.5;                   % Set flow rate to low value
                    this.bHighFlowRate = false;             % Change flow rate indicator to false
                    
                    % Changing the heater delta temperature
                    this.toProcsF2F.Heater.setDeltaTemperature(-10);
                else
                    this.fFlowRate = 1;                     % Set flow rate to high value
                    this.bHighFlowRate = true;              % Change flow rate indicator to true
                    
                    % Changing the heater delta temperature
                    this.toProcsF2F.Heater.setDeltaTemperature(0);
                end
            end
            
            this.oBranch.setFlowRate(this.fFlowRate);       % Setting the flow rate
            
        end
        
     end
    
end

