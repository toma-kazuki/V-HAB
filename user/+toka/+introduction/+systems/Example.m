classdef Example < vsys
    properties (SetAccess = protected, GetAccess = public)
       
    end
   
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30); %exec()関数に使用する時間ステップを定義。この例では30秒が使用されており、これはexec()関数が30秒ごとに呼び出される
            eval(this.oRoot.oCfgParams.configCode(this));
        end
       
        function createMatterStructure(this) %物理システムをコードに変換
            createMatterStructure@vsys(this);

            % ストアの定義
            matter.store(this, 'Cabin', 55); % キャビンのストアが追加される
            matter.store(this, 'HX_Coolant', 0.02); % キャビンのストアが追加される
            matter.store(this, 'O2_Generation', 0.52); % キャビンのストアが追加される
            matter.store(this, 'CO2_Removal', 1.01); % キャビンのストアが追加される
            matter.store(this, 'Water_Supply', 1.1); % キャビンのストアが追加される
            matter.store(this, 'Condensate_Storage', 1); % キャビンのストアが追加される
            matter.store(this, 'Waste_Storage', 10); % キャビンのストアが追加される
            matter.store(this, 'Vacuum', 1e6); % キャビンのストアが追加される

            % フェーズの定義
            %%  固体の定義
            matter.phases.solid(this.toStores.Waste_Storage, 'Solid_Waste', struct('C42H69O13N5',0.1), 293); %宇宙飛行士が出す廃棄物の一部(固形廃棄物コンパートメント内の化学物質は、人間の糞便の組成の近似値としてよく使用されるもの)

            %%  食糧の定義
            components.matter.FoodStore(this, 'Food',  100, struct('Food', 100)); %ISSで使用される宇宙飛行士の標準的な食事

            %%  液体の定義
            matter.phases.liquid(this.toStores.Condensate_Storage, 'Condensate', struct('H2O',1), 293, 1e5);
            matter.phases.liquid(this.toStores.HX_Coolant, 'Coolant', struct('H2O',10), 293, 1e5);
            matter.phases.liquid(this.toStores.O2_Generation, 'Water', struct('H2O',10), 293, 1e5);
            matter.phases.liquid(this.toStores.Water_Supply, 'Water', struct('H2O',1000), 293, 1e5);
            matter.phases.liquid(this.toStores.Waste_Storage, 'Liquid_Waste', struct('H2O',0.1), 293, 1e5);
            
            %%  気体の定義
            matter.phases.gas(this.toStores.O2_Generation, 'Hydrogen', struct('H2',0.3), 0.25, 293);
            matter.phases.gas(this.toStores.O2_Generation, 'Oxygen', struct('H2',0.1), 0.25, 293);

            %%%  気体(分圧で定義する場合)の定義
        	%                               sHelper,   sPhaseName, fVolume,          tfPartialPressure,               fTemperature, rRelativeHumidity)
            this.toStores.Cabin.createPhase(  'gas',   'CabinAir',   54.99, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);

            %%%  フローフェーズの定義(CO2フィルター用のフロー相を定義する場合)
            %                              		  sHelper,  sType,  sPhaseName, fVolume,          tfPartialPressure,               fTemperature, rRelativeHumidity)
            this.toStores.CO2_Removal.createPhase(  'gas', 'flow',   'Air',   0.01, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            %matter.phases.flow.gas(this.toStores.CO2_Removal, 'Air', struct('N2', 8e4, 'O2', 2e4, 'CO2', 500, 'H20', 3889), 0.01,  293);
            %%% 境界フェーズの定義(無限大となるべき相もあります。今の例で言えば、宇宙船の周りの真空だ)
            %                              	 sHelper,  sType,  sPhaseName, fVolume,     tfPartialPressure,        fTemperature, rRelativeHumidity)
            this.toStores.Vacuum.createPhase(  'gas', 'boundary',   'Vacuum',   1e6, 	struct('N2', 2),          3,          0);
            %matter.phases.boundary.gas(this.toStores.Vacuum, 'Vacuum', struct('N2', 2), 1e6, 3);

            %% 混合物の定義
            matter.phases.mixture(this.toStores.CO2_Removal, 'LiOH', 'solid', struct('Li',50), 293, 1e5);


        end
       
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
           
        end
    end
   
     methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
           
        end
     end
end