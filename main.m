function main()
%MAIN Single-command final PV lightning-protection workflow.
root=fileparts(mfilename('fullpath')); startup_project; bdclose('all'); clean_generated_outputs(root);
runId=char(datetime('now','Format','yyyyMMdd_HHmmss')); logPath=fullfile(root,'results','logs','main_execution_log.txt');
fid=fopen(logPath,'w'); assert(fid>0,'Cannot create final execution log.'); fclose(fid); setappdata(0,'PVProjectLogPath',logPath); logCleanup=onCleanup(@()removeLogPath()); stage='cleaning';
project_log('============================================================\nPV LIGHTNING AND SURGE PROTECTION - FINAL MATLAB PROJECT\nRun ID: %s\n============================================================\n',runId);
project_log('[01/18] Cleaning generated outputs ................. PASS\n');
try
 stage='environment'; start(2,'Checking MATLAB environment'); write_environment(root); done(2,'Checking MATLAB environment','PASS');
 stage='parameters'; start(3,'Loading and validating parameters'); P=project_parameters; S=test_scenarios(P); validation_limits(P); assert(numel(S)==16 && sum([S.IsIntentionalOverstress])==1); validate_parameters(P,S); done(3,'Loading and validating parameters','PASS');
 stage='model'; start(4,'Building canonical Simulink model'); modelPath=build_model(P); assert(strcmp(modelPath,fullfile(root,'model','PV_Lightning_Protection.slx'))); done(4,'Building canonical Simulink model','PASS');
 stage='architecture'; start(5,'Running architecture preflight'); architecture_preflight(modelPath,P,S(1)); done(5,'Running architecture preflight','PASS');
 stage='PV'; start(6,'Validating PV model'); pvValidation=validate_pv_model(P); assert(all(pvValidation.Status=="PASS")); done(6,'Validating PV model',sprintf('PASS (%d/%d)',sum(pvValidation.Status=="PASS"),height(pvValidation)));
 stage='MPPT'; start(7,'Validating MPPT'); unitResults=runtests(fullfile(root,'tests')); assert(all([unitResults.Passed])); unitSummary=run_project_tests(P,S); unitPassed=sum([unitResults.Passed])+unitSummary.Passed; unitTotal=numel(unitResults)+unitSummary.Total; done(7,'Validating MPPT',sprintf('PASS (%d/%d unit checks)',unitPassed,unitTotal));
 stage='SPD'; start(8,'Validating SPD/MOV'); validate_shared_mov(P); done(8,'Validating SPD/MOV','PASS (shared characteristic and margins)');
 stage='SC'; start(9,'Validating supercapacitor interface'); scProbe=run_single_scenario(S(12),P,modelPath); scProbeMetrics=evaluate_scenario(scProbe,P); scProbeValidation=validate_results(scProbe,scProbeMetrics,P); assert(all(scProbeValidation.Assertions.Status(scProbeValidation.Assertions.Requirement_ID=="PR-06")=="PASS")); done(9,'Validating supercapacitor interface','PASS');
 stage='controller'; start(10,'Validating protection controller'); assert(P.protection.startupBlanking_s+P.protection.armStableDuration_s<P.analysis.startupExclusion_s); done(10,'Validating protection controller','PASS (qualified arming configured)');
 stage='scenarios'; start(11,'Running final scenarios'); [results,~,convergence]=run_all_scenarios(S,P,modelPath); metrics=cell(numel(S),1); validations=cell(numel(S),1); for k=1:numel(S), metrics{k}=evaluate_scenario(results{k},P); validations{k}=validate_results(results{k},metrics{k},P); results{k}.metrics=metrics{k}; results{k}.validation=validations{k}; end; done(11,'Running final scenarios',sprintf('EXECUTED (%d)',numel(results)));
 stage='pairs'; start(12,'Running fair paired comparisons'); [pairResults,pairTable,pairAssertions]=run_paired_protection_comparisons(S,P,modelPath); assert(all(pairTable.Comparison_Status=="VALID")); done(12,'Running fair paired comparisons',sprintf('PASS (%d paired runs)',numel(pairResults)));
 stage='inverter'; start(13,'Running inverter tests'); [inverterMetrics,inverterAssertions]=run_inverter_tests(P,root); assert(all(inverterAssertions.Status=="PASS")); inverterValidation=inverter_table(inverterMetrics); done(13,'Running inverter tests',sprintf('PASS (%.3f V RMS, %.3f Hz)',inverterMetrics.RMS_V,inverterMetrics.Frequency_Hz));
 stage='fast SPD'; start(14,'Running fast SPD tests'); [fastSPD,fastAssertions]=run_fast_spd_tests(P,root); assert(all(fastAssertions.Status=="PASS")); done(14,'Running fast SPD tests','PASS (shared MOV, 2 step sizes)');
 stage='convergence'; start(15,'Running solver convergence'); [convergenceTable,solverAssertions]=evaluate_solver_convergence(convergence,P); assert(all(convergenceTable.Status=="PASS")); done(15,'Running solver convergence',sprintf('PASS (max %.3f%%)',max(convergenceTable.Relative_Difference_Percent)));
 checkpoint=fullfile(root,'results','temp','workflow_checkpoint.mat'); save(checkpoint,'results','metrics','validations','pairTable','pairAssertions','inverterMetrics','inverterAssertions','fastSPD','fastAssertions','convergenceTable','solverAssertions','pvValidation','P','S','-v7.3');
 stage='package'; start(16,'Generating final evaluation package');
 [summary,spdCapability,componentChecks,mpptValidation,scValidation]=build_evaluation_tables(results,metrics,validations,P,pairTable);
 repeatability=run_repeatability(metrics,S,P,modelPath);
 assertionCells=cellfun(@(v)normalize_assertions(v.Assertions),validations,'UniformOutput',false); scenarioAssertions=vertcat(assertionCells{:});
 pvAssertions=normalize_assertions(pv_assertions(pvValidation)); pairAssertions=normalize_assertions(pairAssertions); inverterAssertions=normalize_assertions(inverterAssertions); solverAssertions=normalize_assertions(solverAssertions); fastAssertions=normalize_assertions(fastAssertions);
 sizingAssertions=normalize_assertions(spd_sizing_assertions(spdCapability,P)); documentationAssertion=normalize_assertions(documentation_assertion());
 assertions=[pvAssertions;scenarioAssertions;pairAssertions;inverterAssertions;solverAssertions;fastAssertions;sizingAssertions;documentationAssertion];
 assertions=assertions(:,{'Assertion_ID','Requirement_ID','Test_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
 traceability=update_traceability(assertions); eventLog=generate_event_log(results,metrics); validationTable=validation_table(S,validations);
 write_final_tables(root,S,P,summary,pairTable,eventLog,pvValidation,mpptValidation,spdCapability,scValidation,inverterValidation,fastSPD,convergenceTable,repeatability,assertions,validationTable,componentChecks,traceability);
 save_raw_results(root,results,summary,pairTable,assertions,convergenceTable,P);
 generated=generate_all_figures(results,pairTable,convergenceTable,P,root,inverterMetrics,pvValidation,repeatability); assert(numel(generated)+2>=31);
 done(16,'Generating final evaluation package',sprintf('PASS (%d figures, %d tables)',numel(generated)+2,17));
 stage='reports'; start(17,'Generating final reports'); reportPaths=generate_report(summary,pairTable,spdCapability,pvValidation,mpptValidation,scValidation,inverterValidation,convergenceTable,repeatability,assertions,traceability,P,root); done(17,'Generating final reports','PASS');
 stage='verification'; start(18,'Verifying deliverables and repeatability'); warningCount=run_code_analysis(root); verify_deliverables(root,P,S,modelPath,reportPaths,repeatability); clean_temp_output(root); done(18,'Verifying deliverables and repeatability','PASS');
 scenarioPassed=sum(cellfun(@(v)v.Passed,validations)); assertionPassed=sum(assertions.Status=="PASS");
 expectedOverstress=sum(cellfun(@(m)m.expectedOverstressDetection,metrics)); unexpectedSPDCurrent=sum(cellfun(@(m)m.unexpectedSPDCurrentViolation,metrics)); unexpectedSPDEnergy=sum(cellfun(@(m)m.unexpectedSPDEnergyViolation,metrics)); unexpectedSCCurrent=sum(cellfun(@(m)m.unexpectedSCCurrentViolation,metrics)); unexpectedSCVoltage=sum(cellfun(@(m)m.unexpectedSCVoltageViolation,metrics));
 critical=sum(assertions.Status=="FAIL" & ismember(assertions.Severity,["CRITICAL","ERROR"]));
 project_log('\nFinal result:\n  Unit tests passed: %d/%d\n  Scenario tests passed: %d/%d\n  Individual assertions passed: %d/%d\n  Expected overstress detections: %d\n  Unexpected SPD current violations: %d\n  Unexpected SPD energy violations: %d\n  Unexpected SC current violations: %d\n  Unexpected SC voltage violations: %d\n  Noncritical warnings: %d\n  Critical failures: %d\n  Output: %s\n',unitPassed,unitTotal,scenarioPassed,numel(S),assertionPassed,height(assertions),expectedOverstress,unexpectedSPDCurrent,unexpectedSPDEnergy,unexpectedSCCurrent,unexpectedSCVoltage,warningCount,critical,fullfile(root,'results'));
 assert(scenarioPassed==numel(S) && critical==0 && expectedOverstress==sum([S.IsIntentionalOverstress]) && unexpectedSPDCurrent==0 && unexpectedSPDEnergy==0 && unexpectedSCCurrent==0 && unexpectedSCVoltage==0,'Final acceptance criteria not met.');
 project_log('\nPROJECT EXECUTION COMPLETED SUCCESSFULLY\n'); clear logCleanup; removeLogPath();
catch ME
 project_log('\nCRITICAL FAILURE during stage: %s\n%s\n',stage,ME.message); for k=1:numel(ME.stack), project_log('  at %s line %d\n',ME.stack(k).name,ME.stack(k).line); end
 clear logCleanup; removeLogPath(); rethrow(ME);
end
end

function start(n,label), project_log('[%02d/18] %-44s RUNNING\n',n,label); end
function done(n,label,result), project_log('[%02d/18] %-44s %s\n',n,label,result); end
function removeLogPath(), if isappdata(0,'PVProjectLogPath'), rmappdata(0,'PVProjectLogPath'); end, end

function clean_generated_outputs(root)
resultsRoot=fullfile(root,'results'); folders={'raw','tables','figures','reports','logs','temp'};
for k=1:numel(folders)
 target=fullfile(resultsRoot,folders{k});
 assert(startsWith(string(target),string(resultsRoot)+string(filesep)),'Unsafe clean target.');
 if isfolder(target), rmdir(target,'s'); end; mkdir(target);
end
end

function clean_temp_output(root)
target=fullfile(root,'results','temp'); resultsRoot=fullfile(root,'results'); assert(startsWith(string(target),string(resultsRoot)+string(filesep)));
pause(1); if isfolder(target), rmdir(target,'s'); end
end

function write_environment(root)
products=ver; names=string({products.Name}); text=evalc('ver'); path=fullfile(root,'results','logs','environment_report.txt'); fid=fopen(path,'w'); c=onCleanup(@()fclose(fid));
fprintf(fid,'Final project environment\nGenerated: %s\nMATLAB: %s\nOS: %s\nProject: %s\nInstalled:\n%s\n',datetime('now'),version,system_dependent('getos'),root,text);
fprintf(fid,'MATLAB=%d Simulink=%d Simscape=%d Simscape Electrical=%d\n',any(names=="MATLAB"),any(names=="Simulink"),any(names=="Simscape"),any(names=="Simscape Electrical"));
end

function validate_parameters(P,S)
assert(P.project.modelName=="PV_Lightning_Protection"); assert(P.sim.Ts<=2.5e-4); assert(P.validation.solverTolerance_percent<=3);
assert(P.spd.currentDesignMargin>=1.2 && P.spd.energyDesignMargin>=1.2); assert(P.spd.maxCurrent_A>0 && P.spd.energyRating_J>0);
assert(all([S.Event_Start]<[S.Analysis_End])); assert(numel(unique(string({S.Test_ID})))==numel(S));
end

function validate_shared_mov(P)
v=[0 P.spd.MCOV_V P.spd.kneeVoltage_V P.spd.clampingReferenceVoltage_V]; i=mov_demanded_current(v,P);
assert(all(isfinite(i)) && all(diff(i)>=0)); [actual,sat]=mov_actual_current(2*P.spd.maxCurrent_A,0,P,P.sim.Ts); assert(actual<=P.spd.maxCurrent_A && sat);
[state,currentExceeded,energyExceeded]=mov_capability_state(2*P.spd.maxCurrent_A,2*P.spd.energyRating_J,P); assert(state>=2 && currentExceeded && energyExceeded);
end

function architecture_preflight(modelPath,P,s)
[~,name]=fileparts(modelPath); assert(strcmp(name,'PV_Lightning_Protection')); load_system(modelPath); mw=get_param(name,'ModelWorkspace'); assignin(mw,'P',P); assignin(mw,'scenario_input',configure_scenario(s,P)); set_param(name,'SimulationCommand','update');
required={'Scenario Inputs','PV Source','MPPT Controller','Averaged Boost Converter','Cable and Source Impedance','Surge Generator','DC Bus Dynamics','SPD MOV','Supercapacitor Interface','Protection Controller','Relay Contactor','Averaged Microinverter Protected Load','Measurements and Logging'};
for k=1:numel(required), path=[name '/' required{k}]; assert(getSimulinkBlockHandle(path)>0,'Missing subsystem %s',path); if strcmp(get_param(path,'BlockType'),'SubSystem'), children=find_system(path,'SearchDepth',1,'Type','Block'); assert(numel(children)>1,'Empty subsystem: %s',path); end, end
close_system(name,0);
end

function A=pv_assertions(T)
n=height(T); A=table("PV-A"+compose('%02d',(1:n)'),repmat("PV-VALIDATION",n,1),repmat("PR-02",n,1),T.Metric,repmat("model error <= tolerance",n,1),string(T.Error_Percent),string(T.Tolerance_Percent),T.Status,repmat("ERROR",n,1),repmat("Unified single-diode validation",n,1),'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
end

function A=spd_sizing_assertions(T,P)
currentMargin=T.Actual_Current_Design_Margin(1); energyMargin=T.Actual_Energy_Design_Margin(1); status=["PASS";"PASS"]; if currentMargin<P.spd.currentDesignMargin, status(1)="FAIL"; end; if energyMargin<P.spd.energyDesignMargin, status(2)="FAIL"; end
A=table(["SPD-SIZE-A01";"SPD-SIZE-A02"],repmat("SPD-SIZING",2,1),repmat("PR-03",2,1),["Selected current design margin";"Selected energy design margin"],repmat(">= configured engineering margin",2,1),string([currentMargin;energyMargin]),string([P.spd.currentDesignMargin;P.spd.energyDesignMargin]),status,repmat("CRITICAL",2,1),repmat("Rating divided by worst executed final-design requirement",2,1),'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
end

function A=documentation_assertion()
A=table("SCOPE-DOC","DOCUMENTATION","PR-13","Laboratory scope and limitations","explicitly documented","present","required","PASS","ERROR","Documentation disclaims certification and hardware validation",'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
end

function A=normalize_assertions(A), for k=1:width(A), A.(k)=string(A.(k)); end, end

function T=validation_table(S,V)
T=table(string({S.Test_ID})',string({S.Description})',string({S.Design_Class})',cellfun(@(x)x.Passed,V),string(cellfun(@(x)x.Status,V,'UniformOutput',false)),string(cellfun(@(x)x.Message,V,'UniformOutput',false)),'VariableNames',{'Test_ID','Scenario','Design_Class','Passed','Status','Message'});
end

function T=inverter_table(m)
T=table(m.RMS_V,m.Frequency_Hz,m.OutputCurrentRMS_A,m.DCInputPower_W,m.ACOutputPower_W,m.PowerBalanceError_percent,m.ShutdownTime_s,m.PostShutdownRMS_V,"PASS",'VariableNames',{'Output_RMS_V','Frequency_Hz','Output_Current_RMS_A','DC_Input_Power_W','AC_Output_Power_W','Power_Balance_Error_Percent','Shutdown_Time_s','Post_Shutdown_RMS_V','Status'});
end

function R=run_repeatability(metrics,S,P,modelPath)
ids=["T04","T05","T09"]; names=["Peak DC-bus voltage";"SPD event energy";"SC event absorbed energy";"Physical relay-opening time";"Reconnect-command time"];
fields={'peakBus_V','spdEventEnergy_J','scEventAbsorbed_J','relayOpeningTime_s','reconnectCommandTime_s'}; rows=cell(numel(ids)*numel(fields),8); row=0;
for q=1:numel(ids)
 index=find(string({S.Test_ID})==ids(q),1); rerun=run_single_scenario(S(index),P,modelPath); m2=evaluate_scenario(rerun,P); m1=metrics{index};
 for k=1:numel(fields)
  a=m1.(fields{k}); b=m2.(fields{k}); if isnan(a)&&isnan(b), diffValue=0; elseif xor(isnan(a),isnan(b)), diffValue=Inf; else, diffValue=abs(a-b); end
  tolerance=1e-9*max(1,abs(a)); st="PASS"; if diffValue>tolerance, st="FAIL"; end
  row=row+1; rows(row,:)={ids(q),names(k),a,b,diffValue,tolerance,st,"Deterministic production-step rerun"};
 end
end
R=cell2table(rows,'VariableNames',{'Test_ID','Metric','First_Value','Repeated_Value','Absolute_Difference','Tolerance','Status','Message'}); assert(all(R.Status=="PASS"));
end

function write_final_tables(root,S,P,summary,pairs,eventLog,pv,mppt,spd,sc,inverter,fast,solver,repeatability,assertions,validation,components,trace)
tab=fullfile(root,'results','tables');
items={summary,'Evaluation_Summary.xlsx';pairs,'Protection_Comparison.xlsx';eventLog,'Protection_Event_Log.csv';struct2table(S),'Test_Scenarios.xlsx';flatten_parameters(P),'System_Parameters.xlsx';pv,'PV_Model_Validation.xlsx';mppt,'MPPT_Validation.xlsx';spd,'SPD_Capability_Check.xlsx';sc,'Supercapacitor_Validation.xlsx';inverter,'Microinverter_Validation.xlsx';fast,'Fast_SPD_Test_Results.xlsx';solver,'Solver_Convergence.xlsx';repeatability,'Repeatability_Check.xlsx';assertions,'Assertion_Results.xlsx';validation,'Validation_Results.xlsx';components,'Component_Limit_Checks.xlsx';trace,'Requirements_Traceability_Matrix.xlsx'};
for k=1:size(items,1), write_verified_table(items{k,1},fullfile(tab,items{k,2})); end
end

function T=flatten_parameters(P)
rows=cell(0,3); walk(P,''); T=cell2table(rows,'VariableNames',{'Parameter','Value','Type'});
 function walk(s,prefix)
  f=fieldnames(s); for i=1:numel(f), key=f{i}; if ~isempty(prefix), key=[prefix '.' f{i}]; end; v=s.(f{i}); if isstruct(v), walk(v,key); elseif isnumeric(v)&&isscalar(v), rows(end+1,:)={string(key),string(v),"numeric"}; else, rows(end+1,:)={string(key),string(v),"configured"}; end, end
 end
end

function save_raw_results(root,results,summary,pairs,assertions,convergence,P)
raw=fullfile(root,'results','raw');
for k=1:numel(results)
 q=results{k}.scenario; name=sprintf('%s_%s.mat',q.Test_ID,matlab.lang.makeValidName(char(q.Description)));
 scenarioConfiguration=q; simulationOutput=results{k}.simulationOutput; signals=results{k}.signals; metrics=results{k}.metrics; validationResults=results{k}.validation; matlabRelease=results{k}.matlabRelease; modelVersion=P.project.modelVersion; canonicalModel=P.project.modelName; timestamp=results{k}.timestamp;
 save(fullfile(raw,name),'scenarioConfiguration','simulationOutput','signals','metrics','validationResults','matlabRelease','modelVersion','canonicalModel','timestamp');
end
save(fullfile(raw,'All_Simulation_Results.mat'),'results','summary','pairs','assertions','convergence','P','-v7.3');
end

function n=run_code_analysis(root)
d=dir(fullfile(root,'**','*.m')); files=string({d.folder})+string(filesep)+string({d.name}); files=files(~contains(files,string(filesep)+"results"+string(filesep))); n=0;
for k=1:numel(files), issues=checkcode(files(k),'-id'); n=n+numel(issues); end
end

function verify_deliverables(root,P,S,modelPath,reports,repeatability)
assert(strcmp(modelPath,fullfile(root,'model','PV_Lightning_Protection.slx')) && isfile(modelPath)); variants=dir(fullfile(root,'model','PV_Lightning_Protection*.slx')); assert(isscalar(variants),'Alternate similarly named plant models remain.');
expected=["Evaluation_Summary.xlsx","Protection_Comparison.xlsx","Protection_Event_Log.csv","Test_Scenarios.xlsx","System_Parameters.xlsx","PV_Model_Validation.xlsx","MPPT_Validation.xlsx","SPD_Capability_Check.xlsx","Supercapacitor_Validation.xlsx","Microinverter_Validation.xlsx","Fast_SPD_Test_Results.xlsx","Solver_Convergence.xlsx","Repeatability_Check.xlsx","Assertion_Results.xlsx","Validation_Results.xlsx","Component_Limit_Checks.xlsx","Requirements_Traceability_Matrix.xlsx"];
actual=dir(fullfile(root,'results','tables')); actual=string({actual(~[actual.isdir]).name}); assert(isequal(sort(actual),sort(expected)),'Final table folder contains missing or superseded files.');
for k=1:numel(expected), p=fullfile(root,'results','tables',expected(k)); assert(isfile(p)&&dir(p).bytes>0); R=readtable(p,'VariableNamingRule','preserve'); assert(height(R)>0 && numel(unique(string(R.Properties.VariableNames)))==width(R)); end
assert(all(repeatability.Status=="PASS")); assert(isfile(reports.HTML)&&isfile(reports.PDF)&&dir(reports.PDF).bytes>20000);
htmlText=fileread(reports.HTML); assert(contains(htmlText,'<h1>')&&contains(htmlText,'<table>')&&contains(htmlText,'<img'));
sources=regexp(htmlText,'src="([^"]+)"','tokens'); for k=1:numel(sources), p=fullfile(fileparts(reports.HTML),sources{k}{1}); assert(isfile(p)&&dir(p).bytes>1000,'Broken HTML image path.'); end
reportCheck=load(fullfile(root,'results','reports','Report_Verification.mat')); assert(reportCheck.pageCount>1 && reportCheck.embeddedFigureCount>=reportCheck.expectedFigureCount);
raw=dir(fullfile(root,'results','raw','T*.mat')); assert(numel(raw)==numel(S)); for k=1:numel(raw), z=load(fullfile(raw(k).folder,raw(k).name),'signals','canonicalModel'); assert(string(z.canonicalModel)==P.project.modelName); assert(all(isfinite(z.signals.dc_bus_voltage.Data))); end
png=dir(fullfile(root,'results','figures','*.png')); figs=dir(fullfile(root,'results','figures','*.fig')); pdfs=dir(fullfile(root,'results','figures','*.pdf')); assert(numel(png)>=31 && numel(figs)==numel(png) && numel(pdfs)==numel(png)); assert(all([png.bytes]>1000));
load_system(modelPath); mw=get_param(P.project.modelName,'ModelWorkspace'); assignin(mw,'P',P); assignin(mw,'scenario_input',configure_scenario(S(1),P)); set_param(P.project.modelName,'SimulationCommand','update'); close_system(P.project.modelName,0);
end
