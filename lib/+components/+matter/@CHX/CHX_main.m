function [fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2,...
    fR_alpha_i, fR_alpha_o, fR_lambda] = ...
    CHX_main(oHX, Fluid_1, Fluid_2, fThermal_Cond_Solid, iIncrements)

%Function used to calculate the outlet temperatures and pressure drop of a
%heat exchanger. (It is also possible to return the thermal resistances)
%
%fluid 1 is always the fluid within the inner pipe(s), if there are pipes.
%
%additional to the inputs explained in the file HX. there are inputs which
%shouldn't be made by a user but come from the V-HAB environment. Every 
%input except for flambda_solid is needed for both fluids which makes a 
%total of 13 flow and material parameters:
%
%The Values for both fluids are required as a struct with the following
%fields filled with the respecitve value for the respective fluid:
%'Massflow' , 'Entry_Temperature' , 'Dynamic_Viscosity' , 'Density' ,
%'Thermal_Conductivity' , 'Heat_Capacity'
%
%for temperature dependant calculations the material values for the fluids
%are required for the average temperature between in and outlet T_m as well
%as the wall temperature T_w.
%These should be saved in the struct values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%Together alle the inputs are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2, fDelta_P_1, fDelta_P_2 fR_alpha_i,...
% fR_alpha_o, fR_lambda] = HX(oHX, Fluid_1, Fluid_2, fThermal_Cond_Solid)
%
%Where the object oHX containing mHX and sHX_type with the user inputs is
%automatically set in the HX.m file (also see that file for more
%information about which heat exchangers can be calculated and what user
%inputs are required)
%
%with the outputs:
%fOutlet_Temp_1 = temperature after HX for fluid within the pipes (if there
%                 are pipes) in K
%fOutlet_Temp_2 = temperature after HX for sheath fluid (fluid outside
%                 pipes if there are pipes) in K
%fDelta_P_1  = pressure loss of fluid 1 in N/m�
%fDelta_P_2  = pressure loss of fluid 2 in N/m�
%fR_alpha_i  = thermal resistivity from convection on the inner side in W/K
%fR_alpha_o  = thermal resistivity from convection on the inner side in W/K
%fR_lambda   = thermal resistivity from conduction in W/K

%the source "W�rme�bertragung" Polifke will from now on be defined as [1]

%Please note generally for the convection coeffcient functions: in some of
%these functions a decision wether nondisturbed flow should be assumed or 
%not is necessary. In this programm this has already been set using the
%respective fConfig variables in these cases to use the most probable case.
%So for example in case of a pipe bundle disturbed flow is assumed inside 
%of it because generally a single pipe with a different diameter will lead 
%to the bundle. 
%But if a single pipe was used non disturbed flow is assumed since the pipe
%leading to it will most likely have the same shape and diameter.

%gets the fluid values from the input structs
fMassFlow1              = Fluid_1.Massflow;
fEntry_Temp1            = Fluid_1.Entry_Temperature;
fDyn_Visc_Fluid1        = Fluid_1.Dynamic_Viscosity;
fDensity_Fluid1         = Fluid_1.Density;
fThermal_Cond_Fluid1    = Fluid_1.Thermal_Conductivity;
fC_p_Fluid1             = Fluid_1.Heat_Capacity;

fMassFlow2              = Fluid_2.Massflow;
fEntry_Temp2            = Fluid_2.Entry_Temperature;
fDyn_Visc_Fluid2        = Fluid_2.Dynamic_Viscosity;
fDensity_Fluid2         = Fluid_2.Density;
fThermal_Cond_Fluid2    = Fluid_2.Thermal_Conductivity;
fC_p_Fluid2             = Fluid_2.Heat_Capacity;

%gets the vector mHX with the geometry information from the struct
mHX = oHX.mHX;
sHX_type = oHX.sHX_type;


%%
if strcmpi(sHX_type, 'counter annular passage')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i = mHX(1);
    fD_o = mHX(2);
    fR_i = mHX(3);
    fLength = mHX(4);
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(pi*(fD_i/2)^2*fDensity_Fluid1(1));
    %flow speed of the fluid in the annular passage
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %Area for the heat exchange
    fArea = pi * fD_i * fLength;
    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help)
    falpha_o = functions.calculateHeatTransferCoefficient.convectionAnnularPassage (fD_i, fD_o, fLength,...
               fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
               fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe ((2*fR_i), fLength, fFlowSpeed_Fluid1,...
                  fDyn_Visc_Fluid1, fDensity_Fluid1,...
                  fThermal_Cond_Fluid1, fC_p_Fluid1, 1);  
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, fR_i,...
                (fD_i/2), fLength);
   
    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the thermal resistance from convection in the pipe
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
   %in case that condensation does occur this is the lower limit for the
    %heat flow. In case that nothing condenses it is the actual heat flow
    fHeatFlow = abs(fHeat_Capacity_Flow_1*(fEntry_Temp1-fOutlet_Temp_1));
    
    %% check for condensation
    %the CHX concept for counter flow heat exchangers is different from the
    %one for cross flow and parallel flow heat exchanger because it is not
    %possible to use the direct incremental HX approach used for the other
    %types, because for the counter flow type only one of the two necessary
    %inflow temperatures is known for each incremental HX at either side.
    %Therefore the CHX approach for the counter flow heat exchanger
    %requires an iterative solution which requires more computations than
    %the incremental approach. For this reason the HX is first checked to
    %see if condensation can occur at all. To do this the lowest possible
    %wall temperature for the hot side is checked for condensation. This
    %temperature has to be at the hot side outlet.
    
    if fEntry_Temp1 > fEntry_Temp2 
        %for the wall temperature it is assumed that inlet coolant
        %temperature is the wall temperature because that is the overall
        %lowest temperature in the system so if no condensation occurs for
        %that temperature it is impossible for it to occur at all
        fTWall = fEntry_Temp2;
    
        afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow, fTWall, fOutlet_Temp_1,fEntry_Temp1, oFlow_1);
    else
        fTWall = fEntry_Temp1;
        
        afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow, fTWall, fOutlet_Temp_2,fEntry_Temp2, oFlow_2);
    end
    
    %now the iterative condensation calculation is only executed if
    %condensation does occur in the HX
    if fCondensateHeatFlow ~= 0
        
        %in order to prevent writing the whole calculation for each case of
        %fluid 1 beeing the hot one or fluid 2 beeing the hot one the
        %indices will be changed to hot and cold for the calculation.
        if  fEntry_Temp1 > fEntry_Temp2 
            fEntryTempHot = fEntry_Temp1;
            fOutletTempHot_Normal =  fOutlet_Temp_1;
            fOutletTempHot_New = fOutlet_Temp_1;
            fEntryTempCold = fEntry_Temp2;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_1;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_2;
            oFlowHot = oFlow_1;
        else
            fEntryTempHot = fEntry_Temp2;
            fOutletTempHot_Normal =  fOutlet_Temp_2;
            fOutletTempHot_New = fOutlet_Temp_2;
            fEntryTempCold = fEntry_Temp1;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_2;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_1;
            oFlowHot = oFlow_2;
        end
        fHeatFlow_Old = 0;
        iCounter = 0;
        
        while (abs(fHeatFlow-fHeatFlow_Old) > 1e-8) && iCounter < 1000
            
            %the effect of condensation on the heat flow is taken into
            %account by increasing the heat capacity flow for the hot fluid
            %by a value calculated based on the amount of heat taken up by
            %the condensation
            fPhaseChangeHeatCapacityFlow = abs(fCondensateHeatFlow/(fEntryTempHot-fOutletTempHot_New));

            %then the normal heat exchanger function is used to calculate
            %the new outlet temperatures using the adapted heat capacity
            %flow
            [fOutletTempCold_New, fOutletTempHot_New] = temperature_counterflow ...
                (fArea, fU, fHeatCapacityFlowCold, (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow),...
                 fEntryTempCold, fEntryTempHot);

            %with the new outlet temperatures a new value for the heat flow
            %can be calculated that is higher than the previous value
            %(because the condensation keeps the temperature at an higher
            %level over all)
            fHeatFlow_Old = fHeatFlow;
            fHeatFlow = (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow)*(fEntryTempHot-fOutletTempHot_New);

            [sCondensateFlowRate, ~,~,fCondensateHeatFlow] = condensation(oHX, struct(), fHeatCapacityFlowHot, fHeatFlow, fTWall,...
                fOutletTempHot_Normal,fEntryTempHot, oFlowHot);

            iCounter = iCounter+1;
        end
        
        if  fEntry_Temp1 > fEntry_Temp2 
            fOutlet_Temp_1 = fOutletTempHot_New;
            fOutlet_Temp_2 = fOutletTempCold_New;
        else
            fOutlet_Temp_2 = fOutletTempHot_New;
            fOutlet_Temp_1 = fOutletTempCold_New;
        end
        oHX.sCondensateMassFlow = sCondensateFlowRate;
        
    else
        %if nothing condenses the condensate mass flow in the oHX object
        %has to be set to an empty struct
        oHX.sCondensateMassFlow = struct();
    end
    
    oHX.fTotalCondensateHeatFlow = fCondensateHeatFlow;
    oHX.fTotalHeatFlow = fHeatFlow;
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = functions.calculateDeltaPressure.Pipe((2*fR_i), fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe((fD_o - fD_i), fLength,...
                    fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                    fDensity_Fluid2, 2, fD_o);

%%    
elseif strcmpi(sHX_type, 'counter plate')
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fBroadness  = mHX(1);
    fHeight_1  = mHX(2);
    fHeight_2  = mHX(3);
    fLength     = mHX(4);
    fThickness  = mHX(5);
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids within calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = fMassFlow2 * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = fBroadness*fLength;
    
    %uses the function for convection along a plate to calculate
    %the convection coeffcient for fluid 1 (for further information view 
    %function help)
    falpha_1 = functions.calculateHeatTransferCoefficient.convectionPlate (fLength, fFlowSpeed_Fluid1,...
                fDyn_Visc_Fluid1, fDensity_Fluid1, fThermal_Cond_Fluid1,...
                fC_p_Fluid1);

    %uses the function for convection along a plate to calculate
    %the convection coeffcient for fluid 2 (for further information view 
    %function help)
    falpha_2 = functions.calculateHeatTransferCoefficient.convectionPlate (fLength, fFlowSpeed_Fluid2,...
                    fDyn_Visc_Fluid2, fDensity_Fluid2,...
                    fThermal_Cond_Fluid2, fC_p_Fluid2);
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)    
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 2, fArea,...
                    fThickness); 
    
    %calculates the thermal resistance from convection on both sides of the
    %plate
    fR_alpha_1 = 1/(fArea * falpha_1);
    fR_alpha_2 = 1/(fArea * falpha_2);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea*(fR_alpha_1 + fR_alpha_2 + fR_lambda));

    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
   %in case that condensation does occur this is the lower limit for the
    %heat flow. In case that nothing condenses it is the actual heat flow
    fHeatFlow = abs(fHeat_Capacity_Flow_1*(fEntry_Temp1-fOutlet_Temp_1));
    
    %% check for condensation
    %the CHX concept for counter flow heat exchangers is different from the
    %one for cross flow and parallel flow heat exchanger because it is not
    %possible to use the direct incremental HX approach used for the other
    %types, because for the counter flow type only one of the two necessary
    %inflow temperatures is known for each incremental HX at either side.
    %Therefore the CHX approach for the counter flow heat exchanger
    %requires an iterative solution which requires more computations than
    %the incremental approach. For this reason the HX is first checked to
    %see if condensation can occur at all. To do this the lowest possible
    %wall temperature for the hot side is checked for condensation. This
    %temperature has to be at the hot side outlet.
    
    if fEntry_Temp1 > fEntry_Temp2 
        %for the wall temperature it is assumed that inlet coolant
        %temperature is the wall temperature because that is the overall
        %lowest temperature in the system so if no condensation occurs for
        %that temperature it is impossible for it to occur at all
        fTWall = fEntry_Temp2;
    
        afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow, fTWall, fOutlet_Temp_1,fEntry_Temp1, oFlow_1);
    else
        fTWall = fEntry_Temp1;
        
        afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow, fTWall, fOutlet_Temp_2,fEntry_Temp2, oFlow_2);
    end
    
    %now the iterative condensation calculation is only executed if
    %condensation does occur in the HX
    if fCondensateHeatFlow ~= 0
        
        %in order to prevent writing the whole calculation for each case of
        %fluid 1 beeing the hot one or fluid 2 beeing the hot one the
        %indices will be changed to hot and cold for the calculation.
        if  fEntry_Temp1 > fEntry_Temp2 
            fEntryTempHot = fEntry_Temp1;
            fOutletTempHot_Normal =  fOutlet_Temp_1;
            fOutletTempHot_New = fOutlet_Temp_1;
            fEntryTempCold = fEntry_Temp2;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_1;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_2;
            oFlowHot = oFlow_1;
            
            afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
        else
            fEntryTempHot = fEntry_Temp2;
            fOutletTempHot_Normal =  fOutlet_Temp_2;
            fOutletTempHot_New = fOutlet_Temp_2;
            fEntryTempCold = fEntry_Temp1;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_2;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_1;
            oFlowHot = oFlow_2;
            
            afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
        end
        fHeatFlow_Old = 0;
        iCounter = 0;
        
        while iCounter == 0 || (abs(fHeatFlow-fHeatFlow_Old) > 1e-8) && iCounter < 1000
            
            %the effect of condensation on the heat flow is taken into
            %account by increasing the heat capacity flow for the hot fluid
            %by a value calculated based on the amount of heat taken up by
            %the condensation
            fPhaseChangeHeatCapacityFlow = abs(fCondensateHeatFlow/(fEntryTempHot-fOutletTempHot_New));

            %then the normal heat exchanger function is used to calculate
            %the new outlet temperatures using the adapted heat capacity
            %flow
            [fOutletTempCold_New, fOutletTempHot_New] = temperature_counterflow ...
                (fArea, fU, fHeatCapacityFlowCold, (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow),...
                 fEntryTempCold, fEntryTempHot);

            %with the new outlet temperatures a new value for the heat flow
            %can be calculated that is higher than the previous value
            %(because the condensation keeps the temperature at an higher
            %level over all)
            fHeatFlow_Old = fHeatFlow;
            fHeatFlow = (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow)*(fEntryTempHot-fOutletTempHot_New);

            [sCondensateFlowRate, ~,~,fCondensateHeatFlow] = condensation(oHX, afCondensableFlowRate, fHeatCapacityFlowHot, fHeatFlow, fTWall,...
                fOutletTempHot_Normal,fEntryTempHot, oFlowHot);

            iCounter = iCounter+1;
        end
        
        if  fEntry_Temp1 > fEntry_Temp2 
            fOutlet_Temp_1 = fOutletTempHot_New;
            fOutlet_Temp_2 = fOutletTempCold_New;
        else
            fOutlet_Temp_2 = fOutletTempHot_New;
            fOutlet_Temp_1 = fOutletTempCold_New;
        end
        oHX.sCondensateMassFlow = sCondensateFlowRate;
        
    else
        %if nothing condenses the condensate mass flow in the oHX object
        %has to be set to an empty struct
        oHX.sCondensateMassFlow = struct();
    end
    
    oHX.fTotalCondensateHeatFlow = fCondensateHeatFlow;
    oHX.fTotalHeatFlow = fHeatFlow;
    
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_1)) , fLength,...
                  fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                  (2*fBroadness+2*fHeight_2)) , fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 1);
              
%% shuttle condensing heat exchanger used in HESTIA
elseif strcmpi(sHX_type, 'shuttle CHX')
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    
    if abs(oFlow_1.fMolMass - oFlow_1.oMT.afMolMass(oFlow_1.oMT.tiN2I.H2O)) < 1e-8
        oWaterFlow = oFlow_1;
        oAirFlow = oFlow_2;
    elseif abs(oFlow_2.fMolMass - oFlow_2.oMT.afMolMass(oFlow_1.oMT.tiN2I.H2O)) < 1e-8
        oWaterFlow = oFlow_2;
        oAirFlow = oFlow_1;
    else
        error('shuttle CHX only works with water as coolant')
    end
    
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = fMassFlow2 * fC_p_Fluid2(1);
    
    %area set to 1 because it is already account for in the empirical
    %calculation for U for this heat exchanger
    fArea = 1;
    
    %flow rates have to be converted to lb/hr because of the empirical
    %equation
    fAirFlow = (oAirFlow.fFlowRate*3600)*(1/0.45359237); %lb/hr
    fWaterFlow = (oWaterFlow.fFlowRate*3600)*(1/0.45359237); %lb/hr
    %calculates the heat exchange coeffcient fU based on the empirical
    %equation for the shuttle heat exchanger assuming that no condensation
    %occurs
    fU = ((exp(2.809-(0.00169*fWaterFlow)))*((fAirFlow*1)^(0.52+(0.00026*fWaterFlow))));

    %If heat exchanger coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet tempratures. Since this function differentiates not between the
    %fluid in the pipes and outside the pipes but between hot and cold a if
    %function is needed to discren which fluid is hotter. (for further
    %information view function help)
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2, fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end
    
    %in case that condensation does occur this is the lower limit for the
    %heat flow. In case that nothing condenses it is the actual heat flow
    fHeatFlow = abs(fHeat_Capacity_Flow_1*(fEntry_Temp1-fOutlet_Temp_1));
    
    %% check for condensation
    %the CHX concept for counter flow heat exchangers is different from the
    %one for cross flow and parallel flow heat exchanger because it is not
    %possible to use the direct incremental HX approach used for the other
    %types, because for the counter flow type only one of the two necessary
    %inflow temperatures is known for each incremental HX at either side.
    %Therefore the CHX approach for the counter flow heat exchanger
    %requires an iterative solution which requires more computations than
    %the incremental approach. For this reason the HX is first checked to
    %see if condensation can occur at all. To do this the lowest possible
    %wall temperature for the hot side is checked for condensation. This
    %temperature has to be at the hot side outlet.
    
    if fEntry_Temp1 > fEntry_Temp2 
        %for the wall temperature it is assumed that inlet coolant
        %temperature is the wall temperature because that is the overall
        %lowest temperature in the system so if no condensation occurs for
        %that temperature it is impossible for it to occur at all
        fTWall = fEntry_Temp2;
    
        afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow, fTWall, fOutlet_Temp_1,fEntry_Temp1, oFlow_1);
    else
        fTWall = fEntry_Temp1;
        
        afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
        
        [sCondensateFlowRate, ~, ~, fCondensateHeatFlow] = condensation ...
                (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow, fTWall, fOutlet_Temp_2,fEntry_Temp2, oFlow_2);
    end
    
    %now the iterative condensation calculation is only executed if
    %condensation does occur in the HX
    if fCondensateHeatFlow ~= 0
        
        %in order to prevent writing the whole calculation for each case of
        %fluid 1 beeing the hot one or fluid 2 beeing the hot one the
        %indices will be changed to hot and cold for the calculation.
        if  fEntry_Temp1 > fEntry_Temp2 
            fEntryTempHot = fEntry_Temp1;
            fOutletTempHot_Normal =  fOutlet_Temp_1;
            fOutletTempHot_New = fOutlet_Temp_1;
            fEntryTempCold = fEntry_Temp2;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_1;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_2;
            oFlowHot = oFlow_1;
        else
            fEntryTempHot = fEntry_Temp2;
            fOutletTempHot_Normal =  fOutlet_Temp_2;
            fOutletTempHot_New = fOutlet_Temp_2;
            fEntryTempCold = fEntry_Temp1;
            fHeatCapacityFlowHot = fHeat_Capacity_Flow_2;
            fHeatCapacityFlowCold = fHeat_Capacity_Flow_1;
            oFlowHot = oFlow_1;
        end
        fHeatFlow_Old = 0;
        iCounter = 0;
        
        while (abs(fHeatFlow-fHeatFlow_Old) > 1e-8) && iCounter < 1000
            
            %calculates the heat exchange coeffcient fU based on the empirical
            %equation for the shuttle heat exchanger with condensation.
            fU = (exp(2.809-0.00169*fWaterFlow)*(fAirFlow*(fHeatFlow/(fHeatFlow-fCondensateHeatFlow)))^(0.52+0.00026*fWaterFlow));
            
            if fU == Inf
                fU = (exp(2.809-0.00169*fWaterFlow)*(fAirFlow*(fHeatFlow/(fHeatFlow-(0.9*fCondensateHeatFlow))))^(0.52+0.00026*fWaterFlow));
            end
            %the effect of condensation on the heat flow is taken into
            %account by increasing the heat capacity flow for the hot fluid
            %by a value calculated based on the amount of heat taken up by
            %the condensation
            fPhaseChangeHeatCapacityFlow = fCondensateHeatFlow/(fEntryTempHot-fOutletTempHot_New);

            %then the normal heat exchanger function is used to calculate
            %the new outlet temperatures using the adapted heat capacity
            %flow
            [fOutletTempCold_New, fOutletTempHot_New] = temperature_counterflow ...
                (fArea, fU, fHeatCapacityFlowCold, (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow),...
                 fEntryTempCold, fEntryTempHot);

            %with the new outlet temperatures a new value for the heat flow
            %can be calculated that is higher than the previous value
            %(because the condensation keeps the temperature at an higher
            %level over all)
            fHeatFlow_Old = fHeatFlow;
            fHeatFlow = (fHeatCapacityFlowHot+fPhaseChangeHeatCapacityFlow)*(fEntryTempHot-fOutletTempHot_New);

            %TO DO
            %since it is not possible to calculate the wall temperature for
            %this heat exchanger the coolant temperature will be assumed to
            %be the wall temperature. However because the incremental
            %approach was not possible for counter flow HX it is not
            %possible to calculate different temperatures and therefore one
            %temperature has to be chosen. One possibility is to use the
            %average temp which is the most accurate overall value but
            %prevents condensation in some cases where it might be
            %possible. Another one would be the inlet coolant temp which
            %would allow condensation in any case where it is possible but
            %it would overestimate the condensate flow rate because of the
            %low temperature.
            %However if the average temperature is used a new problem
            %arises. Then whether condensation occurs or not depends on the
            %iterated outlet temperature of the cold flow and the iteration
            %can get stuck by jumping between a case with and a case
            %without condensation. Therefore and because the correlation
            %with data showed that the condensate flow is underestimate the
            %inlet coolant temperature is used.
            %fTWall = (fEntryTempCold+fOutletTempCold_New)/2;

            %the outlet temperature from the condensation calculation is
            %not required in this case and can even be wrong because the
            %heat capacity flow as increased for the
            %temperature_counterflow calculation which makes it possible
            %for the outlet temperature calculated here to be lower than
            %coolant entry temperature.
            [sCondensateFlowRate, ~,~,fCondensateHeatFlow] = condensation(oHX, struct(), fHeatCapacityFlowHot, fHeatFlow, fTWall,...
                fOutletTempHot_Normal,fEntryTempHot, oFlowHot);

            iCounter = iCounter+1;
        end
        
        if  fEntry_Temp1 > fEntry_Temp2 
            fOutlet_Temp_1 = fOutletTempHot_New;
            fOutlet_Temp_2 = fOutletTempCold_New;
        else
            fOutlet_Temp_2 = fOutletTempHot_New;
            fOutlet_Temp_1 = fOutletTempCold_New;
        end
        oHX.sCondensateMassFlow = sCondensateFlowRate;
        
    else
        %if nothing condenses the condensate mass flow in the oHX object
        %has to be set to an empty struct
        oHX.sCondensateMassFlow = struct();
    end
    
    oHX.fTotalCondensateHeatFlow = fCondensateHeatFlow;
    oHX.fTotalHeatFlow = fHeatFlow;
    
    %% for data correlation purposes
%     fSensibelHeatFlow = fHeatFlow - fCondensateHeatFlow;
%     
%     fA = 4.6543;
%     fB = 1435.264;
%     fC = -64.848;
%     fDewPoint = ((fB/(fA-log10(oHX.oParent.toStores.TVAC.aoPhases(1,1).afPP(182)/(10^5))))-fC);
%     
%     sprintf(' DewPoint: %.2f \n T_air_out: %.2f \n T_water_out: %.2f \n Q_sensible: %.2f \n Q_latent: %.2f' , fDewPoint, fOutlet_Temp_1, fOutlet_Temp_2,...
%         fSensibelHeatFlow, fCondensateHeatFlow)
%     
%     keyboard()
    
    %currently no pressure loss calculation but because the manual solver
    %is used this is not a problem.
    fDelta_P_1 = 0; %value from NASA documents for airside pressure loss is 0.0006 psi 
    fDelta_P_2 = 0;%value from NASA documents for coolant side pressure loss is 0.7326 psi
%%    
%% ISS condensing heat exchanger based on effectivness
elseif strcmpi(sHX_type, 'ISS CHX')
    
    %Assumes flow 1 to be the air flow
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
%     try
%         oFlow_2 = oHX.oF2F_2.getInFlow(); 
%     catch
%         oFlow_2 = oHX.oF2F_2.aoFlows(1);
%     end
    
    fWaterPressure = oFlow_1.afPartialPressure(oHX.oMT.tiN2I.H2O);
    
    %Instead of a geometry input the ISS CHX uses an effectiness
    %calculation and the mHX input is an interpolation of this effectiness
    interpolateEffectiveness = mHX;
    
    %Antoine Equation for Water from nist chemistry webbook
    fA = 4.6543;
    fB = 1435.264;
    fC = -64.848;
    fDewPoint = ((fB/(fA-log10(fWaterPressure/oFlow_1.fPressure)))-fC);
    
    fVolumetricFlowRate = oFlow_1.calculateVolumetricFlowRate(); %[m^3/s]
    
    %The empire strikes back! All values have to converted to imperial
    %units
    fDewPointImp = fDewPoint * 1.8 - 459.67; % [F]
    fAirInletTempImp = Fluid_1.Entry_Temperature * 1.8 - 459.67; % [F]
    fAirInletFlowImp = fVolumetricFlowRate*2118.88; % [cfm] cubic feet per minute
    
    %ensures that values are within their boundaries
    fAirInletTempImp     = min(max(fAirInletTempImp,67), 82);
    fAirInletFlowImp     = min(max(fAirInletFlowImp,50),450);
    fDewPointImp         = min(max(fDewPointImp,42), 60);
                
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    
    %uses the interpolation for the effectiveness to calculatue the correct
    %one for the given values
    rEffectiveness = interpolateEffectiveness( fDewPointImp, fAirInletTempImp, fAirInletFlowImp ); % had a  + 0.10 orginally
    
    %since the effectivity interpolation does not take coolant inlet values
    %into account these effects have to be modeled seperatly by scaling the
    %effectivness with another factor that is calculated by calculating the 
    %ratio between the heat flows for the nominal case (4.1�C coolant temp
    %and 600 lb/hr flow rate) with the actual case and multiplying this
    %ratio with the effectivness from above. I know that this is just a
    %work around but it has to do for now!
    %just some dummy values to generate a somewhat scaleable effect, since
    %the geometry is the same for both cases and only the ratio of the heat
    %flows is calculate this does not have a great effect on the final result.
    fArea = 1;
    fD_i = 0.2;
    fD_o = 0.4;
    fR_i = 0.08;
    fLength = 1;
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(pi*(fD_i/2)^2*fDensity_Fluid1(1));
    %flow speed of the fluid in the annular passage
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));   
                    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help)
    falpha_o = functions.calculateHeatTransferCoefficient.convectionAnnularPassage (fD_i, fD_o, fLength,...
               fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
               fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe ((2*fR_i), fLength, fFlowSpeed_Fluid1,...
                  fDyn_Visc_Fluid1, fDensity_Fluid1,...
                  fThermal_Cond_Fluid1, fC_p_Fluid1, 1);  
    
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, fR_i,...
                (fD_i/2), fLength);
   
    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_o = 1/(fArea * falpha_o);
    
    %calculates the thermal resistance from convection in the pipe
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    % In order to include the influence of the coolant temperature, a
    % normal heat exchanger function is calculated and used to compare the
    % heat transfer for the current coolant temperature and for the nominal
    % coolant temperature, to calculate a coolant temperature influence
    % factor
    if fEntry_Temp1 > fEntry_Temp2
        
        fFlowSpeed_Fluid2_Nominal = (600*0.000125997881)/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));   
        falpha_o_Nominal = functions.calculateHeatTransferCoefficient.convectionAnnularPassage (fD_i, fD_o, fLength,...
               fFlowSpeed_Fluid2_Nominal, fDyn_Visc_Fluid2, fDensity_Fluid2,...
               fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
        fR_alpha_o_Nominal = 1/(fArea * falpha_o_Nominal);
        fU_Nominal = 1/(fArea * (fR_alpha_o_Nominal + fR_alpha_i + fR_lambda));
        
        [~, fOutlet_Temp_1_Nominal] = temperature_counterflow ...
        (fArea, fU_Nominal, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
         277.25, fEntry_Temp1);
        [~, fOutlet_Temp_1] = temperature_counterflow ...
        (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
         fEntry_Temp2, fEntry_Temp1);
    else
        error('fluid 1 has to be the air, and the air has to be hotter than the coolant')
    end
    fHeatFlowNominal = abs(fHeat_Capacity_Flow_1*(fEntry_Temp1-fOutlet_Temp_1_Nominal));
    fHeatFlowOffNominal = abs(fHeat_Capacity_Flow_1*(fEntry_Temp1-fOutlet_Temp_1));
    fCoolantTemperatureInfluenceFactor = fHeatFlowOffNominal/fHeatFlowNominal;
    
    % Additionally according to the diploma thesis from Christof roth, a
    % 18% higher effectiveness is assumed for doubled coolant flows.
    % However reverification showed better results for 9%
    fCoolantFlowCorrectionFactor = (((fMassFlow2 - 0.0756) / 0.0756) * (0.09));
        
    rEffectiveness = (rEffectiveness + fCoolantFlowCorrectionFactor) * fCoolantTemperatureInfluenceFactor;
    
    % The effectivness is based on the air side heat capacity flow which
    % means the heat flow can be calculated using the following equation
    fHeatFlow = rEffectiveness * fHeat_Capacity_Flow_1 * (fEntry_Temp1 - fEntry_Temp2);
    
    % from that the outlet temperature of the air can be calculated. As the
    % interpolated values are already with respect to condensation, this is
    % the actual air outlet temperature, but not the actual heat flow (as
    % it is the heatflow without condensation)
    fOutlet_Temp_1 = fEntry_Temp1 - fHeatFlow/fHeat_Capacity_Flow_1;
        
    %% check for condensation
    % assumption that air side does not change its temperature while
    % condensation occurs
    
    iIncrements = 10;               % Columns,      Rows
    mfOutlet_Temp_1         = zeros(iIncrements,    iIncrements+1);
    mfOutlet_Temp_2         = zeros(iIncrements+1,  iIncrements);
    mfWaterMassFlow         = zeros(iIncrements,    iIncrements+1);
    mfCondensateMassFlow    = zeros(iIncrements,    iIncrements);
    mfCondensateHeatFlow    = zeros(iIncrements,    iIncrements);
    
    mfOutlet_Temp_1(:,:)    = fEntry_Temp1;
    mfOutlet_Temp_2(:,:)    = fEntry_Temp2;
    
    %fWaterMassFlow = fMassFlow1.*oFlow_1.arPartialMass(oHX.oMT.tiN2I.H2O);

    fWaterMassFraction = oFlow_1.arPartialMass(oHX.oMT.tiN2I.H2O); %(fWaterPressure./oFlow_1.fPressure).*(oHX.oMT.afMolarMass(oHX.oMT.tiN2I.H2O)./oFlow_1.fMolarMass);
    fWaterMassFlow = fMassFlow1 * fWaterMassFraction;
    mfWaterMassFlow(:,1) = fWaterMassFlow/iIncrements;
    
    % factor to represent the changes in coolant to air flow
    fFactor = 0.1 + (300* (fEntry_Temp2/278.79 - 1)) - (((fMassFlow2 - 0.0756) / 0.0756) * (0.36));
    
    if fFactor > 0.5
        fFactor = 0.5;
    elseif fFactor < 0
        fFactor = 0;
    end
    
    
    % The boundary flow ratio specifies how much of the air flow is assumed
    % to be in the boundary flow, which is assumed to have coolant
    % temperature (in the wall temperature for the overall flow the wall
    % temperature is calculated differently to account for the boundary
    % layer)
    rBoundaryFlowRatio = 0.05;
    
    for iRow = 1:iIncrements % rows are parallel to coolant flow
        for iColoumn = 1:iIncrements % columns are perpendicular to coolant flow
            
            fError = 1;
            iCounter = 0;
            while fError > 1e-4 && iCounter < 50
                % this condensation calculation basically calculates how much heat
                % the coolant flow can take before no condensation occcurs anymore.
                % The entry temperature of air is considered to reflect the
                % temperature difference between the coolant and the actual wall
                % temperature
                fVaporPressureBoundary = oHX.oMT.calculateVaporPressure(mfOutlet_Temp_2(iColoumn, iRow), 'H2O');
                fMaxMassFractionBoundary = (fVaporPressureBoundary./oFlow_1.fPressure).*(oHX.oMT.afMolarMass(oHX.oMT.tiN2I.H2O)./oFlow_1.fMolarMass);
                
                fMaxPartialMassFlowBoundary = ((rBoundaryFlowRatio * fMassFlow1)/iIncrements).*fMaxMassFractionBoundary;
                
                fCondensateMassFlowBoundary = (rBoundaryFlowRatio * mfWaterMassFlow(iColoumn, iRow)) - fMaxPartialMassFlowBoundary;
                % if the maximum allowed water flow is larger than the
                % current water flow, the values will become negative,
                % which only indicates that nothing will condense
                if fCondensateMassFlowBoundary < 0
                    fCondensateMassFlowBoundary = 0;
                end
                
                fTWall = fFactor * mfOutlet_Temp_1(iColoumn, iRow) + (1-fFactor) * mfOutlet_Temp_2(iColoumn, iRow);
                fVaporPressureWall = oHX.oMT.calculateVaporPressure(fTWall, 'H2O');
                fMaxMassFraction = (fVaporPressureWall./oFlow_1.fPressure).*(oHX.oMT.afMolarMass(oHX.oMT.tiN2I.H2O)./oFlow_1.fMolarMass);
                
                fMaxPartialMassFlow = (((1 - rBoundaryFlowRatio) * fMassFlow1)/iIncrements).*fMaxMassFraction;
                
                fCoreCondensateFlow = ((1- rBoundaryFlowRatio) * mfWaterMassFlow(iColoumn, iRow)) - fMaxPartialMassFlow;
                % if the maximum allowed water flow is larger than the
                % current water flow, the values will become negative,
                % which only indicates that nothing will condense
                if fCoreCondensateFlow < 0
                    fCoreCondensateFlow = 0;
                end
                
                mfCondensateMassFlow(iColoumn, iRow) = fCoreCondensateFlow + fCondensateMassFlowBoundary;
                
                mfCondensateHeatFlow(iColoumn, iRow) = mfCondensateMassFlow(iColoumn, iRow) * oHX.mPhaseChangeEnthalpy(oHX.oMT.tiN2I.H2O);

                % condensation occurs before changing the temperature, therefore
                % only the heatflow from condensation is considered here
                fOutlet_Temp_2_New = mfOutlet_Temp_2(iColoumn, iRow) + (mfCondensateHeatFlow(iColoumn, iRow) + fHeatFlow/(iIncrements^2))/(fHeat_Capacity_Flow_2/iIncrements);

                fError = abs(mfOutlet_Temp_2(iColoumn+1, iRow) - fOutlet_Temp_2_New);
                mfOutlet_Temp_2(iColoumn+1, iRow) = fOutlet_Temp_2_New;
                
                mfOutlet_Temp_1(iColoumn, iRow+1) =  mfOutlet_Temp_1(iColoumn, iRow) - (fHeatFlow/(iIncrements^2))/(fHeat_Capacity_Flow_1/iIncrements);
                
                iCounter = iCounter + 1;
            end
            mfWaterMassFlow(iColoumn, iRow + 1) = mfWaterMassFlow(iColoumn, iRow) - mfCondensateMassFlow(iColoumn, iRow);
        end
    end
    fCondensateHeatFlow =  sum(sum(mfCondensateHeatFlow));
    fOutlet_Temp_2 = fEntry_Temp2 + (fHeatFlow + fCondensateHeatFlow)/fHeat_Capacity_Flow_2;
    fCondensateMassFlow = sum(sum(mfCondensateMassFlow));
    
%     disp(['Condensate Flow: ', num2str(fCondensateMassFlow*3600)])
%     disp(['Air Outlet Temp: ', num2str(fOutlet_Temp_1)])
%     disp(['Coolant Outlet Temp: ', num2str(fOutlet_Temp_2)])
%     mesh(mfCondensateMassFlow)
    
    if fCondensateHeatFlow > 0
        oHX.sCondensateMassFlow = struct('H2O', fCondensateMassFlow);
    else
        %if nothing condenses the condensate mass flow in the oHX object
        %has to be set to an empty struct
        oHX.sCondensateMassFlow = struct();
    end
    
    oHX.fTotalCondensateHeatFlow = fCondensateHeatFlow;
    oHX.fTotalHeatFlow = fHeatFlow + fCondensateHeatFlow;
    
    %currently no pressure loss calculation but because the manual solver
    %is used this is not a problem.
    fDelta_P_1 = 0;
    fDelta_P_2 = 0;
    
%%    
elseif strcmpi(sHX_type, 'counter pipe bundle')

    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i    = mHX(1);
    fD_o    = mHX(2);
    fD_Shell    = mHX(3);
    fLength = mHX(4);
    fN_Pipes= mHX(5);
    fs_1    = mHX(6);
    fs_2    = mHX(7);
   
    %checks user input to prevent strange results (like negative areas) in
    %the following code
    if (pi*(fD_Shell/2)^2) < (fN_Pipes*(pi*(fD_o/2)^2))
        error('shell area smaller than sum of pipe areas, check inputs')
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluid calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) -...
                        (fN_Pipes*(pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area of the heat exchange
    fArea = (fN_Pipes*pi*(fD_i/2)*fLength);
    
    %uses the function for convection inside a pipe to calculate the heat
    %exchange outside the pipe bundle. This is done by calculating the
    %hydraulic diameter of the shell together with the pipes in the bundle
    
    fShell_Area         = pi*(fD_Shell/2)^2;
    fOuter_Bundle_Area  = fN_Pipes*pi*(fD_o/2)^2;
    fOuter_Hydraulic_Diameter = 4*(fShell_Area - fOuter_Bundle_Area)/...
                (pi*fD_Shell + fN_Pipes*pi*fD_o);
    
    falpha_o = functions.calculateHeatTransferCoefficient.convectionPipe(fOuter_Hydraulic_Diameter, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);

    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fLength);

    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);

    %calculates the thermal resistance from convection in the pipe
    fR_alpha_o = 1/(fArea * falpha_o);

    %calculates the heat exchange coefficient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
    %uses the function for counter flow heat exchangers to calculate the
    %outlet temperatures. Since this function differentiates not between    
    %the fluid in the pipes and outside the pipes but between hot and cold 
    %a if function is needed to discern which fluid is hotter. (for further
    %information view function help)  
        if fEntry_Temp1 > fEntry_Temp2
            [fOutlet_Temp_2 , fOutlet_Temp_1] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
             fEntry_Temp2, fEntry_Temp1);
        else
            [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_counterflow ...
            (fArea, fU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
             fEntry_Temp1, fEntry_Temp2);
        end
    end

    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(fD_i, fs_1, fs_2,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);

%%
elseif strcmpi(sHX_type, 'parallel annular passage')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i = mHX(1);
    fD_o = mHX(2);
    fR_i = mHX(3);
    fLength = mHX(4);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(pi*(fD_i/2)^2*fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_o/2)^2)-(pi*(fD_i/2)^2))*...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    %% New Code for Condensating Heat Exchanger
    %
    %In order to calculate the condensation in the heat exchanger it is
    %necessary to get the temperature in the heat exchanger at different
    %locations. This is achieved by splitting the heat exchanger into
    %several smaller heat exchangers and calculating their respective
    %outlet temperatures.
    
    fIncrementalLength = fLength/iIncrements;
    
    %calculates the area of the incremental heat exchangers
    fIncrementalArea = pi * fD_i * fIncrementalLength;
    
    %uses the function for convection in an annular passage to calculate
    %the outer convection coeffcient (for further information view function
    %help).NOTE: The full length is used here since the seperation of the
    %heat exchanger into several smaller one is just a way to get to the
    %internal temperatures and does not ifluence the convection
    %coefficients
    falpha_o = functions.calculateHeatTransferCoefficient.convectionAnnularPassage (fD_i, fD_o, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
 
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (2*fR_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 1);

    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, fR_i,...
                    (fD_i/2), fLength);

    %These values are again for the incrementel heat exchangers since the
    %area has been adapted
    %calculates the thermal resistance from convection in the pipe
    fR_alpha_i = 1/(fIncrementalArea * falpha_pipe);

    %calculates the thermal resistance from convection in the annular gap
    fR_alpha_o = 1/(fIncrementalArea * falpha_o);

    %calculates the heat exchange coeffcient fU
    fIncrementalU = 1/(fIncrementalArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fIncrementalU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %uses the function for parallel flow heat exchangers to calculate the
        %outlet tempratures. Since this function differentiates not between the
        %fluid in the pipes and outside the pipes but between hot and cold a if
        %function is needed to discren which fluid is hotter.(for further
        %information view function help)
        %
        %Now since the calculation is split into several small heat exchangers
        %the outlet temperatures are saved in a vector which contains from top
        %to bottom the different temperatures inside the heat exchanger
        mOutlet_Temp_2 = zeros(iIncrements,1);
        mOutlet_Temp_1 = zeros(iIncrements,1);
        acCondensateNames = cell(iIncrements);
        
        
        %unfortunatly there is no way around checking which flow is
        %beeing cooled down and implement the calculation twice with
        %just some changed values
        if fEntry_Temp1 > fEntry_Temp2
            
            afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;

            for k = 1:iIncrements
                %for the first component the actual entry temperatures of
                %the heat exchanger are used, for everything else the
                %outlet of the previous incremental heat exchanger is used
                %as inlet
                if k == 1
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     fEntry_Temp2, fEntry_Temp1);
                    %It is also necessary to calculate the wall temperature of
                    %the cooled gas side as well since that is the temperature
                    %that is the deciding factor for condensation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = (fR_alpha_o + fR_lambda)*abs(fHeatFlow_Old)+(fEntry_Temp2+mOutlet_Temp_2(k))/2;
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k),fEntry_Temp1, oFlow_1);
                else
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     mOutlet_Temp_2(k-1), mOutlet_Temp_1(k-1));
                    %wall temp calculation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = (fR_alpha_o + fR_lambda)*abs(fHeatFlow_Old)+(mOutlet_Temp_2(k-1)+mOutlet_Temp_2(k))/2;
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k), mOutlet_Temp_1(k-1), oFlow_1);
                end
                
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
            end
        else
            %% same as previous section just with some switches values
            
            afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
            %therefore no comment here
            for k = 1:iIncrements
                if k == 1
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     fEntry_Temp1, fEntry_Temp2);
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(fEntry_Temp1+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),fEntry_Temp2, oFlow_2);
                else
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     mOutlet_Temp_1(k-1), mOutlet_Temp_2(k-1));
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(mOutlet_Temp_1(k-1)+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),mOutlet_Temp_2(k-1), oFlow_2);
                end
                
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
            end
        end
        %%
        %sets the last values in the temperature vectors as the outlet
        %values since the temperature distribution is of no interest for
        %other parts of the program
        fOutlet_Temp_1 = mOutlet_Temp_1(end);
        fOutlet_Temp_2 = mOutlet_Temp_2(end);
    end
    
    %writes the values for condensation into the oHX object
    %for further use
    oHX.sCondensateMassFlow = sCondensateFlowRate;
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1 = functions.calculateDeltaPressure.Pipe((2*fR_i), fLength,...
                    fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                    fDensity_Fluid1, 0);
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe((fD_o - fD_i), fLength,...
                    fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                    fDensity_Fluid2, 2, fD_o);
  
%%
elseif strcmpi(sHX_type, 'parallel plate')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fBroadness  = mHX(1);
    fHeight_1  = mHX(2);
    fHeight_2  = mHX(3);
    fLength     = mHX(4);
    fThickness  = mHX(5);
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                        fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    %% New Code for Condensating Heat Exchanger
    %
    %In order to calculate the condensation in the heat exchanger it is
    %necessary to get the temperature in the heat exchanger at different
    %locations. This is achieved by splitting the heat exchanger into
    %several smaller heat exchangers and calculating their respective
    %outlet temperatures.
    
    fIncrementalLength = fLength/iIncrements;
    
    %calculates the area of the incremental heat exchangers
    fIncrementalArea = fBroadness*fIncrementalLength;
    
    %uses the function for convection along a plate to calculate the 
    %convection coeffcients (for further information view function help)
    falpha_o = functions.calculateHeatTransferCoefficient.convectionPlate (fLength, fFlowSpeed_Fluid1,...
                fDyn_Visc_Fluid1, fDensity_Fluid1, fThermal_Cond_Fluid1,...
                fC_p_Fluid1);
    falpha_i = functions.calculateHeatTransferCoefficient.convectionPlate (fLength, fFlowSpeed_Fluid2,...
                    fDyn_Visc_Fluid2, fDensity_Fluid2,...
                    fThermal_Cond_Fluid2, fC_p_Fluid2);
  
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)    
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 2, fIncrementalArea,...
                    fThickness);
   
    %calculates the thermal resistance from convection on both sides of the
    %plate
    fR_alpha_i = 1/(fIncrementalArea * falpha_i);
    fR_alpha_o = 1/(fIncrementalArea * falpha_o);
    
    %calculates the heat exchange coeffcient fU
    fIncrementalU = 1/(fIncrementalArea * (fR_alpha_o + fR_alpha_i + fR_lambda));

    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fIncrementalU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %uses the function for parallel flow heat exchangers to calculate the
        %outlet tempratures. Since this function differentiates not between the
        %fluid in the pipes and outside the pipes but between hot and cold a if
        %function is needed to discren which fluid is hotter.(for further
        %information view function help)
        %
        %Now since the calculation is split into several small heat exchangers
        %the outlet temperatures are saved in a vector which contains from top
        %to bottom the different temperatures inside the heat exchanger
        mOutlet_Temp_2 = zeros(iIncrements,1);
        mOutlet_Temp_1 = zeros(iIncrements,1);
        acCondensateNames = cell(iIncrements,1);
        sCondensateFlowRate = struct();
        %unfortunatly there is no way around checking which flow is
        %beeing cooled down and implement the calculation twice with
        %just some changed values
        if fEntry_Temp1 > fEntry_Temp2
            
            afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
            
            for k = 1:iIncrements
                %for the first component the actual entry temperatures of
                %the heat exchanger are used, for everything else the
                %outlet of the previous incremental heat exchanger is used
                %as inlet
                if k == 1
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     fEntry_Temp2, fEntry_Temp1);
                    %It is also necessary to calculate the wall temperature of
                    %the cooled gas side as well since that is the temperature
                    %that is the deciding factor for condensation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = fEntry_Temp2;
                    
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k),fEntry_Temp1, oFlow_1);
                else
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     mOutlet_Temp_2(k-1), mOutlet_Temp_1(k-1));
                    %wall temp calculation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = mOutlet_Temp_2(k-1);
                    
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k),mOutlet_Temp_1(k-1), oFlow_1);
                end
                
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
            end
        else
            %% same as previous section just with some switches values
            %therefore no comment here
            
            afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
            
            for k = 1:iIncrements
                if k == 1
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     fEntry_Temp1, fEntry_Temp2);
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(fEntry_Temp1+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),fEntry_Temp2, oFlow_2);
                else
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     mOutlet_Temp_1(k-1), mOutlet_Temp_2(k-1));
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(mOutlet_Temp_1(k-1)+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),mOutlet_Temp_2(k-1), oFlow_2);
                end
                
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
            end
        end
        %%
        %sets the last values in the temperature vectors as the outlet
        %values since the temperature distribution is of no interest for
        %other parts of the program
        fOutlet_Temp_1 = mOutlet_Temp_1(end);
        fOutlet_Temp_2 = mOutlet_Temp_2(end);
        
        %writes the values for condensation into the oHX object
        %for further use
        oHX.sCondensateMassFlow = sCondensateFlowRate;
    
    
        %calculation of pressure loss for both fluids:
        fDelta_P_1 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                      (2*fBroadness+2*fHeight_1)), fLength,...
                      fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
        fDelta_P_2 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                      (2*fBroadness+2*fHeight_2)) , fLength,...
                      fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 1);
    end
    
%%
elseif strcmpi(sHX_type, 'parallel pipe bundle')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    fD_i        = mHX(1);
    fD_o        = mHX(2);
    fD_Shell    = mHX(3);
    fLength     = mHX(4);
    fN_Pipes    = mHX(5);
    fs_1        = mHX(6);
    fs_2        = mHX(7);
  
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    if (pi*(fD_Shell/2)^2) < (fN_Pipes*(pi*(fD_o/2)^2))
        error('shell area smaller than sum of pipe areas, cheack inputs')
    end
    
    %flow speed for the fluids calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) -...
                        (fN_Pipes*(pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    %% New Code for Condensating Heat Exchanger
    %
    %In order to calculate the condensation in the heat exchanger it is
    %necessary to get the temperature in the heat exchanger at different
    %locations. This is achieved by splitting the heat exchanger into
    %several smaller heat exchangers and calculating their respective
    %outlet temperatures.
    
    fIncrementalLength = fLength/iIncrements;
    
    %calculates the area of the heat exchange
    fIncrementalArea = (fN_Pipes*pi*(fD_i/2)*fIncrementalLength);

    %uses the function for convection inside a pipe to calculate the heat
    %exchange outside the pipe bundle. This is done by calculating the
    %hydraulic diameter of the shell together with the pipes in the bundle
    
    fShell_Area         = pi*(fD_Shell/2)^2;
    fOuter_Bundle_Area  = fN_Pipes*pi*(fD_o/2)^2;
    fOuter_Hydraulic_Diameter = 4*(fShell_Area - fOuter_Bundle_Area)/...
                (pi*fD_Shell + fN_Pipes*pi*fD_o);
    
    falpha_o = functions.calculateHeatTransferCoefficient.convectionPipe(fOuter_Hydraulic_Diameter, fLength,...
                fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2,...
                fThermal_Cond_Fluid2, fC_p_Fluid2, 0);
    
    %uses the function for convection in a pipe to calculate the inner
    %convection coeffcient (for further information view function help)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
  
    %uses the function for thermal resisitvity to calculate the resistance 
    %from heat conduction (for further information view function help)
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fIncrementalLength);
   
    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_o = 1/(fIncrementalArea * falpha_o);
   
    %calculates the thermal resistance from convection in the pipe
   	fR_alpha_i = 1/(fIncrementalArea * falpha_pipe);

    %calculates the heat exchange coeffcient fU
    fIncrementalU = 1/(fIncrementalArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fIncrementalU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %uses the function for parallel flow heat exchangers to calculate the
        %outlet tempratures. Since this function differentiates not between the
        %fluid in the pipes and outside the pipes but between hot and cold a if
        %function is needed to discren which fluid is hotter.(for further
        %information view function help)
        %
        %Now since the calculation is split into several small heat exchangers
        %the outlet temperatures are saved in a vector which contains from top
        %to bottom the different temperatures inside the heat exchanger
        mOutlet_Temp_2 = zeros(iIncrements,1);
        mOutlet_Temp_1 = zeros(iIncrements,1);
        acCondensateNames = cell(iIncrements);
        sCondensateFlowRate = struct();
        %unfortunatly there is no way around checking which flow is
        %beeing cooled down and implement the calculation twice with
        %just some changed values
        if fEntry_Temp1 > fEntry_Temp2
            
            afCondensableFlowRate = oFlow_1.arPartialMass .* fMassFlow1;
            
            for k = 1:iIncrements
                %for the first component the actual entry temperatures of
                %the heat exchanger are used, for everything else the
                %outlet of the previous incremental heat exchanger is used
                %as inlet
                if k == 1
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     fEntry_Temp2, fEntry_Temp1);
                    %It is also necessary to calculate the wall temperature of
                    %the cooled gas side as well since that is the temperature
                    %that is the deciding factor for condensation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = (fR_alpha_o + fR_lambda)*abs(fHeatFlow_Old)+(fEntry_Temp2+mOutlet_Temp_2(k))/2;
                    
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k),fEntry_Temp1, oFlow_1);
                else
                    [mOutlet_Temp_2(k), mOutlet_Temp_1(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_2, fHeat_Capacity_Flow_1,...
                     mOutlet_Temp_2(k-1), mOutlet_Temp_1(k-1));
                    %wall temp calculation
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    %wall temp
                    fTwall = (fR_alpha_o + fR_lambda)*abs(fHeatFlow_Old)+(mOutlet_Temp_2(k-1)+mOutlet_Temp_2(k))/2;
                    
                    %now uses the condensation function to calculate a
                    %struct containing the condensate names as fields and
                    %the condensate mass flows as field values and also
                    %calculates the new outlet temperature
                    [sCondensateFlowRateCell, mOutlet_Temp_1(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_1, fHeatFlow_Old, fTwall, mOutlet_Temp_1(k),mOutlet_Temp_1(k-1), oFlow_1);
                end
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
            end
        else
            %% same as previous section just with some switches values
            %therefore no comment here
            
            afCondensableFlowRate = oFlow_2.arPartialMass .* fMassFlow2;
            
            for k = 1:iIncrements
                if k == 1
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     fEntry_Temp1, fEntry_Temp2);
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(fEntry_Temp1-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(fEntry_Temp1+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),fEntry_Temp2, oFlow_2);
                else
                    [mOutlet_Temp_1(k), mOutlet_Temp_2(k)] = temperature_parallelflow...
                    (fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                     mOutlet_Temp_1(k-1), mOutlet_Temp_2(k-1));
                    fHeatFlow_Old = fHeat_Capacity_Flow_1*(mOutlet_Temp_1(k-1)-mOutlet_Temp_1(k));
                    fTwall = (fR_alpha_i + fR_lambda)*abs(fHeatFlow_Old)+(mOutlet_Temp_1(k-1)+mOutlet_Temp_1(k))/2;
                    
                    [sCondensateFlowRateCell, mOutlet_Temp_2(k), acCondensateNames{k}] = condensation ...
                            (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_2, fHeatFlow_Old, fTwall, mOutlet_Temp_2(k),mOutlet_Temp_2(k-1), oFlow_2);
                end
                
                % Reduce the condensable flowrate by the already condensed
                % flow
                acCondensateNamesCell = acCondensateNames{k};
                for n = 1:length(acCondensateNamesCell)
                    afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) = afCondensableFlowRate(oHX.oMT.tiN2I.(acCondensateNamesCell{n})) - sCondensateFlowRateCell.(acCondensateNamesCell{n});
                end
                
                % Add the condensate flow to the current condensation flow
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end         
            end
        end
        %%
        %sets the last values in the temperature vectors as the outlet
        %values since the temperature distribution is of no interest for
        %other parts of the program
        fOutlet_Temp_1 = mOutlet_Temp_1(end);
        fOutlet_Temp_2 = mOutlet_Temp_2(end);
    end
    
    %writes the values for condensation into the oHX object
    %for further use
    oHX.sCondensateMassFlow = sCondensateFlowRate;
    
    
    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(fD_i, fs_1, fs_2,...
                     fFlowSpeed_Fluid1, fDyn_Visc_Fluid1, fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);

%%    
elseif strcmpi(sHX_type, 'cross')
    
    %allocates the entry for the number of pipe rows to decide how the 
    %programm should proceed    
    fN_Rows = mHX(1);
    %if the number of rows is larger than 0 it means that pipes were used
    %and the entries from mHX can be allocated as follows
    if fN_Rows > 0
        fN_Pipes    = mHX(2);
        fD_i        = mHX(3);
        fD_o        = mHX(4);
        fLength     = mHX(5);
        fs_1        = mHX(6); 
        fs_2        = mHX(7);
        fConfig     = mHX(8);
        if length(mHX) == 9
            fs_3    = mHX(9); 
        end
        %calculates the further needed variables for the heat exchanger
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = fMassFlow1/(fN_Pipes*pi*(fD_i/2)^2 *...
                            fDensity_Fluid1(1));
        fFlowSpeed_Fluid2 = fMassFlow2/(((fs_1 - fD_i)* fLength *...
                            (fN_Pipes/fN_Rows)) * fDensity_Fluid2(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
        fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
        
        fN_PipesPerRow = fN_Pipes/fN_Rows;
        if mod(fN_PipesPerRow,1) ~= 0
            error('the number of pipes must be dividable with the number of rows')
        end
        
        fIncrementalLength = fLength/iIncrements;
        %calculates the area of the heat exchanger
        %fArea = (fN_Pipes*pi*fD_i*fLength);  
        
        %Area for one pipe row
        fIncrementalArea = (fN_PipesPerRow*pi*fD_i*fIncrementalLength);
        
        %calculation of pressure loss for both fluids:
        fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(fD_i , fLength,...
                                fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                                fDensity_Fluid1, 0);
        fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(fD_i, fs_1, fs_2,...
                                fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                                fDensity_Fluid1);
    
        fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
        
        %for the pressure loss in the pipe bundle it is only differenitated
        %between aligend and shiffted configuration and not also between
        %partially shiffted
        if fConfig == 0
            fDelta_P_2 = functions.calculateDeltaPressure.PipeBundle(fD_o, fs_1, fs_2,...
                           fN_Rows, fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                           fDensity_Fluid2, 0); 
        elseif fConfig == 1 || fConfig == 2
            fDelta_P_2 = functions.calculateDeltaPressure.PipeBundle(fD_o, fs_1, fs_2,...
                           fN_Rows, fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                           fDensity_Fluid2, 1);
        else
            error('wrong input for fConfig')
        end
    end
  
    %for fN_Rows = 0 no pipes were used => plate heat exchanger
    if fN_Rows == 0
        
        %allocates the entries in the mHX vector from the user entry to the
        %respective variables if a plate heat exchanger is used
        fBroadness  = mHX(2);
        fHeight_1   = mHX(3);
        fHeight_2   = mHX(4);
        fLength     = mHX(5);
        fThickness  = mHX(6);
    
        %calculates the further needed variables for the heat exchanger 
        %from the given values
        
        %flow speed for the fluids calculated from the massflow
        %with massflow = volumeflow*rho = fw*fA*frho        
        fFlowSpeed_Fluid1 = fMassFlow1/(fHeight_1 * fBroadness *...
                            fDensity_Fluid1(1));
        fFlowSpeed_Fluid2 = fMassFlow2/(fHeight_2 * fBroadness *...
                            fDensity_Fluid2(1));
        %heat capacity flow according to [1] page 173 equation (8.1)
        fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
        fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
        %calculates the area of the heat exchanger
        %fArea = fBroadness*fLength;
        
        fIncrementalLength = fLength/iIncrements;
        fIncrementalArea = (fBroadness/iIncrements)*fIncrementalLength;
        
        %uses the function for convection along a plate to calculate the 
        %convection coeffcients(for further information view function help)
        falpha_o = functions.calculateHeatTransferCoefficient.convectionPlate(fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1);
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPlate(fLength, fFlowSpeed_Fluid2,...
                        fDyn_Visc_Fluid2, fDensity_Fluid2,...
                        fThermal_Cond_Fluid2, fC_p_Fluid2);
 
        %uses the function for thermal resisitvity to calculate the 
        %resistance from heat conduction (for further information view
        %function help)    
        fR_lambda_Incremental = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 2, fIncrementalArea,...
                        fThickness, fIncrementalLength);

        %calculation of pressure loss for both fluids:
        fDelta_P_1 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                        (2*fBroadness+2*fHeight_1)) , fLength,...
                        fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                        fDensity_Fluid1, 0);
        fDelta_P_2 = functions.calculateDeltaPressure.Pipe(((4*fBroadness*fHeight_1)/...
                        (2*fBroadness+2*fHeight_2)) , fLength,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, 1);
        
    %for fN_Rows = 1 a single pipe row was used 
    elseif fN_Rows == 1
        %uses the function for convection at one row of pipes to calculate
        %the outer convection coeffcient (for further information view
        %function help)
        falpha_o = functions.calculateHeatTransferCoefficient.convectionOnePipeRow(fD_o,fs_1, fFlowSpeed_Fluid2,...
            fDyn_Visc_Fluid2, fDensity_Fluid2, fThermal_Cond_Fluid2,...
            fC_p_Fluid2);
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
    
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
        fR_lambda_Incremental = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid,0, (fD_i/2),...
            (fD_o/2), fIncrementalLength);
   
    %for fN_Rows > 1 multiple pipe rows
    elseif fN_Rows > 1
        %uses the function for convection at multiple pipe rows to
        %calculate the outer convection coeffcient (for further 
        %information view function help)
        
        %partially shiffted configuration
        if fConfig == 2
            falpha_o = functions.calculateHeatTransferCoefficient.convectionMultiplePipeRow (fD_o, fs_1, fs_2,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, fThermal_Cond_Fluid2,...
                        fC_p_Fluid2, fConfig, fs_3);
        %aligend or shiffted configuration
        elseif fConfig == 1 || fConfig == 0
            falpha_o = functions.calculateHeatTransferCoefficient.convectionMultiplePipeRow (fD_o, fs_1, fs_2,...
                        fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                        fDensity_Fluid2, fThermal_Cond_Fluid2,...
                        fC_p_Fluid2, fConfig);
        else
            error('wrong input for fConfig')
        end
        
        %uses the function for convection in a pipe to calculate the inner
        %convection coeffcient (for further information view function help)
        falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                        fDyn_Visc_Fluid1, fDensity_Fluid1,...
                        fThermal_Cond_Fluid1, fC_p_Fluid1, 0);
   
        %uses the function for thermal resisitvity to calculate the resis-
        %tance from conduction (for further information view function help)
    	fR_lambda_Incremental = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid,0, (fD_i/2),... 
                        (fD_o/2), fIncrementalLength);                    
                    
   
    else 
        error('no negative input for the number of pipe rows allowed')
    end

    %calculates the thermal resistance from convection in the pipes
    fR_alpha_i_Incremental = 1/(fIncrementalArea * falpha_pipe);
    
    %calculates the thermal resistance from convection outside the pipes
    fR_alpha_o_Incremental = 1/(fIncrementalArea * falpha_o);
    
    %calculates the heat exchange coefficient
    fIncrementalU = 1/(fIncrementalArea * (fR_alpha_o_Incremental + fR_alpha_i_Incremental + fR_lambda_Incremental));
    
    try
        oFlow_1 = oHX.oF2F_1.getInFlow(); 
    catch
        oFlow_1 = oHX.oF2F_1.aoFlows(1);
    end
    try
        oFlow_2 = oHX.oF2F_2.getInFlow(); 
    catch
        oFlow_2 = oHX.oF2F_2.aoFlows(1);
    end
    %% New Code for Condensating Heat Exchanger
    %
    %In order to calculate the condensation in the heat exchanger it is
    %necessary to get the temperature in the heat exchanger at different
    %locations. This is achieved by splitting the heat exchanger into
    %several smaller heat exchangers and calculating their respective
    %outlet temperatures.
    
    mCondensateHeatFlow = zeros(iIncrements, fN_Rows);
    mHeatFlow = zeros(iIncrements, fN_Rows);
    %If heat exchange coefficient U is zero there can be no heat transfer
    %between the two fluids
    if fIncrementalU == 0
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
        sCondensateFlowRate = struct();
    else
        %have to split the heat exchanger for multiple pipe rows into
        %several HX with one pipe row. And also the pipes have to be
        %splitted into increments in their length.
        
        %splits the heat capacity flows into increments depending on the
        %configuration
        if fN_Rows >= 1
            fHeat_Capacity_Flow_1_Incremental = fHeat_Capacity_Flow_1/fN_Rows;
            fHeat_Capacity_Flow_2_Incremental = fHeat_Capacity_Flow_2/iIncrements;
            fN_Row_Increments = fN_Rows;
            
        else
            %even if there are no pipe rows as in the plate heat exchanger
            %it is still necessary to have at least one increment (if you
            %can call it that) in the row direction or the for loop would
            %crash because it would for from 1:0
            fN_Row_Increments = iIncrements;
            
            fHeat_Capacity_Flow_1_Incremental = fHeat_Capacity_Flow_1/fN_Row_Increments;
            fHeat_Capacity_Flow_2_Incremental = fHeat_Capacity_Flow_2/iIncrements;
            
        end
        
        % Calculates the total flowrate of water in the CHX hot flow:
        % TO DO: Fix for substances other than water
        if fEntry_Temp1 >= fEntry_Temp2
            fTotalHumidityFlowRate = fMassFlow1 * oFlow_1.arPartialMass(oHX.oMT.tiN2I.H2O);
            mfPartialHumidityFlowRate = ones(1,fN_Row_Increments) * fTotalHumidityFlowRate/fN_Row_Increments;
        else
            fTotalHumidityFlowRate = fMassFlow2 * oFlow_2.arPartialMass(oHX.oMT.tiN2I.H2O);
            mfPartialHumidityFlowRate = ones(iIncrements,1) * fTotalHumidityFlowRate/iIncrements;
        end
        
        % preallocation of variables
        mOutlet_Temp_1 = zeros(iIncrements, fN_Row_Increments);
        mOutlet_Temp_2 = zeros(iIncrements, fN_Row_Increments);
        mCondensateHeatFlow = zeros(iIncrements, fN_Row_Increments);
        mCondensateFlowRate = zeros(iIncrements, fN_Row_Increments);
        
        acCondensateNames = cell(iIncrements, fN_Row_Increments);
        sCondensateFlowRate = struct();
        
        for l = 1:iIncrements
            for k = 1:fN_Row_Increments
                if fN_Rows >= 1
                    %%
                    %uses the function for crossflow heat exchangers for one to multiple
                    %pipe rows to calculate the new outlet temperature of the heat 
                    %exchanger (with regard to condensation from the later sections)
                    if k == 1 && l == 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (1 ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, fEntry_Temp1, fEntry_Temp2, fIncrementalLength);

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-fEntry_Temp1);
                        
                        %it is necessary to calculate the wall temperatures
                        %from both directions and then average them because
                        %the calculation from any one side does not yield
                        %the correct wall temperature
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    elseif k == 1 && l ~= 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (1 ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, mOutlet_Temp_1(l-1,k), fEntry_Temp2, fIncrementalLength);

                         mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-mOutlet_Temp_1(l-1,k));
                         
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    elseif k ~= 1 && l == 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (1 ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, fEntry_Temp1, mOutlet_Temp_2(l,k-1), fIncrementalLength);

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-fEntry_Temp1);
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    else
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (1 ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, mOutlet_Temp_1(l-1,k), mOutlet_Temp_2(l,k-1), fIncrementalLength);

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-mOutlet_Temp_1(l-1,k));
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    end
                else
                    %%
                    %uses the function for crossflow heat exchangers for a plate
                    %heat exchanger and the to calculate the new outlet temperature of the heat 
                    %exchanger (with regard to condensation from the later sections). 
                    if k == 1 && l == 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (fN_Rows ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, fEntry_Temp1, fEntry_Temp2);

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-fEntry_Temp1);
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    elseif k == 1 && l ~= 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (fN_Rows ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, mOutlet_Temp_1(l-1,k), fEntry_Temp2);

                         mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-mOutlet_Temp_1(l-1,k));
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(fEntry_Temp2+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    elseif k ~= 1 && l == 1
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (fN_Rows ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, fEntry_Temp1, mOutlet_Temp_2(l,k-1));

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-fEntry_Temp1);
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(fEntry_Temp1+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    else
                        [mOutlet_Temp_1(l,k), mOutlet_Temp_2(l,k)] = temperature_crossflow...
                        (fN_Rows ,fIncrementalArea, fIncrementalU, fHeat_Capacity_Flow_1_Incremental, ...
                         fHeat_Capacity_Flow_2_Incremental, mOutlet_Temp_1(l-1,k), mOutlet_Temp_2(l,k-1));

                        mHeatFlow(l,k) = fHeat_Capacity_Flow_1_Incremental*(mOutlet_Temp_1(l,k)-mOutlet_Temp_1(l-1,k));
                        
                        fTWall11=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        fTWall21=((-mHeatFlow(l,k))*(fR_alpha_i_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_1(l-1,k)+mOutlet_Temp_1(l,k))/2;
                        
                        fTWall12 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental+fR_lambda_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        fTWall22 = ((mHeatFlow(l,k))*(fR_alpha_o_Incremental))+(mOutlet_Temp_2(l,k-1)+mOutlet_Temp_2(l,k))/2;
                        
                        fTWall1 = (fTWall11+fTWall12)/2;
                        fTWall2 = (fTWall21+fTWall22)/2;
                    end
                end

                %%
                %now the condensation is taken into account and the mass
                %flow for the different condensates is calculated and saved
                %into a struct with the substance that condenses as field
                %name and the mass flow that condenses as field value in
                %kg/s. The temperature is also recalculated here and gets
                %overwritten if it changes from condensation

                if fEntry_Temp1 > fEntry_Temp2
                    %uses the function in the private folder to
                    %calculate the new outlet temp and the condensate
                    %mass flow for this cell
                    % TO DO: Fix for things other than water
                    afCondenseableFlowRate = zeros(1,oHX.oMT.iSubstances);
                    afCondenseableFlowRate(oHX.oMT.tiN2I.H2O) = mfPartialHumidityFlowRate(k) - sum(mCondensateFlowRate(:,k));
                    % For this case mfPartialHumidityFlowRate is along k
                    if l == 1
                        [sCondensateFlowRateCell, mOutlet_Temp_1(l,k), acCondensateNames{l,k}, mCondensateHeatFlow(l,k)] = condensation ...
                            (oHX, afCondenseableFlowRate, fHeat_Capacity_Flow_1_Incremental, abs(mHeatFlow(l,k)), fTWall1, mOutlet_Temp_1(l,k),fEntry_Temp1, oFlow_1, fN_Row_Increments);
                    else
                        [sCondensateFlowRateCell, mOutlet_Temp_1(l,k), acCondensateNames{l,k}, mCondensateHeatFlow(l,k)] = condensation ...
                            (oHX, afCondenseableFlowRate, fHeat_Capacity_Flow_1_Incremental, abs(mHeatFlow(l,k)), fTWall1, mOutlet_Temp_1(l,k),mOutlet_Temp_1(l-1,k), oFlow_1, fN_Row_Increments);
                    end
                else
                    %uses the function in the private folder to
                    %calculate the new outlet temp and the condensate
                    %mass flow for this cell
                    % TO DO: Fix for things other than water
                    afCondenseableFlowRate = zeros(1,oHX.oMT.iSubstances);
                    afCondenseableFlowRate(oHX.oMT.tiN2I.H2O) = mfPartialHumidityFlowRate(k) - sum(mCondensateFlowRate(:,k));
                    if k == 1
                        [sCondensateFlowRateCell, mOutlet_Temp_2(l,k), acCondensateNames{l,k}, mCondensateHeatFlow(l,k)] = condensation ...
                            (oHX, afCondenseableFlowRate, fHeat_Capacity_Flow_2_Incremental, abs(mHeatFlow(l,k)), fTWall2, mOutlet_Temp_2(l,k),fEntry_Temp2, oFlow_2, iIncrements);
                    else
                        [sCondensateFlowRateCell, mOutlet_Temp_2(l,k), acCondensateNames{l,k}, mCondensateHeatFlow(l,k)] = condensation ...
                            (oHX, afCondenseableFlowRate, fHeat_Capacity_Flow_2_Incremental, abs(mHeatFlow(l,k)), fTWall2, mOutlet_Temp_2(l,k),mOutlet_Temp_2(l,k-1), oFlow_2, iIncrements);
                    end
                end
                acCondensateNamesCell = acCondensateNames{l,k};
                for n = 1:length(acCondensateNamesCell)
                    if isfield(sCondensateFlowRate, acCondensateNames{n})
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRate.(acCondensateNamesCell{n})+sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    else
                        sCondensateFlowRate.(acCondensateNamesCell{n}) = sCondensateFlowRateCell.(acCondensateNamesCell{n});
                    end
                end
                % Fix for stuff other than water
                if isfield(sCondensateFlowRateCell, 'H2O')
                    mCondensateFlowRate(l,k) = sCondensateFlowRateCell.H2O;
                end
            end
        end
        %calculates the outlet temperatures by averaging the results
        fOutlet_Temp_1 = sum(mOutlet_Temp_1(end,:))/fN_Row_Increments;
        fOutlet_Temp_2 = sum(mOutlet_Temp_2(:,end))/iIncrements;
    end
    
    %double sum because it is a matrix
    oHX.fTotalCondensateHeatFlow = sum(sum(mCondensateHeatFlow));
    oHX.fTotalHeatFlow = sum(sum(mHeatFlow));
    
    %TO DO: Delete for final implementation, or fix to a state where it
    %makes sense no matter what system is used (esp for last two cases)
    %in case any of these happen something definitly went wrong. Here for
    %debugging purpose.
    if isnan(fOutlet_Temp_1) || isnan(fOutlet_Temp_2)
        keyboard()
    elseif isinf(fOutlet_Temp_1) || isinf(fOutlet_Temp_2)
        keyboard()
    elseif (0>fOutlet_Temp_1) || (0>fOutlet_Temp_2)
        keyboard()
    end
    %writes the values for condensation into the oHX object
    %for further use
    oHX.sCondensateMassFlow = sCondensateFlowRate;
%%
elseif strcmpi(sHX_type, '1 n sat')
    
    %allocates the entries in the mHX vector from the user entry to the
    %respective variables
    
    %length of the passes
    fLength = mHX(1,1);
    fD_Shell = mHX(1,2);
    
    %from this point on entries are column vectors
    mD_i = mHX(:,3);
    mD_o = mHX(:,4);
    mN_Pipes_Pass = mHX(:,5);
  
    %calculates the further needed variables for the heat exchanger from
    %the given values
    
    %number of passes
    fP = size(mHX);
    fP = fP(1,1);
    
    fs_1 = 0;
    
    for k = 1:fP
        fOuter_Pipe_Area = mN_Pipes_Pass(k)*pi*(mD_o(k)/2)^2;
    
        fCircumfence = mN_Pipes_Pass(k)*pi*mD_o(k);
        
        %here a simple assumption is made for the average distance values 
        %between the pipes since they are only used in the pressure loss
        %calculation
        fs_1 = fs_1 + (mD_o(k)/2)+0.005;  
    end
    
    fs_1 = fs_1/fP;
    fs_2 = fs_1;
    
    %calculates the outer hydraulic diameter for the sheath current
    fOuter_Hydraulic_Diameter = 4*((pi*(fD_Shell/2)^2) - ...
                        fOuter_Pipe_Area)/(pi*fD_Shell + fCircumfence);
        
  
    %preallocation of vectors
    mArea_hx_pass = zeros(fP,1);
    mw_fluid1 = zeros(fP,1);
    fArea_pipes = 0;
    
    for k = 1:fP
        %calculates the Area for the heat exchange in each pass
        mArea_hx_pass(k,1) = pi * (mD_i(k,1)/2)^2 * mN_Pipes_Pass(k,1)* fLength;
        %calculates the flowspeed for the fluid within the pipes for each
        %pass
        mw_fluid1(k,1) = fMassFlow1/(mN_Pipes_Pass(k,1)*pi*...
                         (mD_i(k,1)/2)^2 * fDensity_Fluid1(1));
        %calculates the total Area of all pipes which obstructs the flow in
        %the shell
        fArea_pipes =fArea_pipes+(mN_Pipes_Pass(k,1)*(pi*(mD_o(k,1)/2)^2));
    end

    if pi*(fD_Shell/2)^2 - fArea_pipes < 0
        error('area of shell smaller than combined area of pipes')
    end
    %calculates the flow speed for the sheath current
    fFlowSpeed_Fluid2 = fMassFlow2/((pi*(fD_Shell/2)^2 - fArea_pipes) *...
                        fDensity_Fluid2(1));
   
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);

    if (fHeat_Capacity_Flow_1 == 0) || (fHeat_Capacity_Flow_2 == 0)
        fOutlet_Temp_1 = fEntry_Temp1;
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        %preallocation of vectors
        mD_Hydraulic_Pass = zeros(fP,1);
        malpha_o = zeros(fP,1);
        malpha_i = zeros(fP,1);
        fR_lambda = zeros(fP,1);
        fR_alpha_o = zeros(fP,1);
        fR_alpha_i = zeros(fP,1);
        mU = zeros(fP,1);

        for k = 1:fP
            %calculates the convection coefficient outside the pipes for each
            %pass
            mD_Hydraulic_Pass(k) = (pi*(fD_Shell/2)^2 - mN_Pipes_Pass(k,1)*pi*...
                                   (mD_o(k,1)/2)^2/(pi*fD_Shell +...
                                    mN_Pipes_Pass(k,1)*pi*mD_o(k,1)));
            malpha_o(k,1) = functions.calculateHeatTransferCoefficient.convectionPipe(mD_Hydraulic_Pass(k), fLength,...
                            fFlowSpeed_Fluid2, fDyn_Visc_Fluid2,...
                            fDensity_Fluid2, fThermal_Cond_Fluid2,...
                            fC_p_Fluid2, 0);

            %calculates the convection coeffcient inside the pipes for each
            %pass
            malpha_i(k,1) = functions.calculateHeatTransferCoefficient.convectionPipe (mD_i(k,1), fLength,...
                            mw_fluid1(k,1), fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, fThermal_Cond_Fluid1,...
                            fC_p_Fluid1, 0);

            %calculates the thermal resistance from conduction for each pass
            %please note that the data type should be m for a matrix/vector,
            %but because of error in value return when this value is named
            %differently it is called fR_lambda
            fR_lambda(k,1) = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0,...
                                mD_i(k,1), mD_o(k,1), fLength);

            %calculates the thermal resistances from convection for each pass
            %please note that the data type should be m for a matrix/vector,
            %but because of error in value return when this value is named
            %differently it is called fR_alpha_i/o
            fR_alpha_i(k,1) = 1/(mArea_hx_pass(k,1) * malpha_i(k,1));
            fR_alpha_o(k,1) = 1/(mArea_hx_pass(k,1) * malpha_o(k,1));

            %calculates the heat exchange coefficient for each pass
            mU(k,1) = 1/(mArea_hx_pass(k,1) * (fR_alpha_o(k,1) +...
                        fR_alpha_i(k,1) + fR_lambda(k,1)));
        end

        %uses the function for 1,n shell and tube heat exchangers to calculate
        %the outlet temperatures
        [fOutlet_Temp_1, fOutlet_Temp_2] = temperature_1_n_sat...
        (mArea_hx_pass, mU, fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
         fEntry_Temp1, fEntry_Temp2,0);
  
    end
    %calculation of pressure loss for both fluids:
    fDelta_P_1_OverPipe = 0;
    fDelta_P_1_InOut = 0;
    for k = 1:fP
        fDelta_P_1_OverPipe = fDelta_P_1_OverPipe + functions.calculateDeltaPressure.Pipe(mD_i(k) , fLength, mw_fluid1(k), fDyn_Visc_Fluid1, fDensity_Fluid1, 0);
    
        fDelta_P_1_InOut = fDelta_P_1_InOut + functions.calculateDeltaPressure.PipeBundleInletOutlet(mD_i(k), fs_1, fs_2, mw_fluid1(k), fDyn_Visc_Fluid1, fDensity_Fluid1);
    
    end
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    %this heat exchanger does not use any baffles. This means the pressure
    %loss can be calculated with the pressure loss over a pipe using the
    %hydraulic diameter between shell and outer pipe diameters
    
    fDelta_P_2 = functions.calculateDeltaPressure.Pipe(fOuter_Hydraulic_Diameter, fLength,...
                  fFlowSpeed_Fluid2, fDyn_Visc_Fluid2, fDensity_Fluid2, 0);
    
%%
elseif strcmpi(sHX_type, '3 2 sat')

    %allocates the entries of the mHX vector to the respective variables 
    fD_i                = mHX{1};
    fLength             = mHX{2};
    fD_o                = mHX{3};
    fD_Baffle           = mHX{4};
    fD_Batch            = mHX{5};
    fD_Hole             = mHX{6};
    fD_Shell            = mHX{7};
    fD_Int              = mHX{8};
    fLength_Int         = mHX{9};
    fs_1                = mHX{10};
    fs_2                = mHX{11};
    fN_Pipes            = mHX{12};
    fN_Pipes_Win        = mHX{13};
    fN_Flow_Resist      = mHX{14};
    fN_Flow_Resist_end  = mHX{15};
    fN_Sealings         = mHX{16};
    fN_Pipes_Diam       = mHX{17};
    fDist_Baffles       = mHX{18};
    fHeight_Baffle     = mHX{19};
    fConfig             = mHX{20};
    if length(mHX)==21
        fs_3            = mHX{21};
    end
    
    %Area of the window 
    fArea_Win = (fD_Shell/2)^2 *acos(1-(fHeight_Baffle/(fD_Shell/2)))...
                 - sqrt(fHeight_Baffle*fD_Shell-fHeight_Baffle^2)*...
                 (fD_Shell-fHeight_Baffle);
    
    %assumptions for user inputs that were specified as unknown (x)
    if (fD_i == 'x') && (fD_o ~= 'x')
        fD_i = fD_o - 0.001;
    elseif fD_o == 'x' && (fD_i ~= 'x')
        fD_o = fD_i + 0.001;
    elseif (fD_i == 'x') && (fD_o == 'x')
        error('at least one of the inputs fD_i or fD_o is required')
    end
    if fD_Baffle == 'x'
        fD_Baffle = fD_Shell - (0.01*fD_Shell);
    end
    if fD_Batch == 'x'
        fD_Batch = fD_Shell - (0.015*fD_Shell);
    end
    if fD_Hole == 'x'
        fD_Hole = fD_o + 0.0005;
    end
    %assumes a value for the pipes in the window zone from an area 
    %relation and the total number of pipes
    if fN_Pipes_Win == 'x'
        fN_Pipes_Win = fN_Pipes * (fArea_Win/(pi*(fD_Shell/2)^2));
    end
    %assumes a value for the flow resists in the end zone from an area 
    %relation and the flow resists in the transverse zone and rounding it
    %to the higher next integer
    if fN_Flow_Resist_end == 'x'
        fN_Flow_Resist_end = ceil(fN_Flow_Resist/((pi*(fD_Shell/2)^2)...
                              -fArea_Win)*(pi*(fD_Shell/2)^2));
    end
    %assumes a value for the number of pipes at the diameter by discerning
    %how many pipes have room within the diameter with a half centimeter
    %spacing between the outer pipes and the diameter and rounds that
    %number to the lower next integer
    if fN_Pipes_Diam == 'x'
        fN_Pipes_Diam = floor((fD_Shell+0.01+fs_1)/(fD_o+fs_1));
    end
    
    %calculates the further needed variables for the heat exchanger from
    %the given values
    if ((pi*(fD_Shell/2)^2) - (fN_Pipes*(pi*(fD_o/2)^2))) < 0
        error('the shell diameter is smaller than the combined area of he pipes')       
    end
    %flow speed for the fluid within the pipes calculated from the massflow
    %with massflow = volumeflow*rho = fw*fA*frho
    %the number of pipes is halfed because of 2 inner passes
    fFlowSpeed_Fluid1 = fMassFlow1/((fN_Pipes/2)*pi*(fD_i/2)^2 *...
                        fDensity_Fluid1(1));
    fFlowSpeed_Fluid2 = fMassFlow2/(((pi*(fD_Shell/2)^2) - (fN_Pipes*...
                        (pi*(fD_o/2)^2))) * fDensity_Fluid2(1));
    %heat capacity flow according to [1] page 173 equation (8.1)
    fHeat_Capacity_Flow_1 = abs(fMassFlow1) * fC_p_Fluid1(1);
    fHeat_Capacity_Flow_2 = abs(fMassFlow2) * fC_p_Fluid2(1);
    %calculates the area for the heat exchange
    fArea = (fN_Pipes*(pi*(fD_i/2)^2));
    
    %Distance between baffles and end of heat exchanger
    fS_e = fLength-fDist_Baffles;
    
    %simplification for the number of rows, calculated from the number of
    %pipes in the transverse zone
    %number of rows in the transverse zone between baffles
    fN_Pipes_Trans = (fN_Pipes-(2*fN_Pipes_Win));
    fN_Rows_Trans = fN_Pipes_Trans/(fN_Pipes_Diam/1.5);
    %number of baffles
    fN_Baffles = 2;
    
    %calculates the convection coeffcient on the outer side of the pipes
    %using the function for the sheath current of a shell and tube heat
    %exchanger (for further info view the help of the function) 
    %partially shiffted configuration with one additional input for the
    %shiffting length fs_3
    if length(mHX)==21
        falpha_sheath = functions.calculateHeatTransferCoefficient.functions.calculateHeatTransferCoefficient.convectionSheathCurrent (fD_o, fD_Baffle,...
                            fD_Batch, fD_Hole, fD_Shell, fs_1, fs_2,...
                            fN_Pipes, fN_Pipes_Win, fN_Flow_Resist,...
                            fN_Sealings , fN_Pipes_Diam, fDist_Baffles,...
                            fHeight_Baffle, fFlowSpeed_Fluid2,...
                            fDyn_Visc_Fluid2, fDensity_Fluid2,...
                            fThermal_Cond_Fluid2, fC_p_Fluid2, fConfig,...
                            fs_3);
    %shiffted or aligend configuration
    elseif length(mHX)==20
        falpha_sheath = functions.calculateHeatTransferCoefficient.functions.calculateHeatTransferCoefficient.convectionSheathCurrent (fD_o, fD_Baffle,...
            fD_Batch, fD_Hole, fD_Shell, fs_1, fs_2, fN_Pipes,...
            fN_Pipes_Win, fN_Flow_Resist, fN_Sealings , fN_Pipes_Diam,...
            fDist_Baffles, fHeight_Baffle, fFlowSpeed_Fluid2,...
            fDyn_Visc_Fluid2, fDensity_Fluid2, fThermal_Cond_Fluid2,...
            fC_p_Fluid2, fConfig);
    else
        error('wrong input for fConfig')
    end
    %calculates the thermal resistance resulting from convection in the
    %sheath current
    fR_alpha_o = 1/(fArea * falpha_sheath);
    
    %calculates the convection coeffcient on the inner side of the pipes
    %using the function for a simple pipe (for further info view the help 
    %of the function)
    falpha_pipe = functions.calculateHeatTransferCoefficient.convectionPipe (fD_i, fLength, fFlowSpeed_Fluid1,...
                    fDyn_Visc_Fluid1, fDensity_Fluid1,...
                    fThermal_Cond_Fluid1, fC_p_Fluid1, 0);

    %calculates the thermal resistance resulting from convection in the
    %pipes
    fR_alpha_i = 1/(fArea * falpha_pipe);
    
    %calculates the thermal resitivity for further info view the help 
    %of the function
    fR_lambda = functions.calculateHeatTransferCoefficient.conductionResistance(fThermal_Cond_Solid, 0, (fD_i/2),...
                    (fD_o/2), fLength);

    %calculates the heat exchange coeffcient fU
    fU = 1/(fArea * (fR_alpha_o + fR_alpha_i + fR_lambda));
    
    %uses the function for the 3,2 shell and tube heat exchanger to
    %calculate the outlet temperatures (view help of the function for
    %further information)
    if fU == 0
        fOutlet_Temp_1 = fEntry_Temp1; 
        fOutlet_Temp_2 = fEntry_Temp2;
    else
        [fOutlet_Temp_1, fOutlet_Temp_2] =temperature_3_2_sat(fArea, fU,...
                        fHeat_Capacity_Flow_1, fHeat_Capacity_Flow_2,...
                        fEntry_Temp1, fEntry_Temp2);
    end

    fDelta_P_1_OverPipe = functions.calculateDeltaPressure.Pipe(fD_i , fLength,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1, 0);
    fDelta_P_1_InOut = functions.calculateDeltaPressure.PipeBundleInletOutlet(fD_i, fs_1, fs_2,...
                            fFlowSpeed_Fluid1, fDyn_Visc_Fluid1,...
                            fDensity_Fluid1);
    
    fDelta_P_1 = fDelta_P_1_OverPipe + fDelta_P_1_InOut;
    
    if fConfig == 2
        fconfig_press_loss = 1;
    else
        fconfig_press_loss = fConfig;
    end
    
    fDelta_P_2 = functions.calculateDeltaPressure.SheathCurrent(fD_o, fD_Shell, fD_Baffle,...
    fD_Batch, fD_Hole, fD_Int, fDist_Baffles, fS_e, fHeight_Baffle,...
    fLength_Int, fs_1, fs_2, fN_Pipes, fN_Rows_Trans, fN_Pipes_Diam,...
    fN_Pipes_Win, fN_Sealings, fN_Baffles, fN_Flow_Resist,...
    fN_Flow_Resist_end, fDyn_Visc_Fluid2, fDensity_Fluid2, fMassFlow2,...
    fconfig_press_loss);
else
    error('unkown input for the heat exchanger type')
end

end