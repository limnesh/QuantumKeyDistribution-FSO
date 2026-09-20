function output_folder = leo_export_results(R, output_parent)
  % Export a completed extension run; never replace an earlier run.
  if nargin < 2, output_parent=fullfile(fileparts(mfilename('fullpath')),'results'); end
  if ~exist(output_parent,'dir'), mkdir(output_parent); end
  base=['run_',datestr(now,'yyyymmdd_HHMMSS')]; output_folder=fullfile(output_parent,base); count=1;
  while exist(output_folder,'dir')
    output_folder=fullfile(output_parent,sprintf('%s_%02d',base,count)); count=count+1;
  end
  mkdir(output_folder);
  save('-mat7-binary',fullfile(output_folder,'results.mat'),'R');
  write_text(fullfile(output_folder,'summary.txt'),leo_summary_text(R));
  fields=fieldnames(R.parameters); parameters=sprintf('parameter,value\n');
  for k=1:numel(fields)
    parameters=[parameters,sprintf('%s,%.17g\n',fields{k},R.parameters.(fields{k}))];
  end
  write_text(fullfile(output_folder,'parameters.csv'),parameters);
  L=R.pass;
  write_csv(fullfile(output_folder,'satellite_pass.csv'), ...
    ['time_s,elevation_deg,slant_range_km,atmosphere_path_km,beam_radius_m,', ...
     'eta_geo,eta_atm,eta_pointing,eta,gain,qber_fraction,bb84_bits_per_signal_pulse,', ...
     'decoy_bits_per_signal_pulse,detected_rate_hz,sifted_rate_hz,model_key_rate_bps,cumulative_model_bits'], ...
    [L.time_s(:),L.elevation_deg(:),L.slant_range_km(:),L.atmosphere_path_km(:),L.beam_radius_m(:), ...
     L.eta_geo(:),L.eta_atm(:),L.eta_pointing(:),L.eta(:),L.gain(:),L.qber_bb84(:), ...
     L.rate_bb84(:),L.rate_decoy(:),L.detected_rate_hz(:),L.sifted_rate_hz(:), ...
     L.key_rate_bps(:),L.cumulative_key_bits(:)]);
  S=R.sweeps.altitude;
  write_csv(fullfile(output_folder,'altitude_comparison.csv'), ...
    'altitude_km,pass_duration_s,peak_model_key_rate_bps,integrated_asymptotic_model_bits', ...
    [S.altitude_km(:),S.pass_duration_s(:),S.peak_key_rate_bps(:),S.integrated_key_bits(:)]);
  if ~isempty(R.postprocessing)
    B=R.postprocessing; S=B.eve_sweep;
    write_csv(fullfile(output_folder,'example_eve_sweep.csv'), ...
      'eve_fraction,observed_qber_fraction,expected_qber_fraction,known_fraction_before_syndrome', ...
      [S.fractions(:),S.qber(:),S.expected_qber(:),S.known_fraction(:)]);
    write_csv(fullfile(output_folder,'example_ldpc_iterations.csv'),'iteration,unsatisfied_checks', ...
      [(0:numel(B.decoder_history)-1)',B.decoder_history(:)]);
    fields=fieldnames(B.parameters); values=sprintf('parameter,value\n');
    for k=1:numel(fields), values=[values,sprintf('%s,%.17g\n',fields{k},B.parameters.(fields{k}))]; end
    write_text(fullfile(output_folder,'example_processing_parameters.csv'),values);
  end
  previous=graphics_toolkit(); cleanup_toolkit=onCleanup(@() graphics_toolkit(previous));
  export_toolkit=previous;
  if any(strcmp(available_graphics_toolkits(),'gnuplot')), export_toolkit='gnuplot'; end
  graphics_toolkit(export_toolkit);
  figures=leo_plot_results(R,'off',export_toolkit); cleanup_figures=onCleanup(@() close_owned(figures));
  images='';
  for k=1:numel(figures)
    name=sprintf('figure_%02d.png',k); set(figures(k),'paperpositionmode','auto');
    print(figures(k),fullfile(output_folder,name),'-dpng','-r130');
    images=[images,sprintf('<figure><img src="%s" alt="LEO extension result page %d"></figure>',name,k)];
  end
  summary=leo_summary_text(R); summary=strrep(strrep(strrep(summary,'&','&amp;'),'<','&lt;'),'>','&gt;');
  write_text(fullfile(output_folder,'report.html'), ...
    ['<!doctype html><html lang="en"><meta charset="utf-8">', ...
     '<meta name="viewport" content="width=device-width,initial-scale=1">', ...
     '<title>LEO satellite FSO extension results</title><style>', ...
     'body{font:17px/1.6 system-ui,sans-serif;max-width:1150px;margin:35px auto;padding:0 22px;', ...
     'background:#eef3f7;color:#15324f}pre{white-space:pre-wrap;background:white;padding:24px;', ...
     'font-size:14px}figure{margin:24px 0}img{width:100%;height:auto}</style>', ...
     '<h1>LEO satellite FSO extension</h1><p>One completed simulation. ', ...
     'Pass-rate estimates and the selected-elevation bit example are distinct results.</p><pre>', ...
     summary,'</pre>',images,'</html>']);
  fprintf('Saved LEO extension results to: %s\n',output_folder);
end

function write_text(path,value)
  f=fopen(path,'w'); if f<0, error('LEO:export','Cannot write %s.',path); end
  cleanup=onCleanup(@() fclose(f)); fprintf(f,'%s',value);
end
function write_csv(path,header,data)
  f=fopen(path,'w'); if f<0, error('LEO:export','Cannot write %s.',path); end
  cleanup=onCleanup(@() fclose(f)); fprintf(f,'%s\n',header);
  if ~isempty(data), fprintf(f,[repmat('%.17g,',1,size(data,2)-1),'%.17g\n'],data'); end
end
function close_owned(handles)
  for k=1:numel(handles), if ishandle(handles(k)), close(handles(k)); end; end
end
