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
            oLogger.addValue('Example.toStores.Cabin.toPhases.CabinAir', 'fPressure', 'Pa', 'Total Cabin Pressure'); %キャビン内の全圧
            oLogger.addValue('Example.toStores.Cabin.toPhases.CabinAir', 'this.afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 Cabin'); %キャビン内のCO2分圧
            oLogger.addValue('Example.toStores.Cabin.toPhases.CabinAir', 'fTemperature', 'K', 'Cabin Temperature'); %キャビン内の温度
            oLogger.addValue('Example.toStores.Cabin.toPhases.CabinAir', 'rRelHumidity', '%', 'Relative Humidity Cabin'); %キャビン内の相対湿度
            oLogger.addValue('Example.toStores.CO2_Removal.toPhases.LiOH', 'this.afMass(this.oMT.tiN2I.CO2)', 'Pa', 'CO2 LiOH Pressure'); %LiOH内のCO2質量
            oLogger.addValue('Example.toStores.Condensate_Storage.toPhases.Condensate', 'this.afMass(this.oMT.tiN2I.H2O)', 'kg', 'Mass of Condensate Water Storage'); %凝縮水貯蔵庫内の凝縮水質量
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
        
            %{
            %% Define plots
            % Defines the plotter object
            oPlotter = plot@simulation.infrastructure(this);
        
            % Define a single plot
            oPlot{1} = oPlotter.definePlot({'"Total Cabin Pressure"'},'Total Cabin Pressure');
            
            % Define a single figure
            oPlotter.defineFigure(oPlot,  'Total Cabin Pressure');
            %}

            %% Define plots
            % Defines the plotter object
            oPlotter = plot@simulation.infrastructure(this);

            % Define the first row of plots
            coPlot{1,1} = oPlotter.definePlot({'"Total Cabin Pressure"'}, 		'Total Cabin Pressure');
            coPlot{1,2} = oPlotter.definePlot({'"Cabin Temperature"'}, 			'Cabin Temperature');

            % define the second row of plots
            coPlot{2,1} = oPlotter.definePlot({'"Partial Pressure CO2 Cabin"'}, 'Partial Pressure CO2 Cabin');
            coPlot{2,2} = oPlotter.definePlot({'"Relative Humidity Cabin"'}, 	'Relative Humidity Cabin');

            % Define the figure
            oPlotter.defineFigure(coPlot, 'Cabin Atmosphere Values');   

            oPlotter.plot();
        end
    end
end