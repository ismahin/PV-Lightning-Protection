function [results,comparison,convergence] = run_all_scenarios(S,P,modelPath)
%RUN_ALL_SCENARIOS Execute required scenarios, including four-mode comparison.
results=cell(numel(S),1); comparison={}; convergence=struct;
for k=1:numel(S)
 project_log('    %-4s %-32s RUNNING\n',S(k).Test_ID,S(k).Description);
 if S(k).Test_ID=="T15"
  coarse=run_single_scenario(S(k),P,modelPath,P.sim.Ts);
  fine=run_single_scenario(S(k),P,modelPath,P.sim.Ts/2);
  results{k}=coarse; convergence.coarse=coarse; convergence.fine=fine;
 else
  results{k}=run_single_scenario(S(k),P,modelPath);
 end
 project_log('    %-4s %-32s EXECUTED\n',S(k).Test_ID,S(k).Description);
end
end
