function summary = simplify_simscape_presentation(modelName,options)
%SIMPLIFY_SIMSCAPE_PRESENTATION Reduce top-level wiring without changing math.
%   The physical Simscape network is deliberately left intact. Repeated
%   scope/logger branches are replaced by global Goto/From routing, and
%   pure-Simulink control blocks are grouped into virtual subsystems.

arguments
    modelName (1,1) string
    options.GroupControlStages (1,1) logical = true
end

modelName = char(modelName);
resultsName = '08 RESULTS - SCOPES & LOGGING';
if ~isempty(find_system(modelName,'SearchDepth',1,'Name',resultsName))
    stageSummary = split_simscape_electrical_stages(modelName);
    summary = struct('AlreadySimplified',true,'PublishedSignals',0, ...
        'GroupedMonitors',0,'ControlStages',0, ...
        'ElectricalStages',stageSummary.StageCount, ...
        'DeletedDanglingBranches',stageSummary.DeletedDanglingBranches);
    return;
end

load_system(modelName);

%% Replace repeated long monitor branches with reusable signal tags.
scopes = find_system(modelName,'SearchDepth',1,'BlockType','Scope');
loggers = find_system(modelName,'SearchDepth',1,'BlockType','ToWorkspace');
sinks = [scopes(:); loggers(:)];
routes = struct('Sink',{},'SinkPort',{},'SourcePort',{}, ...
    'SourceBlock',{},'SourcePortNumber',{},'LineName',{},'Tag',{});

for sinkIndex = 1:numel(sinks)
    lineHandles = get_param(sinks{sinkIndex},'LineHandles');
    for portIndex = 1:numel(lineHandles.Inport)
        lineHandle = lineHandles.Inport(portIndex);
        if lineHandle <= 0
            continue;
        end
        sourcePort = get_param(lineHandle,'SrcPortHandle');
        sourceBlock = get_param(sourcePort,'Parent');
        sourcePortNumber = get_param(sourcePort,'PortNumber');
        routeIndex = numel(routes) + 1;
        routes(routeIndex).Sink = sinks{sinkIndex};
        routes(routeIndex).SinkPort = portIndex;
        routes(routeIndex).SourcePort = sourcePort;
        routes(routeIndex).SourceBlock = sourceBlock;
        routes(routeIndex).SourcePortNumber = sourcePortNumber;
        routes(routeIndex).LineName = get_param(lineHandle,'Name');
    end
end

sourceKeys = strings(numel(routes),1);
for routeIndex = 1:numel(routes)
    sourceKeys(routeIndex) = sprintf('%.17g_%d', ...
        routes(routeIndex).SourcePort, ...
        routes(routeIndex).SourcePortNumber);
end
[uniqueKeys,firstRoute] = unique(sourceKeys,'stable');

usedTags = strings(0,1);
gotoPaths = strings(numel(uniqueKeys),1);
for keyIndex = 1:numel(uniqueKeys)
    route = routes(firstRoute(keyIndex));
    sourceName = get_param(route.SourceBlock,'Name');
    tag = makeTag(sourceName,route.SourcePortNumber,usedTags);
    usedTags(end+1,1) = tag; %#ok<AGROW>
    matchingRoutes = find(sourceKeys == uniqueKeys(keyIndex));
    for matchingIndex = matchingRoutes(:)'
        routes(matchingIndex).Tag = char(tag);
    end

    sourcePosition = get_param(route.SourceBlock,'Position');
    gotoName = uniqueBlockName(modelName,['Publish ' char(tag)]);
    gotoPath = [modelName '/' gotoName];
    add_block('simulink/Signal Routing/Goto',gotoPath, ...
        'GotoTag',char(tag),'TagVisibility','global', ...
        'ShowName','off','BackgroundColor','white', ...
        'ForegroundColor','blue', ...
        'Position',[sourcePosition(3)+8 sourcePosition(2) ...
        sourcePosition(3)+88 sourcePosition(2)+18]);
    gotoPaths(keyIndex) = string(gotoPath);
end

% Remove only the destination branches after all source information is saved.
for routeIndex = 1:numel(routes)
    sinkPortHandles = get_param(routes(routeIndex).Sink,'PortHandles');
    lineHandle = get_param(sinkPortHandles.Inport(routes(routeIndex).SinkPort), ...
        'Line');
    if lineHandle > 0
        delete_line(lineHandle);
    end
end

% Connect one short branch from each measured source to its publisher.
for keyIndex = 1:numel(uniqueKeys)
    route = routes(firstRoute(keyIndex));
    add_line(modelName,route.SourcePort, ...
        get_param(gotoPaths(keyIndex),'PortHandles').Inport, ...
        'autorouting','on');
end

% Add local subscribers beside every scope/logger input.
fromPaths = strings(numel(routes),1);
for routeIndex = 1:numel(routes)
    route = routes(routeIndex);
    sinkPosition = get_param(route.Sink,'Position');
    fromName = uniqueBlockName(modelName,sprintf('Read %s %02d', ...
        route.Tag,routeIndex));
    fromPath = [modelName '/' fromName];
    y = sinkPosition(2) + 4 + 22*(route.SinkPort-1);
    add_block('simulink/Signal Routing/From',fromPath, ...
        'GotoTag',route.Tag,'ShowName','off', ...
        'BackgroundColor','white','ForegroundColor','blue', ...
        'Position',[sinkPosition(1)-130 y sinkPosition(1)-20 y+16]);
    newLine = add_line(modelName,[fromName '/1'], ...
        [get_param(route.Sink,'Name') '/' num2str(route.SinkPort)], ...
        'autorouting','on');
    if ~isempty(route.LineName)
        set_param(newLine,'Name',route.LineName);
    end
    fromPaths(routeIndex) = string(fromPath);
end

monitorHandles = [cellfun(@(path)get_param(path,'Handle'),sinks); ...
    arrayfun(@(path)get_param(path,'Handle'),fromPaths)];
resultsHandle = groupBlocks(modelName,monitorHandles,resultsName);
set_param(resultsHandle,'Position',[1770 760 2050 870], ...
    'BackgroundColor','white','ForegroundColor','blue', ...
    'AttributesFormatString','8 ordered scopes + all verification logs');
layoutResults(getfullname(resultsHandle));

%% Collapse only pure-Simulink controllers into virtual stage subsystems.
stageDefinitions = {
    '01 INPUTS - PV MPPT & BOOST CONTROL', {
        'Scenario Profile','Scenario Demux','MPPT Input', ...
        'MPPT P and O Controller','Averaged Boost Input', ...
        'Averaged Boost Feedback Delay','Averaged Boost Controller', ...
        'Averaged Boost Outputs'};
    '02 LIGHTNING COMMAND', {
        'Indirect Lightning 8-20 us Profile', ...
        'Configured Lightning Current','Configured Lightning Voltage', ...
        'Selected Norton Current'};
    '05 SUPERCAP CONTROL', {
        'SC Bus Measurement Delay','SC Controller Input', ...
        'SC Supervisory Controller','SC Controller Outputs', ...
        'SC Physical Direction'};
    '06 RELAY PROTECTION CONTROL', {
        'Warning Voltage Threshold','Emergency Trip Voltage Threshold', ...
        'Safe Recovery Voltage Threshold','Protection Input', ...
        'Protection State Machine','Protection Outputs','Relay Timing', ...
        'Relay Timing Outputs'};
    '07 INVERTER CONTROL', {
        'AC Modulation Reference','Inverter Soft Start Ramp', ...
        'Soft Start Limit','Soft Started Modulation','AC Voltage Command'}
    };

stagePositions = [40 40 310 130; 370 40 600 130; ...
    1110 40 1340 130; 1400 40 1660 130; 1720 40 1950 130];
createdStages = 0;
if options.GroupControlStages
    for stageIndex = 1:size(stageDefinitions,1)
        blockNames = stageDefinitions{stageIndex,2};
        paths = cellfun(@(name)[modelName '/' name],blockNames, ...
            'UniformOutput',false);
        exists = cellfun(@(path)getSimulinkBlockHandle(path) > 0,paths);
        if ~all(exists)
            missing = strjoin(blockNames(~exists),', ');
            error('Missing blocks required for %s: %s', ...
                stageDefinitions{stageIndex,1},missing);
        end
        handles = cellfun(@(path)get_param(path,'Handle'),paths);
        stageHandle = groupBlocks(modelName,handles, ...
            stageDefinitions{stageIndex,1});
        set_param(stageHandle,'Position',stagePositions(stageIndex,:), ...
            'BackgroundColor','white','ForegroundColor','blue');
        createdStages = createdStages + 1;
    end
end

% Keep the settings panel prominent and use neutral colors throughout.
settings = [modelName '/USER SETTINGS - DOUBLE CLICK'];
if getSimulinkBlockHandle(settings) > 0
    set_param(settings,'Position',[40 180 310 320], ...
        'BackgroundColor','white','ForegroundColor','blue');
end

plantBlockCount = 0;
hiddenFeedbackRoutes = 0;
stageSummary = struct('StageCount',0,'DeletedDanglingBranches',0);
if options.GroupControlStages
    [~,plantBlockCount] = groupElectricalPlant(modelName);
    groupDerivedMetrics(modelName);
    moveRootPublishersIntoSourceStages(modelName);
    hiddenFeedbackRoutes = hideNonPlantRoutes(modelName, ...
        '03-07 SIMSCAPE ELECTRICAL PLANT');
    rebuildRootCommandLines(modelName,'03-07 SIMSCAPE ELECTRICAL PLANT');
    removeUnusedInterfacePorts(modelName);
    stageSummary = split_simscape_electrical_stages(modelName);
end

summary = struct('AlreadySimplified',false, ...
    'PublishedSignals',numel(uniqueKeys), ...
    'GroupedMonitors',numel(sinks), ...
    'ControlStages',createdStages, ...
    'PlantBlocks',plantBlockCount, ...
    'HiddenFeedbackRoutes',hiddenFeedbackRoutes, ...
    'ElectricalStages',stageSummary.StageCount, ...
    'DeletedDanglingBranches',stageSummary.DeletedDanglingBranches);
end

function subsystemHandle = groupBlocks(parent,blockHandles,name)
before = find_system(parent,'SearchDepth',1,'FindAll','on', ...
    'BlockType','SubSystem');
Simulink.BlockDiagram.createSubsystem(blockHandles);
after = find_system(parent,'SearchDepth',1,'FindAll','on', ...
    'BlockType','SubSystem');
newHandles = setdiff(after,before);
assert(isscalar(newHandles),'Expected exactly one new subsystem.');
subsystemHandle = newHandles;
set_param(subsystemHandle,'Name',name);
end

function [plantHandle,blockCount] = groupElectricalPlant(modelName)
topBlocks = find_system(modelName,'SearchDepth',1,'Type','Block');
physicalPaths = strings(0,1);
for blockIndex = 1:numel(topBlocks)
    try
        reference = get_param(topBlocks{blockIndex},'ReferenceBlock');
    catch
        reference = '';
    end
    if ~isempty(reference)
        physicalPaths(end+1,1) = string(topBlocks{blockIndex}); %#ok<AGROW>
    end
end
physicalHandles = arrayfun(@(path)get_param(path,'Handle'),physicalPaths);

publishers = find_system(modelName,'SearchDepth',1,'BlockType','Goto');
publisherHandles = zeros(0,1);
for publisherIndex = 1:numel(publishers)
    lines = get_param(publishers{publisherIndex},'LineHandles');
    if lines.Inport <= 0
        continue;
    end
    sourceBlock = get_param(lines.Inport,'SrcBlockHandle');
    if any(physicalHandles == sourceBlock)
        publisherHandles(end+1,1) = ...
            get_param(publishers{publisherIndex},'Handle'); %#ok<AGROW>
    end
end

blockCount = numel(physicalHandles);
plantHandle = groupBlocks(modelName, ...
    [physicalHandles(:); publisherHandles(:)], ...
    '03-07 SIMSCAPE ELECTRICAL PLANT');
set_param(plantHandle,'BackgroundColor','white','ForegroundColor','blue', ...
    'AttributesFormatString', ...
    'PV -> surge source -> SPD1 -> SPD2 -> DC bus -> SC -> relay -> inverter');
end

function metricsHandle = groupDerivedMetrics(modelName)
metricNames = {'PV Power','SC Physical Power','SC Absorbed Power', ...
    'SC Absorbed Energy','Protected Residual Power', ...
    'Protection Voltage Reduction'};
metricPaths = cellfun(@(name)[modelName '/' name],metricNames, ...
    'UniformOutput',false);
metricHandles = cellfun(@(path)get_param(path,'Handle'),metricPaths);

publishers = find_system(modelName,'SearchDepth',1,'BlockType','Goto');
publisherHandles = zeros(0,1);
for publisherIndex = 1:numel(publishers)
    lines = get_param(publishers{publisherIndex},'LineHandles');
    if lines.Inport <= 0
        continue;
    end
    sourceBlock = get_param(lines.Inport,'SrcBlockHandle');
    if any(metricHandles == sourceBlock)
        publisherHandles(end+1,1) = ...
            get_param(publishers{publisherIndex},'Handle'); %#ok<AGROW>
    end
end

metricsHandle = groupBlocks(modelName, ...
    [metricHandles(:); publisherHandles(:)],'DERIVED METRICS');
set_param(metricsHandle,'BackgroundColor','white','ForegroundColor','blue');
end

function moveRootPublishersIntoSourceStages(modelName)
publishers = find_system(modelName,'SearchDepth',1,'BlockType','Goto');
for publisherIndex = 1:numel(publishers)
    publisher = publishers{publisherIndex};
    tag = get_param(publisher,'GotoTag');
    lines = get_param(publisher,'LineHandles');
    if lines.Inport <= 0
        continue;
    end
    sourcePort = get_param(lines.Inport,'SrcPortHandle');
    sourceStage = get_param(sourcePort,'Parent');
    if ~strcmp(get_param(sourceStage,'BlockType'),'SubSystem')
        continue;
    end
    portNumber = get_param(sourcePort,'PortNumber');
    outport = findPortBlock(sourceStage,'Outport',portNumber);
    innerLines = get_param(outport,'LineHandles');
    innerSource = get_param(innerLines.Inport,'SrcPortHandle');
    sourceBlock = get_param(innerSource,'Parent');
    position = get_param(sourceBlock,'Position');
    publisherName = uniqueBlockName(sourceStage,['Publish ' tag]);
    newPublisher = [sourceStage '/' publisherName];
    add_block('simulink/Signal Routing/Goto',newPublisher, ...
        'GotoTag',tag,'TagVisibility','global','ShowName','off', ...
        'BackgroundColor','white','ForegroundColor','blue', ...
        'Position',[position(3)+8 position(2) ...
        position(3)+88 position(2)+18]);
    add_line(sourceStage,innerSource, ...
        get_param(newPublisher,'PortHandles').Inport,'autorouting','on');
    delete_block(publisher);
end
end

function hiddenCount = hideNonPlantRoutes(modelName,plantName)
subsystems = find_system(modelName,'SearchDepth',1,'BlockType','SubSystem');
allRoutes = struct('SourceStage',{},'SourcePort',{}, ...
    'DestinationStage',{},'DestinationPort',{});
hiddenRoutes = allRoutes;
for destinationIndex = 1:numel(subsystems)
    destination = subsystems{destinationIndex};
    destinationPorts = get_param(destination,'PortHandles');
    for portIndex = 1:numel(destinationPorts.Inport)
        line = get_param(destinationPorts.Inport(portIndex),'Line');
        if line <= 0
            continue;
        end
        sourcePort = get_param(line,'SrcPortHandle');
        route.SourceStage = get_param(sourcePort,'Parent');
        route.SourcePort = get_param(sourcePort,'PortNumber');
        route.DestinationStage = destination;
        route.DestinationPort = portIndex;
        allRoutes(end+1) = route; %#ok<AGROW>
        if ~strcmp(get_param(destination,'Name'),plantName)
            hiddenRoutes(end+1) = route; %#ok<AGROW>
        end
    end
end
hiddenCount = numel(hiddenRoutes);
if hiddenCount == 0
    return;
end

hiddenKeys = arrayfun(@routeKey,hiddenRoutes);
visibleRoutes = allRoutes(arrayfun(@(route) ...
    strcmp(get_param(route.DestinationStage,'Name'),plantName),allRoutes));
visibleKeys = arrayfun(@routeKey,visibleRoutes);
[uniqueKeys,firstRoute] = unique(hiddenKeys,'stable');
tags = containers.Map('KeyType','char','ValueType','char');
sourceOutports = cell(numel(uniqueKeys),1);

for keyIndex = 1:numel(uniqueKeys)
    route = hiddenRoutes(firstRoute(keyIndex));
    outport = findPortBlock(route.SourceStage,'Outport',route.SourcePort);
    lines = get_param(outport,'LineHandles');
    innerSource = get_param(lines.Inport,'SrcPortHandle');
    sourceBlock = get_param(innerSource,'Parent');
    sourcePosition = get_param(sourceBlock,'Position');
    tag = sprintf('FLOW_%03d_%s',keyIndex,regexprep( ...
        upper(get_param(sourceBlock,'Name')),'[^A-Z0-9]+','_'));
    tag = tag(1:min(numel(tag),48));
    publisher = [route.SourceStage '/' uniqueBlockName( ...
        route.SourceStage,['Route ' tag])];
    add_block('simulink/Signal Routing/Goto',publisher, ...
        'GotoTag',tag,'TagVisibility','global','ShowName','off', ...
        'BackgroundColor','white','ForegroundColor','blue', ...
        'Position',[sourcePosition(3)+8 sourcePosition(2) ...
        sourcePosition(3)+88 sourcePosition(2)+18]);
    add_line(route.SourceStage,innerSource, ...
        get_param(publisher,'PortHandles').Inport,'autorouting','on');
    tags(char(uniqueKeys(keyIndex))) = tag;
    sourceOutports{keyIndex} = outport;
end

% Descending destination port order prevents automatic renumbering from
% invalidating a port that has not yet been processed.
destinationHandles = arrayfun(@(route)get_param( ...
    route.DestinationStage,'Handle'),hiddenRoutes);
[~,order] = sortrows([destinationHandles(:) -[hiddenRoutes.DestinationPort]']);
hiddenRoutes = hiddenRoutes(order);
for routeIndex = 1:numel(hiddenRoutes)
    route = hiddenRoutes(routeIndex);
    tag = tags(char(routeKey(route)));
    inport = findPortBlock(route.DestinationStage,'Inport', ...
        route.DestinationPort);
    lines = get_param(inport,'LineHandles');
    destinationPorts = zeros(0,1);
    signalName = '';
    if lines.Outport > 0
        destinationPorts = get_param(lines.Outport,'DstPortHandle');
        signalName = get_param(lines.Outport,'Name');
        delete_line(lines.Outport);
    end
    position = get_param(inport,'Position');
    subscriber = [route.DestinationStage '/' uniqueBlockName( ...
        route.DestinationStage,['Read ' tag])];
    add_block('simulink/Signal Routing/From',subscriber, ...
        'GotoTag',tag,'ShowName','off','BackgroundColor','white', ...
        'ForegroundColor','blue','Position',position);
    fromPort = get_param(subscriber,'PortHandles').Outport;
    for destinationIndex = 1:numel(destinationPorts)
        newLine = add_line(route.DestinationStage,fromPort, ...
            destinationPorts(destinationIndex),'autorouting','on');
        if destinationIndex == 1 && ~isempty(signalName)
            set_param(newLine,'Name',signalName);
        end
    end
    rootPorts = get_param(route.DestinationStage,'PortHandles');
    if route.DestinationPort <= numel(rootPorts.Inport)
        rootLine = get_param(rootPorts.Inport(route.DestinationPort),'Line');
        if rootLine > 0
            delete_line(rootLine);
        end
    end
    delete_block(inport);
end

for keyIndex = 1:numel(uniqueKeys)
    if ~any(visibleKeys == uniqueKeys(keyIndex)) && ...
            getSimulinkBlockHandle(sourceOutports{keyIndex}) > 0
        delete_block(sourceOutports{keyIndex});
    end
end
end

function removeUnusedInterfacePorts(modelName)
subsystems = find_system(modelName,'SearchDepth',1,'BlockType','SubSystem');
for subsystemIndex = 1:numel(subsystems)
    subsystem = subsystems{subsystemIndex};
    removeUnusedPortType(subsystem,'Inport');
    removeUnusedPortType(subsystem,'Outport');
end
end

function rebuildRootCommandLines(modelName,plantName)
plant = [modelName '/' plantName];
plantPorts = get_param(plant,'PortHandles');
routes = struct('Source',{},'Destination',{},'Name',{});
for portIndex = 1:numel(plantPorts.Inport)
    line = get_param(plantPorts.Inport(portIndex),'Line');
    assert(line > 0,'Electrical plant input %d is disconnected.',portIndex);
    routes(portIndex).Source = get_param(line,'SrcPortHandle');
    routes(portIndex).Destination = plantPorts.Inport(portIndex);
    routes(portIndex).Name = get_param(line,'Name');
end

rootLines = find_system(modelName,'SearchDepth',1,'FindAll','on','Type','line');
if ~isempty(rootLines)
    delete_line(rootLines);
end
for routeIndex = 1:numel(routes)
    line = add_line(modelName,routes(routeIndex).Source, ...
        routes(routeIndex).Destination,'autorouting','on');
    if ~isempty(routes(routeIndex).Name)
        set_param(line,'Name',routes(routeIndex).Name);
    end
end
end

function removeUnusedPortType(subsystem,portType)
while true
    rootPorts = get_param(subsystem,'PortHandles');
    if strcmp(portType,'Inport')
        handles = rootPorts.Inport;
    else
        handles = rootPorts.Outport;
    end
    unused = find(arrayfun(@(port)get_param(port,'Line') <= 0,handles));
    if isempty(unused)
        break;
    end
    portNumber = max(unused);
    block = findPortBlock(subsystem,portType,portNumber);
    if isempty(block) || getSimulinkBlockHandle(block) <= 0
        break;
    end
    delete_block(block);
end
end

function block = findPortBlock(subsystem,portType,portNumber)
blocks = find_system(subsystem,'SearchDepth',1,'LookUnderMasks','all', ...
    'BlockType',portType);
block = '';
for blockIndex = 1:numel(blocks)
    if str2double(get_param(blocks{blockIndex},'Port')) == portNumber
        block = blocks{blockIndex};
        return;
    end
end
end

function key = routeKey(route)
key = string(get_param(route.SourceStage,'Name')) + "#" + route.SourcePort;
end

function layoutResults(resultsPath)
scopes = find_system(resultsPath,'SearchDepth',1,'BlockType','Scope');
loggers = find_system(resultsPath,'SearchDepth',1,'BlockType','ToWorkspace');

for scopeIndex = 1:numel(scopes)
    row = mod(scopeIndex-1,4);
    column = floor((scopeIndex-1)/4);
    x = 250 + 480*column;
    y = 45 + 145*row;
    set_param(scopes{scopeIndex},'Position',[x y x+230 y+95]);
    placeSubscribers(scopes{scopeIndex},x-145,y);
end

for loggerIndex = 1:numel(loggers)
    row = mod(loggerIndex-1,8);
    column = floor((loggerIndex-1)/8);
    x = 250 + 430*column;
    y = 670 + 65*row;
    set_param(loggers{loggerIndex},'Position',[x y x+190 y+32]);
    placeSubscribers(loggers{loggerIndex},x-145,y+7);
end
end

function placeSubscribers(sinkPath,x,y)
lineHandles = get_param(sinkPath,'LineHandles');
for portIndex = 1:numel(lineHandles.Inport)
    if lineHandles.Inport(portIndex) <= 0
        continue;
    end
    sourceHandle = get_param(lineHandles.Inport(portIndex),'SrcBlockHandle');
    set_param(sourceHandle,'Position', ...
        [x y+22*(portIndex-1) x+110 y+16+22*(portIndex-1)]);
end
end

function tag = makeTag(sourceName,portNumber,usedTags)
base = upper(regexprep(sourceName,'[^A-Za-z0-9]+','_'));
base = regexprep(base,'^_+|_+$','');
if strlength(base) > 34
    base = extractBefore(base,35);
end
tag = "MON_" + base + "_P" + portNumber;
candidate = tag;
suffix = 2;
while any(usedTags == candidate)
    candidate = tag + "_" + suffix;
    suffix = suffix + 1;
end
tag = candidate;
end

function name = uniqueBlockName(parent,preferred)
name = preferred;
suffix = 2;
while getSimulinkBlockHandle([parent '/' name]) > 0
    name = sprintf('%s %d',preferred,suffix);
    suffix = suffix + 1;
end
end
