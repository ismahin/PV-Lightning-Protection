classdef TestSurgeGenerator < matlab.unittest.TestCase
 methods(Test)
  function normalized(testCase), P=project_parameters; S=test_scenarios(P); t=(0:P.sim.Ts:1)'; y=prepare_surge_waveform(t,S(4),P); testCase.verifyEqual(max(y),S(4).Surge_Peak,'RelTol',0.01); end
 end
end
