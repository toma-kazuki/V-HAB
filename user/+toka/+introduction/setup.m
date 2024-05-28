classdef setup < simulation.infrastructure
    properties

    end

    methods
        function this = setup(ptConfigParams, tSolverParams) 
            ttMonitorConfig = struct('oLogger', struct('cParams', {{ true, 10000 }}));%実行中のシミュレーションを特定の間隔で保存する %10000という値は、何ティック後にシミュレーションデータがハードドライブにダンプされるか
            this@simulation.infrastructure('Introduction_System', ptConfigParams, tSolverParams, ttMonitorConfig);


            toka.introduction.systems.Example(this.oSimulationContainer,'Example');


            %% Simulation length
            this.fSimTime = 3600; % In seconds
            this.bUseTime = true;
        end

        function configureMonitors(this) %シミュレーションの出力として、非常に基本的なロギングとプロットが利用できるようになる
            %% Logging
            oLogger = this.toMonitors.oLogger;
            oLogger.addValue('Example.toStores.Cabin.toPhases.CabinAir', 'fPressure', 'Pa', 'Total Cabin Pressure');
        end

        function plot(this) %シミュレーションが終了した後や停止した後に使用し、結果を図にします
            % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all % closes all currently open figures
                
            % Tries to load stored data from the hard drive if that option
            % was activated (see ttMonitorConfig). Otherwise it only 
            % displays that no data was found 
            try
                this.toMonitors.oLogger.readDataFromMat;
            catch
                disp('no data outputted yet')
            end
        
        
            %% Define plots
            % Defines the plotter object
            oPlotter = plot@simulation.infrastructure(this);
        
        
            % Define a single plot
            oPlot{1} = oPlotter.definePlot({'"Total Cabin Pressure"'},'Total Cabin Pressure');
            
            % Define a single figure
            oPlotter.defineFigure(oPlot,  'Total Cabin Pressure');
            
            oPlotter.plot();
        end
    end
end