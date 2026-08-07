function result = run_single_scenario(scenario,P,modelPath,dt)
%RUN_SINGLE_SCENARIO Execute model and return actual named output signals.
if nargin<4, dt=P.sim.Ts; end
P.sim.Ts=dt; scenario_input=configure_scenario(scenario,P,dt);
[~,modelName]=fileparts(modelPath); load_system(modelPath);
modelCleanup=onCleanup(@()localCloseModel(modelName));
modelWorkspace=get_param(modelName,'ModelWorkspace'); assignin(modelWorkspace,'P',P); assignin(modelWorkspace,'scenario_input',scenario_input);
in=Simulink.SimulationInput(modelName);
in=in.setVariable('P',P).setVariable('scenario_input',scenario_input);
in=in.setModelParameter('StopTime',num2str(scenario.StopTime),'FixedStep',num2str(dt,16),'ReturnWorkspaceOutputs','on');
tic; simOut=sim(in); elapsed=toc;
signals=collect_logged_signals(simOut);
result=struct('scenario',scenario,'signals',signals,'simulationOutput',simOut,'executionTime_s',elapsed, ...
 'matlabRelease',version('-release'),'modelVersion',P.project.modelVersion,'timestamp',datetime('now'));
clear modelCleanup;
end

function localCloseModel(modelName)
% Always discard SimulationInput overrides and fine-step workspace values.
if bdIsLoaded(modelName), close_system(modelName,0); end
end
