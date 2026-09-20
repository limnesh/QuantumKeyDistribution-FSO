function output_folder = qkd_export_results(R, output_parent)
  % Save ONE completed run in a new folder; keep previous runs available.
  % Saved data always uses R.parameters, which produced these results.
  if nargin < 2
    output_parent = fullfile(fileparts(mfilename('fullpath')),'results');
  end
  if ~exist(output_parent,'dir'), mkdir(output_parent); end
  base = ['run_', datestr(now,'yyyymmdd_HHMMSS')];
  output_folder = fullfile(output_parent,base); counter = 1;
  while exist(output_folder,'dir')
    output_folder = fullfile(output_parent,sprintf('%s_%02d',base,counter)); counter=counter+1;
  end
  mkdir(output_folder);
  save('-mat7-binary',fullfile(output_folder,'results.mat'),'R');
  write_text(fullfile(output_folder,'summary.txt'),qkd_summary_text(R));
  parameters = fieldnames(R.parameters);
  parameter_text = 'parameter,value';
  for k = 1:numel(parameters)
    parameter_text = sprintf('%s\n%s,%.17g',parameter_text,parameters{k},R.parameters.(parameters{k}));
  end
  write_text(fullfile(output_folder,'parameters.csv'),[parameter_text,sprintf('\n')]);
  L = R.link;
  matrix = [L.distance_km(:), L.eta(:), L.gain(:), L.qber_bb84(:), L.qber_dps(:), ...
            L.rate_bb84(:), L.rate_decoy(:), L.rate_dps(:), R.comparison.eta(:)];
  write_csv(fullfile(output_folder,'link_results.csv'), ...
    'distance_km,eta,gain,qber_bb84_fraction,qber_dps_fraction,bb84_rate_per_pulse,decoy_rate_per_pulse,dps_proxy_per_pulse,comparison_eta',matrix);
  S = R.eve_sweep;
  write_csv(fullfile(output_folder,'eve_sweep.csv'), ...
    'intercept_fraction,observed_qber_fraction,expected_qber_fraction,known_fraction_before_syndrome', ...
    [S.fractions(:),S.qber(:),S.expected_qber(:),S.known_fraction(:)]);
  write_csv(fullfile(output_folder,'ldpc_iterations.csv'),'iteration,unsatisfied_checks', ...
    [(0:numel(R.decoder_history)-1)',R.decoder_history(:)]);

  % Gnuplot exports hidden figures without requiring an OpenGL display.
  % Keep the dashboard's own Qt figures and the previous default intact.
  previous_toolkit = graphics_toolkit();
  toolkit_cleanup = onCleanup(@() graphics_toolkit(previous_toolkit));
  if any(strcmp(available_graphics_toolkits(),'gnuplot'))
    graphics_toolkit('gnuplot');
  end
  figures = qkd_plot_results(R,'off');
  cleanup = onCleanup(@() close_owned_figures(figures));
  images = '';
  for k = 1:numel(figures)
    filename = sprintf('figure_%02d.png',k);
    set(figures(k),'paperpositionmode','auto');
    print(figures(k),fullfile(output_folder,filename),'-dpng','-r130');
    images = [images,sprintf('<figure><img src="%s" alt="QKD visual results page %d"></figure>\n',filename,k)];
  end
  summary = escape_html(qkd_summary_text(R));
  html = ['<!doctype html><html lang="en"><meta charset="utf-8">', ...
    '<meta name="viewport" content="width=device-width,initial-scale=1">', ...
    '<title>QKD over FSO - Octave results</title>', ...
    '<style>body{font:17px/1.6 system-ui,sans-serif;background:#eef3f7;color:#15324f;', ...
    'max-width:1150px;margin:35px auto;padding:0 22px}h1{line-height:1.2}', ...
    'pre{white-space:pre-wrap;background:white;padding:24px;border-radius:12px;font-size:14px}', ...
    'figure{margin:24px 0}img{width:100%;height:auto;background:white;border-radius:12px}</style>', ...
    '<h1>QKD over FSO: your Octave run</h1>', ...
    '<p>Settings and outputs from one completed run. Compare the CSV tables or PNG figures with another saved run.</p>', ...
    '<pre>',summary,'</pre>',images,'</html>'];
  write_text(fullfile(output_folder,'report.html'),html);
  fprintf('Saved results to: %s\n',output_folder);
end

function write_text(path,text_value)
  file = fopen(path,'w');
  if file < 0, error('QKD:export','Cannot write %s.',path); end
  cleanup = onCleanup(@() fclose(file));
  fprintf(file,'%s',text_value);
end

function write_csv(path,header,data)
  file = fopen(path,'w');
  if file < 0, error('QKD:export','Cannot write %s.',path); end
  cleanup = onCleanup(@() fclose(file));
  fprintf(file,'%s\n',header);
  if ~isempty(data)
    format = [repmat('%.17g,',1,size(data,2)-1),'%.17g\n'];
    fprintf(file,format,data');
  end
end

function close_owned_figures(handles)
  for k = 1:numel(handles)
    if ishandle(handles(k)), close(handles(k)); end
  end
end

function s = escape_html(s)
  s = strrep(s,'&','&amp;'); s = strrep(s,'<','&lt;'); s = strrep(s,'>','&gt;');
end
