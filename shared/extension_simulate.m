function R = extension_simulate(stage,protocol,F,D,P,mode,BB)
  % Reuse legacy geometry and routing; no changes to old deterministic calls.
  if nargin<2, protocol='DPS QKD'; end
  if nargin<3, F=fading_parameters(); end
  if nargin<4, D=dps_parameters(); end
  if nargin<6, mode='trusted'; end
  if nargin<7, BB=[]; end
  root=fileparts(fileparts(mfilename('fullpath')));
  addpath(fullfile(root,'1-Basic LOS FSO','QKD_FSO_Octave'));
  addpath(fullfile(root,'2-Ground Station and Satellite'));
  if ~any(stage==1:4), error('Stage must be 1..4'); end
  if stage==1
    if nargin<5 || isempty(P), P=qkd_parameters(); end
    P=qkd_validate_parameters(P);
    if ~isfield(P,'extension_samples'), P.extension_samples=5000; end
    if ~isfield(P,'extension_dt_s'), P.extension_dt_s=.02; end
    if ~isscalar(P.extension_samples) || ~isfinite(P.extension_samples) || P.extension_samples<2 || ...
      fix(P.extension_samples)~=P.extension_samples || ~isscalar(P.extension_dt_s) || ...
      ~isfinite(P.extension_dt_s) || P.extension_dt_s<=0, error('Invalid sampling'); end
    t=(0:P.extension_samples-1)*P.extension_dt_s;
    b=qkd_link_model(P.demo_distance_km,P); eta=ones(size(t))*b.eta;
    L=P; L.pulse_rate_hz=1e8; L.signal_duty_fraction=.8;
    R=extension_link(eta,P.detector_efficiency,t,protocol,F,D,L,true(size(t)),0,true,true);
    R.distance_m=ones(size(t))*P.demo_distance_km*1000;
    R.eta_geometric=ones(size(t))*b.eta_geo; R.eta_atmospheric=ones(size(t))*b.eta_atm;
    R.eta_optical=ones(size(t))*P.optical_efficiency;
  elseif stage==2
    if nargin<5 || isempty(P), P=leo_parameters(); end
    P=leo_validate_parameters(P); re=P.earth_radius_km; ro=re+P.altitude_km;
    e=P.min_elevation_deg*pi/180; theta=acos(re/ro*cos(e))-e;
    omega=sqrt(P.earth_mu_km3_s2/ro^3); t=linspace(-theta/omega,theta/omega,P.pass_points);
    elev=atan2(ro*cos(omega*t)-re,ro*sin(abs(omega*t)))*180/pi;
    elev([1,end])=P.min_elevation_deg; elev((P.pass_points+1)/2)=90;
    b=leo_link_model(elev,P);
    R=extension_link(b.eta,P.detector_efficiency,t,protocol,F,D,P,b.visible,0,true);
    R.distance_m=b.slant_range_km*1000; R.elevation_deg=elev; R.atmospheric_path_m=b.atmosphere_path_km*1000;
    R.eta_geometric=b.eta_geo; R.eta_atmospheric=b.eta_atm; R.eta_pointing=b.eta_pointing;
    R.eta_optical=ones(size(t))*P.optical_efficiency; R.baseline=b;
  else
    folders={'3-Two Ground and One Satellite','4-Two Ground and Multiple Satellites'};
    addpath(fullfile(root,folders{stage-2}),'-begin');
    if nargin<5 || isempty(P), P=network_parameters(stage); end
    if P.stage~=stage, error('Stage mismatch'); end
    if ~any(strcmp(mode,{'trusted','bbm92'})) || (stage==4 && strcmp(mode,'bbm92')), error('BBM92 requires stage 3'); end
    B=network_simulate(P); t=B.time_s; edges=cell(size(B.edges));
    if iscell(protocol) && numel(protocol)~=numel(edges), error('Need one protocol per edge'); end
    for k=1:numel(edges)
      b=B.edges(k); L=P.link; dp=D; atmospheric=strcmp(b.kind,'ground');
      if ~atmospheric, L.dark_yield=P.isl_background_yield; dp.background_per_detector=P.isl_background_yield/2; end
      selected=protocol; if iscell(protocol), selected=protocol{k}; end
      E=extension_link(b.eta,L.detector_efficiency,t,selected,F,dp,L,b.visible,k-1,atmospheric);
      E.i=b.i; E.j=b.j; E.label=b.label; E.kind=b.kind;
      E.distance_m=b.distance_km*1000; E.elevation_deg=b.elevation_deg;
      if atmospheric
        ll=leo_link_model(min(90,max(0,b.elevation_deg)),L);
        E.atmospheric_path_m=ll.atmosphere_path_km*1000; E.eta_atmospheric=ll.eta_atm;
        E.eta_geometric=ll.eta_geo; E.eta_pointing=ll.eta_pointing;
      else
        E.eta_geometric=-expm1(-2*P.isl_receiver_radius_m^2./(L.w0_m^2+(P.isl_divergence_rad*E.distance_m).^2));
        E.eta_pointing=ones(size(t))*10^(-P.isl_pointing_loss_db/10);
      end
      E.eta_optical=ones(size(t))*L.optical_efficiency;
      edges{k}=E;
    end
    R.edges=edges; R.time_s=t; R.baseline=B; R.node_names=B.node_names; R.positions_km=B.positions_km;
    R.route_nodes=cell(size(t)); R.rate_bits_per_second=zeros(size(t));
    for j=1:numel(t)
      a=zeros(numel(B.node_names));
      for k=1:numel(edges), E=edges{k}; a(E.i,E.j)=E.rate_bits_per_second(j); a(E.j,E.i)=a(E.i,E.j); end
      [R.route_nodes{j},R.rate_bits_per_second(j)]=network_widest_path(a,1,rows(a));
    end
    R.cumulative_rate_integral_bits=cumtrapz(t,R.rate_bits_per_second);
    R.metadata=edges{1}.metadata;
    if any(cellfun(@(e) strcmp(e.protocol,'DPS QKD'),edges))
      R.metadata.security_status='DPS illustrative rate proxy; route and inventory are proxy budgets; no composable bound';
    end
    R.metadata.edge_protocols=cellfun(@(e) e.protocol,edges,'UniformOutput',false);
    if stage==3
      A=edges{1}; C=edges{2};
      I.generated_a_bits=A.cumulative_rate_integral_bits; I.generated_b_bits=C.cumulative_rate_integral_bits;
      I.delivered_bits=min(I.generated_a_bits,I.generated_b_bits); I.delivered_step_bits=[0,diff(I.delivered_bits)];
      I.pool_a_bits=max(I.generated_a_bits-I.delivered_bits,0); I.pool_b_bits=max(I.generated_b_bits-I.delivered_bits,0); R.inventory=I;
      try
        if isempty(BB), BB=bbm92_parameters(); end
        Q=bbm92_rates(A.eta_total_faded,C.eta_total_faded,A.visible,C.visible,P.link,BB);
        Q.available=true; Q.cumulative_rate_integral_bits=cumtrapz(t,Q.key_rate_bps);
      catch err
        if strcmp(mode,'bbm92'), rethrow(err); end
        Q=struct('available',false,'reason',err.message);
      end
      R.bbm92=Q;
      if strcmp(mode,'bbm92')
        R.rate_bits_per_second=Q.key_rate_bps; R.cumulative_rate_integral_bits=Q.cumulative_rate_integral_bits;
        R.metadata.protocol='BBM92'; R.metadata.security_status='BBM92 asymptotic estimate; high-loss coincidence approximation';
      end
    end
    R.summary.mean_rate_bps=mean(R.rate_bits_per_second); R.summary.median_rate_bps=median(R.rate_bits_per_second);
    rates=sort(R.rate_bits_per_second); pos=1+.05*(numel(rates)-1);
    R.summary.p05_rate_bps=rates(floor(pos))+(pos-floor(pos))*(rates(ceil(pos))-rates(floor(pos)));
    R.summary.outage_fraction=mean(R.rate_bits_per_second<=0);
    R.summary.time_outage_fraction=trapz(t,double(R.rate_bits_per_second<=0))/(t(end)-t(1));
    R.summary.integrated_rate_bits=R.cumulative_rate_integral_bits(end);
  end
  R.stage=stage; R.mode=mode; R.scenario_parameters=P;
end
