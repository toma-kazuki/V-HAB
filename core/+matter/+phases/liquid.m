classdef liquid < matter.phase
    %LIQUID Describes a volume of liquid
    %   Detailed explanation goes here
    %
    %TODO
    %   - support empty / zero volume (different meanings?)

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
        sType = 'liquid';

    end

    properties (SetAccess = protected, GetAccess = public)
        
        fVolume;                % Volume in m^3
        
        % Pressure in Pa
        % the pressure in the tank without the influence of gravity or
        % acceleration even if these effects exist
        fPressure;
        
        fDynamicViscosity;      % Dynamic Viscosity in Pa*s
        
        fLastUpdateLiquid = 0;
        
        % Handles for the pressure and density correlation functions
        hLiquidDensity;
        hLiquidPressure;
        
    end
    
    methods
        % oStore        : Name of parent store
        % sName         : Name of phase
        % tfMasses      : Struct containing mass value for each species
        % fVolume       : Volume of the phase
        % fTemperature  : Temperature of matter in phase
        % fPress        : Pressure of matter in phase
        
        function this = liquid(oStore, sName, tfMasses, fVolume, fTemperature, fPressure, bAdsorber)
            if nargin < 7
                 bAdsorber = false;
            end
            this@matter.phase(oStore, sName, tfMasses, fTemperature, bAdsorber);
            
            this.fVolume      = fVolume;
            this.fTemperature = fTemperature;
            
            if nargin > 5
                this.fPressure    = fPressure;
            else
                this.fPressure    = this.oMT.Standard.Pressure;
            end
            
            
            this.fDensity = this.fMass / this.fVolume;
            
        end
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fVolume', fVolume);
            this.fDensity = this.fMass / this.fVolume;
            
            %TODO Replace this with a calculatePressure() method in the
            %matter table that takes all contained substances into account,
            %not just water. 
            tParameters = struct();
            tParameters.sSubstance = 'H2O';
            tParameters.sProperty = 'Pressure';
            tParameters.sFirstDepName = 'Density';
            tParameters.fFirstDepValue = this.fDensity;
            tParameters.sPhaseType = 'liquid';
            tParameters.sSecondDepName = 'Temperature';
            tParameters.fSecondDepValue = this.fTemperature;
            tParameters.bUseIsobaricData = false;
            
            this.fPressure = this.oMT.findProperty(tParameters);
            
            return;
            %TODO with events:
            %this.trigger('set.fVolume', struct('fVolume', fVolume, 'setAttribute', @this.setAttribute));
            % So events can just set everything they want ...
            % Or see human, events return data which is processed here??
            % What is several events are registered? Different types of
            % volume change etc ...? Normally just ENERGY should be
            % provided to change the volume, and the actual change in
            % volume is returned ...
        end
        
        function bSuccess = setPressure(this, fPressure)
            % Changes the pressure of the phase.
            %
            % Ideally, I would like to set the initial pressure only once, 
            % maybe in the branch?
            %
            % TODO need some kind of check function here, possibly through
            % matter.table to make sure the pressure isn't so low, that a
            % phase change to gas takes place
            
            bSuccess = this.setParameter('fPressure', fPressure);
            
            % Calculate density for newly set pressure
            this.fDensity = this.oStore.oMT.calculateDensity(this);
            
            this.fMass = this.fDensity*this.fVolume;
                        
                        
            return;
            %TODO with events:
            %this.trigger('set.fPressure', struct('fPressure', fPressure, 'setAttribute', @this.setAttribute));
            % So events can just set everything they want ...
            % Or see human, events return data which is processed here??
            % What is several events are registered? Different types of
            % volume change etc ...? Normally just ENERGY should be
            % provided to change the volume, and the actual change in
            % volume is returned ...
        end
        
        function bSuccess = setMass(this, fMass)

            bSuccess = this.setParameter('fMass', fMass);
            this.fDensity = this.fMass / this.fVolume;
  
            return;
        end
        
        function bSuccess = setTemp(this, fTemperature)

            bSuccess = this.setParameter('fTemperature', fTemperature);
            this.fDensity = this.fMass / this.fVolume;
            
            return;
        end

        function this = update(this)
            update@matter.phase(this);
            
            %TODO coeff m to p: also in fluids, plasma. Not solids, right?
            %     calc arPPs, rel humidity, ...
            %
            % Check for volume not empty, when called from constructor
            %TODO change phase contructor, don't call .update() directly?
            %     Or makes sense to always check for an empty fVolume? Does
            %     it happen that fVol is empty, e.g. gas solved in fluid?
            if ~isempty(this.fVolume) && this.fLastUpdateLiquid ~= this.oStore.oTimer.fTime && this.oStore.bIsIncompressible == 0
                %TODO Replace this with a calculatePressure() method in the
                %matter table that takes all contained substances into account,
                %not just water.
                fDensity = this.fMass/this.fVolume;
                tParameters = struct();
                tParameters.sSubstance = 'H2O';
                tParameters.sProperty = 'Pressure';
                tParameters.sFirstDepName = 'Density';
                tParameters.fFirstDepValue = fDensity;
                tParameters.sPhaseType = 'liquid';
                tParameters.sSecondDepName = 'Temperature';
                tParameters.fSecondDepValue = this.fTemperature;
                tParameters.bUseIsobaricData = false;
                
                this.fPressure = this.oMT.findProperty(tParameters);
                
                this.fLastUpdateLiquid = this.oStore.oTimer.fTime;            
            end
            for k = 1:length(this.coProcsEXME)
                this.coProcsEXME{1, k}.update();
            end
        end
    end
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function setAttribute(this, sAttribute, xValue)
            % Internal helper, see @matter.phase class.
            %
            %TODO throw out, all done with events hm?
            
            this.(sAttribute) = xValue;
        end
    end
    
end

