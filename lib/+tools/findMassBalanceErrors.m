function [ ] = findMassBalanceErrors( oInput, fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints )
% This function identifies locations in the simulation where mass balance
% errors occur (if possible) and at least provides the Tick and the
% substance for which a mass balance Issue was identified. Mass balance
% issues arise if the positive and negative flowrates for a substance do
% not sum up to zero over the complete simulation. Matter changes from
% manipulators are respected in this check as the only location where one
% substance can change into another substance. 
%
% Mass balance differs from the mass lost value as mass lost occurs
% whenever a substance within a phase reaches a value of less than 0. Mass
% balance on the other hand occurs if the flowrates do not sum up to zero
% over the whole vsys.
%
% The only required input is the oMT object. Or, if you only want to check
% the balance for one phase, a phase object.
% 
% Optional inputs:
% fAccuracy:    This values defines the size of the mass balance error
%               befor information about it is provided by this tool. For
%               Example if the value is 1e-6 the mass balance error has to
%               be larger than 1e-6 kg/s for information about it to be
%               displayed.
%
% fMaxMassBalanceDifference:    can be set if you want your simulation to
%                               stop in case you exceed a certain total
%                               error in the mass balance. E.g. if the
%                               value is 1 [kg] then the simulation will
%                               pause once the total mass balance error is
%                               larger than 1 kg
%
% bSetBreakPoints:  This function is a bit experimental, but if you set the
%                   value to true the function will try to automaticall set
%                   breakpoints at the locations within V-HAB where the
%                   mass balance error orginiates.
    
    if nargin < 2
        fAccuracy = 0;
    end
    if nargin < 3
        fMaxMassBalanceDifference =  inf;
    end
    if nargin < 4
        bSetBreakPoints =  false;
    end
    
    if isa(oInput, 'matter.table')
        aoPhases = oInput.aoPhases;
        aoFlows  = oInput.aoFlows;
        oMT = oInput;
    elseif isa(oInput, 'matter.phase')
        aoPhases = oInput;
        oMT = oInput.oMT;
        
        for iExme = 1:aoPhases.iProcsEXME
            aoFlows(iExme) = aoPhases.coProcsEXME{iExme}.oFlow;
        end
    else
        error('provide matter table or phase as input')
    end
    
    
    %% Check branches and P2Ps
    for iFlow = 1:length(aoFlows)
        
        if isempty(aoFlows(iFlow).oBranch)
            oExmeIn = aoFlows(iFlow).oIn;
            oExmeOut = aoFlows(iFlow).oOut;
        else
            oExmeIn = aoFlows(iFlow).oBranch.coExmes{1};
            oExmeOut = aoFlows(iFlow).oBranch.coExmes{2};
        end
        
        % branches and p2ps are NOT allowed to change mass into a different
        % substance! Therefore the check is done for each substance
        % individually. There will be a different check for the manips in
        % the system
        mfMassBalanceErrorsFlows =   ( oExmeIn.iSign  .* oExmeIn.oFlow.fFlowRate  .* oExmeIn.oFlow.arPartialMass) +...
                                ( oExmeOut.iSign .* oExmeOut.oFlow.fFlowRate .* oExmeOut.oFlow.arPartialMass);
        
        if any(abs(mfMassBalanceErrorsFlows) > fAccuracy)
            
            if isempty(aoFlows(iFlow).oBranch)
                disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the P2P ', aoFlows(iFlow).sName]);
                
                if bSetBreakPoints
                    oMT.setMassErrorNames(aoFlows(iFlow).sName)
                end
            else
                disp(['Between the phases ', oExmeIn.oPhase.sName, ' and ', oExmeOut.oPhase.sName, ' in the branch ', aoFlows(iFlow).oBranch.sCustomName]);
                if bSetBreakPoints
                    oMT.setMassErrorNames(aoFlows(iFlow).oBranch.sCustomName)
                end
            end
            
            csSubstances = oMT.csSubstances(abs(mfMassBalanceErrorsFlows) > fAccuracy);
            for iSubstance = 1:length(csSubstances)
                disp(['a mass balance error of ', num2str(mfMassBalanceErrorsFlows(oMT.tiN2I.(csSubstances{iSubstance}))),' kg/s occured for the substance ', csSubstances{iSubstance}]);
            end
            
            % Note in case changes were made to the phase file, search for the
            % expression "this.mfTotalFlowsByExme" and set the integer below to
            % the line number!
            % For the branch look for the expression:
            % "this.hSetFlowData"
            if bSetBreakPoints
                oMT.setMassErrorNames(oExmeIn.oPhase.sName);
                oMT.setMassErrorNames(oExmeOut.oPhase.sName);
                dbstop in matter.phase at 1278 if ~isempty(strmatch(this.sName, this.oMT.tMassErrorHelper.csMassErrorNames));
                dbstop in matter.branch at 661 if ~isempty(strmatch(this.sCustomName, this.oMT.tMassErrorHelper.csMassErrorNames));
            end
        end
    end
    
    %% Check manipulators (only checked for total mass change since manips are allowed to transform substances)
    for iPhase = 1:length(aoPhases)
        if ~isempty(aoPhases(iPhase).toManips.substance)
            oManip = aoPhases(iPhase).toManips.substance;
            if ~isempty(oManip.afPartialFlows)
                fMassBalanceError = sum(oManip.afPartialFlows);
                if abs(fMassBalanceError) > fAccuracy
                    disp(['In the phases ', aoPhases(iPhase).sName, ' the manipulator ', oManip.sName, ' generated a mass error of ', num2str(fMassBalanceError) ,' kg/s']);
                end
            end
        end
    end
    
    %% Check the current  partial mass changes in the phases:
    afCurrentMassBalance = zeros(1, oMT.iSubstances);
    if length(aoPhases) > 1
        for iPhase = 1:length(aoPhases)
            % Manips are not included in the afCurrentTotalInOuts value,
            % the mass balance for those is calculated individually
            afCurrentMassBalance = afCurrentMassBalance + aoPhases(iPhase).afCurrentTotalInOuts;
        end
    end
    
    if any(abs(afCurrentMassBalance) > fAccuracy)
        miSubstances = abs(afCurrentMassBalance) > fAccuracy;
        sSubstancesStringWithSpaces = strjoin({oMT.csI2N{miSubstances}}, ', ');
        disp(['An overall mass balance issue was detected in tick ', num2str(aoPhases(1).oTimer.iTick), ' for the substances: ', sSubstancesStringWithSpaces]);
    end
    
    %% checks the mass balance in V-HAB and stops the simulation if it exceeds a value defined by the user
    if fMaxMassBalanceDifference ~= inf
        oInfrastructure = oMT.aoPhases(1).oStore.oContainer.oRoot.oInfrastructure;
        
        iLength = size(oInfrastructure.toMonitors.oMatterObserver.mfTotalMass);
        iLength = iLength(1);
        if iLength > 1
            afInitialTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(1,:);
            afCurrentTotalMass = oInfrastructure.toMonitors.oMatterObserver.mfTotalMass(end,:);
            % afCurrentTotalMass = sum(reshape([ oMT.aoPhases.afMass ], oMT.iSubstances, []), 2)';
            
            fError = abs(sum(afInitialTotalMass) - sum(afCurrentTotalMass));
            if fError > fMaxMassBalanceDifference
                keyboard()
            end
        end
    end
end

