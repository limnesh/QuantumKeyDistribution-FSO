function R = dps_statistics(eta,D)
  % Exact independent threshold detectors, random double-click bit assignment.
  % eta includes detector efficiency ONCE. See DPS_THEORY.md.
  if nargin<2, D=dps_parameters(); end
  names=fieldnames(dps_parameters());
  for k=1:numel(names)
    v=D.(names{k});
    if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v), error('DPS parameters must be finite real scalars'); end
  end
  if D.mean_photons<0 || D.mean_photons>=.5 || D.visibility<0 || D.visibility>1 || ...
    D.background_per_detector<0 || D.background_per_detector>1 || abs(D.phase_error_rad)>pi/2 || ...
    D.ec_efficiency<1 || D.pulse_rate_hz<0 || D.duty<0 || D.duty>1 || ...
    D.train_pulses<2 || fix(D.train_pulses)~=D.train_pulses || D.guard_slots<1 || fix(D.guard_slots)~=D.guard_slots
    error('Invalid DPS parameters');
  end
  if ~isreal(eta) || any(~isfinite(eta(:))) || any(eta(:)<0 | eta(:)>1), error('Invalid efficiency'); end
  e=(1-D.visibility*cos(D.phase_error_rad))/2; lambda=D.mean_photons*eta;
  pc=-expm1(-lambda*(1-e))+D.background_per_detector*exp(-lambda*(1-e));
  pw=-expm1(-lambda*e)+D.background_per_detector*exp(-lambda*e);
  R.double_click_gain=pc.*pw; R.gain=pc+pw-R.double_click_gain;
  R.error_gain=pw.*(1-pc)+.5*R.double_click_gain;
  R.qber=NaN(size(eta)); k=R.gain>0; R.qber(k)=R.error_gain(k)./R.gain(k);
  q=R.qber; q(~isfinite(q))=.5; eb=min(q,6/38);
  collision=1-eb.^2-(1-6*eb).^2/2;
  fraction=max(-(1-2*D.mean_photons)*log2(collision)-D.ec_efficiency*dps_entropy(q),0);
  fraction(q>6/38)=0;
  R.valid_slot_fraction=(D.train_pulses-1)/D.train_pulses;
  emitted_hz=D.pulse_rate_hz*D.duty*D.train_pulses/(D.train_pulses+D.guard_slots);
  R.rate_bits_per_pulse=R.valid_slot_fraction*R.gain.*fraction;
  R.rate_bits_per_second=R.rate_bits_per_pulse*emitted_hz;
  R.detection_rate_hz=emitted_hz*R.valid_slot_fraction*R.gain;
  R.error_rate_hz=emitted_hz*R.valid_slot_fraction*R.error_gain;
  R.visibility_error=(1-D.visibility)/2; R.optical_error=e;
  R.protocol='DPS QKD'; R.model_name='dps_threshold_collision_proxy'; R.model_version='1.0';
  R.security_status='DPS illustrative rate proxy; no composable security bound established';
  R.parameters=D;
end
