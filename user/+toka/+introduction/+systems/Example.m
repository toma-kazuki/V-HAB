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
            matter.store(this, 'Cabin', 55); % キャビンのストアが追加される
            matter.store(this, 'HX_Coolant', 0.02); % キャビンのストアが追加される
            matter.store(this, 'O2_Generation', 0.52); % キャビンのストアが追加される
            matter.store(this, 'CO2_Removal', 1.01); % キャビンのストアが追加される
            matter.store(this, 'Water_Supply', 1.1); % キャビンのストアが追加される
            matter.store(this, 'Condensate_Storage', 1); % キャビンのストアが追加される
            matter.store(this, 'Waste_Storage', 10); % キャビンのストアが追加される
            matter.store(this, 'Vacuum', 1e6); % キャビンのストアが追加される

            matter.phases.solid(this.toStores.Waste_Storage, 'Solid_Waste', struct('C42H69O13N5',0.1), 293); %宇宙飛行士が出す廃棄物の一部(固形廃棄物コンパートメント内の化学物質は、人間の糞便の組成の近似値としてよく使用されるもの)

            components.matter.FoodStore(this, 'Food',  100, struct('Food', 100)); %ISSで使用される宇宙飛行士の標準的な食事

        	matter.phases.gas(this.toStores.Cabin, 'CabinAir', struct('N2', 1), 1, 293.15); % キャビンのストアに1キログラム の窒素の気体フェーズが追加される
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