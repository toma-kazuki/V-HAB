classdef OGA < vsys
    
    
    %% Oxygen Generation Assembly or OGA
    %
    % The OGA is basically an electrolyzer that splits water in H2 and O2.
    % The O2 is used to replace the O2 consumed by the crew while the H2 is
    % used in the sabatier system to react CO2 and H2 to water and methane.
    %
    % Also used to simulate the russian Elektron VM electrolyzer
        
    
    properties
        oAtmosphere;
        
        %Variable to decide if the OGA is on (1) or off (0), off is standby
        bOn = true;
        %Variable to decide if elektron values should be used
        bElektron = false;
        
        fElectrolyzerOutflowTemp;
    end
    
    methods
        function this = OGA(oParent, sName, fFixedTS, fElectrolyzerOutflowTemp, bElektron, bOn)
            this@vsys(oParent, sName, fFixedTS);
            
            this.fElectrolyzerOutflowTemp = fElectrolyzerOutflowTemp;
            if nargin == 5
                this.bElektron = bElektron;
            elseif nargin == 6
                this.bElektron = bElektron;
                this.bOn = bOn;
            end
        end
            
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Setting of the ambient temperature used in nearly every
            % component to calculate the temperature exchange
            AmbientTemperature = 295.35;
            fPressure = 101325;
            
            %% Creating the stores
            
            % Creating the Buffer store before the electrolyzer
            matter.store(this, 'Buffer', 0.01);
            oLiquid = this.toStores.Buffer.createPhase(  'water',   'PhaseLiquid', 0.009, AmbientTemperature, fPressure);
            matter.procs.exmes.liquid(oLiquid, 'Port_In_1');
            components.matter.OGA.const_press_exme_liquid(oLiquid, 'Port_OutLiquid', 101325);
            
            % Creating the Electrolyzer
            matter.store(this, 'Electrolyzer', 0.225);
            % Input phase
            oH2O = matter.phases.mixture(this.toStores.Electrolyzer, 'PhaseInLiquid', 'liquid', struct('H2O', 24, 'H2', 0.1, 'O2', 0.1), AmbientTemperature, fPressure);
            
            % O2Phase 
            tO2.sSubstance = 'O2';
            tO2.sProperty = 'Density';
            tO2.sFirstDepName = 'Pressure';
            tO2.fFirstDepValue = 101325;
            tO2.sSecondDepName = 'Temperature';
            tO2.fSecondDepValue = AmbientTemperature;
            tO2.sPhaseType = 'gas';
            fDensityO2 = this.oMT.findProperty(tO2);
            oO2 = matter.phases.gas(this.toStores.Electrolyzer, ...
                          'O2Phase', ...            % Phase name
                          struct('O2', fDensityO2*0.1), ...    % Phase contents
                          0.1, ...                 % Phase volume
                          AmbientTemperature);      % Phase temperature 
                      
            
            tH2.sSubstance = 'H2';
            tH2.sProperty = 'Density';
            tH2.sFirstDepName = 'Pressure';
            tH2.fFirstDepValue = 101325;
            tH2.sSecondDepName = 'Temperature';
            tH2.fSecondDepValue = AmbientTemperature;
            tH2.sPhaseType = 'gas';
            fDensityH2 = this.oMT.findProperty(tH2);          
            oH2 = matter.phases.gas(this.toStores.Electrolyzer, ...
                          'H2Phase', ...           % Phase name
                          struct('H2', fDensityH2*0.1), ...% Phase contents
                          0.1, ...                  % Phase volume
                          AmbientTemperature);      % Phase temperature
            % Creating the ports
            matter.procs.exmes.mixture(oH2O, 'Port_In');
            
            matter.procs.exmes.mixture(oH2O, 'Port_H2_Out');
            matter.procs.exmes.gas(oH2, 'Port_H2_In');
            
            components.matter.OGA.const_press_exme(oH2, 'Port_Out_H2', 101325);
            
            matter.procs.exmes.mixture(oH2O, 'Port_O2_Out');
            matter.procs.exmes.gas(oO2, 'Port_O2_In');
            
            components.matter.OGA.const_press_exme(oO2, 'Port_Out_O2', 101325);
            
            % Create the Cellstack_manip_proc
            components.matter.OGA.CellStack_manip_proc('ElectrolyzerProcMain', oH2O, this.fElectrolyzerOutflowTemp);
            
            %p2p proc to move the O2 generated by the manip to the O2 phase
            components.matter.P2Ps.ManualP2P(this.toStores.Electrolyzer, 'O2Proc', 'PhaseInLiquid.Port_O2_Out', 'O2Phase.Port_O2_In');
            
            %p2p proc to move the H2 to the gas phase
            components.matter.P2Ps.ManualP2P(this.toStores.Electrolyzer, 'GLS_proc', 'PhaseInLiquid.Port_H2_Out', 'H2Phase.Port_H2_In');
            
            % Adding the Electrolyzer_f2fs for the Electrolyzer
            components.matter.OGA.CellStack_f2f(this, 'Electrolyzer_f2f_H2', 'Electrolyzer');
            components.matter.OGA.CellStack_f2f(this, 'Electrolyzer_f2f_O2', 'Electrolyzer');
            
            %% Creating the flowpath into, between and out of this subsystem
            % Branch for flowpath into/out of a subsystem: ('store.exme', {'f2f-processor', 'f2f-processor'}, 'system level port name')
            matter.branch(this,'Buffer.Port_In_1',          {},                         'OGA_Water_In' ,            'OGA_Water_In');
            matter.branch(this,'Electrolyzer.Port_Out_H2',   {'Electrolyzer_f2f_H2'},    'OGA_H2_Out' ,             'OGA_H2_Out');
            matter.branch(this,'Buffer.Port_OutLiquid',     {},                     	'Electrolyzer.Port_In',     'ELY_In');
            matter.branch(this,'Electrolyzer.Port_Out_O2',   {'Electrolyzer_f2f_O2'},    'OGA_O2_Out',              'OGA_O2_Out');
            
            
            % Setting of the electrolyzer power (for ISS as one tank model case!!!)
            this.toStores.Electrolyzer.aoPhases(1).toManips.substance.setPower(44.8*10);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % Create the solver
            
            solver.matter.manual.branch(this.toBranches.OGA_Water_In);
            solver.matter.residual.branch(this.toBranches.OGA_H2_Out);
            solver.matter.residual.branch(this.toBranches.ELY_In);
            solver.matter.residual.branch(this.toBranches.OGA_O2_Out);
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    
                    arMaxChange = zeros(1,this.oMT.iSubstances);
                    arMaxChange(this.oMT.tiN2I.Ar) = 0.75;
                    arMaxChange(this.oMT.tiN2I.O2) = 1;
                    arMaxChange(this.oMT.tiN2I.N2) = 0.75;
                    arMaxChange(this.oMT.tiN2I.H2) = 1;
                    arMaxChange(this.oMT.tiN2I.H2O) = 0.75;
                    arMaxChange(this.oMT.tiN2I.CO2) = 0.75;
                    arMaxChange(this.oMT.tiN2I.CH4) = 0.75;
                    tTimeStepProperties.arMaxChange = arMaxChange;
                    
                    oPhase.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            this.setThermalSolvers();
        end    
        
        
        %% Function to connect the system and subsystem level branches with each other
        function setIfFlows(this, sInlet1, sOutlet1, sOutlet2)
                this.connectIF('OGA_Water_In' , sInlet1);
                this.connectIF('OGA_O2_Out', sOutlet1);
                this.connectIF('OGA_H2_Out', sOutlet2);
                
                this.oAtmosphere = this.toBranches.OGA_O2_Out.coExmes{2}.oPhase;
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);

            if this.oTimer.iTick ~= 0
                fAtmosphereO2Press = this.oAtmosphere.afPP(this.oMT.tiN2I.O2);
                fAtmospherePress = this.oAtmosphere.fPressure;
            else
                fAtmospherePress = 101325;
                fAtmosphereO2Press = 20600;
            end
            
            %There is no actual control logic for the OGA since it is 
            %controlled by ground control. Therefore the control logic
            %implemented here will try to emulate what ground control would
            %PROBABLY do!
            %The set points are taken from ICES 2015 146 paper:
            %"Report on ISS O2 Production, Gas Supply & Partial Pressure
            %Management" Ryan N. Schaezler, Anthony J. Cook
            if this.bOn == 1
                if (fAtmosphereO2Press > 23700) || ((fAtmosphereO2Press/fAtmospherePress) > 0.235)
                    %At 24% OGA must be shut off because of fire hazard, but
                    %here it is assumed that the shut down will occur earlier
                    %standby OGA flow rate produces 0.2 kg/day of O2. The (8/9)
                    %are used to convery O2 flow to water flow! No specific
                    %value for elektron so it uses the same as OGA.
                    fElectrolyzedMassFlow = ((0.2)/(8/9))/(24*3600);
                elseif fAtmosphereO2Press < 19500
                    %Maximum OGA operation
                    if this.bElektron == 1
                    %Maximum Elektron production limit according to ICES-2015-146 (see above) 
                        fElectrolyzedMassFlow = ((5.22)/(8/9))/(24*3600);
                    else
                    %Maximum OGA production limit according to ICES-2015-146 (see above)      
                        fElectrolyzedMassFlow = ((9.25)/(8/9))/(24*3600);
                    end
                else
                    if this.bElektron == 1
                    %Nominal Elektron production limit according to ICES-2015-146 (see above) 
                        fElectrolyzedMassFlow = ((2.59)/(8/9))/(24*3600);
                    else
                    %nominal OGA operation assumed to be 31% of the max value
                    %of 9 kg/day of O2, which should be enough for ~ 3 CM. The
                    %remaining oxygen in nominal condition will be supplied by
                    %ElektronVM
                        fElectrolyzedMassFlow = ((0.31*9)/(8/9))/(24*3600);
                    end
                end
            else
                %OGA was permanently set to standby
                fElectrolyzedMassFlow = ((0.2)/(8/9))/(24*3600);
            end
            
            % Setting of fixed flow rates
            this.toBranches.OGA_Water_In.oHandler.setFlowRate(-fElectrolyzedMassFlow);
        end
	end
end