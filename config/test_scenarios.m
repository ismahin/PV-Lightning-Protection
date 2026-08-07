function S = test_scenarios(P)
%TEST_SCENARIOS Final design suite plus one intentional capability test.
base = struct('Test_ID',"",'Description',"",'Protection_Mode',3, ...
 'Irradiance_Profile',"nominal",'Temperature_Profile',"nominal", ...
 'Surge_Type',"disabled",'Surge_Peak',0,'Surge_Start_Time',0.60, ...
 'Surge_Duration',0,'Pulse_Count',0,'StopTime',P.sim.stopTime, ...
 'AutoReset',true,'ManualResetTime',NaN,'NoiseStd_V',0, ...
 'Startup_Exclusion_Time',P.analysis.startupExclusion_s,'Event_Start',0.60, ...
 'Event_End',0.70,'Fault_Clear_Time',0.70,'Recovery_Start',0.70, ...
 'Analysis_End',P.sim.stopTime,'IsIntentionalOverstress',false, ...
 'Design_Class',"FINAL_DESIGN",'Expected_Behavior',"",'Validation_Rules',"");
S = repmat(base,16,1);
S(1)=setv(base,"T01","Normal Operation","disabled",0,3,"Stable bus, no trip");
S(2)=setv(base,"T02","Irradiance Step","disabled",0,3,"MPPT recovers without trip"); S(2).Irradiance_Profile="step";
S(3)=setv(base,"T03","Short Ripple","ripple",1.00,3,"Buffers without isolation"); S(3).Surge_Duration=0.018;
S(4)=setv(base,"T04","Moderate Design Transient","impulse",160,3,"SPD and SC coordinate; relay stays closed"); S(4).Pulse_Count=1;
S(5)=setv(base,"T05","Severe Design Transient","impulse",1200,3,"Emergency isolation within selected SPD rating"); S(5).Pulse_Count=1;
S(6)=setv(base,"T06","Repeated Design Surges","impulse",300,3,"Three stable coordinated responses"); S(6).Pulse_Count=3;
S(7)=setv(base,"T07","Sustained Overvoltage","sustained",1.00,3,"Timed isolation"); S(7).Surge_Duration=0.22;
S(8)=setv(base,"T08","Emergency Overvoltage","impulse",1200,3,"Emergency isolation within selected SPD rating"); S(8).Pulse_Count=1;
S(9)=setv(base,"T09","Automatic Recovery","sustained",1.20,3,"Isolation then full safe-dwell reconnect"); S(9).Surge_Duration=0.12;
S(10)=setv(base,"T10","Manual Reset","sustained",1.20,3,"Wait for manual reset"); S(10).Surge_Duration=0.12; S(10).AutoReset=false; S(10).ManualResetTime=1.10;
S(11)=setv(base,"T11","Protection Comparison","impulse",1200,3,"Four-mode fair comparison"); S(11).Pulse_Count=1;
S(12)=setv(base,"T12","SC Current Limit","impulse",450,3,"SC converter current limit without SPD overstress"); S(12).Pulse_Count=1;
S(13)=setv(base,"T13","Sensor Noise","disabled",0,3,"No false chatter"); S(13).NoiseStd_V=0.35;
S(14)=setv(base,"T14","Inverter Integration","impulse",1200,3,"Averaged inverter shuts down after isolation"); S(14).Pulse_Count=1;
S(15)=setv(base,"T15","Solver Convergence","impulse",1200,3,"Production and half-step metrics converge"); S(15).Pulse_Count=1;
S(16)=setv(base,"T16","Intentional SPD Overstress","impulse",1e5,3,"Capability exceedance is detected outside design envelope"); S(16).Pulse_Count=1; S(16).IsIntentionalOverstress=true; S(16).Design_Class="INTENTIONAL_OVERSTRESS";
for k=1:numel(S)
 S(k).Validation_Rules="Scenario-specific Requirement_ID assertions";
 S(k).Event_Start=S(k).Surge_Start_Time;
 if S(k).Surge_Type=="disabled"
  S(k).Event_Start=P.analysis.startupExclusion_s; S(k).Event_End=S(k).StopTime;
 elseif S(k).Surge_Type=="impulse"
  S(k).Event_End=S(k).Surge_Start_Time+max(0.10,(max(1,S(k).Pulse_Count)-1)*0.085+0.10);
 else
  S(k).Event_End=S(k).Surge_Start_Time+S(k).Surge_Duration;
 end
 if S(k).Test_ID=="T02", S(k).Event_Start=0.55; S(k).Event_End=1.05; end
 S(k).Fault_Clear_Time=S(k).Event_End; S(k).Recovery_Start=S(k).Fault_Clear_Time; S(k).Analysis_End=S(k).StopTime;
end
end

function s=setv(s,id,desc,stype,peak,mode,expected)
s.Test_ID=id; s.Description=desc; s.Surge_Type=stype; s.Surge_Peak=peak;
s.Protection_Mode=mode; s.Expected_Behavior=expected;
end
