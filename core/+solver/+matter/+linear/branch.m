classdef branch < solver.matter.base.branch
    
    properties (SetAccess = public, GetAccess = public)
        rMaxChange = 0.2;
        rSetChange = 0.05;
        iRemChange = 0;
        fMaxStep   = 60;
        
        % Fixed time step - set to empty ([]) to deactivate
        fFixedTS = [];
    end
    
    properties (SetAccess = protected, GetAccess = public)
        rFlowRateChange  = 0;
        iSignChangeFRCnt = 0;
        
        fTimeStep = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = branch(oBranch, rMaxChange, iRemChange)
            this@solver.matter.base.branch(oBranch);
            
            if nargin >= 2, this.rMaxChange = rMaxChange; end;
            if nargin >= 3, this.iRemChange = iRemChange; end;
        end
        
        
    end
    
    methods (Access = protected)
        function update(this)
            if this.oBranch.oContainer.oTimer.fTime < this.fLastUpdate
                return;
            end
            
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            abActiveProcs = [ this.oBranch.aoFlowProcs.bActive ];
            for iI = 1:length(abActiveProcs)
                if abActiveProcs(iI)
                    this.oBranch.aoFlowProcs(iI).update();
                end
            end
            
            % Getting the temperature differences for each processor in the
            % branch
            afTemps = [ this.oBranch.aoFlowProcs.fDeltaTemp ];
            
            % Getting all hydraulic diameters and lengths
            afHydrDiam   = [ this.oBranch.aoFlowProcs.fHydrDiam ];
            afHydrLength = [ this.oBranch.aoFlowProcs.fHydrLength ];
            
            % Find all components with negative hydraulic diameters
            afNegHydrDiam = find(afHydrDiam < 0);
            if ~isempty(afNegHydrDiam)
                % If there are any components that produce a pressure rise
                % sum them up and create new arrays with just the
                % components producing pressure drops
                fPressureRises = sum(this.oBranch.aoFlowProcs(afNegHydrDiam).fDeltaPressure);
                afPosHydrDiam = afHydrDiam(afHydrDiam>0);
                afHydrLength  = afHydrLength(afHydrDiam>0);
            else
                fPressureRises = 0;
                afPosHydrDiam = afHydrDiam;
            end
            
           
            %TODO real calcs, also derive pressures/temperatures
            %     check active components - get pressure rise / hydr.
            %     diameter depending on flow rate
            %     -> in constructor, find comps that have some bActive attr
            %        set to true. For these comps, call some updHydrDiam.
            %        The comps use the LAST pressures / flow rate to calc.
            %        a hydraulic diameter and update fHydrDiam.
            fCoeff = sum(afPosHydrDiam * 0.000001 ./ afHydrLength);
            
            fPressureLeft  = this.oBranch.coExmes{1}.getPortProperties();
            fPressureRight = this.oBranch.coExmes{2}.getPortProperties();
            
            fFlowRate = fCoeff * (fPressureLeft - fPressureRight + fPressureRises);
            %TODO see above
            
            
            
            
            if ~isempty(this.fFixedTS)
                if this.fTimeStep ~= this.fFixedTS
                    this.setTimeStep(this.fFixedTS);
                    this.fTimeStep = this.fFixedTS;
                end
                
            else


                % Change in flow rate
                %TODO use this.fLastUpdate and this.oBranch.oCont.oTimer.fTime
                %     and set the rChange in relation to elapsed time!
                rChange = abs(fFlowRate / this.fFlowRate - 1);

                % Old time step
                fOldStep = this.fTimeStep;

                if fOldStep < this.oBranch.oContainer.oTimer.fTimeStep
                    fOldStep = this.oBranch.oContainer.oTimer.fTimeStep;
                end

                % Change in flow rate direction? Min. time step!
                if (rChange < 0) || isinf(rChange) || (this.iSignChangeFRCnt > 1)
                    fNewStep = 0;

                    this.iSignChangeFRCnt = this.iSignChangeFRCnt + 1;

                else
                    if this.iSignChangeFRCnt > 1
                        this.iSignChangeFRCnt = this.iSignChangeFRCnt - 1;
                    else
                        this.iSignChangeFRCnt = 0;
                    end

                    % Remember/damp flow rate changes
                    this.rFlowRateChange = (rChange + this.iRemChange * this.rFlowRateChange) / (1 + this.iRemChange);

                    % Change larger than limit? Minimum time step.
                    if this.rFlowRateChange > this.rMaxChange, fNewStep = 0;
                    else
                        % Interpolate
                        fNewStep = interp1([ 0 this.rSetChange this.rMaxChange ], [ 2 * fOldStep fOldStep 0 ], this.rFlowRateChange, 'linear', 'extrap');
                    end
                end

                if fNewStep > this.fMaxStep, fNewStep = this.fMaxStep; end;

                this.setTimeStep(fNewStep);
                %this.setTimeStep(10);
    %             disp(this.rFlowRateChange);
    %             disp(fNewStep);
    %             disp('---------');
                this.fTimeStep = fNewStep;
            end
            
            
            % Sets new flow rate
            update@solver.matter.base.branch(this, fFlowRate, [], afTemps);
        end
    end
end