function output_folder = network_export_results(R, output_parent)
  if nargin < 2, output_parent = fullfile(network_stage_folder(R.parameters.stage),'results'); end
  if ~exist(output_parent,'dir'), mkdir(output_parent); end
  base = ['run_',datestr(now,'yyyymmdd_HHMMSS')]; output_folder = fullfile(output_parent,base); count = 1;
  while exist(output_folder,'dir')
    output_folder = fullfile(output_parent,sprintf('%s_%02d',base,count)); count = count+1;
  end
  mkdir(output_folder);
  save('-mat7-binary',fullfile(output_folder,'results.mat'),'R');
  write_text(fullfile(output_folder,'summary.txt'),network_summary_text(R));
  parameters = sprintf('parameter,value\n'); fields = fieldnames(R.parameters);
  for k=1:numel(fields)
    name = fields{k}; value = R.parameters.(name);
    if isstruct(value)
      nested = fieldnames(value);
      for j=1:numel(nested), parameters = [parameters,sprintf('%s.%s,%.17g\n',name,nested{j},value.(nested{j}))]; end
    else, parameters = [parameters,sprintf('%s,%.17g\n',name,value)]; end
  end
  if isfield(R,'comparison')
    C=R.comparison; names=fieldnames(C.parameters);
    parameters=[parameters,sprintf('architecture_mode,%s\n',C.mode)];
    for k=1:numel(names), parameters=[parameters,sprintf('bbm92.%s,%.17g\n',names{k},C.parameters.(names{k}))]; end
    E=C.bbm92; I=C.trusted.inventory;
    f=fopen(fullfile(output_folder,'stage3_comparison.csv'),'w'); check_file(f); closefile=onCleanup(@() fclose(f));
    fprintf(f,'time_s,visible_a,visible_b,common_visibility,eta_a,eta_b,true_coincidences_hz,accidental_coincidences_hz,total_coincidences_hz,bbm92_qber,bbm92_key_rate_bps,bbm92_cumulative_bits,trusted_causal_bits,pool_a_bits,pool_b_bits\n');
    values=[R.time_s(:),double(E.visible_a(:)),double(E.visible_b(:)),double(E.common_visibility(:)), ...
      E.eta_a(:),E.eta_b(:),E.true_coincidence_hz(:),E.accidental_coincidence_hz(:), ...
      E.coincidence_hz(:),E.qber(:),E.key_rate_bps(:),E.cumulative_key_bits(:), ...
      I.delivered_bits(:),I.pool_a_bits(:),I.pool_b_bits(:)];
    fprintf(f,[repmat('%.17g,',1,14),'%.17g\n'],values'); clear closefile;
  end
  write_text(fullfile(output_folder,'parameters.csv'),parameters);
  f = fopen(fullfile(output_folder,'routes.csv'),'w'); check_file(f); closefile=onCleanup(@() fclose(f));
  fprintf(f,'time_s,route_rate_bps,cumulative_model_bits,route\n');
  for k=1:numel(R.time_s)
    route = R.route_nodes{k};
    if isempty(route), name = 'disconnected'; else, name = strjoin(R.node_names(route),' -> '); end
    fprintf(f,'%.17g,%.17g,%.17g,%s\n',R.time_s(k),R.route_rate_bps(k),R.cumulative_key_bits(k),name);
  end
  clear closefile;
  f = fopen(fullfile(output_folder,'links.csv'),'w'); check_file(f); closefile=onCleanup(@() fclose(f));
  fprintf(f,'link,kind,time_s,distance_km,elevation_deg,visible,eta,qber_fraction,key_rate_bps,cumulative_model_bits\n');
  for j=1:numel(R.edges)
    e=R.edges(j);
    for k=1:numel(R.time_s)
      fprintf(f,'%s,%s,%.17g,%.17g,%.17g,%d,%.17g,%.17g,%.17g,%.17g\n', ...
        e.label,e.kind,R.time_s(k),e.distance_km(k),e.elevation_deg(k),e.visible(k), ...
        e.eta(k),e.qber(k),e.key_rate_bps(k),e.cumulative_key_bits(k));
    end
  end
  clear closefile;
  previous = graphics_toolkit(); cleanup_toolkit = onCleanup(@() graphics_toolkit(previous));
  if any(strcmp(available_graphics_toolkits(),'gnuplot')), graphics_toolkit('gnuplot'); end
  figures = network_plot_results(R,'off'); cleanup_figures=onCleanup(@() close_owned(figures));
  images = '';
  for k=1:numel(figures)
    name = sprintf('figure_%02d.png',k); set(figures(k),'paperpositionmode','auto');
    print(figures(k),fullfile(output_folder,name),'-dpng','-r120');
    images=[images,sprintf('<figure><img src="%s" alt="Scenario %d result page %d"></figure>',name,R.parameters.stage,k)];
  end
  summary = network_summary_text(R);
  summary = strrep(strrep(strrep(summary,'&','&amp;'),'<','&lt;'),'>','&gt;');
  if R.parameters.stage==3
    heading='Stage 3 | Two ground stations and one satellite';
  else
    heading='Stage 4 | Multi-Satellite Trusted-Node QKD Network';
  end
  write_text(fullfile(output_folder,'report.html'), ...
    ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">', ...
     '<title>Satellite network simulation</title><style>body{font:16px/1.6 system-ui;max-width:1200px;margin:30px auto;padding:20px;background:#eef4f8;color:#16324a}', ...
     'pre{white-space:pre-wrap;background:white;padding:24px}figure{margin:24px 0}img{width:100%}</style>', ...
     '<h1>',heading,'</h1><pre>',summary,'</pre>',images,'</html>']);
  fprintf('Saved completed network run: %s\n',output_folder);
end
function check_file(f)
  if f<0, error('Could not open export file for writing.'); end
end
function write_text(filename,value)
  f=fopen(filename,'w'); check_file(f); cleanup=onCleanup(@() fclose(f)); fprintf(f,'%s',value);
end
function close_owned(handles)
  for k=1:numel(handles), if ishandle(handles(k)), close(handles(k)); end; end
end
