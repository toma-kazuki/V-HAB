function iIndex = addValueToLog(this, tLogProp)
% This method adds a value to the tLogValues struct array property and
% returns its index.

% Initializing a local variable to hold the object from which we want to
% add a property to the log.
oObj   = [];

% Replace shorthand to full path (e.g. :s: to .toStores.) and prefix so
% object is reachable through eval().
tLogProp.sObjectPath = simulation.helper.paths.convertShorthandToFullPath(tLogProp.sObjectPath);

% Making sure that the object exists.
try
    oObj = eval([ 'this.oSimulationInfrastructure.oSimulationContainer.toChildren.' tLogProp.sObjectPath ]);
    
    % The object exists so now we can set the UUID field in the tLogProp
    % struct.
    tLogProp.sObjUuid = oObj.sUUID;
catch oErr
    assignin('base', 'oLastErr', oErr);
    this.throw('addValueToLog', 'Object does not seem to exist: %s \n(message was: %s)', tLogProp.sObjectPath, oErr.message);
end


% Now we have to check to see if the item we are adding already exists in
% the tLogValues struct. If it does, we can just get its index and return.

% First we see if there are matching UUIDs
aiObjMatches = find(strcmp({ this.tLogValues.sObjUuid }, tLogProp.sObjUuid));

if any(aiObjMatches)
    % There are matching UUIDs, so now we see if there are matching
    % expressions for these objects.
    aiExpressionMatches = find(strcmp({ this.tLogValues(aiObjMatches).sExpression }, tLogProp.sExpression));
    
    if any(aiExpressionMatches)
        % The expression and the object matches an existing entry, so we
        % can just get its index.
        iIndex = this.tLogValues(aiObjMatches(aiExpressionMatches(1))).iIndex;
        
        % It may be the case, that the existing item was entered into the
        % log via an automatic helper. This means, that the label was
        % created automatically and is not very legible. Also the sName
        % field may be empty. If the user has provided new values for these
        % two fields, we overwrite them and publish a warning, so the user
        % knows what's going on.
        if ~strcmp(this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sLabel, tLogProp.sLabel) && ~isempty(tLogProp.sLabel)
            this.warn('addValueToLog', 'Overwriting log item label from "%s" to "%s".', this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sLabel, tLogProp.sLabel);
            this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sLabel = tLogProp.sLabel;
        end
        
        if ~strcmp(this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sName, tLogProp.sName) && ~isempty(tLogProp.sName)
            this.warn('addValueToLog', 'Overwriting log item name from "%s" to "%s".', this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sName, tLogProp.sName);
            this.tLogValues(aiObjMatches(aiExpressionMatches(1))).sName = tLogProp.sName;
        end
        
        return;
    end
end

% If the user did not provide a name for this item, we generate it
% automatically from the information we have, which is the expression to be
% evaluated and the object.
if ~isfield(tLogProp, 'sName') || isempty(tLogProp.sName)
    % Since we may need to use the name of the log item as a field name in
    % a struct, we need to do some formatting with the sExpression field.
    
    % First we replace all characters that are not alphanumeric with
    % underscores.
    sName = regexprep(tLogProp.sExpression, '[^a-zA-Z0-9]', '_');
    
    % Next we remove all occurances of 'this_'
    sName = strrep(sName, 'this_', '');
    
    % Since we may need to use the name of the log item as a field name in
    % a struct, we shorten the string to the allowed 63 characters. In
    % order to make sure that the name is still unique, we will add the
    % object UUID to the string, which is 32 characters long, so the
    % remaining name can only be 30 characters in length, since we'll add
    % an underscore for separation.
    if length(sName) > 30
        sName = sName(1:30);
    end
    
    % Now we can set the name with the appended UUID.
    tLogProp.sName = [sName, '_', oObj.sUUID];
    
end


% If the user did not provide a unit string, we can try to find it in the
% poExpressionToUnit map.
if ~isfield(tLogProp, 'sUnit') || isempty(tLogProp.sUnit)
    % Setting the fallback unit to '-'
    tLogProp.sUnit = '-';
    
    % Getting a cell with all the expressions that we have units for
    csKeys = this.poExpressionToUnit.keys();
    
    % See if any expressions match the one we are looking for.
    abIndex =  strcmp(csKeys, tLogProp.sExpression);
    if any(abIndex) && sum(abIndex) == 1
        % We have a match, so we can set the field accordingly.
        tLogProp.sUnit = this.poExpressionToUnit(csKeys{abIndex});
    end
end


% If the user did not provide a label, we will build one here.
if ~isfield(tLogProp, 'sLabel') || isempty(tLogProp.sLabel)
    
    % First we'll check if the object we are logging from has a sName
    % property. We want to use that name for our label. If there is no such
    % property, we just use the object's path.
    try
        tLogProp.sLabel = oObj.sName;
        
    catch
        tLogProp.sLabel = tLogProp.sObjectPath;
        
    end
    
    % If a unit is given hat is included in the poUnitsToLabels map, then
    % we use that to finish our label, otherwise we just set the label to
    % the expression to be evaluated.
    try
        tLogProp.sLabel = [ tLogProp.sLabel ' - ' this.poUnitsToLabels(tLogProp.sUnit) ];
        
    catch
        tLogProp.sLabel = tLogProp.sExpression;
        
    end
end



% Now we are finally done and can add the element to log struct array
iIndex          = length(this.tLogValues) + 1;
tLogProp.iIndex = iIndex;

this.tLogValues(tLogProp.iIndex) = tLogProp;
end
