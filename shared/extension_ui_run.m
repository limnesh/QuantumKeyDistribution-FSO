function X=extension_ui_run(stage,P,mode,B)
  if nargin<3, mode='trusted'; end
  if nargin<4, B=[]; end
  P=extension_ui_defaults(P,stage);
  if stage==1, protocols={'BB84','Decoy-state BB84','DPS QKD'}; else, protocols={'Decoy-state BB84','DPS QKD'}; end
  modes={'none','independent_lognormal','correlated_lognormal'};
  selections=[P.x_protocol,P.x_fading_mode,P.x_link_b_protocol];
  if any(~isfinite(selections)) || any(selections~=fix(selections)) || ...
    P.x_protocol<1 || P.x_protocol>numel(protocols) || P.x_fading_mode<1 || P.x_fading_mode>3 || P.x_link_b_protocol<1 || P.x_link_b_protocol>3
    error('Invalid protocol or turbulence selection');
  end
  if ~isscalar(P.x_realizations) || ~isfinite(P.x_realizations) || P.x_realizations<1 || P.x_realizations>100 || fix(P.x_realizations)~=P.x_realizations
    error('Independent realizations must be an integer from 1 to 100');
  end
  protocol=protocols{P.x_protocol}; F=fading_parameters(); D=dps_parameters();
  F.mode=modes{P.x_fading_mode}; F.sigma=P.x_sigma; F.correlation_time_s=P.x_tau_s; F.seed=P.x_seed;
  D.mean_photons=P.x_mean_photons; D.visibility=P.x_visibility; D.background_per_detector=P.x_background;
  D.phase_error_rad=P.x_phase_rad; D.ec_efficiency=P.x_ec; D.pulse_rate_hz=P.x_clock_hz;
  D.duty=P.x_duty; D.train_pulses=P.x_train_pulses; D.guard_slots=P.x_guard_slots;
  if stage==3 && P.x_link_b_protocol>1
    choices={'Decoy-state BB84','DPS QKD'}; protocol={protocol,choices{P.x_link_b_protocol-1}};
  end
  X=extension_simulate(stage,protocol,F,D,P,mode,B);
  no=F; no.mode='none'; X.deterministic=extension_simulate(stage,protocol,no,D,P,mode,B);
  X.ensemble=zeros(P.x_realizations,3);
  for k=1:P.x_realizations
    f=F; f.seed=F.seed+1000+k;
    Y=extension_simulate(stage,protocol,f,D,P,mode,B);
    X.ensemble(k,:)=[f.seed,Y.summary.integrated_rate_bits,Y.summary.outage_fraction];
  end
  strengths=[0,.2,.4,.6,.8]; totals=zeros(size(strengths));
  for k=1:numel(strengths)
    f=F; f.mode='independent_lognormal'; f.sigma=strengths(k);
    Y=extension_simulate(stage,protocol,f,D,P,mode,B);
    totals(k)=Y.summary.integrated_rate_bits;
  end
  X.sensitivity=struct('sigma',strengths,'integrated_bits',totals);
  if stage==2 || stage==4
    if stage==2, values=[5,10,20,30]; else, values=[2,3,4,6]; end
    totals=zeros(size(values));
    for k=1:numel(values)
      pp=P;
      if stage==2, pp.min_elevation_deg=values(k); else, pp.satellite_count=values(k); end
      Y=extension_simulate(stage,protocol,F,D,pp,mode,B);
      totals(k)=Y.summary.integrated_rate_bits;
    end
    X.sensitivity.design_values=values; X.sensitivity.design_bits=totals;
  end
  if stage==1
    d=linspace(P.distance_min_km,P.distance_max_km,P.distance_points); base=qkd_link_model(d,P);
    X.distance_sweep=dps_statistics(base.eta,D); X.distance_sweep.distance_km=d;
    v=linspace(.8,1,81); q=zeros(size(v)); rate=q; base=qkd_link_model(P.demo_distance_km,P);
    for k=1:numel(v), dp=D; dp.visibility=v(k); a=dps_statistics(base.eta,dp); q(k)=a.qber; rate(k)=a.rate_bits_per_second; end
    X.visibility_sweep=struct('visibility',v,'qber',q,'rate',rate);
    f=F; f.mode='independent_lognormal'; L=P; L.pulse_rate_hz=1e8; L.signal_duty_fraction=.8;
    X.monte_carlo=extension_link(ones(1,P.mc_samples)*base.eta,P.detector_efficiency,[],'DPS QKD',f,D,L,true(1,P.mc_samples),0,true,true);
    aperture=linspace(.05,.3,25); background=logspace(-8,-3,25); ar=zeros(size(aperture)); br=ar;
    for k=1:numel(aperture)
      pp=P; pp.receiver_radius_m=aperture(k); a=qkd_link_model(P.demo_distance_km,pp); z=dps_statistics(a.eta,D); ar(k)=z.rate_bits_per_second;
      dp=D; dp.background_per_detector=background(k); z=dps_statistics(base.eta,dp); br(k)=z.rate_bits_per_second;
    end
    X.design=struct('aperture',aperture,'aperture_rate',ar,'background',background,'background_rate',br);
  end
end
