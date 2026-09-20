function C = stage3_compare(R,B,mode)
  % One geometry, separate protocols. Classical pools are NOT quantum memory.
  if nargin<2, B=bbm92_parameters(); end
  if nargin<3, mode='trusted'; end
  if R.parameters.stage~=3, error('BBM92 comparison is restricted to Stage 3.'); end
  if ~any(strcmp(mode,{'trusted','bbm92'})), error('mode must be trusted or bbm92.'); end
  C.mode=mode; C.parameters=B; C.network=R; C.time_s=R.time_s;
  A=R.edges(1); D=R.edges(2); L=R.parameters.link; t=R.time_s;
  try
    E=bbm92_rates(A.eta,D.eta,A.visible,D.visible,L,B);
    E.available=true; E.reason='';
  catch err
    if strcmp(mode,'bbm92'), rethrow(err); end
    names={'singles_a_hz','singles_b_hz','true_coincidence_hz','accepted_true_hz', ...
      'accidental_coincidence_hz','coincidence_hz','qber','sifted_rate_bps','key_rate_bps'};
    for k=1:numel(names), E.(names{k})=NaN(size(t)); end
    E.available=false; E.reason=err.message;
    E.eta_a=A.eta; E.eta_b=D.eta; E.visible_a=A.visible; E.visible_b=D.visible;
    E.common_visibility=A.visible & D.visible;
  end
  E.cumulative_key_bits=cumtrapz(t,E.key_rate_bps);
  E.metrics.peak_key_rate_bps=max(E.key_rate_bps);
  E.metrics.integrated_key_bits=E.cumulative_key_bits(end);
  E.metrics.true_coincidences=trapz(t,E.true_coincidence_hz);
  E.metrics.measured_coincidences=trapz(t,E.coincidence_hz);
  E.metrics.common_visibility_s=trapz(t,double(E.common_visibility));
  E.metrics.pooled_qber=NaN;
  if E.metrics.measured_coincidences>0
    errors=zeros(size(t)); valid=E.coincidence_hz>0;
    errors(valid)=E.qber(valid).*E.coincidence_hz(valid);
    E.metrics.pooled_qber=trapz(t,errors)/E.metrics.measured_coincidences;
  end
  C.bbm92=E;
  % Credit trapezoid-generated amounts at each interval end, starting empty.
  % Greedy unlimited demand consumes one bit from EACH pool per delivered bit.
  I.generated_a_bits=A.cumulative_key_bits; I.generated_b_bits=D.cumulative_key_bits;
  I.delivered_bits=min(I.generated_a_bits,I.generated_b_bits);
  I.delivered_step_bits=[0,diff(I.delivered_bits)];
  I.pool_a_bits=max(I.generated_a_bits-I.delivered_bits,0);
  I.pool_b_bits=max(I.generated_b_bits-I.delivered_bits,0);
  C.trusted.inventory=I;
  signal_a=-expm1(-L.mu_signal*A.eta); signal_b=-expm1(-L.mu_signal*D.eta);
  C.trusted.detection_a_hz=(signal_a+(1-signal_a)*L.dark_yield)*L.pulse_rate_hz*L.signal_duty_fraction;
  C.trusted.detection_b_hz=(signal_b+(1-signal_b)*L.dark_yield)*L.pulse_rate_hz*L.signal_duty_fraction;
  C.trusted.detection_a_hz(~A.visible)=0; C.trusted.detection_b_hz(~D.visible)=0;
  C.trusted.qber_a=A.qber; C.trusted.qber_b=D.qber;
  C.trusted.simultaneous_rate_bps=R.route_rate_bps;
  C.trusted.simultaneous_bits=R.cumulative_key_bits;
  C.trusted.delivered_bits=I.delivered_bits(end);
  if strcmp(mode,'trusted')
    C.architecture='Trusted Satellite Relay - Decoy-State BB84';
    C.selected_key_bits=C.trusted.delivered_bits;
  else
    C.architecture='Entanglement-Based Satellite QKD - BBM92';
    C.selected_key_bits=E.metrics.integrated_key_bits;
  end
end
