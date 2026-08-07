function write_verified_table(T,path)
%WRITE_VERIFIED_TABLE Replace a generated table and verify its schema.
folder=fileparts(path); if ~isfolder(folder), mkdir(folder); end
if isfile(path), delete(path); end
[~,~,ext]=fileparts(path);
writetable(T,path);
assert(isfile(path) && dir(path).bytes>0,'Generated table is missing or empty: %s',path);
if strcmpi(ext,'.xlsx')
 sheets=sheetnames(path); assert(numel(sheets)==1 && string(sheets(1))=="Sheet1",'Unexpected workbook sheets: %s',path);
end
R=readtable(path,'VariableNamingRule','preserve');
assert(height(R)==height(T),'Generated table row-count mismatch: %s',path);
assert(isequal(string(R.Properties.VariableNames),string(T.Properties.VariableNames)),'Generated table schema mismatch: %s',path);
assert(numel(unique(string(R.Properties.VariableNames)))==width(R),'Duplicate table column names: %s',path);
assert(width(R)>0 && (height(R)>0 || isempty(T)),'Generated table has no populated schema: %s',path);
end
