classdef SWME < vsys
    % SWME Model of the Space Suit Water Membrane Evaporator designed for
    % the AEMU
    % 
    % Add a nice description here
    
    properties
        % The external pressure in [Pa] is set to zero for a simulation of
        % an EVA in space, but can be changed to the atmospheric pressure
        % of Mars for a Mars EVA simulation.
        fEnvironmentalPressure = 0;
        
        % Total internal volume of the SWME in [m^3]   
        fSWMEVolume            = 9.620939e-4;
        
        % SWME volume - HoFI volume in [m^3]
        fSWMEVaporVolume       = 8.7395e-4;
        
        % Initial inlet water temperature in [K]
        fInitialTemperature; 
        
        % Function handle to the temperature set point changing method on
        % the back pressure valve f2f processor.
        hSetTemperatureSetPoint;
        
        
    end
    
    methods
        function this = SWME(oParent, sName, fInitialTemperature)
            
            this@vsys(oParent, sName);
            
            this.bExecuteContainer = false;
            
            this.fInitialTemperature = fInitialTemperature;
            
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            % Creating an empty tank where the vapor flows to, simulating
            % the environment (can be vacuum or planetary atmosphere)
            matter.store(this, 'EnvironmentTank', 10);
            
            % Adding an empty phase to the environment tank, representing
            % an empty tank
            oEnvironment = matter.phases.gas(...
                this.toStores.EnvironmentTank, ...        % Store in which the phase is located
                'VaporEnvironment', ...                   % Phase name
                struct('H2O', 0), ...                     % Phase contents
                0.001, ...                                % Phase volume
                293);                                     % Phase temperature
            
            % Special exme with a constant pressure, set on the initial
            % parameters
            oExme = special.matter.const_press_exme(oEnvironment, 'ToEnvironment', this.fEnvironmentalPressure);
            
            % Creating the SWME Store
            components.SWME.stores.SWMEStore(this, 'SWMEStore', this.fSWMEVolume, this.fSWMEVaporVolume, this.fInitialTemperature);
            
            % Two standard pipes, which connect the SWME to the super
            % system
            components.pipe(this, 'Pipe_1', 0.01, 0.0127);
            components.pipe(this, 'Pipe_2', 0.01, 0.0127);
            
            % Creating the BPV, passing the constant pressure exme as the
            % reference for the environmental pressure.
            components.SWME.procs.BPV(this, 'BPV', oExme);
            
            this.hSetTemperatureSetPoint = @(fTemperature) this.toProcsF2F.BPV.setTemperatureSetPoint(fTemperature);
            
            % We need to change the outlet temperature via a f2f processor,
            % which we create here.
            oProc = components.SWME.procs.TemperatureProcessor(this, 'TemperatureProcessor');
            
            % We also have to tell the P2P Processor in the SWME, that this
            % is the processor it is linked to.
            this.toStores.SWMEStore.setTemperatureProcessor(oProc);
            
            % Creating the inlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterIn', {'Pipe_1'}, 'Inlet', 'InletBranch');
            
            % Creating the outlet branch with an interface
            matter.branch(this, 'SWMEStore.WaterOut', {'TemperatureProcessor', 'Pipe_2'}, 'Outlet', 'OutletBranch');
            
            % Creating the branch to the environment with an interface
            matter.branch(this, 'SWMEStore.VaporOut', {'BPV'}, 'EnvironmentTank.ToEnvironment', 'EnvironmentBranch');
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Creating references to branches in order to set flow rate manually later
            solver.matter.manual.branch(this.toBranches.InletBranch);
            solver.matter.manual.branch(this.toBranches.OutletBranch);
            solver.matter.manual.branch(this.toBranches.EnvironmentBranch);
            
            % Binding the setFlowRate() methods of the outlet and vacuum
            % solver branches to the inlet branches' 'outdated' event. 
            this.toBranches.InletBranch.bind('outdated', @(~) this.toBranches.EnvironmentBranch.oHandler.setFlowRate(this.toProcsF2F.BPV.fVaporFlowRate));
            this.toBranches.InletBranch.bind('outdated', @(~) this.toBranches.OutletBranch.oHandler.setFlowRate(-1 * this.toBranches.InletBranch.fFlowRate - this.toStores.SWMEStore.toProcsP2P.X50Membrane.fWaterVaporFlowRate));
            
        end
        
        function setInterfaces(this, sInlet, sOutlet)
            % Setting the interface flows.
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        
        function setTemperatureSetPoint(this, fTemperatureSetPoint)
            this.toProcsF2F.setTemperatureSetPoint(fTemperatureSetPoint);
        end
    end
    
    
    methods (Access= protected)
        function exec(this, ~)
            exec@vsys(this);
        end
    end
end


