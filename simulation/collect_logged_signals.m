function signals = collect_logged_signals(simOut)
%COLLECT_LOGGED_SIGNALS Extract all required named Simulink time series.
names=required_signal_names();
signals=struct;
for k=1:numel(names)
 try, ts=simOut.get(char(names{k})); catch, ts=[]; end
 if isempty(ts), error('Missing required logged signal: %s',names{k}); end
 signals.(names{k})=struct('Time',ts.Time(:),'Data',ts.Data(:));
end
signals.time=signals.dc_bus_voltage.Time;
end
