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
            matter.store(this, 'Cabin', 1);
        	matter.phases.gas(this.toStores.Cabin, 'CabinAir', struct('N2', 1), 1, 293.15);   
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