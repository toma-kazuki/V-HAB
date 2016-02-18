classdef SWMEStore < matter.store
    % SWME is a matter store with a liquid water and a water vapor phase,
    % connected with each other through the X50Membrane P2P processor
    %
    % The SWME contains:
    % -one inlet (warm water flowing from the Thermal Control Loop of the
    %  AEMU
    % -two outlets ( vapor escaping through the Backpressure Valve (BPV) to
    %  space and cold water flowing back to the Thermal Control Loop
    % -two exmes connecting both phases through the p2p processor (the X50
    %  membrane in this case, components.SWME.procs.X50Membrane)
    
    % SWME(oMT, sName, fSWMEVolume, fSWMEVaporVolume, fInitialTemperature)
    
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        oProc;                          % P2P processor
        
    end
    
    methods
        
        function this = SWMEStore(oContainer, sName, fSWMEVolume, fSWMEVaporVolume, fInitialTemperature)
            
            this@matter.store(oContainer, sName, fSWMEVolume);
            
            % Defining volume available for the liquid phase inside the
            % hollow fibers
            fSWMELiquidVolume = fSWMEVolume - fSWMEVaporVolume;
            
            % Creating liquid water phase inside the hollow fibers of the
            % X50 membrane
            oLiquidHoFiPhase = matter.phases.liquid(...
                               this,...                           % Store where the phase is located
                              'HoFiWater', ...                    % Phase name
                               struct('H2O', 0.0881439), ...      % Phase contents
                               fSWMELiquidVolume, ...             % Phase volume
                               fInitialTemperature,...            % Phase temperature
                               28300);                            % Phase pressure
            
            % Creating the vapor phase filling the SWME around the hollow
            % fibers
            oVaporSWME = matter.phases.gas(...
                         this, ...                          % Store in which the phase is located
                        'VaporSWME', ...                    % Phase name
                         struct('H2O', 9.160756e-6), ...    % Phase contents
                         fSWMEVaporVolume, ...              % Phase volume
                         fInitialTemperature);              % Phase temperature
            
            % Creating exmes for the vapor phase
            matter.procs.exmes.gas(oVaporSWME, 'VaporIn');                % vapor exiting the  X50 membrane
            matter.procs.exmes.gas(oVaporSWME, 'VaporOut');               % vapor exiting the housing to the backpressure valve
            
            % Creating exmes for the liquid water phase
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterIn');       % water entering the SWME from the inlet feed tank
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterOut');      % water exiting the SWME to the outlet feed tank
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterToVapor');  % water evaporating through the membrane wall
            
            
            % Creating P2P processor which describes the vapor flux from
            % the inside of the hollow fibers, through the hydrophobic
            % membrane wall, to the inside of the SWME housing
            this.oProc = components.SWME.procs.X50Membrane(this, 'X50Membrane', 'HoFiWater.WaterToVapor', 'VaporSWME.VaporIn');
            
        end
        
        function setTemperatureProcessor(this, oProcessor)
            this.toProcsP2P.X50Membrane.setTemperatureProcessor(oProcessor);
        end
    end
    
end

