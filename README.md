# VHABチュートリアル作成

## メモ
* vhab.simおよびvhab.execがあやしい
* function oSim = sim(sSimulation, varargin)
  * sSimulationからシミュレーションオブジェクトを生成する
  * simConstructor = str2func(sSimulation)：パスを記述する文字列からシミュレーション構築関数を生成
  * oSim = simConstructor(varargin{:})：シミュレーション構築関数からシミュレーションオブジェクトを作成
  * oSim.initialize()：結構大事な何か
* function oSimRtn = exec(sSimulation, ptConfigParams, tSolverParams, varargin)
* 気になるパラメーター
  * sSimulation：ストリングの型を持つ、シミュレーションクラスファイルにアクセスするためのパスを記述する(例：'tutorials.simple_flow.setup')
  * ptConfigParams
  * tSolverParams
  * varagin
* 気になる関数
  * [1] oSim：vhab.simによって作られるシミュレーションオブジェクト
  * [1] oSim.run
  * [1] str2func(sSimulation)：パスを記述する文字列からシミュレーション構築関数を生成→MATLABの標準関数だった
    * https://jp.mathworks.com/help/matlab/ref/str2func.html
    *  文字から関数ハンドルを作る
  * [1] simConstructor：シミュレーション構築関数：sSimulationで表現されたシミュレーション関数のハンドル



Welcome to the Virtual Habitat (V-HAB)
------------------------
V-HAB is a MATLAB-based simulation system specifically designed for the analysis of life support systems in crewed spacecraft. 


V-HAB Base Repository
------------------------

Basic repository with the framework for V-HAB / STEPS. Contains four directories:

* core: central, shared V-HAB framework.
* lib: helper functions, pre/post processing, logging, GUI, date functions, ... (TBD)
* user: user-specific simulations
* data: user-generated simulation results (e.g. logs, plots, spreadsheets)

The core and lib packages are managed, i.e. most likely no changes should be done or can be committed to the online repository.

How to get started with programming for V-HAB
------------------------------------
After you have the code and your user project you can go to the [introduction chapter](https://wiki.tum.de/display/vhab/1.+Introduction+to+V-HAB) for V-HAB and read it. You should also have a look at the [coding guidelines](https://wiki.tum.de/display/vhab/2.+Coding+Guidelines+in+V-HAB) to avoid having your advisor tell you to do stuff differently after you have programmed everything!


About Matlab OOP
----------------

More about Matlab packages / class organization:

* <http://www.mathworks.de/de/help/matlab/matlab_oop/scoping-classes-with-packages.html>
* <http://www.mathworks.de/de/help/matlab/matlab_oop/saving-class-files.html>

More about Matlab classes:

* <http://www.mathworks.de/de/help/matlab/ref/classdef.html>
* <http://www.mathworks.de/de/help/matlab/object-oriented-programming-in-matlab.html>
