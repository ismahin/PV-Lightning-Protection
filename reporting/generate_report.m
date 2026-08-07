function paths = generate_report(summary,pairs,spdCapability,pvValidation,mpptValidation,scValidation,inverterValidation,convergence,repeatability,assertions,traceability,P,root)
%GENERATE_REPORT Browser-rendered final HTML and A4 PDF with real figures.
out=fullfile(root,'results','reports'); html=fullfile(out,'MATLAB_Evaluation_Report.html'); pdf=fullfile(out,'MATLAB_Evaluation_Report.pdf');
figureNames={ ...
 'PV_IV_Curves.png','PV_PV_Curves.png','Irradiance_Step_MPPT_Response.png', ...
 'Fair_Paired_Severe_Design_Transient.png','SPD_Demanded_Versus_Actual_Current.png', ...
 'Intentional_SPD_Overstress_Response.png','SC_Current_Command_Versus_Actual.png', ...
 'Automatic_Recovery_Timing.png','Switching_Inverter_Output_Voltage_And_Current.png', ...
 'Solver_Convergence_All_Metrics.png','Repeatability_Comparison.png'};
for k=1:numel(figureNames)
 p=fullfile(root,'results','figures',figureNames{k}); assert(isfile(p) && dir(p).bytes>1000,'Missing/empty report figure: %s',p);
end
fid=fopen(html,'w','n','UTF-8'); assert(fid>0,'Cannot create HTML report.'); c=onCleanup(@()fclose(fid));
fprintf(fid,'<!doctype html><html><head><meta charset="utf-8"><title>PV Protection Evaluation</title><style>');
fprintf(fid,'@page{size:A4;margin:15mm}body{font-family:Arial,Helvetica,sans-serif;color:#111;background:#fff;font-size:10.5pt;line-height:1.4}h1{font-size:24pt;color:#17365d}h2{font-size:16pt;color:#1f4e79;border-bottom:1px solid #9fbad0;padding-bottom:4px;page-break-after:avoid}h3{font-size:12pt;color:#365f91}table{border-collapse:collapse;width:100%%;font-size:7.5pt;margin:8px 0 18px}th,td{border:1px solid #888;padding:3px;overflow-wrap:anywhere}th{background:#d9eaf7}img{max-width:100%%;max-height:220mm;display:block;margin:8px auto}.figure{page-break-inside:avoid;text-align:center}.caption{font-size:9pt;color:#333}.pagebreak{break-before:page}.note{background:#fff4cc;border-left:4px solid #e6ad00;padding:8px}.safe{background:#e7f4e4;padding:8px}footer{position:fixed;bottom:0;font-size:8pt;color:#666}</style></head><body>');
fprintf(fid,'<h1>PV Lightning and Surge Protection</h1><p><b>Final MATLAB/Simulink Evaluation Report</b></p><p>Generated %s<br>MATLAB %s<br>Canonical model: %s</p>',char(datetime('now')),version,char(P.project.modelName));
section('Objectives and scope','Evaluate PV tracking, surge protection, supercapacitor buffering, relay coordination, recovery and inverter shutdown using the final canonical low-voltage model.');
section('Environment and architecture','MATLAB and Simulink execute modular top-level subsystems for scenario inputs, PV source, MPPT, boost converter, cable/source impedance, surge generator, DC bus, SPD/MOV, supercapacitor interface, protection controller, contactor, averaged inverter/load and named logging. Simscape products are not installed.');
section('Mathematical conventions','Positive supercapacitor current charges from the DC bus into the capacitor. Vterminal = Vinternal + Isc*ESR and positive terminal power is absorbed energy. The bus equation subtracts positive charging current. SPD current is positive from the DC bus into the protective branch.');
fprintf(fid,'<h2>Final parameters and SPD sizing</h2><p>MCOV %.3g V; knee %.3g V; selected current rating %.3g A; selected energy rating %.3g J. Minimum configured design margins are %.2f current and %.2f energy. Values are engineering datasheet-style assumptions, not a certified commercial-device claim.</p>',P.spd.MCOV_V,P.spd.kneeVoltage_V,P.spd.maxCurrent_A,P.spd.energyRating_J,P.spd.currentDesignMargin,P.spd.energyDesignMargin);
fprintf(fid,'<h2>PV validation</h2>%s',tableHTML(pvValidation)); figureBlock('PV_IV_Curves.png','Figure 1. Unified single-diode I-V curves.'); figureBlock('PV_PV_Curves.png','Figure 2. Unified single-diode P-V curves.');
fprintf(fid,'<h2>MPPT validation</h2>%s',tableHTML(mpptValidation)); figureBlock('Irradiance_Step_MPPT_Response.png','Figure 3. Irradiance-step MPPT response.');
fprintf(fid,'<h2>Final scenario results</h2>%s',tableHTML(summary));
fprintf(fid,'<h2>Fair paired comparisons</h2>%s',tableHTML(pairs)); figureBlock('Fair_Paired_Severe_Design_Transient.png','Figure 4. Fair severe-design paired comparison.');
fprintf(fid,'<h2>SPD sizing, capability and intentional overstress</h2>%s',tableHTML(spdCapability)); figureBlock('SPD_Demanded_Versus_Actual_Current.png','Figure 5. Design-case demanded and actual SPD current.'); figureBlock('Intentional_SPD_Overstress_Response.png','Figure 6. Dedicated out-of-envelope SPD capability test.');
fprintf(fid,'<h2>Supercapacitor interface</h2>%s',tableHTML(scValidation)); figureBlock('SC_Current_Command_Versus_Actual.png','Figure 7. Current command, limit and dynamic response.');
fprintf(fid,'<h2>Controller, contactor and recovery</h2><p>Startup-qualified arming prevents startup operation from being classified as a fault. Recovery timing begins at the uninterrupted safe interval that ultimately produces reconnect.</p>'); figureBlock('Automatic_Recovery_Timing.png','Figure 8. Detection, isolation, safe dwell and physical reconnection.');
fprintf(fid,'<h2>Microinverter validation</h2>%s',tableHTML(inverterValidation)); figureBlock('Switching_Inverter_Output_Voltage_And_Current.png','Figure 9. Switching low-voltage inverter output and isolation.');
fprintf(fid,'<h2>Solver convergence</h2>%s',tableHTML(convergence)); figureBlock('Solver_Convergence_All_Metrics.png','Figure 10. Production versus half-step differences.');
fprintf(fid,'<h2>Repeatability</h2>%s',tableHTML(repeatability)); figureBlock('Repeatability_Comparison.png','Figure 11. Repeated key-metric differences.');
fprintf(fid,'<h2>Requirements traceability</h2>%s',tableHTML(traceability));
fprintf(fid,'<h2>Assertion summary</h2><p>Total %d; PASS %d; FAIL %d. Expected overstress assertions are identified separately from design failures.</p>',height(assertions),sum(assertions.Status=="PASS"),sum(assertions.Status=="FAIL"));
section('Limitations','This is an averaged low-voltage laboratory study, not a direct-strike, certification, insulation-coordination, full EMT, grid-compliance or hardware-validation model. Fast impulses are standards-inspired numerical tests only. The selected SPD ratings are engineering assumptions pending a supplied commercial datasheet.');
section('Conclusion','Final design scenarios, fair paired comparisons, recovery timing, component limits, inverter shutdown, convergence and repeatability are supported by executed assertions. The dedicated overstress case is outside the design envelope and verifies capability detection only.');
fprintf(fid,'</body></html>'); clear c;
if isfile(pdf), delete(pdf); end
edge=findEdge(); edgeProfile=fullfile(root,'results','temp','edge_profile'); if ~isfolder(edgeProfile), mkdir(edgeProfile); end
uri="file:///"+replace(string(html),'\','/');
cmd=sprintf('"%s" --headless --disable-gpu --no-pdf-header-footer --user-data-dir="%s" --print-to-pdf="%s" "%s"',edge,edgeProfile,pdf,uri);
[status,output]=system(cmd); assert(status==0 && isfile(pdf) && dir(pdf).bytes>20000,'PDF conversion failed: %s',output);
verifyScript=fullfile(root,'reporting','verify_pdf_report.py'); jsonPath=fullfile(root,'results','temp','pdf_verification.json');
cmd=sprintf('python "%s" "%s" "%s"',verifyScript,pdf,jsonPath); [status,output]=system(cmd); assert(status==0,'PDF verification failed: %s',output);
verification=jsondecode(fileread(jsonPath)); expectedFigureCount=numel(figureNames); actualSourceFigureCount=numel(regexp(fileread(html),'<img ','match'));
assert(verification.page_count>1 && verification.image_count>=expectedFigureCount,'PDF pages/images failed verification.');
assert(actualSourceFigureCount==expectedFigureCount,'HTML report figure count mismatch.');
assert(all(verification.required_titles_found),'Expected report titles are not extractable from PDF.');
pageCount=verification.page_count; embeddedFigureCount=verification.image_count; conversionMethod="Microsoft Edge headless print-to-PDF from verified HTML";
save(fullfile(out,'Report_Verification.mat'),'pageCount','embeddedFigureCount','expectedFigureCount','actualSourceFigureCount','conversionMethod','verification');
paths=struct('HTML',html,'PDF',pdf);
 function section(titleText,body), fprintf(fid,'<h2>%s</h2><p>%s</p>',titleText,body); end
 function figureBlock(name,caption), fprintf(fid,'<div class="figure"><img src="../figures/%s" alt="%s"><div class="caption">%s</div></div>',name,caption,caption); end
end

function edge=findEdge()
candidates={'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe','C:\Program Files\Microsoft\Edge\Application\msedge.exe'};
edge=''; for k=1:numel(candidates), if isfile(candidates{k}), edge=candidates{k}; break; end, end
assert(~isempty(edge),'Microsoft Edge is required for final PDF rendering.');
end

function html=tableHTML(T)
html='<table><thead><tr>'; for j=1:width(T), html=html+"<th>"+escape(T.Properties.VariableNames{j})+"</th>"; end; html=html+'</tr></thead><tbody>';
for i=1:height(T)
 html=html+'<tr>'; for j=1:width(T), value=T{i,j}; if iscell(value), value=value{1}; end; q=string(value); if ismissing(q), q=""; end; html=html+"<td>"+escape(q)+"</td>"; end; html=html+'</tr>';
end
html=char(html+'</tbody></table>');
end
function out=escape(in), out=replace(replace(replace(string(in),'&','&amp;'),'<','&lt;'),'>','&gt;'); end
