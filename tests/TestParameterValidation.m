classdef TestParameterValidation < matlab.unittest.TestCase
 methods(Test)
  function ratings(testCase), P=project_parameters; testCase.verifyGreaterThan(P.pv.Voc_V,P.pv.Vmp_V); testCase.verifyGreaterThan(P.sc.maximumEnergy_J,0); end
 end
end
