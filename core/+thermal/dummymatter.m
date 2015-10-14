classdef dummymatter < matter.store
    %DUMMYMATTER A dummy stationary mass object
    %   The dummy matter is a simple matter.store that only holds one
    %   homogenous, single-substance phase. Used to model simple matter
    %   stores that do not change much. If you are using this, you are
    %   likely doing it wrong (or prototyping).
    
    properties (SetAccess = protected)
        
        oPhase; % Reference to phase. A dummy matter can only handle one phase!
        
        % Properties that can be overloaded and used instead of the phase
        % properties.
        
        fTemperature  = -1; % The temperature of the object in |K|.
        
        fMolarMass = -1; % The molar mass of the object in |kg/mol|.
        fDensity   = -1; % The density of the object in |kg/m^3|.
        % Already defined by superclass: fVolume    = -1; % The volume of the object in |m^3|.
        fMass      = -1; % The total mass of the object in |kg|.
        
        fTotalHeatCapacity = -1; % The total heat capacity of the object in |J/K|.
        
    end
    
    methods
        
        function this = dummymatter(oContainer, sName, fVolume)
            % Create a new dummy (stationary) matter object with a matter
            % container, a (dummy) store name, and a store volume. 
            
            % Call the superconstructor to make this a proper instance of 
            % |matter.store|.
            this@matter.store(oContainer, sName, fVolume);
            
        end
        
        function addCreatePhase(this, sSubstance, sPhase, fTemperature, fDensity, fSpecificHeatCap)
            % Fast-track method to create and add a single phase to the
            % dummy matter object. |sSubstance| is the type of matter (e.g.
            % Al, O2, N2), |sPhase| the state of the matter. The fourth
            % (|fDensity| in |kg/m^3|) and fifth (|fSpecificHeatCap| in
            % |J/(kg*K)|) parameter is optional and will be  loaded from
            % the matter table if not provided. 
            
            % Fail if phase object was already set for this instance. 
            if ~isempty(this.oPhase) && isvalid(this.oPhase)
                this.throw('thermal:dummymatter:createPhase', 'Phase already defined. You can only add one phase to a dummy matter object!');
            end
            
            % Create new masses array and fill it with a dummy mass (of the
            % supplied substance) so we can calculate matter properties per
            % mass).
            afMasses = zeros(1, this.oMT.iSubstances);
            afMasses(this.oMT.tiN2I.(sSubstance)) = 1;
            
            % Load substance properties from the matter table: Molar mass.
            this.fMolarMass = this.oMT.calculateMolarMass(afMasses);
            
            % Load density from matter table if not provided. 
            if nargin <= 4
                this.fDensity = this.oMT.calculateDensity(sPhase, afMasses, fTemperature, this.oMT.Standard.Pressure);
            else 
                this.fDensity = fDensity;
            end
            
            % Load specific heat capacity from matter table if not
            % provided.
            bOverwriteHeatCapacity = true;
            if nargin <= 5
                bOverwriteHeatCapacity = false;
                fSpecificHeatCap = this.oMT.calculateHeatCapacity(sPhase, afMasses, fTemperature, this.oMT.Standard.Pressure);
            end
            
            % Calculate the mass of the phase (and thus matter object) in 
            % |kg|.
            this.fMass = this.fDensity * this.fVolume;
            
            % Calculate the object's actual heat capacity in |J/K|.
            this.fTotalHeatCapacity = this.fMass * fSpecificHeatCap;
            
            % Create path to the correct phase constructor.
            sPhaseCtor = ['matter.phases.', sPhase];
            
            % Create a handle to the correct phase constructor.
            hPhaseCtor = str2func(sPhaseCtor);
            
            % Create and store the single associated phase. Use |sPhase| as
            % the phase name and |sSubstance| as the "subphase" / substance
            % name (??). 
            % Thanks to some magic in the phase constructor, the created
            % phase is automatically added to the matter object (store,
            % phase, ...) provided. This should not happen in the interest
            % of "separation of concerns", KISS, and the principle of least
            % surprise, but meh ...
            this.oPhase = hPhaseCtor( ...
                this, ...   % The store (here: |thermal.dummymatter| instance).
                sPhase, ... % The name of the phase. 
                struct(sSubstance, this.fMass), ... % "Subphases", here: the total mass of a single material in this phase.
                this.fVolume, ... % The volume of the phase (== volume of the "store").
                fTemperature ...  % The temperature of the phase (== temperature of the "store"). 
            );
            
            % Overload specific heat capacity if we can.
            if bOverwriteHeatCapacity
                if ismethod(this.oPhase, 'overloadSpecificHeatCapacity')
                    this.oPhase.overloadSpecificHeatCapacity(fSpecificHeatCap);
                else
                    this.warn('thermal:dummymatter:addCreatePhase', ...
                        'Failed to overload specific heat capacity. Using value from matter table instead.');
                end
            end
            
            %TODO: remove!
            this.fTemperature = fTemperature;
            
        end
        
        function changeInnerEnergy(this, fEnergyChange)
            % Accepts a change in inner energy in |J| to calculate a
            % temperature change of the store and/or its phase.
            
            if isempty(this.oPhase) || ~isvalid(this.oPhase) || ~ismethod(this.oPhase, 'changeInnerEnergy')
                % Phase is not set, invalid, or does not have the
                % |changeInnerEnergy| method.
                this.warn('thermal:dummymatter:changeInnerEnergy', 'Failed to change inner energy of phase.');
            else
                % Forward call to phase.
                this.oPhase.changeInnerEnergy(fEnergyChange);
                %this.fTemperature = this.oPhase.fTemperature;
                %return; % We're done here.
            end
            
            if this.fTotalHeatCapacity == -1
                this.throw('thermal:dummymatter:changeInnerEnergy', 'Failed to change inner energy: Heat capacity is not set.');
            end
            
            % Calculate new temperature. 
            this.fTemperature = this.fTemperature + fEnergyChange / this.fTotalHeatCapacity;
            
        end
        
        function setTemperature(this, fTemperature)
            % Overload the temperature of the object.
            
            this.warn('thermal:dummymatter:setTemperature', ...
                'The temperature should not be set directly because it cannot change the phases'' temperature. Use "changeInnerEnergy" instead.');
            
            % Set new temperature of matter.
            this.fTemperature = fTemperature;
            
        end
        
        function fTemperature = getTemperature(this)
            % Get current temperature of store and cross-check with
            % temperature of phase. 
            
            % Get temperature from matter and set as return value. 
            fTemperature = this.fTemperature;
            
            % Check if phase is set and a valid instance. 
            if ~isempty(this.oPhase) && isvalid(this.oPhase)
                
                % Cross-check temperature with phase temperature. Warn if
                % phase temperature differs from matter temperature.
                if (1 - this.oPhase.fTemperature / fTemperature) > 1-e2
                    this.warn('thermal:dummymatter:getTemperature', ...
                        'Temperature %f of phase "%s" differs from temperature %f of (dummy) matter "%s"', ...
                        this.oPhase.fTemperature, this.oPhase.sName, fTemperature, this.sName);
                end
                
            end % /if valid
            
        end
        
        function fHeatCapacity = getTotalHeatCapacity(this)
            % Get total heat capacity of store, if it was overloaded, or of
            % the phase.
            
            if this.fTotalHeatCapacity ~= -1
                fHeatCapacity = this.fTotalHeatCapacity;
            else
                fHeatCapacity = this.oPhase.getTotalHeatCapacity();
            end
            
        end
        
    end
    
end

