function L = qkd_link_model(distance_km, P, alpha_db_km)
  % Same deterministic FSO and rate equations as notebook Sections 4-6.
  % Pass P explicitly, so edited settings take effect on every call.
  if nargin < 3, alpha_db_km = P.atmospheric_loss_db_km; end
  L.distance_km = distance_km;
  L.beam_radius = sqrt(P.w0_m^2 + (P.divergence_rad .* distance_km .* 1000).^2);
  L.eta_geo = 1 - exp(-2 * P.receiver_radius_m^2 ./ L.beam_radius.^2);
  L.eta_atm = 10 .^ (-alpha_db_km .* distance_km / 10);
  L.eta = L.eta_geo .* L.eta_atm .* P.optical_efficiency .* P.detector_efficiency;

  % eta already includes the detector efficiency. Do not apply it twice.
  signal = -expm1(-P.mu_signal .* L.eta);
  L.gain = signal + P.dark_yield; % Small-background additive approximation.
  denominator = max(L.gain, 1e-30);
  L.qber_bb84 = (P.bb84_misalignment .* signal + 0.5*P.dark_yield) ./ denominator;
  L.qber_dps = (((1-P.dps_visibility)/2) .* signal + 0.5*P.dark_yield) ./ denominator;

  L.rate_bb84 = 0.5 .* L.gain .* max(1-(1+P.ec_efficiency).*qkd_entropy(L.qber_bb84), 0);
  Y1 = 1 - (1-P.dark_yield).*(1-L.eta);
  e1 = (P.bb84_misalignment.*L.eta + 0.5*P.dark_yield) ./ max(Y1,1e-30);
  Q1 = P.mu_signal * exp(-P.mu_signal) .* Y1;
  L.rate_decoy = 0.5 .* max(Q1.*(1-qkd_entropy(min(e1,1))) ...
                     - L.gain.*P.ec_efficiency.*qkd_entropy(L.qber_bb84), 0);
  % This DPS curve is a teaching proxy, not a rigorous secure-key bound.
  L.rate_dps = L.gain .* max(1-(1+P.ec_efficiency).*qkd_entropy(L.qber_dps), 0);
end
