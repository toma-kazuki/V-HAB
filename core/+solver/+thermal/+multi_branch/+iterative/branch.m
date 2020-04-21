classdef branch < base & event.source
% A multi branch thermal solver which calculates the heat flow in a network
% of thermal branches. It can solve all only branches which do not include
% mass flows, so add only non fluidic conductors to branches for this
% solver! 
% Note that it is not possibe to combine convective/conductive conductors
% and radiative conductors in one solver, you have to seperate these heat
% transfers so that the convective/conductive part and the radiative part
% are solved seperatly
    
%% Basic description of the basics for this solver
% The thermal network consists of as many equations as there are branches.
% Each branch represents a thermal heat exchange between two thermal
% capacities. So each equation has the form of some kind of resistance *
% some kind of temperature difference (T1 - T2). For radiation the
% temperature difference is between the temperatures^4 but that is handled
% in the creation of the afTemperatures vector. So in the matrix, we
% require 1 at the location of the corresponding capacity which is T1
% (which is the left side of the thermal branch), and a -1 for each
% capacity that represent T2 in the equation (the right side of the
% branch).
%
% The heat flow can be calculated using: fHeatFlow = fDeltaTemperature /
% fTotalThermalResistance Where fTotalThermalResistance is the total
% thermal resistance from all conductors in the branch. Each of these
% resistances must be updated beforehand and then summed up (within a
% branch no parallel heat exchange is modelled, for that purpose multiple
% branches are necessary): afResistances(iConductor) =
% this.oBranch.coConductors{iConductor}.update();
%
% So each equation has the form: fHeatFlow = fDeltaTemperature /
% fTotalThermalResistance
%
% The vector matrix system that we create only brings that into the
% corresponding form. Let us assume we have 4 Capacity, which are connected
% be 3 Branches in a 1D problem (capacity 1 is connected to capacity 2 and
% so on). In that case the following vector matrix multiplication allows
% you to calculate the delta temperatures
%
%   System of Equations  | Temperatures |   	Delta T
%   1	-1	  0     0           303               5
%   0    1   -1     0       *   298           =   13
%   0    0    1    -1           285               9
%                               276
%
% SoE   = [1 -1 0 0; 0 1 -1 0; 0 0 1 -1]
% T     = [303; 298; 285; 276]
%
% However, we want not the delta between the temperatures but the branch
% heat flows. For that purpose we transform the equation (T1 - T2)/ R into
% T1/R - T2/R. If we assume a thermal resistance of 0.5 K/W for our example
% for all conductors the system of equations becomes:
%
%   System of Equations  | Temperatures |   	Heat Flows
%   2	-2	  0     0           303               10
%   0    2   -2     0       *   298           =   26
%   0    0    2    -2           285               18
%                               276
%
% SoE   = [2 -2 0 0; 0 2 -2 0; 0 0 2 -2]
% T     = [303; 298; 285; 276]
%
% Since we have to use temperatures^4 for the radiative heat transfer, we
% cannot simply use the same temperature values for the radiative heat
% transfers, as we might require them as normal values and as ^4 values. To
% solve this in the initializeNetwork function the aoBranches property is
% reordered to ensure that all radiative branches are at the end of the
% property. All capacities which take part in the radiative heat transfer
% are also added again to aoCapacities and the property
% iFirstRadiativeCapacity is defined to find out which temperatures have to
% be ^4
    
    properties (SetAccess = private, GetAccess = public)
       	% array containing the branches that are solved by this solver
        aoBranches;
        
        % Arrray containing the capacities which are connected to the
        % solved matrix in an order specfied by the initializeNetwork
        % function
        aoCapacities;
        
        abRadiationBranches;
        iFirstRadiationBranch;
        iFirstRadiativeCapacity;
        
        % number of total branches in the network
        iBranches;
        
        % Last time the solver was updated
        fLastUpdate = -10;
        % A flag to decide if the solver is already outdated or not
        bRegisteredOutdated = false;
        
        % In recursive calls within the post tick where the solver itself
        % triggers outdated calls up to the point where it is set outdated
        % again itself it is possible for the solver to get stuck with a
        % true bRegisteredOutdated flag. To prevent this we also store the
        % last time at which we registered an update
        fLastSetOutdated = -1;
        
        oTimer;
        
        %% Network variables
        % A matrix where each row corresponds to the branch from aoBranches
        % with the same index. so this.mfConnectivityMatrix(iBranch, :)
        % provides the row representing this.aoBranches(iBranch). For each
        % branch there are two entries, a 1 (for the left capacity) and 
        % a -1 (for the right capacity). The matrix must be divided with
        % the current resistances before it can be used in heat flow
        % calculations
        mfConnectivityMatrix;
        
    end
    
    properties (SetAccess = private, GetAccess = private)
        % cell containing the handles of the set flow rate functions of the
        % individual branches in this network
        chSetBranchHeatFlows;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        
        hBindPostTickUpdate;
        hBindPostTickTimeStepCalculation;
    end
    
    methods
        function this = branch(aoBranches)
            
            this.aoBranches = aoBranches;
            this.iBranches = length(this.aoBranches);
            this.chSetBranchHeatFlows = cell(1, this.iBranches);
            
            for iB = 1:this.iBranches 
                this.chSetBranchHeatFlows{iB} = this.aoBranches(iB).registerHandler(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
            
            this.oTimer     = this.aoBranches(1).oTimer;
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            % we only have to do this once, but initially we have to create
            % the thermal network we want to solve here
            this.initializeNetwork();
            
            % and update the solver to initialize everything
            this.update();
        end
        
    end
    
    methods (Access = protected)
        
        function registerUpdate(this, ~)
            % this function registers an update
            
            if ~(this.oTimer.fTime > this.fLastSetOutdated) && this.bRegisteredOutdated
                return;
            end
            
            if ~base.oDebug.bOff, this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated }); end
            
            for iB = 1:this.iBranches
                for iE = 1:2
                    keyboard()
                    this.aoBranches(iB).coExmes{iE}.oPhase.registerMassupdate();
                end
            end
            
            % Allows other functions to register an event to this trigger
            if this.bTriggerRegisterUpdateCallbackBound
                this.trigger('register_update');
            end

            if ~base.oDebug.bOff, this.out(1, 1, 'registerUpdate', 'Registering update() method on the multi-branch solver.'); end
            
            this.hBindPostTickUpdate();
            this.hBindPostTickTimeStepCalculation();
            
            this.bRegisteredOutdated = true;
            this.fLastSetOutdated = this.oTimer.fTime;
        end
        
        function initializeNetwork(this)
            %% initializeNetwork
            % Is only execute once when the solver is created. It creates
            % the aoCapacities property in the corresponding order, as well
            % as reorders the aoBranches property. In addition the
            % connectivity Matrix is defined here, allowing fast
            % calculation of the whole network in the update function
            
            % Since it is possible to access property as follows:
            % afHeatFlows = [this.aoBranches.fHeatFlow]
            % We define an object array of the capacities for the normal
            % conductors and for the radiative conductors. From that we
            % also construct the overall object array of all capacities,
            % but keeping them seperate is easier initially
            this.aoCapacities 	= thermal.capacity.empty();
            
            % The matrix is not initialized with the correct size, because
            % we do not know yet how many capacities are actually present
            % in the network, but it is at least 1
            this.mfConnectivityMatrix = zeros(this.iBranches, 1);
            
            % The first SoE is for all types of conductive heat transfer
            % (conduction, convection etc) and the second type is for
            % radiative heat transfer. Unfortunatly this would mean the
            % index of the row for the matrix to no longer corresponds to
            % the row in the aoBranches property. Therefore, we reorder the
            % aoBranches property to move all radiative branches to the
            % back of the array!
            this.abRadiationBranches = [this.aoBranches.bRadiative]';
            aoConductiveBranches = this.aoBranches(~this.abRadiationBranches);
            aoRadiativeBranches  = this.aoBranches(this.abRadiationBranches);
            this.aoBranches = [aoConductiveBranches; aoRadiativeBranches];
            this.abRadiationBranches = [this.aoBranches.bRadiative]';
            
            this.iFirstRadiationBranch = find(this.abRadiationBranches, 1);
            
            for iBranch = 1:this.iBranches
                oLeftCapacity  = this.aoBranches(iBranch).coExmes{1}.oCapacity;
                oRightCapacity = this.aoBranches(iBranch).coExmes{2}.oCapacity;
                
                % for heterogenous object arrays it is not possible to use
                % simple == comparisons therefore, we have to loop through
                % the already defined capacities to find out if the
                % capacities of this branch are already part of the network
                iLeftCapacityIndex = 0;
                iRightCapacityIndex = 0;
                if iBranch == this.iFirstRadiationBranch
                    this.iFirstRadiativeCapacity = length(this.aoCapacities) + 1;
                end
                
                if iBranch < this.iFirstRadiationBranch
                    for iCapacity = 1:length(this.aoCapacities)
                         if this.aoCapacities(iCapacity) == oLeftCapacity
                             iLeftCapacityIndex = iCapacity;
                         end

                         if this.aoCapacities(iCapacity) == oRightCapacity
                             iRightCapacityIndex = iCapacity;
                         end
                    end
                else
                    % In this case we have to readd the capacity, because
                    % we require its temperature a second time, from now on
                    % we only check the capacities 
                    if length(this.aoCapacities) >= this.iFirstRadiativeCapacity
                        for iCapacity = this.iFirstRadiativeCapacity:length(this.aoCapacities)
                             if this.aoCapacities(iCapacity) == oLeftCapacity
                                 iLeftCapacityIndex = iCapacity;
                             end

                             if this.aoCapacities(iCapacity) == oRightCapacity
                                 iRightCapacityIndex = iCapacity;
                             end
                        end
                    end
                end
                % Objects of different classes cannot be put into the same
                % array if they do not inherit from the
                % matlab.mixin.Heterogenous class
                if iLeftCapacityIndex == 0
                    this.aoCapacities(end+1, 1)	= oLeftCapacity;
                    iLeftCapacityIndex = length(this.aoCapacities);
                end
                if iRightCapacityIndex == 0
                    this.aoCapacities(end+1, 1) 	= oRightCapacity;
                    iRightCapacityIndex = length(this.aoCapacities);
                end
                
                % So here we perform the assignment of left and right side
                % with 1 and -1 as mentioned in the explanatory comments at
                % the beginning of this function. Since the
                % resistance/conductivity changes in each tick, we cannot
                % assign those yet
                this.mfConnectivityMatrix(iBranch, iLeftCapacityIndex)   = 1;
                this.mfConnectivityMatrix(iBranch, iRightCapacityIndex)  = -1;
            end
        end
        
        function update(this)
            % update the thermal solver
            
            keyboard()
            
            % The first step is to divide
            
            % we update the conductors in the branch and identify any
            % radiative conductors (all others are considered conductive,
            % because the heat transfer for them scales with T while
            % radiative heat transfer scales with T^4)
            afResistances = zeros(1,this.oBranch.iConductors);
            bRadiative    = false;
            bConductive   = false;
            
            for iConductor = 1:this.oBranch.iConductors
                if this.oBranch.coConductors{iConductor}.bRadiative
                    bRadiative = true;
                else
                    bConductive = true;
                end
                afResistances(iConductor) = this.oBranch.coConductors{iConductor}.update();
            end
            
            % check if both types are present in the branch at the same
            % time, which is currently not possible
            if bRadiative && bConductive
                this.throw('branch', 'Basic thermal solver cannot calculate conductive/convective and radiative heat transfer at the same time, please use two different branches or use a different solver');
            end
            
            % for conductive/convective heat transfer we use delta T with
            % T1 - T2, for radiative we use T1^4 - T2^4
            if bConductive
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            
            else
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature^4 - this.oBranch.coExmes{2}.oCapacity.fTemperature^4;
            
            end
            
            % See W�rme�betragung Polifke equation 3.16, only valid if
            % all resistances are in a row and not parallel, for
            % parallel resistances use multiple branches
            fTotalThermalResistance = sum(afResistances);

            % calculate the heat flow
            fHeatFlow = fDeltaTemperature / fTotalThermalResistance;
            
            % set heat flows
            this.oBranch.coExmes{1}.setHeatFlow(fHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(fHeatFlow);
            
            % the temperatures between the conductors are not always
            % required. If it is of interest to model various temperatures
            % multiple thermal branches for each step of the heat transfer
            % can be used e.g. to calculate the wall temperature in a heat
            % exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
            
            this.fLastUpdate = this.oTimer.fTime;
        end
        
        function calculateTimeStep(this)
            %% time step limitation
            
            
        end
    end
end
