classdef (Abstract) stationary < matter.manips.volume
    % a stationary volume manipulator changes the volume by fixed values
    % not flows. Different from the substance manipulator the seperation
    % into stationary and flow manips for volumes has nothing to do with
    % flow phases but is purely used to describe manipulators which
    % describe volume change rates (flow) or change the volume by fixed
    % values (stationary)
    
    % to easier discern between volume manipulators that provide change
    % rates and volume manipulators that directly change the volume a
    % boolean flag is introduced to identify these two options. Since the
    % type is defined by inherting from this parent class, the property is
    % constant and cannot be changed.
    properties (Constant)
        % Identifies this manipualtor as a stationary volume manipulator
        bStationaryVolumeProcessor = true;
    end
    
    methods
        function this = stationary(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manips.volume(sName, oPhase, sRequiredType);
        end
    end
end