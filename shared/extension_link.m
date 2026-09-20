function R = extension_link(eta,detector,t,protocol,F,D,L,visible,stream,atmospheric,stage1)
  if nargin<11, stage1=false; end
  factor=fading_factors(numel(eta),F,t,stream);
  A=fade_efficiency(eta,detector,factor,atmospheric);
  if strcmp(protocol,'DPS QKD')
    R=dps_statistics(A.eta_total_faded,D);
  elseif any(strcmp(protocol,{'BB84','Decoy-state BB84'}))
    signal=-expm1(-L.mu_signal*A.eta_total_faded);
    bg=(1-signal)*L.dark_yield; if stage1, bg=ones(size(signal))*L.dark_yield; end
    R.gain=signal+bg; R.qber=NaN(size(eta)); k=R.gain>0;
    R.qber(k)=(L.bb84_misalignment*signal(k)+.5*bg(k))./R.gain(k);
    q=R.qber; q(~isfinite(q))=.5; h=dps_entropy(q);
    y1=A.eta_total_faded+(1-A.eta_total_faded)*L.dark_yield;
    err=L.bb84_misalignment*A.eta_total_faded+.5*(1-A.eta_total_faded)*L.dark_yield;
    if stage1, err=L.bb84_misalignment*A.eta_total_faded+.5*L.dark_yield; end
    e1=zeros(size(eta)); k=y1>0; e1(k)=err(k)./y1(k);
    if strcmp(protocol,'BB84'), rate=.5*R.gain.*max(1-(1+L.ec_efficiency)*h,0);
    else, rate=.5*max(L.mu_signal*exp(-L.mu_signal)*y1.*(1-dps_entropy(min(e1,1)))-L.ec_efficiency*R.gain.*h,0); end
    R.rate_bits_per_pulse=rate; R.rate_bits_per_second=rate*L.pulse_rate_hz*L.signal_duty_fraction;
    R.detection_rate_hz=R.gain*L.pulse_rate_hz*L.signal_duty_fraction;
    R.error_rate_hz=q.*R.detection_rate_hz;
    R.protocol=protocol; R.security_status='BB84 asymptotic estimate';
  else, error('Unknown trusted-link protocol'); end
  names={'gain','rate_bits_per_pulse','rate_bits_per_second','detection_rate_hz','error_rate_hz','error_gain','double_click_gain'};
  for k=1:numel(names), if isfield(R,names{k}), R.(names{k})(~visible)=0; end; end
  R.qber(~visible)=NaN;
  names=fieldnames(A); for k=1:numel(names), R.(names{k})=A.(names{k}); end
  R.visible=visible; R.eta_detector=detector; R.fading_mode=F.mode;
  R.metadata.model_name='dps_fso_extension'; R.metadata.model_version='1.0';
  R.metadata.protocol=protocol; R.metadata.security_status=R.security_status;
  R.metadata.random_seed=F.seed; R.metadata.stream=stream; R.metadata.fading=F; R.metadata.dps=D;
  R.metadata.assumptions={'Quasi-static neighboring pulses','Independent edge terminals','Phenomenological collected-power fading','Detector efficiency applied once'};
  R.metadata.units=struct('time_s','s','distance_m','m','qber','fraction','gain','per valid gate', ...
    'rate_bits_per_pulse','bits/emitted pulse','rate_bits_per_second','bits/s','cumulative_rate_integral_bits','bits (proxy for DPS)');
  R.summary=extension_summary(R,t);
  if ~isempty(t), R.time_s=t; R.cumulative_rate_integral_bits=cumtrapz(t,R.rate_bits_per_second); end
  if strcmp(protocol,'DPS QKD')
    avg=dps_statistics(mean(A.eta_total_faded),D);
    R.summary.rate_at_mean_efficiency_bps=avg.rate_bits_per_second;
  end
end
