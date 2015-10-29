classdef flow < matter.manips.substance
    %FLOW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        % Changes in partial masses in kg/s
        afPartialFlows;
    end
    
    methods
        function this = flow(sName, oPhase)
            this@matter.manips.substance(sName, oPhase);
            
        end
        
        function update(this, afPartialFlows)
            this.afPartialFlows = afPartialFlows;
        end
        
    end
    
    methods (Access = protected)
        function afFlowRates = getTotalFlowRates(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afFlowRates, mrInPartials ] = this.getInFlows();
            
            
            if ~isempty(afFlowRates)
                afFlowRates = sum(bsxfun(@times, afFlowRates, mrInPartials), 1);
            else
                afFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            end
        end
    end
    
end
