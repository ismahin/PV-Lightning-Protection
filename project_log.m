function project_log(formatSpec,varargin)
%PROJECT_LOG Write identical progress text to terminal and the clean run log.
message=sprintf(formatSpec,varargin{:}); fprintf('%s',message);
if isappdata(0,'PVProjectLogPath')
 path=getappdata(0,'PVProjectLogPath'); fid=fopen(path,'a');
 if fid>0, cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',message); clear cleanup; end
end
end
