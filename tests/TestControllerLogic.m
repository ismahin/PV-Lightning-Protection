classdef TestControllerLogic < matlab.unittest.TestCase
 methods(Test)
  function emergency(testCase), P=project_parameters; [state,relay]=protection_logic(1.6*P.bus.nominalVoltage_V,1,0,0,false,true,P,P.sim.Ts); testCase.verifyEqual(state,4); testCase.verifyFalse(relay); end
 end
end
