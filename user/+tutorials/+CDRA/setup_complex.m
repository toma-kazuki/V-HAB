classdef setup_complex < simulation.infrastructure
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
        function this = setup_complex(ptConfigParams, tSolverParams) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestep_observer';
            ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            
%             ttMonitorConfig.oMassBalanceObserver.sClass = 'simulation.monitors.massbalance_observer';
%             fAccuracy = 1e-8;
%             fMaxMassBalanceDifference = inf;
%             bSetBreakPoints = false;
%             ttMonitorConfig.oMassBalanceObserver.cParams = { fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints };
            
            this@simulation.infrastructure('Tutorial_CDRA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            bSimpleCDRA = false;
            
            % Creating the root object
            tutorials.CDRA.systems.Example(this.oSimulationContainer, 'Example', bSimpleCDRA);

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 50; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity',              '-',    'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)',  'Pa',   'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature',              'K',    'Temperature Atmosphere');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fTemperature',      'K',    'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fPressure',         'Pa',   'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate',      'kg/s', 'Condensate Flowrate CHX');
            
            iCellNumber13x = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite13x.iCellNumber;
            iCellNumberSylobead = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Sylobead.iCellNumber;
            iCellNumber5A = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite5A.iCellNumber;
            miCellNumber = [iCellNumberSylobead, iCellNumber13x, iCellNumber5A];
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            for iType = 1:3
                for iBed = 1:2
                    oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.MassBuffer'],      'fPressure',                    'Pa',   ['Flow Pressure', csType{iType}, num2str(iBed),' MassBuffer']);
                    
                    for iCell = 1:miCellNumber(iType)
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'fPressure',                    'Pa',   ['Flow Pressure', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'afPP(this.oMT.tiN2I.H2O)',     'Pa',   ['Flow Pressure H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'afPP(this.oMT.tiN2I.CO2)',     'Pa',   ['Flow Pressure CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'fTemperature',                 'K',    ['Flow Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'fTemperature',                 'K',    ['Absorber Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);

                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.CO2)',   'kg',   ['Partial Mass CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.H2O)',   'kg',   ['Partial Mass H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toProcsP2P.AdsorptionProcessor_',num2str(iCell)],  'mfFlows(this.oMT.tiN2I.CO2)',   'kg/s',   ['Absorber Flowrate CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toProcsP2P.AdsorptionProcessor_',num2str(iCell)],  'mfFlows(this.oMT.tiN2I.H2O)',   'kg/s',   ['Absorber Flowrate H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                    
                        oLog.addValue(['Example:c:CDRA.tMassNetwork.InternalBranches_',csType{iType}, num2str(iBed), '(', num2str(iCell), ')'],  'fFlowRate',   'kg/s',   ['Flowrate ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        
                    end
                end
            end
            
            csInterfaceBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tMassNetwork.InterfaceBranches);
            iInterfaceBranches = length(csInterfaceBranches);
            for iIB = 1:iInterfaceBranches
                oLog.addValue(['Example:c:CDRA.tMassNetwork.InterfaceBranches.', csInterfaceBranches{iIB}],  'fFlowRate',   'kg/s',   csInterfaceBranches{iIB});
            end
            
            oLog.addValue('Example.toStores.CCAA_CDRA_Connection.aoPhases',      'fPressure',  'Pa',   'Connection Pressure CCAA to CDRA');
            oLog.addValue('Example.toStores.CDRA_CCAA_Connection.aoPhases',      'fPressure',  'Pa',   'Connection Pressure CDRA to CCAA');
            
            % CDRA In
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 2');
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 2');
            
            oLog.addVirtualValue('-1 .*("CDRA CO2 Inlet Flow 1" + "CDRA CO2 Inlet Flow 2")', 'kg/s', 'CDRA CO2 InletFlow');
            oLog.addVirtualValue('-1 .*("CDRA H2O Inlet Flow 1" + "CDRA H2O Inlet Flow 2")', 'kg/s', 'CDRA H2O InletFlow');
            
            oLog.addVirtualValue('"CDRA CO2 Outlet Flow 1" + "CDRA CO2 Outlet Flow 2"', 'kg/s', 'CDRA CO2 OutletFlow');
            oLog.addVirtualValue('"CDRA H2O Outlet Flow 1" + "CDRA H2O Outlet Flow 2"', 'kg/s', 'CDRA H2O OutletFlow');
            
            oLog.addVirtualValue('"Partial Pressure CO2" ./ 133.322', 'torr', 'Partial Pressure CO2 Torr');
            
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            
            %% Define plots
            
            oPlotter = plot@simulation.infrastructure(this);
            
            iCellNumber13x = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite13x.iCellNumber;
            iCellNumberSylobead = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Sylobead.iCellNumber;
            iCellNumber5A = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite5A.iCellNumber;
            miCellNumber = [iCellNumberSylobead, iCellNumber13x, iCellNumber5A];
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            
            csCDRA_CO2_Mass             = cell(3,2,max(miCellNumber));
            csCDRA_H2O_Mass             = cell(3,2,max(miCellNumber));
            csCDRA_Pressure             = cell(3,2,max(miCellNumber)+1);
            csCDRA_CO2_Pressure         = cell(3,2,max(miCellNumber));
            csCDRA_H2O_Pressure         = cell(3,2,max(miCellNumber));
            csCDRA_Flow_Temperature     = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_Temperature = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_FlowrateCO2 = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_FlowrateH2O = cell(3,2,max(miCellNumber));
            
            csCDRA_FlowRate = cell(3,2,max(miCellNumber));
            
            for iType = 1:3
                for iBed = 1:2
                    for iCell = 1:miCellNumber(iType)
                         csCDRA_Pressure{iType,iBed,iCell}              =  ['"Flow Pressure', csType{iType}, num2str(iBed),' Cell ',num2str(iCell), '"'];
                         
                         csCDRA_CO2_Mass{iType,iBed,iCell}              = ['"Partial Mass CO2 ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell) ,'"'];
                         csCDRA_H2O_Mass{iType,iBed,iCell}              = ['"Partial Mass H2O ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];

                         csCDRA_CO2_Pressure{iType,iBed,iCell}          = ['"Flow Pressure CO2 ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_H2O_Pressure{iType,iBed,iCell}          = ['"Flow Pressure H2O ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];

                         csCDRA_Flow_Temperature{iType,iBed,iCell}      = ['"Flow Temperature ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_Absorber_Temperature{iType,iBed,iCell}  = ['"Absorber Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         
                         csCDRA_Absorber_FlowrateCO2{iType,iBed,iCell}  = ['"Absorber Flowrate CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_Absorber_FlowrateH2O{iType,iBed,iCell}  = ['"Absorber Flowrate H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         
                         csCDRA_FlowRate{iType,iBed,iCell}              = ['"Flowrate ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell), '"'];
                    end
                    
                    csCDRA_Pressure{iType,iBed,iCell+1} = ['"Flow Pressure', csType{iType}, num2str(iBed),' MassBuffer"'];
                end
            end
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Pressure(iType,iBed,:), [csType{iType}, num2str(iBed), ' Pressure']);
                end
            end
            oPlotter.defineFigure(coPlot,  'CDRA Pressure');
            
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_CO2_Mass(iType,iBed,:), [csType{iType}, num2str(iBed), ' Adsorbed CO2 Mass']);     
                end
            end
            oPlotter.defineFigure(coPlot,  'CO2 Adsorbed Masses');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_H2O_Mass(iType,iBed,:), [csType{iType}, num2str(iBed), ' Adsorbed H2O Mass']);
                end
            end
            oPlotter.defineFigure(coPlot,  'H2O Adsorbed Masses');
            
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_CO2_Pressure(iType,iBed,:), [csType{iType}, num2str(iBed), ' CO2 Pressure Flow']);
                end
            end
            oPlotter.defineFigure(coPlot,  'CO2 Partial Pressures in Flow');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                    coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_H2O_Pressure(iType,iBed,:), [csType{iType}, num2str(iBed), ' H2O Pressure Flow']);
                end
            end
            oPlotter.defineFigure(coPlot,  'H2O Partial Pressures in Flow');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_FlowrateCO2(iType,iBed,:), [csType{iType}, num2str(iBed), ' CO2 Adsorption Flowrate']);
                end
            end
            oPlotter.defineFigure(coPlot,  'CO2 Adsorption Flow Rates');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                    coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_FlowrateH2O(iType,iBed,:), [csType{iType}, num2str(iBed), ' H2O Adsorption Flowrate']);
                end
            end
            oPlotter.defineFigure(coPlot,  'H2O Adsorption Flow Rates');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Flow_Temperature(iType,iBed,:), [csType{iType}, num2str(iBed), ' Flow Temperature']);
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_Temperature(iType,iBed,:), [csType{iType}, num2str(iBed), ' Adsorber Temperature']);
                end
            end
            oPlotter.defineFigure(coPlot,  'Temperatures');
            
            % csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            csCDRA_FlowRate{1,1,iCellNumberSylobead+1} = '"CDRA_Air_In_1"';
            csCDRA_FlowRate{1,1,iCellNumberSylobead+2} = '"CDRA_Air_Out_2"';
            
            csCDRA_FlowRate{1,2,iCellNumberSylobead+1} = '"CDRA_Air_In_2"';
            csCDRA_FlowRate{1,2,iCellNumberSylobead+2} = '"CDRA_Air_Out_1"';
            
            csCDRA_FlowRate{2,1,iCellNumber13x+1} = '"Sylobead1_to_13x1"';
            csCDRA_FlowRate{2,1,iCellNumber13x+2} = '"Zeolite5A2_to_13x1"';
            
            csCDRA_FlowRate{2,2,iCellNumber13x+1} = '"Sylobead2_to_13x2"';
            csCDRA_FlowRate{2,2,iCellNumber13x+2} = '"Zeolite5A1_to_13x2"';
            
            csCDRA_FlowRate{3,1,iCellNumber5A+1} = '"Zeolite13x1_to_5A1"';
            csCDRA_FlowRate{3,1,iCellNumber5A+2} = '"CDRA_Vent_2"';
            csCDRA_FlowRate{3,1,iCellNumber5A+3} = '"CDRA_AirSafe_2"';
            
            csCDRA_FlowRate{3,2,iCellNumber5A+1} = '"Zeolite13x2_to_5A2"';
            csCDRA_FlowRate{3,2,iCellNumber5A+2} = '"CDRA_Vent_1"';
            csCDRA_FlowRate{3,2,iCellNumber5A+3} = '"CDRA_AirSafe_1"';
            
            miCellNumber(1) = miCellNumber(1) + 2;
            miCellNumber(2) = miCellNumber(2) + 2;
            miCellNumber(3) = miCellNumber(3) + 3;
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_FlowRate(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Flowrate']);
                end
            end
            oPlotter.defineFigure(coPlot,  'FlowRates');
            
            csNormalPhasePressures = {'"Flow PressureSylobead_1 MassBuffer"', '"Flow PressureSylobead_2 MassBuffer"',...
                                      '"Flow PressureZeolite13x_1 MassBuffer"', '"Flow PressureZeolite13x_2 MassBuffer"',...
                                      '"Flow PressureZeolite5A_1 MassBuffer"', '"Flow PressureZeolite5A_2 MassBuffer"',...
                                      '"Connection Pressure CCAA to CDRA"', '"Connection Pressure CDRA to CCAA"'};
            
            coPlot = cell(2,3);
            coPlot{1,1} = oPlotter.definePlot({'"CDRA CO2 InletFlow"', '"CDRA H2O InletFlow"', '"CDRA CO2 OutletFlow"', '"CDRA H2O OutletFlow"'}, 'CDRA In- and Outlet Flows');
            coPlot{1,2} = oPlotter.definePlot({'"Condensate Flowrate CHX"'}, 'CHX Condensate Flowrate');
            coPlot{1,3} = oPlotter.definePlot({'"Partial Pressure CO2"'}, 'Partial Pressure CO2 Habitat');
            coPlot{2,1} = oPlotter.definePlot({'"Partial Pressure CO2 Torr"'}, 'Partial Pressure CO2 Habitat in Torr');
            coPlot{2,2} = oPlotter.definePlot({'"Relative Humidity Cabin"'}, 'Relative Humidity Cabin');
            coPlot{2,3} = oPlotter.definePlot(csNormalPhasePressures, 'Phase Pressures of Non-Flow Phases');
            oPlotter.defineFigure(coPlot,  'Plots');
            
            
            
            oPlotter.plot();
        end
    end
end