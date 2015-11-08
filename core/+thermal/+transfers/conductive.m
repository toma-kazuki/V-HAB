classdef conductive < thermal.conductors.linear
    %CONDUCTIVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = conductive(oLeftCapacity, oRightCapacity, fThermalConductivity, fArea, fLength)
            
            calcFunc = str2func([mfilename('class'), '.calculateConductance']);
            conductanceValue = calcFunc(fThermalConductivity, fArea, fLength);
            
            sIdentifier = ['conductive:', oLeftCapacity.sName, '+', oRightCapacity.sName];
            this@thermal.conductors.linear(oLeftCapacity, oRightCapacity, conductanceValue, sIdentifier);
            
        end
        
    end
    
    methods (Static)
        
        function conductanceValue = calculateConductance(fThermalConductivity, fArea, fLength)
            
            conductanceValue = fThermalConductivity * fArea / fLength;
            
        end
        
    end
    
end

