classdef TestOutputFiles < matlab.unittest.TestCase
 methods(Test)
  function modelExists(testCase), root=fileparts(fileparts(mfilename('fullpath'))); testCase.verifyTrue(isfile(fullfile(root,'model','PV_Lightning_Protection.slx'))); end
 end
end
