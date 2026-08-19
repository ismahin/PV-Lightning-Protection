function summary = split_simscape_electrical_stages(modelName)
%SPLIT_SIMSCAPE_ELECTRICAL_STAGES Expose the physical plant as eight stages.
%   This is a presentation-only refactor. Simscape components and their
%   conserving connections are retained, while sparse Demux blocks and
%   dangling visual branches are removed.

arguments
    modelName (1,1) string
end

modelName = char(modelName);
load_system(modelName);

combinedPlant = [modelName '/03-07 SIMSCAPE ELECTRICAL PLANT'];
firstStage = [modelName '/03A PV ARRAY'];
if getSimulinkBlockHandle(combinedPlant) > 0
    Simulink.BlockDiagram.expandSubsystem(combinedPlant,'CreateArea','off');
    deleteUnusedReference(modelName,'Electrical Reference 7');
elseif getSimulinkBlockHandle(firstStage) > 0
    replaceSparseDemuxes(modelName);
    danglingCount = deleteDanglingSignalBranches(modelName);
    removeDisconnectedStagePorts(modelName);
    labelStagePorts(modelName);
    layoutIndividualStages(modelName);
    summary = collectSummary(modelName,danglingCount,true);
    return;
else
    error('No combined or previously split electrical plant was found.');
end

stageDefinitions = {
    '03A PV ARRAY', {
        'Irradiance to PS','PV Array - Solar Cell','PV Current Sensor', ...
        'PV Voltage Sensor','PV Input Capacitor', ...
        'PV-side Converter Current Draw','PV Draw Current to PS', ...
        'PV Solver Configuration','Electrical Reference', ...
        'PV Voltage to Simulink','PV Current to Simulink'};
    '03B SURGE SOURCE & CABLE', {
        'Lightning Current to PS','Selectable Lightning Injection Source', ...
        'Injection Source Shunt Resistance','Injected Current Sensor', ...
        'Injected Current to Simulink','Injection Voltage Sensor', ...
        'Injection Voltage to Simulink','Surge Source Inductance', ...
        'DC Cable Resistance','DC Cable Inductance','Surge Blocking Diode', ...
        'Surge Current Sensor','Surge Current to Simulink', ...
        'Electrical Reference 3'};
    '03C SPD1 PRIMARY PROTECTION', {
        'SPD Current Sensor','SPD Lead Inductance','SPD MOV Varistor', ...
        'SPD Ground Resistance','SPD Ground Inductance', ...
        'SPD Current to Simulink','SPD1 Voltage Sensor', ...
        'SPD1 Voltage to Simulink','Electrical Reference 4'};
    '03D SPD2 COORDINATED PROTECTION', {
        'SPD2 Current Sensor','SPD2 Lead Inductance','SPD2 MOV Varistor', ...
        'SPD2 Ground Resistance','SPD2 Ground Inductance', ...
        'SPD2 Current to Simulink','SPD2 Output Current Sensor', ...
        'SPD2 Coordination Inductance','SPD2 Coordination Resistance', ...
        'SPD2 Output Current to Simulink','SPD2 Voltage Sensor', ...
        'SPD2 Voltage to Simulink','Electrical Reference 6'};
    '03E PROTECTED DC BUS', {
        'Bus-side Converter Current Injection','Bus Injection Current to PS', ...
        'DC Link Capacitor','DC Bus Voltage Sensor', ...
        'Bus Voltage to Simulink','Electrical Reference 2', ...
        'Solver Configuration'};
    '03F SUPERCAPACITOR BANK', {
        'SC Bidirectional Interface','SC Command to PS','SC Current Sensor', ...
        'SC Converter Inductance','SC Converter Path Resistance', ...
        'Supercapacitor Bank','SC Voltage Sensor','SC Voltage to Simulink', ...
        'SC Current to Simulink','Electrical Reference 5'};
    '03G RELAY & DC LOAD', {
        'Relay State to PS','Protected Load Contactor', ...
        'Protected DC Inverter Load'};
    '03H INVERTER & AC LOAD', {
        'Modulation to PS','Averaged Microinverter AC Source', ...
        'AC Current Sensor','Microinverter AC Load','AC Voltage Sensor', ...
        'AC Voltage to Simulink','AC Current to Simulink', ...
        'Electrical Reference 8','AC Solver Configuration'}
    };

for stageIndex = 1:size(stageDefinitions,1)
    stageName = stageDefinitions{stageIndex,1};
    blockNames = stageDefinitions{stageIndex,2};
    handles = getNamedRootHandles(modelName,blockNames);
    handles = [handles; sourcePublisherHandles(modelName,handles)]; %#ok<AGROW>
    stageHandle = groupBlocks(modelName,unique(handles),stageName);
    set_param(stageHandle,'BackgroundColor','white', ...
        'ForegroundColor','blue','ShowPortLabels','FromPortIcon');
    disableContentPreview(stageHandle);
end

replaceSparseDemuxes(modelName);
danglingCount = deleteDanglingSignalBranches(modelName);
removeDisconnectedStagePorts(modelName);
labelStagePorts(modelName);
layoutIndividualStages(modelName);
summary = collectSummary(modelName,danglingCount,false);
end

function handles = getNamedRootHandles(modelName,blockNames)
rootBlocks = find_system(modelName,'SearchDepth',1,'Type','Block');
rootBlocks = rootBlocks(~strcmp(rootBlocks,modelName));
rootNames = cellfun(@(path)normalizeName(get_param(path,'Name')), ...
    rootBlocks,'UniformOutput',false);
handles = zeros(numel(blockNames),1);
missing = strings(0,1);
for blockIndex = 1:numel(blockNames)
    wanted = normalizeName(blockNames{blockIndex});
    match = find(strcmp(rootNames,wanted),1);
    if isempty(match)
        missing(end+1,1) = string(blockNames{blockIndex}); %#ok<AGROW>
    else
        handles(blockIndex) = get_param(rootBlocks{match},'Handle');
    end
end
if ~isempty(missing)
    error('Missing electrical-stage blocks: %s',strjoin(missing,', '));
end
end

function name = normalizeName(name)
name = regexprep(strtrim(name),'\s+',' ');
end

function handles = sourcePublisherHandles(modelName,sourceHandles)
publishers = find_system(modelName,'SearchDepth',1,'BlockType','Goto');
handles = zeros(0,1);
for publisherIndex = 1:numel(publishers)
    lineHandles = get_param(publishers{publisherIndex},'LineHandles');
    if lineHandles.Inport <= 0
        continue;
    end
    sourceBlock = get_param(lineHandles.Inport,'SrcBlockHandle');
    if any(sourceHandles == sourceBlock)
        handles(end+1,1) = get_param(publishers{publisherIndex},'Handle'); %#ok<AGROW>
    end
end
end

function subsystemHandle = groupBlocks(parent,blockHandles,name)
before = find_system(parent,'SearchDepth',1,'FindAll','on', ...
    'BlockType','SubSystem');
Simulink.BlockDiagram.createSubsystem(blockHandles);
after = find_system(parent,'SearchDepth',1,'FindAll','on', ...
    'BlockType','SubSystem');
newHandles = setdiff(after,before);
assert(isscalar(newHandles),'Expected exactly one new subsystem for %s.',name);
subsystemHandle = newHandles;
set_param(subsystemHandle,'Name',name);
end

function replaceSparseDemuxes(modelName)
replaceDemux([modelName '/01 INPUTS - PV MPPT & BOOST CONTROL'], ...
    'Scenario Demux',[1 4 5 6 7],9, ...
    {'Irradiance','Relay Disturbance','Ground Fault', ...
    'Supercap Enable','Emergency Stop'});
replaceDemux([modelName '/05 SUPERCAP CONTROL'], ...
    'SC Controller Outputs',5,14,{'SC Current Command'});
replaceDemux([modelName '/06 RELAY PROTECTION CONTROL'], ...
    'Protection Outputs',[1 2],13,{'Relay Command','Controller State'});
replaceDemux([modelName '/06 RELAY PROTECTION CONTROL'], ...
    'Relay Timing Outputs',1,3,{'Physical Relay State'});
end

function replaceDemux(parent,demuxName,indices,inputWidth,selectorNames)
demux = [parent '/' demuxName];
if getSimulinkBlockHandle(demux) <= 0
    return;
end

portHandles = get_param(demux,'PortHandles');
inputLine = get_param(portHandles.Inport,'Line');
assert(inputLine > 0,'%s has no input signal.',demux);
sourcePort = get_param(inputLine,'SrcPortHandle');
oldPosition = get_param(demux,'Position');

destinations = cell(numel(indices),1);
signalNames = cell(numel(indices),1);
attachedLines = inputLine;
for selectionIndex = 1:numel(indices)
    outputLine = get_param(portHandles.Outport(indices(selectionIndex)),'Line');
    assert(outputLine > 0,'Required output %d of %s is disconnected.', ...
        indices(selectionIndex),demux);
    destinationPorts = get_param(outputLine,'DstPortHandle');
    destinations{selectionIndex} = destinationPorts(destinationPorts > 0);
    assert(~isempty(destinations{selectionIndex}), ...
        'Required output %d of %s has no destination.', ...
        indices(selectionIndex),demux);
    signalNames{selectionIndex} = get_param(outputLine,'Name');
    attachedLines(end+1,1) = outputLine; %#ok<AGROW>
end

allOutputLines = arrayfun(@(port)get_param(port,'Line'),portHandles.Outport);
usedOutputLines = allOutputLines(allOutputLines > 0);
attachedLines = unique([attachedLines(:); usedOutputLines(:)]);
for lineIndex = 1:numel(attachedLines)
    if ishandle(attachedLines(lineIndex))
        delete_line(attachedLines(lineIndex));
    end
end
delete_block(demux);
for selectionIndex = 1:numel(indices)
    selectorName = uniqueBlockName(parent,selectorNames{selectionIndex});
    selector = [parent '/' selectorName];
    y = oldPosition(2) + 42*(selectionIndex-1);
    add_block('simulink/Signal Routing/Selector',selector, ...
        'NumberOfDimensions','1','IndexMode','One-based', ...
        'IndexOptionArray',{'Index vector (dialog)'}, ...
        'IndexParamArray',{num2str(indices(selectionIndex))}, ...
        'InputPortWidth',num2str(inputWidth), ...
        'Position',[oldPosition(1) y oldPosition(1)+95 y+28]);
    selectorPorts = get_param(selector,'PortHandles');
    add_line(parent,sourcePort,selectorPorts.Inport,'autorouting','on');
    for destinationIndex = 1:numel(destinations{selectionIndex})
        newLine = add_line(parent,selectorPorts.Outport, ...
            destinations{selectionIndex}(destinationIndex),'autorouting','on');
        if destinationIndex == 1 && ~isempty(signalNames{selectionIndex})
            set_param(newLine,'Name',signalNames{selectionIndex});
        end
    end
end
end

function count = deleteDanglingSignalBranches(modelName)
count = 0;
systems = [{modelName}; find_system(modelName,'FollowLinks','off', ...
    'LookUnderMasks','all','BlockType','SubSystem')];
for systemIndex = 1:numel(systems)
    lines = find_system(systems{systemIndex},'SearchDepth',1, ...
        'FindAll','on','Type','line');
    for lineIndex = 1:numel(lines)
        if ~ishandle(lines(lineIndex))
            continue;
        end
        sourcePort = get_param(lines(lineIndex),'SrcPortHandle');
        destinationPorts = get_param(lines(lineIndex),'DstPortHandle');
        destinationPorts = destinationPorts(destinationPorts > 0);
        isSimulinkSignal = false;
        if ~isempty(sourcePort) && sourcePort > 0
            isSimulinkSignal = strcmp(get_param(sourcePort,'PortType'),'outport');
        end
        if isSimulinkSignal && isempty(destinationPorts)
            delete_line(lines(lineIndex));
            count = count + 1;
        end
    end
end
end

function removeDisconnectedStagePorts(modelName)
stageNames = electricalStageNames();
for stageIndex = 1:numel(stageNames)
    stage = [modelName '/' stageNames{stageIndex}];
    disableContentPreview(stage);
    removeDisconnectedPortType(stage,'Outport');
    removeDisconnectedPortType(stage,'Inport');
end
end

function deleteUnusedReference(modelName,blockName)
block = [modelName '/' blockName];
if getSimulinkBlockHandle(block) <= 0
    return;
end
ports = get_param(block,'PortHandles');
physicalPorts = [ports.LConn(:); ports.RConn(:)];
if all(arrayfun(@(port)get_param(port,'Line') <= 0,physicalPorts))
    delete_block(block);
end
end

function disableContentPreview(block)
try
    set_param(block,'ContentPreviewEnabled','off');
catch
    % Content previews are unavailable in older Simulink releases.
end
end

function removeDisconnectedPortType(stage,portType)
while true
    stagePorts = get_param(stage,'PortHandles');
    if strcmp(portType,'Outport')
        outerPorts = stagePorts.Outport;
    else
        outerPorts = stagePorts.Inport;
    end
    disconnected = zeros(0,1);
    for portIndex = 1:numel(outerPorts)
        lineHandle = get_param(outerPorts(portIndex),'Line');
        connected = false;
        if lineHandle > 0
            if strcmp(portType,'Outport')
                peerPorts = get_param(lineHandle,'DstPortHandle');
            else
                peerPorts = get_param(lineHandle,'SrcPortHandle');
            end
            connected = any(peerPorts > 0);
        end
        if ~connected
            disconnected(end+1,1) = portIndex; %#ok<AGROW>
        end
    end
    if isempty(disconnected)
        return;
    end
    portNumber = max(disconnected);
    internalPorts = find_system(stage,'SearchDepth',1, ...
        'BlockType',portType);
    target = '';
    for internalIndex = 1:numel(internalPorts)
        if str2double(get_param(internalPorts{internalIndex},'Port')) == portNumber
            target = internalPorts{internalIndex};
            break;
        end
    end
    if isempty(target)
        return;
    end
    delete_block(target);
end
end

function labelStagePorts(modelName)
stageNames = electricalStageNames();
commandLabels = containers.Map( ...
    {'Irradiance to PS','PV Draw Current to PS', ...
    'Lightning Current to PS','Bus Injection Current to PS', ...
    'SC Command to PS','Relay State to PS','Modulation to PS'}, ...
    {'Irradiance (W/m^2)','PV draw current (A)', ...
    'Lightning current (A)','Boost injection current (A)', ...
    'SC current command (A)','Relay state command', ...
    'AC voltage command (V)'});

for stageIndex = 1:numel(stageNames)
    stage = [modelName '/' stageNames{stageIndex}];
    inports = find_system(stage,'SearchDepth',1,'BlockType','Inport');
    for portIndex = 1:numel(inports)
        lineHandles = get_param(inports{portIndex},'LineHandles');
        destinationPorts = get_param(lineHandles.Outport,'DstPortHandle');
        destinationPorts = destinationPorts(destinationPorts > 0);
        if isempty(destinationPorts)
            continue;
        end
        destination = get_param(destinationPorts(1),'Parent');
        destinationName = get_param(destination,'Name');
        if isKey(commandLabels,destinationName)
            set_param(inports{portIndex},'Name',commandLabels(destinationName));
        end
    end
end

% Conserving-port labels state the neighboring functional stage. This is
% more useful at the top level than generated names such as Connection Port.
for stageIndex = 1:numel(stageNames)
    stage = [modelName '/' stageNames{stageIndex}];
    pmPorts = find_system(stage,'SearchDepth',1,'BlockType','PMIOPort');
    for portIndex = 1:numel(pmPorts)
        set_param(pmPorts{portIndex},'Name',sprintf('Electrical link %d',portIndex));
    end
end
end

function layoutIndividualStages(modelName)
positions = {
    '01 INPUTS - PV MPPT & BOOST CONTROL',[40 80 360 280];
    'USER SETTINGS - DOUBLE CLICK',[40 420 360 550];
    '03A PV ARRAY',[500 100 790 250];
    '02 LIGHTNING COMMAND',[500 380 800 490];
    '03B SURGE SOURCE & CABLE',[900 430 1190 610];
    '03C SPD1 PRIMARY PROTECTION',[1320 300 1600 450];
    '03D SPD2 COORDINATED PROTECTION',[1320 570 1600 730];
    '03E PROTECTED DC BUS',[1730 480 1980 650];
    '05 SUPERCAP CONTROL',[2050 70 2350 220];
    '03F SUPERCAPACITOR BANK',[2110 300 2380 450];
    '03G RELAY & DC LOAD',[2110 570 2380 720];
    '06 RELAY PROTECTION CONTROL',[2050 810 2350 980];
    '03H INVERTER & AC LOAD',[2500 570 2780 720];
    '07 INVERTER CONTROL',[2500 810 2800 930];
    'DERIVED METRICS',[2900 100 3180 250];
    '08 RESULTS - SCOPES & LOGGING',[2900 430 3230 600]};
for positionIndex = 1:size(positions,1)
    path = [modelName '/' positions{positionIndex,1}];
    if getSimulinkBlockHandle(path) > 0
        set_param(path,'Position',positions{positionIndex,2}, ...
            'BackgroundColor','white','ForegroundColor','blue');
    end
end

lines = find_system(modelName,'SearchDepth',1,'FindAll','on','Type','line');
for lineIndex = 1:numel(lines)
    try
        Simulink.BlockDiagram.routeLine(lines(lineIndex));
    catch
        % Branch segments are routed with their corresponding trunk line.
    end
end
end

function summary = collectSummary(modelName,danglingCount,alreadySplit)
stageNames = electricalStageNames();
physicalCount = 0;
for stageIndex = 1:numel(stageNames)
    blocks = find_system([modelName '/' stageNames{stageIndex}], ...
        'SearchDepth',1,'Type','Block');
    for blockIndex = 1:numel(blocks)
        try
            reference = get_param(blocks{blockIndex},'ReferenceBlock');
        catch
            reference = '';
        end
        physicalCount = physicalCount + ~isempty(reference);
    end
end
summary = struct('AlreadySplit',alreadySplit,'StageCount',numel(stageNames), ...
    'PhysicalLibraryBlocks',physicalCount, ...
    'DeletedDanglingBranches',danglingCount);
end

function names = electricalStageNames()
names = {'03A PV ARRAY','03B SURGE SOURCE & CABLE', ...
    '03C SPD1 PRIMARY PROTECTION','03D SPD2 COORDINATED PROTECTION', ...
    '03E PROTECTED DC BUS','03F SUPERCAPACITOR BANK', ...
    '03G RELAY & DC LOAD','03H INVERTER & AC LOAD'};
end

function name = uniqueBlockName(parent,preferred)
name = preferred;
suffix = 2;
while getSimulinkBlockHandle([parent '/' name]) > 0
    name = sprintf('%s %d',preferred,suffix);
    suffix = suffix + 1;
end
end
