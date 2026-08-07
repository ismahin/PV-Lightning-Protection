classdef TestSimulationScenarios < matlab.unittest.TestCase
 methods(Test)
  function count(testCase), P=project_parameters; S=test_scenarios(P); testCase.verifyEqual(numel(S),16); testCase.verifyEqual(sum([S.IsIntentionalOverstress]),1); end
 end
end
