classdef setup < simulation.infrastructure
    %%
    % CURRENTLY NOT FUNCTIONAL TUTORIAL!
    %
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            this@simulation.infrastructure('SEAR_1', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the simulation object
            oSystem = components.SEAR(this.oSimulationContainer, 'SEAR');
            
            % Creating a thermal solver for the LCAR System with a time
            % step of 1 second
            solver.thermal.lumpedparameter(oSystem.toChildren.LCARSystem, 2);
                        
            %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 25200 * 1; 
            this.iSimTicks = 600;
            this.bUseTime = true;
            
        end
        
        function configureMonitors(this)
            %% Logging
            oLogger = this.toMonitors.oLogger;
            
            tiLog = struct();
            
            tiLog.FlowRates.SWMEout = oLogger.addValue('SEAR:b:IVV__In___SWME__Out',            'fFlowRate', 'kg/s', 'SWME to IVV');
            tiLog.FlowRates.IVVout  = oLogger.addValue('SEAR:b:Environment__In_1___IVV__Out_2', 'fFlowRate', 'kg/s', 'IVV to Vacuum');
            tiLog.FlowRates.LCARin  = oLogger.addValue('SEAR/LCARSystem:b:InletBranch',         'fFlowRate', 'kg/s', 'IVV to LCAR');
            tiLog.FlowRates.LCARout = oLogger.addValue('SEAR/LCARSystem:b:OutletBranch',        'fFlowRate', 'kg/s', 'LCAR to Vacuum');
            
            %tiLog.H2OMasses.SWME = oLogger.addValue('SEAR:s:SWME:p:WaterVapor', 'afMass(this.oMT.H2O)', 'kg', 'SWME');
            %tiLog.H2OMasses.Environment = oLogger.addValue('SEAR:s:Environment:p:air', 'afMass(this.oMT.H2O)', 'kg', 'Environment');
            %tiLog.H2OMasses.AbsorberPhase = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'afMass(this.oMT.H2O)', 'kg', 'AbsorberPhase');
            
            %tiLog.Masses.SWME = oLogger.addValue('SEAR:s:SWME:p:WaterVapor', 'fMass', 'kg', 'SWME');
            %tiLog.Masses.Environment = oLogger.addValue('SEAR:s:Environment:p:air', 'fMass', 'kg', 'Environment');
            tiLog.Masses.AbsorberPhase = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'fMass', 'kg', 'AbsorberPhase');
            %tiLog.Masses.Vapor = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:Vapor', 'fMass', 'kg', 'Vapor');
            
            tiLog.AbsorptionRates.Actual   = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber.oProc', 'fFlowRate', 'kg/s', 'actual rate of absorption');
            tiLog.AbsorptionRates.Computed = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber.oProc', 'fAbsorbRate', 'kg/s', 'computed rate of absorption');
            
            tiLog.AbsorbentMassFraction = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'rMassFractionLiCl', '-', '\epsilon_{LiCl} = m(LiCl)/m(total)');
            
            tiLog.VaporPressure = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:Vapor', 'fPressure', 'Pa', 'Vapor Phase Pressure');
            
            tiLog.Temperatures.Radiator = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:RadiatorSurface', 'fTemperature', 'K', 'Radiator');
            tiLog.Temperatures.Absorber = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'fTemperature', 'K', 'Absorber');
            tiLog.Temperatures.Sink     = oLogger.addValue('SEAR/LCARSystem', 'fSinkTemperature', 'K', 'Sink');
            
            tiLog.Equilibrium.Equilibrium = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'rXH2O_eq', '-', 'Equilibrium molar fraction x_{H_{2}O,eq}');
            tiLog.Equilibrium.Actual      = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber:p:AbsorberPhase', 'rXH2O',     '-', 'Actual molar fraction x_{H_{2}O}');
            
            tiLog.RadPower.Radiator = oLogger.addValue('SEAR/LCARSystem', 'fRadiatedPower * -1', 'W', 'Radiated power');
            tiLog.RadPower.Absorber = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber.oProc', 'fCoolingRate', 'W', 'LCAR cooling power');
            tiLog.RadPower.SWME     = oLogger.addValue('SEAR', 'fSupplyPow', 'W', 'SWME cooling power');
            
            tiLog.RadFlow.Radiator = tiLog.RadPower.Radiator;
            tiLog.RadFlow.SWME     = oLogger.addValue('SEAR', 'fSupplyPow', 'W', 'SWME power');
            
            tiLog.PowerRatio = oLogger.addValue('SEAR/LCARSystem:s:LCARAbsorber.oProc', 'rPowerRatio','-', '(LCAR Power)/(SWME Power)');

            
            csStores = fieldnames(this.oSimulationContainer.toChildren.SEAR.toStores);
            for iStore = 1:length(csStores)
                oLogger.addValue(['SEAR.toStores.', csStores{iStore}, '.aoPhases(1)'],	'this.fMass * this.fMassToPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLogger.addValue(['SEAR.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.SEAR.toBranches);
            for iBranch = 1:length(csBranches)
                oLogger.addValue(['SEAR.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.SEAR.toStores);
            csPressures = cell(length(csStores),1);
            csTemperatures = cell(length(csStores),1);
            for iStore = 1:length(csStores)
                csPressures{iStore} = ['"', csStores{iStore}, ' Pressure"'];
                csTemperatures{iStore} = ['"', csStores{iStore}, ' Temperature"'];
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.SEAR.toBranches);
            csFlowRates = cell(length(csBranches),1);
            for iBranch = 1:length(csBranches)
                csFlowRates{iBranch} = ['"', csBranches{iBranch}, ' Flowrate"'];
            end
            
            tPlotOptions.sTimeUnit = 'seconds';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);

            coPlots{1,1} = oPlotter.definePlot(csPressures,     'Pressures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csFlowRates,     'Flow Rates', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csTemperatures,  'Temperatures', tPlotOptions);
            oPlotter.defineFigure(coPlots,  'Plots', tFigureOptions);
            
            oPlotter.plot();
        end
        
    end
    
end
