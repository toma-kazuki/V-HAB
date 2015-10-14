classdef Example1 < vsys
    %EXAMPLE1 Example simulation demonstrating P2P processors in V-HAB 2.0
    %   Creates one tank, one with ~two bars of pressure, one completely
    %   empty tank. A filter is created. The tanks are connected to the 
    %   filter with pipes of 50cm length and 5mm diameter.
    %   The filter only filters O2 (oxygen) up to a certain capacity. 
    
    properties
    end
    
    methods
        function this = Example1(oParent, sName)
            this@vsys(oParent, sName, 10);
           
            % Creating a store, volume 10m^3
            matter.store(this, 'Atmos', 10);
            
            % Creating a phase using the 'air' helper
            oAir = this.toStores.Atmos.createPhase('air', 10);
            
            % Adding a extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Out');
            matter.procs.exmes.gas(oAir, 'In');
            
            % Creating the filter, last parameter is the filter capacity in
            % kg.
            tutorials.p2p.components.Filter(this, 'Filter', 0.5);
            
            % Adding a fan
            components.fan(this, 'Fan', 'setSpeed', 40000, 'Left2Right');
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.pipe(this, 'Pipe_3', 0.5, 0.005);
            
            % Creating the flowpath (=branch) between the components
            % Since we are using default exme-processors here, the input
            % format can be 'store.phase' instead of 'store.exme'
            %oBranch_1 = this.createBranch('Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            %oBranch_2 = this.createBranch('Filter.Out', {'Pipe_3' }, 'Atmos.In');
            oBranch_1 = matter.branch(this, 'Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            oBranch_2 = matter.branch(this, 'Filter.Out', {'Pipe_3' }, 'Atmos.In');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            
            
            fTime = this.oTimer.fTime;
            oFan  = this.toProcsF2F.Fan;
            
            %if fTime >= 100, keyboard(); end;
            
            if fTime >= 500 && fTime < 1000 && oFan.fSpeedSetpoint ~= 0
                fprintf('Fan OFF at second %f and tick %i\n', fTime, this.oTimer.iTick);
                oFan.fSpeedSetpoint = 0;
                
            elseif fTime >= 1000 && oFan.fSpeedSetpoint ~= 40000
                fprintf('Fan ON at second %f and tick %i\n', fTime, this.oTimer.iTick);
                
                oFan.fSpeedSetpoint = 40000;
            end
        end
        
     end
    
end

