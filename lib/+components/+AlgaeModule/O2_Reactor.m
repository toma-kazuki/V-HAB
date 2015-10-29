classdef O2_Reactor < matter.manips.partial
    %SOMEABSORBEREXAMPLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        fHarvest;
    end
    
    
    methods
        function this = O2_Reactor(sName, oPhase, fHarvest)
            this@matter.manips.partial(sName, oPhase);
            this.fHarvest=fHarvest;
        end
        
        function update(this)
            % splits up the components taken from the flowphase inside of
            % the algae phase so the algae grow and produce O2
            
            
            %
            afFRs2      = this.getTotalFlowRates();
            afFRs      = this.getTotalMasses();
            
            arPartials = zeros(1, this.oPhase.oMT.iSubstances);
            afMolMass  = this.oPhase.oMT.afMolMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            fSpirulina = afMolMass(tiN2I.Spirulina)*(afFRs(tiN2I.CO2)/afMolMass(tiN2I.CO2)/3.00030003);
            fO2 = 3.4719472*afMolMass(tiN2I.O2)*(afFRs(tiN2I.CO2)/afMolMass(tiN2I.CO2)/3.00030003);
            fCO2 = afFRs(tiN2I.CO2);
            fNO3 = afFRs(tiN2I.NO3);
            %             fC   = fCO2 *afMolMass(tiN2I.C)  / afMolMass(tiN2I.CO2);
            %             fO21  = fCO2 *afMolMass(tiN2I.O2) / afMolMass(tiN2I.CO2);
            
            %             fN   = fNO3 * afMolMass(tiN2I.N)  / afMolMass(tiN2I.NO3);
            %             fO3  = fNO3 * afMolMass(tiN2I.O3) / afMolMass(tiN2I.NO3);
            %             fO2  = fO3  * afMolMass(tiN2I.O2) / afMolMass(tiN2I.O3);
            %             fO   = fO3  * afMolMass(tiN2I.O)  / afMolMass(tiN2I.O3);
            %
            arPartials(tiN2I.CO2) = -1 * fCO2;
            arPartials(tiN2I.Spirulina)   = fSpirulina;
            arPartials(tiN2I.O2)  = fO2;
            arPartials(tiN2I.NO3) = -1 * fNO3;
%             arPartials(tiN2I.N)   = fN;
%             arPartials(tiN2I.O3)  = -1 *fO3;
%             %arPartials(tiN2I.O2)   = fO2;
%             arPartials(tiN2I.O)  = fO;
            
            
            
            
            update@matter.manips.partial(this, arPartials, true);
        end
    end
    
end