classdef p2p < matter.flow
    %P2P
    %
    %TODO
    %   - more than two phases possible?
    
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate = -1;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Name of the p2p processor
        % @type string
        % @default p2proc
        sName;
        
        % Parent store
        % @type object
        oStore;
    end
    
    
    
    methods
        function this = p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            % p2p constructor.
            %
            % Parameters:
            %   - sName         Name of the processor
            
            % Parent constructor
            this@matter.flow(oStore.oMT);
            
            
            % Phases / ports
            [ sPhaseAndPortIn,  sPortIn ]  = strtok(sPhaseAndPortIn, '.');
            [ sPhaseAndPortOut, sPortOut ] = strtok(sPhaseAndPortOut, '.');
            
            % Find the phases
            iPhaseIn  = find(strcmp({ oStore.aoPhases.sName }, sPhaseAndPortIn ), 1);
            iPhaseOut = find(strcmp({ oStore.aoPhases.sName }, sPhaseAndPortOut), 1);
            
            if isempty(iPhaseIn) || isempty(iPhaseOut)
                this.throw('p2p', 'Phase could not be found: in phase "%s" has index "%i", out phase "%s" has index "%i"', sPhaseIn, iPhaseIn, sPhaseOut, iPhaseOut);
            end
            
            % Set name and a fake oBranch ref - back to ourself
            this.sName   = sName;
            this.oBranch = this;
            this.oStore  = oStore;
            
            % Can only be done after this.oStore is set, store checks that!
            this.oStore.addP2P(this);
            
            %this.fFlowRate = 0;
            
            % Add ourselves to phase ports (default name!)
            %TODO do the phases need some .getPort or stuff?
            oStore.aoPhases(iPhaseIn ).toProcsEXME.(sPortIn(2:end) ).addFlow(this);
            oStore.aoPhases(iPhaseOut).toProcsEXME.(sPortOut(2:end)).addFlow(this);
        end
    end
    
    
    
    %% Methods required for the matter handling
    methods
        
        function oExme = getInEXME(this)
            % Little bit of a fake method. The p2p sets the oBranch attri-
            % bute to itself. By implementing this method, the flow can get
            % the inflowing phase properties through the according EXME.
            % This is needed to e.g. get the phase type for heat capacity
            % calculations.
            oExme = this.(sif(this.fFlowRate < 0, 'oOut', 'oIn'));
        end
        
        
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
        function update(this, fFlowRate, arPartials)
            % Calculate new flow rate in [kg/s]. The update method is
            % called right before the phases merge/extract. The p2p merge
            % or extract is done after the merge of the 'outer' flows and
            % before the extract of those takes places.
            % Therefore, at the point of p2p extraction, the whole (tempo-
            % rary) mass flowing through the phase within that time step is
            % stored in the phase.
            % An absolute value for mass extraction has to be divided by
            % the fTimeStep parameter to get a flow.
            % In case of flow through the filter volume >> the mass within,
            % the in/out flow rates can be used for absorption flow rate
            % calculations.
            
            
            % Fake method, can be used to set a manual FR. If .update is
            % not defined in a subclass, flow rate never changes on mass
            % update sutff in phases, only if the .update method here is
            % manually called including the flow rate parameter.
            if nargin >= 3
                this.setMatterProperties(fFlowRate, arPartials);
            elseif nargin >= 2
                this.setMatterProperties(fFlowRate);
            else
                this.setMatterProperties();
            end
        end
    end
    
    
    methods (Access = protected)
        function setData(this)
            % Inactive ... badaboom
            this.throw('Should that happen on a p2p processor?');
        end
        
        
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemperature, fPressure)
            % Get missing values from exmes
            
            if (nargin < 2) || isempty(fFlowRate), fFlowRate = this.fFlowRate; end;
            
            % We're a p2p, so we're directly connected to EXMEs
            oExme = this.(sif(fFlowRate >= 0, 'oIn', 'oOut'));
            
            if nargin < 3 || isempty(arPartialMass)
                % We also get the mol mass and heat capacity ... however, 
                % setMatterProps calculates those anyway so ignore  them.
                [ arPartialMass, ~, ~ ] = oExme.getMatterProperties();
            end
            
            
            % Get matter properties from in exme. 
            [ fPortPressure, fPortTemperature ] = oExme.getPortProperties();
            
            % Check temp and pressure. First temp ... cause that might
            % change in a p2p ... pressure not really.
            if (nargin < 4) || isempty(fTemperature), fTemperature = fPortTemperature; end;
            if (nargin < 5) || isempty(fPressure), fPressure = fPortPressure; end;
                
            
            setMatterProperties@matter.flow(this, fFlowRate, arPartialMass, fTemperature, fPressure);
        end
    end
end

