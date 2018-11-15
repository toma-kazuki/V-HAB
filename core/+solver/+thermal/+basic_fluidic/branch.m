classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the temperature difference between the adjacent phases
% and the conductor values
    
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        afSolverHeatFlow = [0, 0];
        
        bP2P = false;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            if ~isa(this.oBranch.coConductors{1}.oMassBranch, 'matter.branch')
                this.bP2P = true;
            else
                this.oBranch.coConductors{1}.oMassBranch.bind('update',@(~)this.update());
            end
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            this.update();
            
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            
            afResistances = zeros(1,this.oBranch.iConductors);
            
            for iConductor = 1:this.oBranch.iConductors
                afResistances(iConductor) = this.oBranch.coConductors{iConductor}.update();
            end
            
            oMassBranch = this.oBranch.coConductors{1}.oMassBranch;
            fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            

            % Currently for mass bound heat transfer it is not possible to
            % allow different conducitvities in the thermal branch, as that
            % would result in energy being destroyed/generated. To solve
            % this it would be necessary for the branch to store thermal
            % energy, which would be equivalent to the matter branch
            % storing mass. Therefore, the issue is solved by averaging the
            % resistance values in the branch
            fResistance = sum(afResistances) / this.oBranch.iConductors;
            
            fHeatFlow = fDeltaTemperature / fResistance;
            
            try
                iFlowProcs = oMassBranch.iFlowProcs;
            catch
                % in this case we have a p2p
                iFlowProcs = 0;
            end
            
            if fResistance == inf
                this.afSolverHeatFlow = [0, 0];
                
                afTemperatures = ones(1,iFlowProcs + 1) * this.oBranch.coExmes{1}.oCapacity.fTemperature;
                
                if this.bP2P
                    oMassBranch.setTemperature(afTemperatures(1));
                else
                    for iFlow = 1: iFlowProcs+1
                        oMassBranch.aoFlows(iFlow).setTemperature(afTemperatures(iFlow));
                    end
                end
                
                this.afSolverHeatFlow = [0, 0];
                this.oBranch.coExmes{1}.setHeatFlow(this.afSolverHeatFlow(1));
                this.oBranch.coExmes{2}.setHeatFlow(this.afSolverHeatFlow(2));
                
                update@solver.thermal.base.branch(this, 0, afTemperatures);
                return
            end
            
            afTemperatures  = zeros(1,iFlowProcs + 1); % there is one more flow than f2f procs
            afF2F_HeatFlows = zeros(1,iFlowProcs);
            if oMassBranch.fFlowRate >= 0
                afTemperatures(1) = this.oBranch.coExmes{1}.oCapacity.fTemperature; %temperature of the first flow
                iFirstFlow = 1;
                iDirection = 1;
                iFlowProcShifter = -1;
                iExme = 2;
            else
                afTemperatures(end) = this.oBranch.coExmes{2}.oCapacity.fTemperature; %temperature of the first flow
                iFirstFlow = iFlowProcs + 1;
                iDirection = -1;
                iFlowProcShifter = 0;
                iExme = 1;
            end
            
            % for the flows we solve the temperatures in a downstream order
            % and also thermally update the procs in a downstream order
            %
            % e.g. we have two f2f thus 3 flows and a positive flow
            % direction. Then:
            % afTemperatures(1) = temperature of left capacity
            % afF2F_HeatFlows(2) = heatflow of first f2f, updated after
            % first temperature is known and therefore before the second
            % flow temperature is set
            
            if this.bP2P
                oMassBranch.setTemperature(afTemperatures(1));
            else
                oMassBranch.aoFlows(iFirstFlow).setTemperature(afTemperatures(iFirstFlow));
                
                if oMassBranch.fFlowRate >= 0
                    aiFlows = 2:(iFlowProcs + 1);
                else
                    aiFlows = (iFlowProcs):-1:1;
                end
                for iFlow = aiFlows
                    try
                        oMassBranch.aoFlowProcs(iFlow - iDirection).updateThermal();
                    catch
                        % thermally not active f2f
                    end
                    % The thermal energy from the f2f before this flow is added
                    % to the overall heat flow
                    afF2F_HeatFlows(iFlow + iFlowProcShifter) = oMassBranch.aoFlowProcs(iFlow + iFlowProcShifter).fHeatFlow;

                    afTemperatures(iFlow) = afTemperatures(iFlow - iDirection) + (afF2F_HeatFlows(iFlow + iFlowProcShifter) / (1/fResistance) );

                    oMassBranch.aoFlows(iFlow).setTemperature(afTemperatures(iFlow))

                end
            end
            % for matter bound heat transfer only the side receiving the
            % mass receives the heat flow, the energy change on the other
            % side is handled by changing the total heat capacity
            this.afSolverHeatFlow = [0, 0];
            if iExme == 1
                this.afSolverHeatFlow(iExme) = fHeatFlow - sum(afF2F_HeatFlows);
            else
                this.afSolverHeatFlow(iExme) = fHeatFlow + sum(afF2F_HeatFlows);
            end
            
            % If the mass transfer is matter bound the heat flow is only
            % added to the phase receiving the mass but not subtracted from
            % the other side (a phase that empties does not change its
            % temperature). Therefore, two heat flow values are kept up
            % till this point, where the information is set to the exmes.
            % If the transfer is not matter bound the heat flows are
            % identical (also in sign, because the sign for the respective
            % phase is stored in the exme)
            this.oBranch.coExmes{1}.setHeatFlow(this.afSolverHeatFlow(1));
            this.oBranch.coExmes{2}.setHeatFlow(this.afSolverHeatFlow(2));
            
            fHeatFlow = this.afSolverHeatFlow(this.afSolverHeatFlow ~= 0);
            if isempty(fHeatFlow)
                fHeatFlow = 0;
            end
             
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
            
        end
    end
end
