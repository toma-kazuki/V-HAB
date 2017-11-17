classdef heatsource_multi < thermal.heatsource
    %HEATSOURCE A dumb constant heat source
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        aoHeatSources;
    end
    
    methods
        
        function this = heatsource_multi(varargin)
            this@thermal.heatsource(varargin{:});
            
            this.aoHeatSources = thermal.heatsource.empty();
        end
        
        function addHeatSource(this, oHeatSource)
            this.aoHeatSources(end + 1) = oHeatSource;
            
            oHeatSource.bind('update', @this.updatePower);
        end
        
        function setPower(this, ~)
            this.throw('setPower', 'Power of multi-heatsource cannot bet set! Use addHeatSource to add new heat source object, setPower there.');
        end
    end
    
    methods (Access = protected)
        function updatePower(this, ~)
            this.fPower  = sum([ this.aoHeatSources(iSource).fPower ]);
            
            this.trigger('update', fPower);
            
            %TODO trigger a thermal solver update? How to do that?
            %     in case the thermal solver did change the heat source
            %     value itself, 
        end
    end
    
end

