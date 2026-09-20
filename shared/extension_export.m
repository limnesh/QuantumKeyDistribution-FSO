function folder=extension_export(R,folder)
  if nargin<2, folder=fullfile(pwd,'dps_turbulence_octave',datestr(now,'yyyymmdd_HHMMSS')); end
  if ~exist(folder,'dir'), mkdir(folder); end
  save('-mat7-binary',fullfile(folder,'results.mat'),'R');
  fid=fopen(fullfile(folder,'results.json'),'w'); if fid<0, error('Cannot open export'); end
  cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s',jsonencode(R)); clear cleanup;
  write_series(R,fullfile(folder,'timeseries.csv'));
  if isfield(R,'edges')
    for k=1:numel(R.edges), write_series(R.edges{k},fullfile(folder,sprintf('edge_%d.csv',k))); end
    fid=fopen(fullfile(folder,'routes.csv'),'w'); cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'time_s,rate_bits_per_second,route_nodes\n');
    for k=1:numel(R.time_s), fprintf(fid,'%.17g,%.17g,%s\n',R.time_s(k),R.rate_bits_per_second(k),sprintf('%d-',R.route_nodes{k})); end
    clear cleanup;
  end
  if isfield(R,'inventory'), I=R.inventory; I.time_s=R.time_s; write_series(I,fullfile(folder,'trusted_inventory.csv')); end
  if isfield(R,'bbm92') && R.bbm92.available, B=R.bbm92; B.time_s=R.time_s; write_series(B,fullfile(folder,'bbm92.csv')); end
  figures=extension_plot(R,'off'); cleanup=onCleanup(@() close(figures));
  for k=1:numel(figures)
    if any(strcmp(available_graphics_toolkits(),'gnuplot')), graphics_toolkit(figures(k),'gnuplot'); end
    print(figures(k),fullfile(folder,sprintf('figure_%02d.png',k)),'-dpng','-r120');
  end
  fid=fopen(fullfile(folder,'report.html'),'w'); cleanup2=onCleanup(@() fclose(fid));
  fprintf(fid,'<!doctype html><meta charset="utf-8"><h1>Stage %d DPS / turbulence</h1><p>%s</p><pre>%s</pre>',R.stage,R.metadata.security_status,jsonencode(R.summary));
  for k=1:numel(figures), fprintf(fid,'<img style="max-width:100%%" src="figure_%02d.png">',k); end
end
function write_series(R,filename)
  n=numel(R.time_s); fields=fieldnames(R); selected={}; values=[];
  for k=1:numel(fields)
    v=R.(fields{k});
    if (isnumeric(v) || islogical(v)) && isvector(v) && numel(v)==n
      selected{end+1}=fields{k}; values(:,end+1)=v(:);
    end
  end
  fid=fopen(filename,'w'); if fid<0, error('Cannot open CSV'); end
  cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',strjoin(selected,','));
  fprintf(fid,[repmat('%.17g,',1,numel(selected)-1),'%.17g\n'],values');
end
