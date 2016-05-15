classdef setup_simpleArm < simulation.infrastructure
    %SETUP_SIMPLEARM Runner script/class for example simulation
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = setup_simpleArm(ptConfigParams, tSolverParams)
            % Create a new simulation with the system described in
            % |Example_simpleArm|. 
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % Initialize simulation with name. 
            this@simulation.infrastructure('TestCase_simpleArm', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Create system |Example_simpleArm|. 
            oThermalSystem = tutorials.thermal.systems.example_simpleArm(this.oSimulationContainer, 'simpleArm');
            
            % Create a new solver.
            oThermalSystem.oThermalSolver = solver.thermal.lumpedparameter(oThermalSystem);
            
            % Register timer callback to update capacities of nodes and
            % thermal conductivities of conductive conductors. 
            this.oSimulationContainer.oTimer.bind(@(~) this.updateMassFlow(), 1);
            
            
            % Simulate 2000s.
            this.fSimTime = 2000; % [s]
            
        end
        
        function configureMonitors(this)
            
            % Set what data should be logged.
            oLog = this.toMonitors.oLogger;
            
            %tiFlowProps = oLog.add('simpleArm', 'thermal_properties');
            oLog.add('simpleArm', 'thermal_properties');
            oLog.add('simpleArm', 'temperatures');
            
            
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('K', 'Temperatures');
            oPlot.definePlotAllWithFilter('J/K', 'Capacities');
            oPlot.definePlotAllWithFilter('W/K','Conductances');
            
            
        end
        
        function updateMassFlow(this)
            
            oTSys  = this.oSimulationContainer.toChildren.simpleArm;
            oTimer = oTSys.oTimer;
            
            % Get fluidic conductors map.
            poFluidC = oTSys.poFluidicConductors;
            
            if oTimer.fTime > 1100 && oTimer.fTime < 1120
                fFactor = 0.97; % reduce by 3%
            elseif oTimer.fTime > 1580 && oTimer.fTime < 1600
                fFactor = 1.02; % increase by 2%
            else
                return; % Nothing to do here.
            end
            
            %return;
            
            % Adjust mass flow rate.
            oTSys.fMassFlowRate = fFactor * oTSys.fMassFlowRate;
            
            % Get handle to |calculateConductance| of fluidic heat transfer
            % class.
            hCalcFunc = str2func('thermal.transfers.fluidic.calculateConductance');
            
            % Set new conductivities: 
            poFluidC('fluidic:Arm__Arm1Shoulder+Arm__Arm2Upper').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 1.00*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm__Arm2Upper+Arm__Arm1Shoulder').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 1.00*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm__Arm2Upper+Arm__Arm3Elbow').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.52*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm__Arm3Elbow+Arm__Arm2Upper').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.52*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm__Arm3Elbow+Arm__Arm4Lower').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.48*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm__Arm4Lower+Arm__Arm3Elbow').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.48*oTSys.fMassFlowRate) ...
            );
            
            poFluidC('fluidic:Arm__Arm4Lower+Arm__Arm5Hand').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.08*oTSys.fMassFlowRate) ...
            );
            poFluidC('fluidic:Arm__Arm5Hand+Arm__Arm4Lower').setConductivity( ...
                hCalcFunc(oTSys.fSpecificHeatCap, 0.08*oTSys.fMassFlowRate) ...
            );
            
            % Mark thermal container as tainted.
            oTSys.taint();
            
        end
        
        function plot(this)
            % Actually plot stuff
            this.toMonitors.oPlotter.plot();
            return;
        end
        
    end
    
end

