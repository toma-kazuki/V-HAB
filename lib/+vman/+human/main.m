classdef main < vsys
    % human model subsystem. ideally one subsystem is used for each Crew
    % Member with an individual crew planer for each subsystem / crew
    % member. However it is also possible to define the system to represent
    % multiple crew members, in that case however it is necessary to be
    % aware that a schedule for the restroom events is required as well.
    % Otherwise all crew member represented by the subsystem would use the
    % restroom at the same time.
    %
    
    properties
        
        %Number of Crew Members used for this simulation
        iCrewMembers = 1;
        
        %% Crew Planer Properties
        %struct containing the human metabolic values for O2 consumption,
        %heat relase, CO2, TC and H2O production
        tHumanMetabolicValues;
        
        %current state the crew is in containing a field for each crew
        %member that contains a string with the current status for that
        %crew member. For example if crew member one is sleeping the first
        %field contains the string 'sleep'
        cCrewState;
        
        %vector with one field for each crew member that contains when the
        %current state for this crew member began. Necessary for automatic
        %changes between certain states
        mCrewStateStartTime; %s
        
        %cell array as planer for crew activities that contains one row for
        %each crew member and one column per event. Each field therefore 
        %stands for a certain event for a certain crew member. For example
        %if crew member 2 falls asleep the second row would contain an
        %event 'sleep'. Each event is a struct containing the fields sName
        %for the event name (sleep) a start time when this event should
        %begin and an end time when it should end. It also contains two
        %boolean variables to keep track if the event has already started
        %or ended
        tCrewPlaner = [];
        
        afInitialMassSolidFood;
        afInitialMassLiquidFood;
        
        fInitialMassFeces;
        fInitialMassUrine;
        
        bAlreadyWarned = false;
        
        sGenericDrinkEvent;
        
        % Random factors to trigger restroom events
        fRandomUrineFactor = 0.2*rand(1,1);
        fRandomFecesFactor = 0.1*rand(1,1);
        
        fEatStartTime = -1;
        
        % according to BVAD page 43 table 3.21
        fNominalDailyEnergyRequirement = 12.996*10^6; % J
        
        % Vector that contains the current requirement of energy that has
        % to be supplied from food for each crew member
        miEnergyRequirement;
        
        mfTotalRequiredFoodMass;
        fSetTimeFoodRequirement = - 48 * 3600;
        
        tMealTimes;
    end
    
    methods
        function this = main(oParent, sName, iCrewMembers, tCrewPlaner, tMealTimes)
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
            this@vsys(oParent, sName, 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            this.iCrewMembers = iCrewMembers;
            this.tCrewPlaner = tCrewPlaner;
            
            this.sGenericDrinkEvent.fConsumption = 0.2;
            this.sGenericDrinkEvent.bSolid = false;
            
            this.miEnergyRequirement = zeros(this.iCrewMembers,1);
            for iK = 1:this.iCrewMembers
                this.miEnergyRequirement(iK) = this.fNominalDailyEnergyRequirement;
            end
            
            this.tMealTimes = tMealTimes;
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Temperature used in the human model for the phases. This MUST
            % BE DIFFERENT from the normal temperature a human would have
            % (about 38�C) because the HEAT RELEASE IS MODELLED
            % SEPERATLY!!! 
            % For example if the CO2 the human released had a temperature
            % of 38�C while the cabin has 22�C that would result in an
            % additional heat flow from the human to the cabin. But since a
            % dedicated calculation for the heat release of the humans is
            % used this HAS TO BE OMITTED for a correct calculation!
            fHumanTemperature = 295; %~22�C
            
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                        CREW Values                      %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %the model for the crew does not have a mass balance since
            %there is no food taken into account. Also a lot of the actual
            %processes are severly simplified.
            %all values taken from NASA/TP-2015�218570 "Life Support 
            %Baseline Values and Assumptions Document"
            
            %these are multiple states for the human metabolic rate taken
            %from table 3.22 in the above mentioned document saved into a
            %struct to allow easy access:
            this.tHumanMetabolicValues = struct();
            %all values converted to SI units
            %sleeping state
            this.tHumanMetabolicValues.sleep.fDryHeat = 224*1000/3600;
            this.tHumanMetabolicValues.sleep.fWaterVapor = (6.3*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fSweat = 0;
            this.tHumanMetabolicValues.sleep.fO2Consumption = (3.6*10^-4)/60;
            this.tHumanMetabolicValues.sleep.fCO2Production = (4.55*10^-4)/60;
            %nominal state
            this.tHumanMetabolicValues.nominal.fDryHeat = 329*1000/3600;
            this.tHumanMetabolicValues.nominal.fWaterVapor = (11.77*10^-4)/60;
            this.tHumanMetabolicValues.nominal.fSweat = 0;
            this.tHumanMetabolicValues.nominal.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.nominal.fCO2Production = (7.2*10^-4)/60;
            %exercise minute 0-15
            this.tHumanMetabolicValues.exercise015.fDryHeat = 514*1000/3600;
            this.tHumanMetabolicValues.exercise015.fWaterVapor = (46.16*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fSweat = (1.56*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise015.fCO2Production = (49.85*10^-4)/60;
            %exercise minute 15-30
            this.tHumanMetabolicValues.exercise1530.fDryHeat = 624*1000/3600;
            this.tHumanMetabolicValues.exercise1530.fWaterVapor = (128.42*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fSweat = (33.52*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fO2Consumption = (39.40*10^-4)/60;
            this.tHumanMetabolicValues.exercise1530.fCO2Production = (49.85*10^-4)/60;
            %recovery minute 0-15
            this.tHumanMetabolicValues.recovery015.fDryHeat = 568*1000/3600;
            this.tHumanMetabolicValues.recovery015.fWaterVapor = (83.83*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fSweat = (15.16*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery015.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 15-30
            this.tHumanMetabolicValues.recovery1530.fDryHeat = 488*1000/3600;
            this.tHumanMetabolicValues.recovery1530.fWaterVapor = (40.29*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fSweat = (0.36*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery1530.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 30-45
            this.tHumanMetabolicValues.recovery3045.fDryHeat = 466*1000/3600;
            this.tHumanMetabolicValues.recovery3045.fWaterVapor = (27.44*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery3045.fCO2Production = (7.2*10^-4)/60;
            %recovery minute 45-60
            this.tHumanMetabolicValues.recovery4560.fDryHeat = 455*1000/3600;
            this.tHumanMetabolicValues.recovery4560.fWaterVapor = (20.4*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fSweat = (0*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fO2Consumption = (5.68*10^-4)/60;
            this.tHumanMetabolicValues.recovery4560.fCO2Production = (7.2*10^-4)/60;
            
            %defines the initial crew conditions as nominal for each crew
            %member and sets the start time for this event to 0
            for k = 1:this.iCrewMembers
                this.cCrewState{k} = 'nominal';
                this.mCrewStateStartTime(k) = 0;
            end
            
            %% Breathing
            % This part of the code is used to model the O2 consumption and
            % CO2 release
            tfMasses = struct('C', 0.5, 'O2', 0.4);
            fSolidVolume = this.oMT.calculateSolidVolume(tfMasses, fHumanTemperature, true);
            
            tfMassesStomache = struct('C', 0.5, 'H2O', 0.5*0.42);
            fSolidVolumeStomache = this.oMT.calculateSolidVolume(tfMasses, fHumanTemperature, true);
            
            tfMassesFeces =  struct('Feces', 0.092, 'H2O', 0.091);
            fSolidVolumeFeces = this.oMT.calculateSolidVolume(tfMasses, fHumanTemperature, true);
            
            fLiquidFoodVolume   = 2e-4;
            fBladderVolume      = 1e-4;
            
            matter.store(this, 'Human', 2 + fSolidVolume + fSolidVolumeStomache + fSolidVolumeFeces + fLiquidFoodVolume + fBladderVolume);
            
            % uses the custom air helper to generate an air phase with a
            % defined co2 level and relative humidity
            fCO2Percent = 0.0062;
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Human, 2, struct('CO2', fCO2Percent),  fHumanTemperature, 0.4, 101325);
               
            oAirPhase = matter.phases.gas(this.toStores.Human, 'Air', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            matter.procs.exmes.gas(oAirPhase, 'AirHumanModelIn');
            matter.procs.exmes.gas(oAirPhase, 'AirHumanModelOut');
            matter.procs.exmes.gas(oAirPhase, 'O2_Out');
            matter.procs.exmes.gas(oAirPhase, 'CO2_In');
            matter.procs.exmes.gas(oAirPhase, 'Humidity_In');
            
            % Since mutliple gas phases in one store no longer yield
            % correct results (wrong volumes) a solid phase is first used
            % to absorb the consumed oxygen and then react it with C to CO2
            oBreathingProcessorPhase = matter.phases.absorber(this.toStores.Human, 'ProcessPhase', tfMasses, fHumanTemperature, 'solid', 'C'); 
            
            matter.procs.exmes.absorber(oBreathingProcessorPhase, 'O2_In');
            matter.procs.exmes.absorber(oBreathingProcessorPhase, 'C_In');
            matter.procs.exmes.absorber(oBreathingProcessorPhase, 'CO2_Out');
            
            % And a p2p proc that removes the consumed O2 from the cabin
            % phase
            vman.human.components.Crew_Respiratory_Simulator_O2(this.toStores.Human, 'O2_P2P', 'Air.O2_Out', 'ProcessPhase.O2_In');
            
            % Manipulator to transform the O2 the humans breathed in into
            % CO2 (does not result in closed mass balance, but it at least
            % somewhat closes it)
            vman.human.components.Human_O2_to_CO2_Converter('O2_to_CO2_Converter', oBreathingProcessorPhase);
            
            % And a p2p proc that removes the produced CO2 from the process
            % phase
            vman.human.components.Crew_Respiratory_Simulator_CO2(this.toStores.Human, 'CO2_P2P', 'ProcessPhase.CO2_Out', 'Air.CO2_In');
            
            %% Digestion (solid)
            % this part of the code is used to model the solid food intake
            % (differing from the liquid intake called drinking) and
            % subsequent production of solid waste (feces). It is assumed
            % that the water provided from the solid food also counts
            % towards the amount of liquid the humans drink
            
            oStomacheSolidPhase = matter.phases.solid(this.toStores.Human, 'SolidFood', tfMassesStomache, [], fHumanTemperature);
            
            this.afInitialMassSolidFood = oStomacheSolidPhase.afMass;
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.solid(oStomacheSolidPhase, 'Solid_Food_In');
            matter.procs.exmes.solid(oStomacheSolidPhase, 'C_Out');
            matter.procs.exmes.solid(oStomacheSolidPhase, 'Feces_Out_Internal');
            matter.procs.exmes.solid(oStomacheSolidPhase, 'H2O_Out_Internal');
            
            vman.human.components.Breathing_Carbon_Supply(this.toStores.Human, 'C_from_food_to_breathing', 'SolidFood.C_Out', 'ProcessPhase.C_In');
            
            oFecesPhase = matter.phases.solid(this.toStores.Human, 'Feces', tfMassesFeces, [], fHumanTemperature);
            this.fInitialMassFeces = oFecesPhase.fMass;
            
            matter.procs.exmes.solid(oFecesPhase, 'Feces_In_Internal');
            matter.procs.exmes.solid(oFecesPhase, 'Feces_Out');
            
            % add a manip that converts food to feces
            vman.human.components.Food_to_Feces_Converter('Food_to_Feces_Manip', oStomacheSolidPhase);
            
            % add a p2p to move the feces to a different phase
            vman.human.components.Feces_Removal(this.toStores.Human, 'Feces_Removal', 'SolidFood.Feces_Out_Internal', 'Feces.Feces_In_Internal');
            
            %% Digestion (liquid)
            % this part of the code is used to model drinking and
            % subsequent production of liquid waste (urine) and
            % sweat/humidity
            
            oStomacheLiquidPhase = matter.phases.liquid(this.toStores.Human, 'LiquidFood', struct('H2O', fLiquidFoodVolume*999), fLiquidFoodVolume, fHumanTemperature, 101325); 
            
            this.afInitialMassLiquidFood = oStomacheLiquidPhase.afMass;
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.liquid(oStomacheLiquidPhase, 'Liquid_Food_In'); % liquid that the crewmember drank
            matter.procs.exmes.liquid(oStomacheLiquidPhase, 'H2O_In_Internal'); % water from solid food
            matter.procs.exmes.liquid(oStomacheLiquidPhase, 'Urine_Out_Internal');
            
            matter.procs.exmes.liquid(oStomacheLiquidPhase, 'Humidity_Out');
            
            % Adds a p2p proc that removes part of the liquid the human
            % consumed to produce humidity. The remaining liquid is assumed
            % to transform into urine
            vman.human.components.Crew_Humidity_Generator(this.toStores.Human, 'Humidity_P2P', 'LiquidFood.Humidity_Out', 'Air.Humidity_In');
            
            oBladderPhase = matter.phases.liquid(this.toStores.Human, 'Urine', struct('Urine', fBladderVolume *999.1), fBladderVolume , fHumanTemperature, 101325); 
            
            this.fInitialMassUrine = oBladderPhase.fMass;
            
            matter.procs.exmes.liquid(oBladderPhase, 'Urine_In_Internal');
            matter.procs.exmes.liquid(oBladderPhase, 'Urine_Out');
            
            % add a manip that converts water to urine
            vman.human.components.Water_to_Urine_Converter('Water_to_Urine_Manip', oStomacheLiquidPhase);
            
            % add a p2p to move the urine to a different phase
            vman.human.components.Urine_Removal(this.toStores.Human, 'Urine_Removal', 'LiquidFood.Urine_Out_Internal', 'Urine.Urine_In_Internal');
            
            %% connecting p2p procs
            
            % Adds a p2p proc that removes the water taken in with the food
            % (this water is then rerouted to the digestion liquid part of
            % the model)
            vman.human.components.Food_H2O_Removal(this.toStores.Human, 'Food_H2O_P2P', 'SolidFood.H2O_Out_Internal', 'LiquidFood.H2O_In_Internal');
            
            % TO DO: Add a manip that converts ingoing food of various
            % composition (e.g. carrots, peanuts) into C and feces and add
            % a calculation of the nutrition the human gets from the food.
            % If the nutrition is not properly balanced add states of
            % sickness and/or death. Also use some of the H2O in the manip
            % that produces feces (since they also retain some water)
            
            
            %% Human Thermal Model (simplified)
            % TO DO: everything
            
            %% Interface branches of the human subsystem to other systems
            % This includes the output of CO2, feces, urine and humidity
            % and the intake of food, water and O2
            
            matter.branch(this, 'Human.AirHumanModelIn', {}, 'Air_In', 'Air_In');
            matter.branch(this, 'Human.AirHumanModelOut', {}, 'Air_Out', 'Air_Out');
            
            matter.branch(this, 'Human.Solid_Food_In', {}, 'Solid_Food_In', 'Solid_Food_In');
            matter.branch(this, 'Human.Feces_Out', {}, 'Feces_Out', 'Feces_Out');
            
            matter.branch(this, 'Human.Liquid_Food_In', {}, 'Liquid_Food_In', 'Liquid_Food_In');
            matter.branch(this, 'Human.Urine_Out', {}, 'Urine_Out', 'Urine_Out');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.residual.branch(this.toBranches.Air_Out);
            
            solver.matter.manual.branch(this.toBranches.Air_In);
            this.toBranches.Air_In.oHandler.setFlowRate(-this.iCrewMembers*0.1);
            
            solver.matter.manual.branch(this.toBranches.Solid_Food_In);
            solver.matter.manual.branch(this.toBranches.Feces_Out);
            solver.matter.manual.branch(this.toBranches.Liquid_Food_In);
            solver.matter.manual.branch(this.toBranches.Urine_Out);
            
            
            %All phases except the human air phase work with a 60s time
            %step
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    if ~strcmp(this.toStores.(csStoreNames{iStore}).aoPhases(iPhase).sName, 'Air')
                        oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                        oPhase.fFixedTS = this.fTimeStep;
                    end
                end
            end
            
        end
        
        function setIfFlows(this, sInterface1, sInterface2, sInterface3, sInterface4, sInterface5, sInterface6)
            this.connectIF('Air_In' , sInterface1);
            this.connectIF('Air_Out' , sInterface2);
            this.connectIF('Solid_Food_In', sInterface3);
            this.connectIF('Feces_Out', sInterface4);
            this.connectIF('Liquid_Food_In', sInterface5);
            this.connectIF('Urine_Out', sInterface6);
        end
        
        function setCrew(this, iCrewMembers)
            % TO DO: reimplement the possibility to discretize the habitat
            % volume! Question, implement that part on the subsystem level
            % or within the main system where the discretization takes
            % place?
            this.iCrewMembers = iCrewMembers;
        end
        
        function consumeFood(this, fFoodMass)
            % Function used by the main system once the food preperation is
            % finished that tells the human to eat the food
            this.toBranches.Solid_Food_In.oHandler.setFlowRate(-fFoodMass/this.fTimeStep);
            this.fEatStartTime = this.oTimer.fTime;
        end
    end
    
    methods (Access = protected)
        
        function triggerFoodEvent(this, tEvent)
            %function used to trigger the food consumption of the crew
            %member
            if tEvent.bSolid
%                 tEvent.fConsumption; % consumed food mass
%                 tEvent.arFoodComposition; % consumed food composition (vector according to matter table)

                this.oParent.requestFood(this.sName, tEvent)
                % Implement request food event in parent system that
                % triggers the perperation of the food? 
                % TO DO: Finish eating simulation!
            else
               % if the crew member is drining instead of eating he just gets water from the potable water store (over ~ 60s)
               fWaterConsumptionFlowRate = tEvent.fConsumption/this.fTimeStep;
               this.toBranches.Liquid_Food_In.oHandler.setFlowRate(-fWaterConsumptionFlowRate);
            end
        end
        
        function triggerRestroomEvent(this, bLarge)
            %function used to trigger the restroom use of the crew member
            if this.iCrewMembers > 1
                % If the human model represents more than one crew member
                % the feces and urine in the stores of the human model are
                % "shared" between the humans (strange thought right^^) and
                % therefore it is necessary to find some way to distribute
                % them somewhat equally and yet also somewhat random
                fMassUrinePerCM = (this.toStores.Human.toPhases.Urine.fMass - this.fInitialMassUrine)/this.iCrewMembers;
                
                if fMassUrinePerCEM < 0
                    fUrineMassEvent = 0;
                elseif fMassUrinePerCEM < 0.1
                    fUrineMassEvent = fMassUrinePerCM;
                else
                    fUrineMassEvent = 0.1 + rand(1,1)*(fMassUrinePerCEM-0.1);
                end
                
                if bLarge
                    fMassFecesPerCM = (this.toStores.Human.toPhases.Feces.fMass - this.fInitialMassFeces)/this.iCrewMembers;
                    if fMassFecesPerCEM < 0
                        fFecesMassEvent = 0;
                    elseif fMassFecesPerCEM < 0.2
                        fFecesMassEvent = fMassFecesPerCM;
                    else
                        fFecesMassEvent = 0.2 + rand(1,1)*(fMassFecesPerCEM - 0.2);
                    end
                    this.toBranches.Urine_Out.oHandler.setFlowRate(fUrineMassEvent/this.fTimeStep);
                    this.toBranches.Feces_Out.oHandler.setFlowRate(fFecesMassEvent/this.fTimeStep);
                else
                    this.toBranches.Urine_Out.oHandler.setFlowRate(fUrineMassEvent/this.fTimeStep);
                end
            else
                % if the model only represents one human it is easier since
                % the mass in the store belongs to this one human and it
                % can be assumed that they are completly emptied during
                % each event (the events for one human are already
                % randomized)
                if bLarge
                    this.toBranches.Urine_Out.oHandler.setFlowRate((this.toStores.Human.toPhases.Urine.fMass - this.fInitialMassUrine)/this.fTimeStep);
                    this.toBranches.Feces_Out.oHandler.setFlowRate((this.toStores.Human.toPhases.Feces.fMass - this.fInitialMassFeces)/this.fTimeStep);
                else
                    this.toBranches.Urine_Out.oHandler.setFlowRate((this.toStores.Human.toPhases.Urine.fMass - this.fInitialMassUrine)/this.fTimeStep);
                end
            end
        end
        
        function exec(this, ~)
            % exec(ute) function for this system
            exec@vsys(this);
            
            % Overwrites previously set food consumtpion flowrates (all
            % food intake is assumed to occur within one TS)
            this.toBranches.Liquid_Food_In.oHandler.setFlowRate(0);
            if this.oTimer.fTime > this.fEatStartTime
                this.toBranches.Solid_Food_In.oHandler.setFlowRate(0);
                this.fEatStartTime = -1;
            end
            
            this.toBranches.Feces_Out.oHandler.setFlowRate(0);
            this.toBranches.Urine_Out.oHandler.setFlowRate(0);
            
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%              Crew Metabolism Simulator                  %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % this section sets the correct values for the humans according
            % to their current state and also takes care of automatic
            % transitions to follow up states (like recovery after
            % exercise)
            
            %%%%%%%%%%%%%% automatic crew state changes %%%%%%%%%%%%%%%%%%% 
            % switches the crew state between the different time dependant
            % states automatically
            for k = 1:this.iCrewMembers
                if strcmp(this.cCrewState{k}, 'exercise015')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'exercise1530';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery015')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery1530';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery1530')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery3045';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
               	elseif strcmp(this.cCrewState{k}, 'recovery3045')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'recovery4560';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                elseif strcmp(this.cCrewState{k}, 'recovery4560')
                    if (this.oTimer.fTime-this.mCrewStateStartTime(k)) > 900
                        this.cCrewState{k} = 'nominal';
                        this.mCrewStateStartTime(k) = this.oTimer.fTime;
                    end
                end
            end
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%  Metabolism crew state planner %%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % using the tCrewPlaner.cMetabolism variable for this object it is
            % possible to set different states for each crew member for
            % different times. This section takes care of all the necessary
            % allocations regarding the metabolis
            
            % if the variable is empty nothing happens because nothing is
            % planned for the crew. In that case the initial values remain
            % valid for the whole simulation.
            if ~isempty(this.tCrewPlaner.cMetabolism)
                %if the planer is not empty it has to move through each
                %crew member. The index used for this is iCM (for Crew
                %Member)
                miCrewPlanerSize = size(this.tCrewPlaner.cMetabolism);
                for iCM = 1:miCrewPlanerSize(1)
                    %each CM may have multiple events assigned so it is
                    %necessary to iterate through all the events as well
                    for iEvent = 1:miCrewPlanerSize(2)
                        %if the event start time has been reached and the event
                        %has not been started yet the crew state has to be
                        %switched
                        if (this.tCrewPlaner.cMetabolism{iCM,iEvent}.Start < this.oTimer.fTime) && (~this.tCrewPlaner.cMetabolism{iCM,iEvent}.Started)
                            this.cCrewState{iCM} = this.tCrewPlaner.cMetabolism{iCM,iEvent}.State;
                            if strcmp(this.tCrewPlaner.cMetabolism{iCM,iEvent}.State, 'exercise015') || strcmp(this.tCrewPlaner.cMetabolism{iCM,iEvent}.State, 'EVA')
                                fExerciseTime = this.tCrewPlaner.cMetabolism{iCM,iEvent}.End - this.tCrewPlaner.cMetabolism{iCM,iEvent}.Start;
                                % according to NASA STD 3001 Vol 2A for one
                                % hour of EVA 837 kJ of additional energy
                                % have to supply via the food. It is
                                % assumed that for exercise the same rule
                                % applies
                                this.miEnergyRequirement(iCM) = this.miEnergyRequirement(iCM) + (fExerciseTime/3600)*837000;
                            end
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.Started = true;
                            this.mCrewStateStartTime(iCM) = this.oTimer.fTime;
                        %if the event end time has been reached and the event
                        %has not ended yet the crew state has to be switched
                        elseif (this.tCrewPlaner.cMetabolism{iCM,iEvent}.End < this.oTimer.fTime) && (~this.tCrewPlaner.cMetabolism{iCM,iEvent}.Ended)
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.Ended = true;
                            %if the crew member was sleeping --> enter nominal
                            %state
                            if strcmp(this.tCrewPlaner.cMetabolism{iCM,iEvent}.State, 'sleep');
                                this.cCrewState{iCM} = 'nominal';
                            %of the crew member was working out --> enter
                            %recovery state
                            else
                                this.cCrewState{iCM} = 'recovery015';
                            end
                            this.mCrewStateStartTime(iCM) = this.oTimer.fTime;
                        end
                        % for repetition of events:
                        if this.tCrewPlaner.cMetabolism{iCM,iEvent}.bRepeat && this.tCrewPlaner.cMetabolism{iCM,iEvent}.Ended
                            % If the event is supposed to repeat it is 
                            % repeated each day (every 24 h). Therefore
                            % the parameters are set to enable this
                            % repetition
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.Start = this.tCrewPlaner.cMetabolism{iCM,iEvent}.Start + (24*3600);
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.End = this.tCrewPlaner.cMetabolism{iCM,iEvent}.End + (24*3600);
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.Started = false;
                            this.tCrewPlaner.cMetabolism{iCM,iEvent}.Ended = false;
                        end
                    end
                end
            end
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%  food crew state planner %%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Calculates the energy requirement of the humans once per day
            if (this.oTimer.fTime - this.fSetTimeFoodRequirement) > 24*3600
                fTotalEnergyRequirement = 0;
                for iCM = 1:this.iCrewMembers
                    fTotalEnergyRequirement = fTotalEnergyRequirement + this.miEnergyRequirement(iCM);
                end

                % According to the calculated energy requirement three meals
                % are consumed:
                % It is assumed here that 1.26 kg of food contain exactly the
                % nominal required amount of energy per crew member (based on
                % BVAD page 106 table 4.54, the assumed nominal energy
                % requirement here is 12.996 MJ/day therefore the value is
                % slightly larger than the one from BVAD. Overall this means
                % that each kg of food contains 10.315 MJ of energy.
                % TO DO: Use food matter table for these calculations once it
                % is available.
                fEnergyPerKilo = 10.315 *10^6; % J
                
                this.mfTotalRequiredFoodMass = zeros(this.oMT.iSubstances,1);
                this.mfTotalRequiredFoodMass(this.oMT.tiN2I.C) = fTotalEnergyRequirement / fEnergyPerKilo;
                
                this.fSetTimeFoodRequirement = this.oTimer.fTime;
            end
            
            if this.oTimer.fTime > this.tMealTimes.Breakfast
                
                tBreakfast = struct();
                tBreakfast.bSolid = true;
                % TO DO: Once food matter table is implement include it
                % here to correctly reflect different foods.
                
                % food mass consumed during breakfast, assumes that 20% of
                % the total required food is consumed for breakfast
                tBreakfast.fConsumption = this.mfTotalRequiredFoodMass(this.oMT.tiN2I.C)*0.2; 
                
                % the next values makes it defineable what the human eats (like
                % carrots, peas and meat for lunch and bread with jam for
                % breakfast...) by defining the partial mass composition of the
                % total consumed mass (so if you want him to eat 10% jam and
                % 90% bread then set the value for bread to 0.9 and for carrots
                % to 0.1)
                tBreakfast.arFoodComposition = zeros(this.oMT.iSubstances);
                tBreakfast.arFoodComposition(this.oMT.tiN2I.C) = 1; %at the moment the crew only eats raw carbon... MMMHH Yummy
                
                this.triggerFoodEvent(tBreakfast);
                
                this.tMealTimes.Breakfast = this.tMealTimes.Breakfast + (24*3600);
            end
            
            if this.oTimer.fTime > this.tMealTimes.Lunch
                
                tLunch = struct();
                tLunch.bSolid = true;
                % TO DO: Once food matter table is implement include it
                % here to correctly reflect different foods.
                
                % food mass consumed during Lunch, assumes that 50% of
                % the total required food is consumed for Lunch
                tLunch.fConsumption = this.mfTotalRequiredFoodMass(this.oMT.tiN2I.C)*0.5; 
                
                % the next values makes it defineable what the human eats (like
                % carrots, peas and meat for lunch and bread with jam for
                % breakfast...) by defining the partial mass composition of the
                % total consumed mass (so if you want him to eat 10% jam and
                % 90% bread then set the value for bread to 0.9 and for carrots
                % to 0.1)
                tLunch.arFoodComposition = zeros(this.oMT.iSubstances);
                tLunch.arFoodComposition(this.oMT.tiN2I.C) = 1; %at the moment the crew only eats raw carbon... MMMHH Yummy
                
                this.triggerFoodEvent(tLunch);
                
                this.tMealTimes.Lunch = this.tMealTimes.Lunch + (24*3600);
            end
            
            if this.oTimer.fTime > this.tMealTimes.Dinner
                
                tDinner = struct();
                tDinner.bSolid = true;
                % TO DO: Once food matter table is implement include it
                % here to correctly reflect different foods.
                
                % food mass consumed during Dinner, assumes that 30% of
                % the total required food is consumed for Dinner
                tDinner.fConsumption = this.mfTotalRequiredFoodMass(this.oMT.tiN2I.C)*0.3; 
                
                % the next values makes it defineable what the human eats (like
                % carrots, peas and meat for lunch and bread with jam for
                % breakfast...) by defining the partial mass composition of the
                % total consumed mass (so if you want him to eat 10% jam and
                % 90% bread then set the value for bread to 0.9 and for carrots
                % to 0.1)
                tDinner.arFoodComposition = zeros(this.oMT.iSubstances);
                tDinner.arFoodComposition(this.oMT.tiN2I.C) = 1; %at the moment the crew only eats raw carbon... MMMHH Yummy
                
                this.triggerFoodEvent(tDinner);
                
                this.tMealTimes.Dinner = this.tMealTimes.Dinner + (24*3600);
            end
            
            % aside from planned events the humans can also become hungry
            % or thirsty (for example if a human exercises the sweat has to
            % be replaced) by themselves
            if this.toStores.Human.toPhases.LiquidFood.afMass(this.oMT.tiN2I.H2O) < this.afInitialMassLiquidFood(this.oMT.tiN2I.H2O)
                this.triggerFoodEvent(this.sGenericDrinkEvent);
            end
            
            %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%  restroom crew state planner %%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if this.iCrewMembers == 1
                if isfield(this.tCrewPlaner, 'cRestroom') && ~this.bAlreadyWarned
                    warning('a restroom schedule was given to the subsystem but it only simulates one human, therefore internal calculations are used to schedule restroom events instead!')
                    this.bAlreadyWarned = true;
                end
                if (this.toStores.Human.toPhases.Feces.fMass - this.fInitialMassFeces) > 0.1 + this.fRandomFecesFactor % values are just an initial guess atm
                    this.triggerRestroomEvent(true);
                    this.fRandomFecesFactor = 0.1*rand(1,1);
                end

                if (this.toStores.Human.toPhases.Urine.fMass - this.fInitialMassUrine) > 0.1 + this.fRandomUrineFactor % values are just an initial guess atm
                    this.triggerRestroomEvent(false);
                    this.fRandomUrineFactor = 0.2*rand(1,1);
                end
            else
                if ~isempty(this.tCrewPlaner.cRestroom)
                    %if the planer is not empty it has to move through each
                    %crew member. The index used for this is iCM (for Crew
                    %Member)
                    miCrewPlanerRestroomSize = size(this.tCrewPlaner.cRestroom);
                    for iCM = 1:miCrewPlanerRestroomSize(1)
                        %each CM may have multiple events assigned so it is
                        %necessary to iterate through all the events as well
                        for iEvent = 1:miCrewPlanerRestroomSize(2)
                           if (this.oTimer.fTime > this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(1)) && (this.oTimer.fTime < this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(2)) && ~(this.tCrewPlaner.cRestroom{iCM,iEvent}.Ended)
                                fTotalTime = this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(2) - this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(1);

                                if isempty(this.tCrewPlaner.cRestroom{iCM,iEvent}.fStartTime)
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.fStartTime = this.oTimer.fTime;
                                end

                                fAverageTimeBetweenEvents = fTotalTime/this.tCrewPlaner.cRestroom{iCM,iEvent}.NumberOfEvents;

                                iCurrentEvent = floor(((this.oTimer.fTime - this.tCrewPlaner.cRestroom{iCM,iEvent}.fStartTime)/fAverageTimeBetweenEvents)+1);

                                if iCurrentEvent > this.tCrewPlaner.cRestroom{iCM,iEvent}.iNumberOfEventsExecuted

                                    % now we use the random function to decide
                                    % when the event will take place (within
                                    % the defined time intervall)
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.fNextEventTime = (fAverageTimeBetweenEvents * rand(1,1)) + this.tCrewPlaner.cRestroom{iCM,iEvent}.fStartTime + (this.tCrewPlaner.cRestroom{iCM,iEvent}.iNumberOfEventsExecuted*fAverageTimeBetweenEvents);

                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.iNumberOfEventsExecuted = this.tCrewPlaner.cRestroom{iCM,iEvent}.iNumberOfEventsExecuted+1;
                                end

                                if this.oTimer.fTime > this.tCrewPlaner.cRestroom{iCM,iEvent}.fNextEventTime 
                                    this.triggerRestroomEvent(this.tCrewPlaner.cRestroom{iCM,iEvent});
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.fNextEventTime = inf;
                                end

                            elseif (this.oTimer.fTime > this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(2))
                                % if the event is to be repeated it will be
                                % repeated in 24h
                                if this.tCrewPlaner.cRestroom{iCM,iEvent}.bRepeat
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.Ended = false;
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(1) = this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(1) + (24*3600);
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(2) = this.tCrewPlaner.cRestroom{iCM,iEvent}.TimeIntervall(2) + (24*3600);
                                    this.tCrewPlaner.cRestroom{iCM,iEvent}.fStartTime = [];
                                else
                                    % if not the event is set to have ended
                                    this.tCrewPlaner.cFood{iCM,iEvent}.Ended = true;
                                end
                            end
                        end
                    end
                elseif  ~this.bAlreadyWarned
                    warning('if the human model represents more than one crew member a restroom schedule is necessary')
                    this.bAlreadyWarned = true;
                end
            end
        end
    end
end

