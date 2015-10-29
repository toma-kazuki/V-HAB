classdef (Abstract) phase < base & matlab.mixin.Heterogeneous
    %PHASE Phase with isotropic properties (abstract class)
    %   This class represents a matter phase with homogeneous mass
    %   distribution and thus isotropic properties. It is not meant to be
    %   used directly, use e.g. |matter.phases.gas| instead.
    %
    %TODO: rename to |IsotropicPhase| or |HomogeneousPhase|
    %
    %TODO: refactor some of this code out to a new |Mass| class and inherit
    %      from it??
    %
    %TODO (further ideas)
    %   * conduct (mass)update calculations for all phases scheduled for
    %     current tick in a single post-tick (before solvers/timesteps)
    %     callback simultaneously
    %   * manipulators for volume - package matter.manips.volume, different
    %     base classes for isobaric, isochoric etc. volume changes
    %     -> how to handle the store (which distributes the volume equally
    %        throughout gas phases)? How to treat volume changes due to
    %        inflowing matter?
    %   * method .setHeatSource(oHeatSource), see thermal solver
    %   * post-tick priorities / execution groups: separate update of flow
    %     p2ps and manips - first post-tick callback - from the time step
    %     calculation - second post-tick callback. In post tick, first
    %     exec phase properties update methods (mass, mol mass etc), then
    %     the solver flow rates. Then the phase manips/p2ps can update and
    %     finally the phases can calculate their time steps. Each p2p/manip
    %     should add itself to post-tick - if already done, not done again.

    properties (Abstract, Constant)

        % State of matter in phase (e.g. gas, liquid, solid), used for
        % example by the EXMEs to check compatibility.
        %TODO: rename to |sMatterState|
        %TODO: drop this and let the code check for |isa(oObj, 'matter.phase.gas')| ?
        % @type string
        sType;

    end

    properties (SetAccess = protected, GetAccess = public)
        % Basic parameters:

        % Mass of every substance in phase
        %TODO: rename to |afMasses| or better
        % @type array
        % @types float
        afMass;       % [kg]

        % Temperature of phase
        %TODO: rename to |fTemperature|
        % @type float
        fTemp;        % [K]

    end

    properties (SetAccess = protected, GetAccess = public) %(Dependent, ?Access???)
        % Dependent variables:
        %TODO: investigate making them dependent + using accessors methods

        % (Mean?) Density of mixture; not updated by this class, has to be
        % handled by a deriving class.
        % @type float
        fDensity = -1; % [kg/m^3]

        % Total negative masses per substance encountered during mass
        % update. This data is only kept for debugging/logging purposes.
        % If a branch requests more mass of a substance than stored in the
        % phase, there is currently no way to tell the branch about this
        % issue. Instead of throwing an error or setting a negative value
        % for the substance mass, the mass is set to zero and the absolute
        % 'lost' (negative) mass is added to this vector.
        %TODO implement check in matter.branch setFlowRate for this issue?
        %     What if several branches request too much mass?
        % @type array
        % @types float
        afMassLost;

        % Mass fraction of every substance in phase
        %TODO: rename to |arMassFractions|
        % @type array
        % @types float
        arPartialMass; % [%]

        % Total mass of phase
        %TODO: rename to |fTotalMass|
        % @type float
        fMass;         % [kg]

        % Molar mass of mixture in phase
        %TODO: rename to |fMolarMass| and return [kg/mol]
        % @type float
        fMolMass;      % [g/mol]

        % Specific heat capacity of mixture in phase (NOT total heat cap.!)
        %TODO: rename to |fSpecificHeatCapacity|, implement
        %      |this.getTotalHeatCapacity()| that returns
        %      |this.fSpecificHeatCapacity * this.fMass|
        %TODO: Keep |fHeatCapacity|, implement |get.fHeatCapacity| that
        %      warns and instead returns |fSpecificHeatCapacity| or
        %      |this.getTotalHeatCapacity| (?)
        % @type float
        fHeatCapacity = 0; % [J/(K*kg)]

    end

    properties (SetAccess = protected, GetAccess = public)
        % Internal properties, part 1:
        %TODO: investigate if this block can be merged with other ones

        % Length of the last time step (??)
        fTimeStep;

    end

    properties (SetAccess = private, GetAccess = public)
        % Internal properties, part 2:
        %TODO: investigate if this block can be merged with other ones

        % Associated matter store object
        %TODO: rename because everything must be new now >:-]
        oStore;

        % Matter table object
        oMT;

        % User-defined name of phase
        % @type string
        %TODO: rename to |sIdent|??
        %TODO: auto-generate name???
        sName;

        % List of Extract/Merge processors added to the phase: Key of
        % struct is set to the processor's name and can be used to retrieve
        % that object.
        %NOTE: A port with the name 'default' is not allowed (was previously
        %      used to define ports that can have several flows).
        %TODO: rename to |toExMePorts|, |toExMeProcessors|, etc.; or ?
        %TODO: use map and rename to |poExMeProcessors|?
        % @type struct
        % @types object
        toProcsEXME = struct();

        % List of manipulators added to the phase
        % @type struct
        % @types object
        toManips = struct('volume', [], 'temperature', [], 'substance', []);

    end

    properties (SetAccess = private, GetAccess = public) % (Access = private)
        % Internal properties, part 3:
        %TODO: investigate if this block can be merged with other ones

        % Cache: List and count of ExMe objects, used in |this.update()|
        %NOTE: cf. |toProcsEXME| property
        %TODO: investigate if we need this or data can be stored
        %      differently, e.g. in a general cache property
        %TODO: rename to something more fitting
        coProcsEXME;
        iProcsEXME;

        % Cache: List and count of all p2p flow processor objects (i.e.
        % |matter.procs.p2ps.flow|) that are connected to an ExMe of this
        % phase. Used to quickly access the objects in |this.massupdate()|;
        % created in |this.seal()|.
        %TODO make Transient, reload on loadobj
        coProcsP2Pflow;
        iProcsP2Pflow;

    end

    properties (SetAccess = private, GetAccess = public)
        % Internal properties, part 4:
        %TODO: investigate if this block can be merged with other ones

        % Last time the phase was updated (??)
        % @type float
        fLastMassUpdate = 0;

        % Time step in last massupdate (???)
        % @type float
        fMassUpdateTimeStep = 0;

        % Current total incoming or (if negative value) outgoing mass flow,
        % for all substances combined. Used to improve pressure estimation
        % in ExMe processors.
        % @type float
        fCurrentTotalMassInOut = 0;

        % ???
        fLastUpdate = -10;
        fLastTimeStepCalculation = -10;

%         % ???
%         fTimeStep;

    end

    properties (Access = private)

        % ???
        bOutdatedTS = false;

    end

    properties (Access = public)

        % Limit - how much can the phase mass (total or single substances)
        % change before an update of the matter properties (of the whole
        % store) is triggered?
        rMaxChange = 0.25;
        fMaxStep   = 20;
        fFixedTS;

        % If true, massupdate triggers all branches to re-calculate their
        % flow rates. Use when volumes of phase compared to flow rates are
        % small!
        bSynced = false;

    end

    properties (Transient, SetAccess = private, GetAccess = public)

        % Masses in phase at last update.
        fMassLastUpdate;
        afMassLastUpdate;

    end

    methods

        function this = phase(oStore, sName, tfMass, fTemp)
            % Constructor for the |matter.phase| class. Input parameters
            % can be provided to define the contained masses and
            % temperature, additionally the internal, merge and extract
            % processors.
            %
            % phase parameters:
            %   oStore  - object reference to the store, matter table also
            %             received from there
            %   sName   - name of the phase
            %   aoPorts - ports (exme procs instances); can be empty or not
            %             provided, but then no mass can be extracted or
            %             merged.
            %   tfMass  - optional. Struct containing the initial masses.
            %             Keys refer to the name of the according substance
            %   fTemp 	- temperature of the initial mass, has to be given
            %             if  tfMass is provided

            % Parent has to be a or derive from matter.store
            if ~isa(oStore, 'matter.store'), this.throw('phase', 'Provided oStore parameter has to be a matter.store'); end;

            % Set name
            this.sName = sName;

            % Parent store - FIRST call addPhase on parent, THEN set the
            % store as the parent - matter.store.addPhase only does that if
            % the oStore attribute here is empty!
            %CHECK changed, see connector_store, need oStore already set
            this.oStore = oStore;
            this.oStore.addPhase(this);

            % DELETE? This is only necessary if the number of substances
            % changes during runtime...
            % Set the matter table
            %this.oMT = oMT;
            this.updateMatterTable();

            % Preset masses
            this.afMass = zeros(1, this.oMT.iSubstances);
            this.arPartialMass = zeros(1, this.oMT.iSubstances);

            % Mass provided?
            if (nargin >= 3) && ~isempty(tfMass) && ~isempty(fieldnames(tfMass))
                % If tfMass is provided, fTemp also has to be there
                if nargin < 4 || isempty(fTemp) || ~isnumeric(fTemp) || (fTemp <= 0)
                    this.throw('phase', 'If tfMass is provided, the fTemp parameter also has to be provided (Kelvin, non-empty number, greater than zero).');
                end

                % Extract initial masses from tfMass and set to afMass
                csKeys = fieldnames(tfMass);

                for iI = 1:length(csKeys)
                    sKey = csKeys{iI};

                    % Throw an error if the matter substance is not in the
                    % matter table
                    if ~isfield(this.oMT.tiN2I, sKey), this.throw('phase', 'Matter type %s unkown to matter.table', sKey); end;

                    this.afMass(this.oMT.tiN2I.(sKey)) = tfMass.(sKey);
                end

                % Calculate total mass
                this.fMass = sum(this.afMass);


                % Calculate the partial masses
                if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
                else               this.arPartialMass = this.afMass; % afMass is just zeros
                end

                % Handle temperature
                this.fTemp = fTemp;
            else
                % Set this to zero to handle empty phases
                this.fMass = 0;
                % No mass - no temp
                this.fTemp = 0;

                % Partials also to zeros
                this.arPartialMass = this.afMass;
            end

            % Now update the matter properties
            this.fMolMass      = this.oMT.calculateMolecularMass(this.afMass);
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);

            % Mass
            this.fMass = sum(this.afMass);
            this.afMassLost = zeros(1, this.oMT.iSubstances);

            % Preset the cached masses (see calculateTimeStep)
            this.fMassLastUpdate  = 0;
            this.afMassLastUpdate = zeros(1, this.oMT.iSubstances);
        end

        function hRemove = addManipulator(this, oManip)

            sManipType = [];

            if     isa(oManip, 'matter.manips.volume'),               sManipType = 'volume';
            elseif isa(oManip, 'matter.manips.temperature'),          sManipType = 'temperature';
            elseif isa(oManip, 'matter.manips.substance.flow'),       sManipType = 'substance';
            elseif isa(oManip, 'matter.manips.substance.stationary'), sManipType = 'substance';
            end

            if ~isempty(this.toManips.(sManipType))
                this.throw('addManipulator', 'A manipulator of type %s is already set for phase %s (store %s)', sManipType, this.sName, this.oStore.sName);
            end

            % Set manipulator
            this.toManips.(sManipType) = oManip;

            % Remove fct call to detach manipulator
            hRemove = @() this.detachManipulator(sManipType);

        end

        function this = massupdate(this)
            % This method updates the mass and temperature related
            % properties of the phase. It takes into account all in- and
            % outflowing matter streams via the exme processors connected
            % to the phase, including the ones associated with p2p
            % processors. It also gets the mass changes from substance
            % manipulators. The new temperature is based on the thermal
            % energy of the in- and outflow. After completing the update of
            % fMass, afMass and fTemp this method sets the phase's timestep
            % outdated, so it will be recalculated during the post-tick.
            % Additionally, if this phase is set as 'sycned', this method
            % will set all branches connected to exmes connected to this
            % phase to outdated, also causing a recalculation in the
            % post-tick.

            fTime     = this.oStore.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;

            % Return if no time has passed
            if fLastStep == 0,
                return;
            end;

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;

            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            [ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();

            % Check manipulator
            if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.substance.afPartialFlows;

            end

            % Cache total mass in/out so the EXMEs can use that
            this.fCurrentTotalMassInOut = sum(afTotalInOuts);

            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fLastStep;
            %afTotalInOuts = this.getTotalMassChange() * fTimeStep;

            % Do the actual adding/removing of mass.
            %CHECK round the whole, resulting mass?
            %  tools.round.prec(this.afMass, this.oStore.oTimer.iPrecision)
            this.afMass =  this.afMass + afTotalInOuts;

            % Now we check if any of the masses has become negative. This
            % can happen for two reasons, the first is just MATLAB rounding
            % errors causing barely negative numbers (e-14 etc.) The other
            % is an error in the programming of one of the procs/solvers.
            % In any case, we don't interrupt the simulation for this, we
            % just log the negative masses and set them to zero in the
            % afMass array. The sum of all mass lost is shown in the
            % command window in the post simulation summary.
            abNegative = this.afMass < 0;

            if any(abNegative)
                this.afMassLost(abNegative) = this.afMassLost(abNegative) - this.afMass(abNegative);
                this.afMass(abNegative) = 0;
            end


            %%%% Now calculate the new temperature of the phase using the
            % inflowing enthalpies / inner energies / ... whatever.

            % Convert flow rates to masses
            mfInflowDetails(:, 1) = mfInflowDetails(:, 1) * fLastStep;

            % Add the phase mass and stuff
            if ~isempty(mfInflowDetails) % no inflows?
                %mfInflowDetails = [ this.fMass, this.fTemp, this.fHeatCapacity ];
                mfInflowDetails(end + 1, 1:3) = [ this.fMass, this.fTemp, this.fHeatCapacity ];

                % Calculate inner energy (m * c_p * T) for all masses
                afEnergy = mfInflowDetails(:, 1) .* mfInflowDetails(:, 3) .* mfInflowDetails(:, 2);

                % For all masses - mass * heat capacity - helper
                afMassTimesCP = mfInflowDetails(:, 1) .* mfInflowDetails(:, 3);

                % New temperature
                fOldTemp   = this.fTemp;
                this.fTemp = sum(afEnergy) / sum(afMassTimesCP);

                %TODO instead of using the old temperature, analyze what
                %     actually happens here (phase empty? some problems
                %     with the flow properties? where is the NaN coming
                %     from?)
                %     -> fix source of error, prevent NaN from happening
                if isnan(this.fTemp)
                    this.warn('massupdate', 'TEMPERATURE IS NAN!!! Store: %s, Phase: %s - old temp used. Maybe phase was empty?', this.oStore.sName, this.sName);
                    this.fTemp = fOldTemp;
                end

            end

            % Logic for deriving new temperature:
            % Inner Energy
            %   Q = m * c_p * T
            %
            % Total energy, mass:
            %   Q_t = Q_1 + Q_2 + ...
            %   m_t = m_1 + m_2 + ...
            %
            % Total Heat capacity of the mixture
            %   c_p,t = (c_p,1*m_1 + c_p,2*m_2 + ...) / (m_1 + m_2 + ...)
            %
            %
            % Temperature from total energy of a mix
            %   T_t = Q_t / (m_t * c_p,t)
            %       = (m_1 * c_p,1 * T_1 + m_2 * c_p,2 * T_2 + ...) /
            %         ((m_1 + m_2 + ...) * (c_p,1*m_1 + ...) / (m_1 + ...))
            %       = (m_1 * c_p,1 * T_1 + m_2 * c_p,2 * T_2 + ...) /
            %               (c_p,1*m_1 + c_p,2*m_2 + ...)
            %
            %
            %TODO see http://de.wikipedia.org/wiki/Innere_Energie
            %     also see EXME, old .merge
            %     -> handle further things?


            % Update total mass
            this.fMass = sum(this.afMass);


            % If synced, trigger 'fr recalc' in all branches
            if this.bSynced
                this.setBranchesOutdated();
            end

            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
        end

        function this = update(this)
            % Only update if not yet happened at the current time.
            if (this.oStore.oTimer.fTime <= this.fLastUpdate) || (this.oStore.oTimer.fTime < 0)
                return;
            end

            % Store update time
            this.fLastUpdate = this.oStore.oTimer.fTime;


            % Massupdate triggers setBranchesOutdated for this.bSynced
            % automatically, so only trigger if this phase is not synced.
            if ~this.bSynced
                this.setBranchesOutdated();
            end

            % Actually move the mass into/out of the phase.
            this.massupdate();

            % Cache current fMass / afMass so they represent the values at
            % the last phase update. Needed in phase time step calculation.
            this.fMassLastUpdate  = this.fMass;
            this.afMassLastUpdate = this.afMass;



            % Partial masses
            if this.fMass > 0, this.arPartialMass = this.afMass / this.fMass;
            else               this.arPartialMass = this.afMass; % afMass is just zeros
            end

            % Now update the matter properties
            this.fMolMass      = this.oMT.calculateMolecularMass(this.afMass);
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
        end
    end


    %% Methods for adding ports, getting flow information etc
    % The EXME procs get an instance to this object on construction and
    % call the addProcEXME here, therefore not protected - but checks
    % the store's bSealed attr, so nothing can be changed later.
    methods

        function addProcEXME(this, oProcEXME)
            % Adds a exme proc, i.e. a port. Returns a function handle to
            % the this.setAttribute method (actually the one of the derived
            % class) which allows manipulation of all set protected
            % attributes within the phase.

            if this.oStore.bSealed
                this.throw('addProcEXME', 'The store to which this phase belongs is sealed, so no ports can be added any more.');
            end


            if ~isa(oProcEXME, [ 'matter.procs.exmes.' this.sType ])
                this.throw('addProcEXME', [ 'Provided object ~isa matter.procs.exmes.' this.sType ]);

            elseif ~isempty(oProcEXME.oPhase)
                this.throw('addProcEXME', 'Processor has already a phase set as parent.');

            elseif isfield(this.toProcsEXME, oProcEXME.sName)
                this.throw('addProcEXME', 'Proc %s already exists.', oProcEXME.sName);

            elseif strcmp(oProcEXME.sName, 'default')
                this.throw('addProcEXME', 'Default EXMEs are not allowed any more!');

            end



            this.toProcsEXME.(oProcEXME.sName) = oProcEXME;
        end

        % Moved to public methods, sometimes external access required
        function [ afTotalInOuts, mfInflowDetails ] = getTotalMassChange(this)
            % Get vector with total mass change through all EXME flows in
            % [kg/s].
            %
            % The second output parameter is a matrix containing all inflow
            % rates, temperatures and heat capacities for calculating the
            % inflowing enthalpy/inner energy
            %
            %TODO
            %   * on .seal() and when branches are (re)connected, write all
            %     flow objects connected to the EXMEs to this.aoFlowsEXMEs
            %     or something, in order to access them more quickly here!
            %   * Simplify - all EXMEs can only have one flow now!

            % Total flows - one row (see below) for each EXME, number of
            % columns is the number of substances (partial masses)
            mfTotalFlows = zeros(this.iProcsEXME, this.oMT.iSubstances);

            % Each row: flow rate, temperature, heat capacity
            mfInflowDetails = zeros(0, 3);

            % Get flow rates and partials from EXMEs
            for iI = 1:this.iProcsEXME
                [ afFlowRates, mrFlowPartials, mfProperties ] = this.coProcsEXME{iI}.getFlowData();

                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                % mfProperties contains temp, heat capacity

                if isempty(afFlowRates), continue; end;

                % So bsxfun with switched afFlowRates (to col vector) will
                % multiply every column value in the flow partials matrix
                % with the value in flow rates at the according position
                % (i.e. each element in first row with first element of fr,
                % each element in second row with 2nd element on fr, ...)
                % Then we sum() the resulting matrix which sums up column
                % wise ...
                mfTotalFlows(iI, :) = sum(bsxfun(@times, afFlowRates, mrFlowPartials), 1);

                % ... and now we got a vector with the absolute mass in-/
                % outflow for the current EXME for each substance and for one
                % second!


                % Calculate inner energy of INflows, per sec
                abInf    = (afFlowRates > 0);
                %TODO store as attribute for 'automatic' preallocation,
                %     replace rows instead of append.
                if any(abInf)
                    mfInflowDetails = [ mfInflowDetails; afFlowRates(abInf), mfProperties(abInf, 1), mfProperties(abInf, 2) ];
                end
            end

            % Now sum up in-/outflows over all EXMEs
            afTotalInOuts = sum(mfTotalFlows, 1);

        end

        function seal(this, oData)
            if ~this.oStore.bSealed
                this.coProcsEXME = struct2cell(this.toProcsEXME)';
                this.iProcsEXME  = length(this.coProcsEXME);


                % Get all p2p flow processors on EXMEs
                this.coProcsP2Pflow = {};
                this.iProcsP2Pflow  = 0;

                for iE = 1:this.iProcsEXME
                    % If p2p flow, cannot be port 'default', i.e. just one
                    % flow possible!
                    if ~isempty(this.coProcsEXME{iE}.aoFlows) && isa(this.coProcsEXME{iE}.aoFlows(1), 'matter.procs.p2ps.flow')
                        this.iProcsP2Pflow = this.iProcsP2Pflow + 1;

                        this.coProcsP2Pflow{this.iProcsP2Pflow} = this.coProcsEXME{iE}.aoFlows(1);
                    end
                end
            end
        end

    end


    %% Internal, protected methods
    methods (Access = protected)

        function detachManipulator(this, sManip)
            %CHECK several manipulators possible?

            this.toManips.(sManip) = [];
        end

        function setBranchesOutdated(this)
            % Loop through exmes / flows and set outdated, i.e. request re-
            % calculation of flow rate.
            for iE = 1:this.iProcsEXME
                for iF = 1:length(this.coProcsEXME{iE}.aoFlows)
                    oBranch = this.coProcsEXME{iE}.aoFlows(iF).oBranch;

                    % Make sure it's not a p2ps.flow - their update method
                    % is called in time step calculation method
                    if isa(oBranch, 'matter.branch')
                        % We can't directly set this oBranch as outdated if
                        % it is just connected to an interface, because the
                        % solver is assigned to the 'leftest' branch.
                        while ~isempty(oBranch.coBranches{1})
                            oBranch = oBranch.coBranches{1};
                        end

                        % Tell branch to recalculate flow rate (done after
                        % the current tick, in timer post tick).
                        oBranch.setOutdated();
                    end
                end
            end
        end

        function calculateTimeStep(this)

            %TODO move this to another function or class or whatever. Why
            %is this executed here anyway?
            %ANSWER: Because we need to make sure these guys are updated
            %every time massupdate is called. Than cannot only be done by
            %the phase.update(), which is called from store.update(), but
            %also from branch.update(). Then the update methods from the
            %p2ps and manips would not be called, if they weren't in here.
            %Still, they seem out of place here and might be put into a
            %separate method? Or should we bind them to the post-tick of
            %the timer as well?
            % Check manipulator
            %TODO allow user to set a this.bManipBeforeP2P or so, and if
            %     true execute the [manip].update() before the P2Ps update!
            if ~isempty(this.toManips.substance)
                %keyboard();
                this.toManips.substance.update();

                % Add the changes from the manipulator to the total inouts
                %afTotalInOuts = afTotalInOuts + this.toManips.substances.afPartial;
            end


            %TODO move this to another function or class or whatever. Why
            % is this executed here anyway? Shouldn't that be done in the
            % Store after all phases have updated?
            %keyboard();
            % Call p2ps.flow update methods (if not yet called)
            for iP = 1:this.iProcsP2Pflow
                % That check would make more sense within the flow p2p
                % update method - however, that method will be overloaded
                % in p2ps to include the model to derive the flow rate, so
                % would have to be manually added in each derived p2p ...
                if this.coProcsP2Pflow{iP}.fLastUpdate < this.fLastMassUpdate
                    % Triggers the .massupdate of both connected phases
                    % which is ok, because the fTimeStep == 0 check above
                    % will prevent this .massupdate from re-executing.
                    this.coProcsP2Pflow{iP}.update();
                end
            end



            if ~isempty(this.fFixedTS)
                fNewStep = this.fFixedTS;
            else

                % Calculate the change in total and partial mass since the
                % phase was last updated
                rPreviousChange  = this.fMass / this.fMassLastUpdate - 1;

                arPreviousChange = abs(this.afMassLastUpdate ./ this.afMass - 1);

                % Should only happen if fMass (therefore afMass) is zero!
                if isnan(rPreviousChange)
                    rPreviousChange  = 0;
                    arPreviousChange = this.afMass; % ... set to zeros!
                end

                % Change in kg of partial masses per second
                afChange = this.getTotalMassChange();

                % Only use entries where change is not zero
                % If some substance changed a bit, but less then the thres-
                % hold, and does not any more - not taken into account. It
                % can still change in relation to other substances, where mass
                % flows in/out, but that should be covered by the total
                % mass change check.
                abChange = (afChange ~= 0);

                % Changes of substance masses - get max. change, add the change
                % that happend already since last update
                %arPreviousChange = abs(afChange(abChange) ./ tools.round.prec(this.afMass(abChange), this.oStore.oTimer.iPrecision)) + arPreviousChange(abChange);
                arPartialsChange = abs(afChange(abChange) ./ tools.round.prec(this.fMass, this.oStore.oTimer.iPrecision));% + arPreviousChange(abChange);

                % Only use non-inf --> inf if current mass of according
                % substance is zero. If new substance enters phase, still
                % covered through the overall mass check.
                rPartialsPerSecond = max(arPartialsChange(~isinf(arPartialsChange)));

                if isempty(rPartialsPerSecond), rPartialsPerSecond = 0; end;

                % Change per second of TOTAL mass
                fChange = sum(afChange);

                % No change in total mass?
                if fChange == 0
                    rTotalPerSecond = 0;
                else
                    rTotalPerSecond = abs(fChange / this.fMass);
                end


                % Derive timestep, use the max change (total mass or one of
                % the substances change)
                %fNewStep = this.rMaxChange / max([ rChangePerSecond rTotalPerSecond ]);
                %fNewStep = (this.rMaxChange - rPreviousChange) / max([ rPartialsPerSecond rTotalPerSecond ]);

                fNewStepTotal    = (this.rMaxChange - rPreviousChange) / rTotalPerSecond;
                fNewStepPartials = (this.rMaxChange - max(arPreviousChange)) / rPartialsPerSecond;

                fNewStep = min([ fNewStepTotal fNewStepPartials ]);

                %{
                %CHECK can calulateTimeStep be called multiple times in one
                %      tick?
                iRemDeSi = this.iRememberDeltaSign;
                iPrec    = this.oStore.oTimer.iPrecision;
                iExpRem  = 0;
                iExpDelta= 0; % inactive right now!


                if this.fLastTimeStepCalculation < this.oStore.oTimer.fTime
                    this.abDeltaPositive(1:iRemDeSi)   = this.abDeltaPositive(2:(iRemDeSi + 1));
                    this.abDeltaPositive(iRemDeSi + 1) = fChange > 0;

                    if tools.round.prec(fChange, iPrec) == tools.round.prec(this.fLastTotalChange, iPrec)
                        %this.abDeltaPositive(iRemDeSi + 1) = this.abDeltaPositive(iRemDeSi);
                    end
                end

                this.fLastTimeStepCalculation = this.oStore.oTimer.fTime;


                aiChanges = abs(diff(this.abDeltaPositive));
                afExp     = (1:iRemDeSi) .^ iExpRem;
                arExp     = afExp ./ sum(afExp);% * 1.5;
                rChanges  = sum(arExp .* aiChanges);

                fNewStep = interp1([ 0 1 ], [ this.oStore.oTimer.fTimeStep fNewStep ], (1 - rChanges) ^ iExpDelta, 'linear', 'extrap');
                %}


                if fNewStep > this.fMaxStep
                    fNewStep = this.fMaxStep;
                elseif fNewStep < 0
                    fNewStep = 0;
                end
            end


            % Set the time at which the containing store will be updated
            % again. Need to pass on an absolute time, not a time step.
            % Value in store is only updated, if the new update time is
            % earlier than the currently set next update time.
            this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);

            % Cache - e.g. for logging purposes
            this.fTimeStep = fNewStep;

            % Now up to date!
            this.bOutdatedTS = false;
        end

        function setOutdatedTS(this)
            if ~this.bOutdatedTS
                this.bOutdatedTS = true;

                this.oStore.oTimer.bindPostTick(@this.calculateTimeStep);
            end
        end

        function this = updateMatterTable(this)
            % Adds the phase to the matter table index and sets property
            this.oMT = this.oStore.oMT;

            % addPhase returns the old afMass mappend to the new MT
            this.afMass = this.oMT.addPhase(this);
        end

        function setAttribute(this, sAttribute, xValue)
            % Internal method that needs to be copied to every child.
            % Required to enable the phase class to adapt values on the
            % child through processors.
            %
            %TODO see manipulators (not done with procs any more) - new way
            %     of handling that. Remove?

            this.(sAttribute) = xValue;
        end

        function [ bSuccess, txValues ] = setParameter(this, sParamName, xNewValue)
            % Helper for executing internal processors.
            %
            %TODO OLD - change to 'manipulators' etc ... some other
            %           functionality to map manips to phases?
            %
            % setParameter parameters:
            %   sParamName  - attr/param to set
            %   xNewValue   - value to set param to
            %   setValue    - function handle to set the struct returned by
            %                 the processor (params key, value).
            %
            %TODO   need that method so e.g. a gas phase can change the
            %       fVolume property, and some external manipulator can be
            %       called from here to e.g. change the temperature due to
            %       the volume change stuff.
            %       -> how to define which manipulators to use? This class
            %          here should handle the manipulators for its own
            %          properties (fTemp, fVol) etc - but depending on
            %          phase type. Specific phase type class should handle
            %          manips for their properties (gas -> fPressure).
            %          SEE setAttribute -> provide generic functionality to
            %          trigger an event or external handler when a property
            %          is changed -> different manipulators can be attached
            %          to different phases and properties
            %       -> just make properties SetAcc protected or create some
            %          more specific setVol, setTemp etc. methods?

            bSuccess = false;
            txValues = [];

            %TODO work with events, or direct callbacks, or ...? 'static
            %     events' that happen generally on e.g.
            %     matter.phase.setVolume?
            this.setAttribute(sParamName, xNewValue);
            this.update();

            return;

            % Check if processor was registered for that parameter
            if isfield(this.ttoProcs.internal, sParamName)
                % Found a processor - true
                bSuccess = true;

                % Struct returned by callback is written onto the object,
                % i.e. arbitrary attributes can be changed by processor!
                %TODO use (int procs, also ex/me procs) a events system?
                %     So several procs can register? Same mode, they can
                %     return a struct with the class props to modify ...
                txValues = this.ttoProcs.internal.(sParamName)(this, xNewValue, sParamName);

                % If returned value not empty ...
                if ~isempty(txValues)
                    % ... get the keys (= attribute names) from struct ...
                    csAttrs = fieldnames(txValues);

                    % ... and write the values on this object
                    for iI = 1:length(csAttrs)
                        %setValue(csAttrs{iI}, txValues.(csAttrs{iI}));
                        %this.(csAttrs{iI}) = txValues.(csAttrs{iI});
                        this.setAttribute(csAttrs{iI}, txValues.(csAttrs{iI}));
                    end
                end
            end
        end

    end

    methods(Sealed)
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end

end