classdef Human_O2_to_CO2_Converter < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of O2 into CO2 inside the
    %human body. It does not use any other inputs except for O2 so the mass
    %balance is not closed.
                                    
    
    properties (SetAccess = protected, GetAccess = public)
       fLastUpdate;
    end
    
    methods
        function this = Human_O2_to_CO2_Converter(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0
                return
            end
            
            afPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            %simply converts all the O2 in the human into CO2, since only
            %O2 that is consumed by the human goes into the phase it is not
            %necessary to regard the ~17% O2 that are left in the air when
            %a human breathes out
            fO2MassFlow = this.oPhase.toProcsEXME.O2In.oFlow.fFlowRate;
            
            afPartialFlowRates(tiN2I.CO2)   =  fO2MassFlow;%fO2Mass/fTimeStep;
            afPartialFlowRates(tiN2I.O2)   = -fO2MassFlow;%-fO2Mass/fTimeStep;
            
            update@matter.manips.substance.flow(this, afPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end