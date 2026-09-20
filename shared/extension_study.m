function R=extension_study(stage,folder)
  % Reproducible fixed-geometry ensembles and sensitivity in GNU Octave.
  if nargin<2, folder=fullfile(pwd,sprintf('dps_turbulence_octave_stage%d',stage)); end
  F=fading_parameters(); F.mode='correlated_lognormal'; D=dps_parameters();
  R=extension_simulate(stage,'DPS QKD',F,D); no=F; no.mode='none'; B=extension_simulate(stage,'DPS QKD',no,D);
  extension_export(R,folder); extension_export(B,fullfile(folder,'deterministic'));
  values=zeros(12,3);
  for k=1:12
    f=F; f.seed=999+k; x=extension_simulate(stage,'DPS QKD',f,D);
    values(k,:)=[f.seed,x.summary.integrated_rate_bits,x.summary.outage_fraction];
  end
  csvwrite_header(fullfile(folder,'ensemble.csv'),'seed,integrated_proxy_bits,outage_fraction',values);
  sigma=[0,.2,.4,.6,.8]; sensitivity=zeros(25,3); count=0;
  for s=sigma
    for seed=2000:2004
      count=count+1; f=F; f.sigma=s; f.seed=seed; x=extension_simulate(stage,'DPS QKD',f,D);
      sensitivity(count,:)=[s,seed,x.summary.integrated_rate_bits];
    end
  end
  csvwrite_header(fullfile(folder,'turbulence_sensitivity.csv'),'sigma,seed,integrated_proxy_bits',sensitivity);
  fig=figure('visible','off'); graphics_toolkit(fig,'gnuplot');
  subplot(2,2,1); plot(R.time_s,R.rate_bits_per_second,B.time_s,B.rate_bits_per_second); legend('Faded','Deterministic'); xlabel('Time (s)'); ylabel('DPS proxy rate (bits/s)');
  subplot(2,2,2); hist(values(:,2),8); xlabel('Integrated DPS proxy (bits)'); ylabel('Realization count (1)');
  subplot(2,2,3); plot(values(:,1),values(:,3),'o'); xlabel('Independent seed (1)'); ylabel('Rate outage sample fraction (1)');
  means=arrayfun(@(s) mean(sensitivity(sensitivity(:,1)==s,3)),sigma);
  subplot(2,2,4); plot(sigma,means,'o-'); xlabel('Log-irradiance sigma (1)'); ylabel('Mean integrated DPS proxy (bits)');
  set(fig,'position',[50,50,1200,820],'paperpositionmode','auto');
  print(fig,fullfile(folder,'comparison_ensemble.png'),'-dpng','-r120'); close(fig);
  if stage==3 && R.bbm92.available
    fig=figure('visible','off'); graphics_toolkit(fig,'gnuplot');
    plot(R.time_s,R.bbm92.key_rate_bps,B.time_s,B.bbm92.key_rate_bps); legend('Faded','Deterministic');
    xlabel('Time (s)'); ylabel('BBM92 asymptotic rate (bits/s)');
    set(fig,'position',[50,50,1000,600],'paperpositionmode','auto');
    print(fig,fullfile(folder,'bbm92_comparison.png'),'-dpng','-r120'); close(fig);
  end
  if stage==2 || stage==4
    if stage==2, vals=[5,10,20,30]; else, vals=[2,3,4,6]; end
    design=zeros(20,3); count=0;
    for val=vals
      p=R.scenario_parameters;
      if stage==2, p.min_elevation_deg=val; else, p.satellite_count=val; end
      for seed=3000:3004
        count=count+1; f=F; f.seed=seed; x=extension_simulate(stage,'DPS QKD',f,D,p);
        design(count,:)=[val,seed,x.summary.integrated_rate_bits];
      end
    end
    csvwrite_header(fullfile(folder,'design_sensitivity.csv'),'parameter,seed,integrated_proxy_bits',design);
    fig=figure('visible','off'); graphics_toolkit(fig,'gnuplot');
    means=arrayfun(@(s) mean(design(design(:,1)==s,3)),vals); plot(vals,means,'o-');
    if stage==2, xlabel('Elevation cutoff (deg)'); else, xlabel('Satellite count (1)'); end
    ylabel('Mean integrated DPS proxy (bits)');
    set(fig,'position',[50,50,1000,600],'paperpositionmode','auto');
    print(fig,fullfile(folder,'design_sensitivity.png'),'-dpng','-r120'); close(fig);
  end
  fid=fopen(fullfile(folder,'report.html'),'a'); cleanup=onCleanup(@() fclose(fid));
  fprintf(fid,'<h2>Fixed geometry, independent realizations</h2><img style="max-width:100%%" src="comparison_ensemble.png">');
  if stage==3, fprintf(fid,'<img style="max-width:100%%" src="bbm92_comparison.png">'); end
  if stage==2 || stage==4, fprintf(fid,'<img style="max-width:100%%" src="design_sensitivity.png">'); end
end
function csvwrite_header(path,header,values)
  fid=fopen(path,'w'); cleanup=onCleanup(@() fclose(fid));
  fprintf(fid,'%s\n',header); fprintf(fid,'%.17g,%.17g,%.17g\n',values');
end
