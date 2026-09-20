function figures = extension_plot(R,visibility)
  if nargin<2, visibility='on'; end
  figures=[]; t=R.time_s;
  figures(end+1)=figure('visible',visibility,'name','DPS / turbulence — protocol statistics');
  subplot(2,2,1); plot(t,R.rate_bits_per_second); xlabel('Time (s)'); ylabel('Rate (bits/s; proxy for DPS)'); grid on;
  title([R.metadata.protocol,' rate (proxy for DPS)'],'interpreter','none');
  subplot(2,2,2); plot(t,R.cumulative_rate_integral_bits); xlabel('Time (s)'); ylabel('Integrated bits (DPS proxy)'); grid on;
  if R.stage<3
    subplot(2,2,3); plot(t,100*R.qber); xlabel('Time (s)'); ylabel('Protocol QBER (%)'); grid on;
    subplot(2,2,4); plot(t,R.fading_factor); xlabel('Time (s)'); ylabel('Collected-power factor (1)'); grid on;
  else
    subplot(2,2,3); hold on; for k=1:numel(R.edges), plot(t,100*R.edges{k}.qber); end
    xlabel('Time (s)'); ylabel('Link QBER (%)'); legend(cellfun(@(e) e.label,R.edges,'UniformOutput',false));
    subplot(2,2,4); hold on; for k=1:numel(R.edges), plot(t,R.edges{k}.fading_factor); end
    xlabel('Time (s)'); ylabel('Collected-power factor (1)'); legend(cellfun(@(e) e.label,R.edges,'UniformOutput',false));
  end
  if R.stage==1
    figures(end+1)=figure('visible',visibility,'name','DPS distance / visibility / distributions');
    D=R.metadata.dps; P=R.scenario_parameters; distance=linspace(1,80,301); b=qkd_link_model(distance,P); x=dps_statistics(b.eta,D);
    subplot(3,2,1); plot(distance,x.qber*100); xlabel('Distance (km)'); ylabel('DPS QBER (%)');
    subplot(3,2,2); plot(distance,x.rate_bits_per_second); xlabel('Distance (km)'); ylabel('DPS proxy rate (bits/s)');
    v=linspace(.8,1,101); q=zeros(size(v)); rate=q; b=qkd_link_model(P.demo_distance_km,P);
    for k=1:numel(v), dp=D; dp.visibility=v(k); z=dps_statistics(b.eta,dp); q(k)=z.qber; rate(k)=z.rate_bits_per_second; end
    subplot(3,2,3); plot(v,q*100); xlabel('Visibility (1)'); ylabel('DPS QBER (%)');
    subplot(3,2,4); plot(v,rate); xlabel('Visibility (1)'); ylabel('DPS proxy rate (bits/s)');
    F=R.metadata.fading; F.mode='independent_lognormal'; L=P; L.pulse_rate_hz=1e8; L.signal_duty_fraction=.8;
    M=extension_link(ones(1,5000)*b.eta,P.detector_efficiency,[],'DPS QKD',F,D,L,true(1,5000),0,true,true);
    subplot(3,2,5); hist(M.qber*100,40); xlabel('DPS QBER (%)'); ylabel('Monte Carlo sample count');
    subplot(3,2,6); hist(M.rate_bits_per_second,40); xlabel('DPS proxy rate (bits/s)'); ylabel('Monte Carlo sample count');
    figures(end+1)=figure('visible',visibility,'name','Atmospheric fading / design sensitivity');
    subplot(2,2,1); hist(M.fading_factor,40); xlabel('Collected-power factor (1)'); ylabel('Monte Carlo sample count');
    radii=linspace(.05,.3,30); y=zeros(size(radii));
    for k=1:numel(radii), pp=P; pp.receiver_radius_m=radii(k); b=qkd_link_model(P.demo_distance_km,pp); z=dps_statistics(b.eta,D); y(k)=z.rate_bits_per_second; end
    subplot(2,2,2); plot(radii,y); xlabel('Receiver radius (m)'); ylabel('DPS proxy rate (bits/s)');
    b=qkd_link_model(P.demo_distance_km,P); bg=logspace(-8,-3,30);
    for k=1:numel(bg), dp=D; dp.background_per_detector=bg(k); z=dps_statistics(b.eta,dp); y(k)=z.rate_bits_per_second; end
    subplot(2,2,3); semilogx(bg,y); xlabel('Background / detector / gate (1)'); ylabel('DPS proxy rate (bits/s)');
    sigma=0:.1:.8; y=zeros(size(sigma));
    for k=1:numel(sigma), F.sigma=sigma(k); z=extension_link(ones(1,5000)*b.eta,P.detector_efficiency,[],'DPS QKD',F,D,L,true(1,5000),0,true,true); y(k)=z.summary.mean_rate_bps; end
    subplot(2,2,4); plot(sigma,y); xlabel('Log-irradiance sigma (1)'); ylabel('Mean DPS proxy rate (bits/s)');
  elseif R.stage==2
    figures(end+1)=figure('visible',visibility,'name','LEO geometry and elevation');
    subplot(2,2,1); plot(t,R.elevation_deg); xlabel('Time (s)'); ylabel('Elevation (deg)');
    subplot(2,2,2); plot(t,R.distance_m/1000,t,R.atmospheric_path_m/1000); xlabel('Time (s)'); ylabel('Length (km)'); legend('Slant range','Atmospheric shell');
    subplot(2,2,3); plot(R.elevation_deg,R.qber*100); xlabel('Elevation (deg)'); ylabel('Protocol QBER (%)');
    subplot(2,2,4); plot(R.elevation_deg,R.rate_bits_per_second); xlabel('Elevation (deg)'); ylabel('Rate (bits/s; proxy for DPS)');
  else
    figures(end+1)=figure('visible',visibility,'name','Network routes and capacities');
    subplot(2,2,1); hold on; for k=1:numel(R.edges), plot(t,R.edges{k}.rate_bits_per_second); end
    xlabel('Time (s)'); ylabel('Edge capacity (bits/s; proxy for DPS)'); legend(cellfun(@(e) e.label,R.edges,'UniformOutput',false));
    subplot(2,2,2); hold on; for k=1:numel(R.edges), plot(t,double(R.edges{k}.visible)); end
    xlabel('Time (s)'); ylabel('Geometric availability (0/1)');
    labels=cellfun(@(p) sprintf('%d-',p),R.route_nodes,'UniformOutput',false); [names,~,ids]=unique(labels);
    subplot(2,2,3); stairs(t,ids); xlabel('Time (s)'); ylabel('Selected route (node indices)'); set(gca,'ytick',1:numel(names),'yticklabel',names);
    subplot(2,2,4); stairs(t,double(R.rate_bits_per_second<=0)); xlabel('Time (s)'); ylabel('Disconnected / rate outage (0/1)');
    figures(end+1)=figure('visible',visibility,'name','Network topology');
    [~,j]=max(R.rate_bits_per_second); xy=R.positions_km(:,:,j); hold on;
    a=linspace(0,2*pi,300); plot(6371*cos(a),6371*sin(a)); plot(xy(:,1),xy(:,2),'o');
    for k=1:rows(xy), text(xy(k,1),xy(k,2),R.node_names{k}); end
    for k=1:numel(R.edges), e=R.edges{k}; plot(xy([e.i,e.j],1),xy([e.i,e.j],2)); end
    axis equal; xlabel('Orbital x (km)'); ylabel('Orbital y (km)');
  end
  if R.stage==3
    I=R.inventory; figures(end+1)=figure('visible',visibility,'name','Trusted classical pool budgets');
    subplot(2,2,1); plot(t,I.generated_a_bits,t,I.generated_b_bits); legend('A','B'); xlabel('Time (s)'); ylabel('Generated (proxy bits for DPS)');
    subplot(2,2,2); plot(t,I.pool_a_bits,t,I.pool_b_bits); legend('A','B'); xlabel('Time (s)'); ylabel('Remaining (proxy bits for DPS)');
    subplot(2,2,3); plot(t,I.delivered_bits); xlabel('Time (s)'); ylabel('Delivered (proxy bits for DPS)');
    subplot(2,2,4); plot(t,min(R.edges{1}.rate_bits_per_second,R.edges{2}.rate_bits_per_second)); xlabel('Time (s)'); ylabel('Bottleneck (proxy bits/s for DPS)');
    if R.bbm92.available
      B=R.bbm92; figures(end+1)=figure('visible',visibility,'name','BBM92 two-arm fading');
      subplot(2,2,1); plot(t,B.true_coincidence_hz,t,B.accidental_coincidence_hz); legend('True','Accidental'); xlabel('Time (s)'); ylabel('Coincidences (counts/s)');
      subplot(2,2,2); plot(t,B.singles_a_hz,t,B.singles_b_hz); legend('A','B'); xlabel('Time (s)'); ylabel('Singles (counts/s)');
      subplot(2,2,3); plot(t,B.qber*100); xlabel('Time (s)'); ylabel('BBM92 QBER (%)');
      subplot(2,2,4); plot(t,B.key_rate_bps); xlabel('Time (s)'); ylabel('BBM92 asymptotic rate (bits/s)');
    end
  end
  set(figures,'units','pixels','position',[50,50,1200,820],'paperpositionmode','auto');
  for fig=figures
    ax=findall(fig,'type','axes'); set(ax,'fontsize',10);
  end
end
