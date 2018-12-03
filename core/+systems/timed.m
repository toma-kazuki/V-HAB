classdef timed < sys
    %TIMED Method exec called either with parent or in regular intervals
    %   Can attach the .exec() method to the parent's exec method
    %   execution, or set a fixed interval for calling the exec method. The
    %   setTimestep method can be used to adjust that interval at any time
    %   in the simulation.
    
    properties (SetAccess = protected, GetAccess = public)
       % Reference to timer object
       oTimer;
       
       % Current time step
       fTimeStep;
       
       fLastExec     = -1;
       fLastTimeStep = 0;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        setTimeStepCB;
        unbindCB;
        
        iBindIndex;
    end
    
    methods
        function this = timed(oParent, sName, fTimeStep)
            this@sys(oParent, sName);
            
            this.oTimer = oParent.oTimer;
            
            if nargin >= 3 && ~isempty(fTimeStep)
                this.setTimeStep(fTimeStep);
            else
                % Set execution with each tick!
                this.setTimeStep();
            end
        end
    end
    
    
    methods (Access = protected)
        function exec(this, ~)
            % Specifically don't call the sys exec - we do trigger event
            % here with time provided!
            
            this.fLastTimeStep = this.oTimer.fTime - this.fLastExec;
            
            this.trigger('exec', this.oTimer.fTime);
            
            this.fLastExec = this.oTimer.fTime;
        end
        
        function setTimeStep(this, xTimeStep)
            % Sets the time step for xTimeStep > 0. If xTimeStep not
            % provided or 0, global time step. If logical false, link to 
            % parent! If -1 execute every simulation tick (default).
            
            % No xTimeStep provided?
            if nargin < 2 || isempty(xTimeStep), xTimeStep = -1; end
            
            % Set as obj property/attribute
            this.fTimeStep = xTimeStep;
            
            % If logical false - link to parent
            if islogical(xTimeStep) && ~xTimeStep
                % Unregister with timer if we're registered!
                if ~isempty(this.unbindCB)
                    this.unbindCB();
                    
                    this.unbindCB      = [];
                    this.setTimeStepCB = [];
                end
                
                % Need to register on parent
                if isempty(this.iBindIndex)
                    this.iBindIndex = this.oParent.bind('exec', @this.exec);
                end
            else
                if ~isempty(this.iBindIndex)
                    this.oParent.unbind(this.iBindIndex);
                    this.iBindIndex = [];
                end
                
                % Not yet registered on timer?
                if isempty(this.unbindCB)
                    [ this.setTimeStepCB, this.unbindCB ] = this.oTimer.bind(@this.exec, xTimeStep, struct(...
                        'sMethod', 'exec', ...
                        'sDescription', 'The .exec method of a timed system', ...
                        'oSrcObj', this ...
                    ));
                    
                % Set new time step
                else
                    this.setTimeStepCB(xTimeStep);
                end
                
                % If time step is 0, means we registered on the global time
                % step -> write to this sys
                if this.fTimeStep == 0, this.fTimeStep = this.oTimer.fMinimumTimeStep; end
            end
        end
    end
end