function assetDirectory = generate_simscape_report_assets()
%GENERATE_SIMSCAPE_REPORT_ASSETS Run the model and export report evidence.

root = fileparts(fileparts(mfilename('fullpath')));
assetDirectory = fullfile(root,'docs','report_assets');
if ~isfolder(assetDirectory), mkdir(assetDirectory); end
addpath(genpath(root));

P = simscape_user_settings(project_parameters);
modelName = 'PV_Lightning_Protection_Simscape';
load_system(fullfile(root,'model',[modelName '.slx']));
modelWorkspace = get_param(modelName,'ModelWorkspace');
assignin(modelWorkspace,'P',P);
assignin(modelWorkspace,'lightning_profile',prepare_indirect_lightning_profile(P));

simulationInput = Simulink.SimulationInput(modelName);
simulationInput = simulationInput.setModelParameter( ...
    'StopTime',num2str(P.lightning.eventTime_s+1e-3), ...
    'ReturnWorkspaceOutputs','on');
simulationOutput = sim(simulationInput);

pvVoltage = signal('Simscape_pv_voltage');
pvCurrent = signal('Simscape_pv_current');
configuredCurrent = signal('Simscape_configured_lightning_current');
injectedCurrent = signal('Simscape_injected_current');
injectionVoltage = signal('Simscape_injection_voltage');
spd1Current = signal('Simscape_spd_current');
afterSpd1Current = signal('Simscape_surge_current');
spd1Voltage = signal('Simscape_spd1_voltage');
spd2Current = signal('Simscape_spd2_current');
afterSpd2Current = signal('Simscape_spd2_residual_current');
spd2Voltage = signal('Simscape_spd2_voltage');
busVoltage = signal('Simscape_bus_voltage');
scVoltage = signal('Simscape_sc_voltage');
scCurrent = signal('Simscape_sc_current');
acVoltage = signal('Simscape_ac_voltage');
acCurrent = signal('Simscape_ac_current');
relayCommand = signal('Simscape_relay_command');
relayState = signal('Simscape_relay_state');

normalWindow = [0.55 P.lightning.eventTime_s-1e-4];
pvV = windowMean(pvVoltage,normalWindow);
pvI = windowMean(pvCurrent,normalWindow);
pvP = pvV*pvI;
busNormal = windowMean(busVoltage,normalWindow);
acV_RMS = windowRms(acVoltage,[0.54 0.59]);
acI_RMS = windowRms(acCurrent,[0.54 0.59]);

injectedPeak = max(injectedCurrent.Data);
spd1Peak = max(spd1Current.Data);
afterSpd1Peak = max(afterSpd1Current.Data);
spd2Peak = max(spd2Current.Data);
afterSpd2Peak = max(afterSpd2Current.Data);
injectionVPeak = max(injectionVoltage.Data);
spd1VPeak = max(spd1Voltage.Data);
spd2VPeak = max(spd2Voltage.Data);
busPeak = max(busVoltage.Data);
scIPeak = max(abs(scCurrent.Data));

metric = ["PV voltage before surge"; "PV current before surge"; ...
    "PV power delivered to MPPT/boost"; "Protected DC bus before surge"; ...
    "Configured lightning-current peak"; "Measured injected-current peak"; ...
    "Injection-node voltage peak"; "SPD1 conduction threshold"; ...
    "SPD1 diverted-current peak"; "Residual-current peak after SPD1"; ...
    "SPD1 terminal-voltage peak"; "SPD2 conduction threshold"; ...
    "SPD2 diverted-current peak"; "Residual-current peak after SPD2"; ...
    "SPD2 terminal-voltage peak"; "Protected DC-bus peak"; ...
    "Emergency trip threshold"; "Supercapacitor current peak"; ...
    "Supercapacitor current limit"; "AC output voltage RMS before surge"; ...
    "AC output current RMS before surge"; "Minimum relay command"; ...
    "Minimum physical relay state"];
value = [pvV; pvI; pvP; busNormal; max(configuredCurrent.Data); ...
    injectedPeak; injectionVPeak; P.spd1.lowerVoltage_V; spd1Peak; ...
    afterSpd1Peak; spd1VPeak; P.spd2.lowerVoltage_V; spd2Peak; ...
    afterSpd2Peak; spd2VPeak; busPeak; ...
    P.threshold.emergencyTripVoltage_V; scIPeak; P.sc.maximumCurrent_A; ...
    acV_RMS; acI_RMS; min(relayCommand.Data); min(relayState.Data)];
unit = ["V"; "A"; "W"; "V"; "A"; "A"; "V"; "V"; "A"; "A"; ...
    "V"; "V"; "A"; "A"; "V"; "V"; "V"; "A"; "A"; "V RMS"; ...
    "A RMS"; "logic"; "logic"];
metrics = table(metric,value,unit);
writetable(metrics,fullfile(assetDirectory,'measured_metrics.csv'));

summary = struct;
summary.eventTime_s = P.lightning.eventTime_s;
summary.frontTime_us = P.lightning.frontTime_s*1e6;
summary.halfValueTime_us = P.lightning.halfValueTime_s*1e6;
summary.spd1DiversionPercent = 100*spd1Peak/injectedPeak;
summary.afterSpd1Percent = 100*afterSpd1Peak/injectedPeak;
summary.afterSpd2Percent = 100*afterSpd2Peak/afterSpd1Peak;
summary.busMargin_V = P.threshold.emergencyTripVoltage_V-busPeak;
summary.relayRemainedClosed = min(relayState.Data) > 0.5;
summary.defaultInjectionMode = '10 kA current injection';
writeText(fullfile(assetDirectory,'summary.json'),jsonencode(summary,'PrettyPrint',true));

makePvFigure();
makeInjectionFigure();
makeSpdCurrentFigure();
makeVoltageFigure();
makeOutputFigure();
close_system(modelName,0);

    function ts = signal(name)
        ts = simulationOutput.get(name);
    end

    function makePvFigure()
        f = reportFigure();
        tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
        nexttile;
        yyaxis left; plot(pvVoltage.Time,pvVoltage.Data,'LineWidth',1.5); ylabel('Voltage (V)');
        yyaxis right; plot(pvCurrent.Time,pvCurrent.Data,'LineWidth',1.5); ylabel('Current (A)');
        xlim([0.45 P.lightning.eventTime_s]); grid on; title('PV array electrical output before the surge');
        legend('PV voltage','PV current','Location','best');
        nexttile;
        plot(pvVoltage.Time,pvVoltage.Data.*pvCurrent.Data,'LineWidth',1.5);
        xlim([0.45 P.lightning.eventTime_s]); grid on; ylabel('Power (W)'); xlabel('Time (s)');
        title(sprintf('Power presented to MPPT/boost (mean %.1f W)',pvP));
        exportFigure(f,'01_pv_output.png');
    end

    function makeInjectionFigure()
        f = reportFigure();
        tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
        nexttile;
        plot(relativeMicroseconds(configuredCurrent.Time),configuredCurrent.Data,'--','LineWidth',1.5); hold on;
        plot(relativeMicroseconds(injectedCurrent.Time),injectedCurrent.Data,'LineWidth',1.4);
        xlim([-2 80]); grid on; ylabel('Current (A)');
        title('Configured and measured 8/20 us indirect-lightning injection');
        legend('Configured','Measured','Location','best');
        nexttile;
        plot(relativeMicroseconds(injectionVoltage.Time),injectionVoltage.Data,'LineWidth',1.5);
        xlim([-2 80]); grid on; ylabel('Voltage (V)'); xlabel('Time from surge start (us)');
        title(sprintf('Injection-node voltage produced by the surge (peak %.1f V)',injectionVPeak));
        exportFigure(f,'02_lightning_injection.png');
    end

    function makeSpdCurrentFigure()
        f = reportFigure();
        tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
        nexttile;
        plot(relativeMicroseconds(injectedCurrent.Time),injectedCurrent.Data,'LineWidth',1.5); hold on;
        plot(relativeMicroseconds(spd1Current.Time),spd1Current.Data,'--','LineWidth',1.4);
        xlim([-2 80]); grid on; ylabel('Current (A)');
        title(sprintf('SPD1 diverts %.2f%% of the injected peak toward ground',summary.spd1DiversionPercent));
        legend('Injected','SPD1 to ground','Location','best');
        nexttile;
        plot(relativeMicroseconds(afterSpd1Current.Time),afterSpd1Current.Data,'LineWidth',1.5); hold on;
        plot(relativeMicroseconds(spd2Current.Time),spd2Current.Data,'--','LineWidth',1.4);
        plot(relativeMicroseconds(afterSpd2Current.Time),afterSpd2Current.Data,':','LineWidth',1.8);
        xlim([-2 80]); grid on; ylabel('Current (A)'); xlabel('Time from surge start (us)');
        title('Residual surge handled by SPD2 and delivered downstream');
        legend('After SPD1','SPD2 to ground','After SPD2','Location','best');
        exportFigure(f,'03_spd_current_diversion.png');
    end

    function makeVoltageFigure()
        f = reportFigure();
        plot(relativeMicroseconds(injectionVoltage.Time),injectionVoltage.Data,'LineWidth',1.5); hold on;
        plot(relativeMicroseconds(spd1Voltage.Time),spd1Voltage.Data,'--','LineWidth',1.4);
        plot(relativeMicroseconds(spd2Voltage.Time),spd2Voltage.Data,'-.','LineWidth',1.4);
        plot(relativeMicroseconds(busVoltage.Time),busVoltage.Data,':','LineWidth',1.8);
        yline(P.spd1.lowerVoltage_V,'--','Color',[0.85 0.33 0.10]);
        yline(P.spd2.lowerVoltage_V,'--','Color',[0.93 0.69 0.13]);
        yline(P.threshold.emergencyTripVoltage_V,'r--');
        text(28,135,'Relay emergency threshold: 69.6 V','Color',[0.75 0 0]);
        text(28,112,'SPD1 model threshold: 62 V','Color',[0.70 0.25 0.05]);
        text(28,89,'SPD2 model threshold: 55 V','Color',[0.70 0.50 0.05]);
        xlim([-2 80]); grid on; xlabel('Time from surge start (us)'); ylabel('Voltage (V)');
        title('Voltage reduction from the injection point to the protected DC bus');
        legend('Injection node','SPD1 terminal','SPD2 terminal','Protected bus','Location','best');
        exportFigure(f,'04_voltage_protection.png');
    end

    function makeOutputFigure()
        f = reportFigure();
        tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
        nexttile;
        yyaxis left; plot(scVoltage.Time,scVoltage.Data,'LineWidth',1.4); ylabel('SC voltage (V)');
        yyaxis right; plot(scCurrent.Time,scCurrent.Data,'LineWidth',1.4); ylabel('SC current (A)');
        xlim([0.55 P.lightning.eventTime_s+1e-3]); grid on;
        title('Supercapacitor response downstream of the SPDs');
        nexttile;
        yyaxis left; plot(acVoltage.Time,acVoltage.Data,'LineWidth',1.2); ylabel('AC voltage (V)');
        yyaxis right; plot(acCurrent.Time,acCurrent.Data,'LineWidth',1.2); ylabel('AC current (A)');
        xlim([0.55 0.60]); grid on; xlabel('Time (s)');
        title(sprintf('Inverter/load output before surge: %.1f V RMS, %.2f A RMS',acV_RMS,acI_RMS));
        exportFigure(f,'05_downstream_output.png');
    end

    function f = reportFigure()
        f = figure('Visible','off','Color','white','Position',[100 100 1200 700]);
        set(f,'DefaultAxesFontName','Arial','DefaultAxesFontSize',11);
    end

    function exportFigure(f,fileName)
        axesHandles = findall(f,'Type','axes');
        set(axesHandles,'Color','white','XColor','black','YColor','black', ...
            'GridColor',[0.65 0.65 0.65]);
        set(findall(f,'Type','text'),'Color','black');
        legendHandles = findall(f,'Type','legend');
        set(legendHandles,'Color','white','TextColor','black', ...
            'EdgeColor',[0.4 0.4 0.4]);
        exportgraphics(f,fullfile(assetDirectory,fileName),'Resolution',180);
        close(f);
    end

    function q = relativeMicroseconds(time)
        q = (time-P.lightning.eventTime_s)*1e6;
    end
end

function value = windowMean(ts,interval)
use = ts.Time >= interval(1) & ts.Time <= interval(2);
value = mean(ts.Data(use));
end

function value = windowRms(ts,interval)
use = ts.Time >= interval(1) & ts.Time <= interval(2);
value = sqrt(mean(ts.Data(use).^2));
end

function writeText(path,text)
file = fopen(path,'w');
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s',text);
end
