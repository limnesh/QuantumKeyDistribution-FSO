function L = leo_link_model(elevation_deg,P)
  % LEO_LINK_MODEL  Gaussian satellite-to-ground channel at given elevations.
  % Elevations are degrees in [0,90]. Rates are asymptotic illustrative
  % estimates per emitted signal pulse; key_rate_bps includes signal duty.
  % The background model counts clicks only when no signal click occurs.
  P = leo_validate_parameters(P);
  if ~isnumeric(elevation_deg) || ~isreal(elevation_deg) || isempty(elevation_deg) || ...
     any(~isfinite(elevation_deg(:))) || any(elevation_deg(:) < 0 | elevation_deg(:) > 90)
    error('LEO:elevation','Elevations must be finite real numbers from 0 to 90 degrees.');
  end
  L.elevation_deg = elevation_deg;
  e = elevation_deg*pi/180;
  Re = P.earth_radius_km; h = P.altitude_km;
  % Rationalized spherical intersection avoids cancellation near zenith.
  radial_delta = h*(2*Re+h);
  L.slant_range_km = radial_delta ./ (sqrt((Re*sin(e)).^2+radial_delta)+Re*sin(e));
  H = P.atmosphere_height_km;
  shell_delta = H*(2*Re+H);
  L.atmosphere_path_km = shell_delta ./ (sqrt((Re*sin(e)).^2+shell_delta)+Re*sin(e));
  L.beam_radius_m = hypot(P.w0_m,P.divergence_rad*L.slant_range_km*1000);
  L.eta_geo = -expm1(-2*P.receiver_radius_m^2 ./ L.beam_radius_m.^2);
  L.eta_atm = 10.^(-P.zenith_atmospheric_loss_db*L.atmosphere_path_km/(10*H));
  L.eta_pointing = ones(size(e))*10^(-P.pointing_loss_db/10);
  L.visible = elevation_deg >= P.min_elevation_deg-1e-10;
  L.eta = L.eta_geo .* L.eta_atm .* L.eta_pointing * ...
          P.optical_efficiency * P.detector_efficiency;
  L.eta(~L.visible) = 0;

  signal = -expm1(-P.mu_signal*L.eta);
  background_only = P.dark_yield*(1-signal);
  L.gain = signal + background_only; % Exact 1-(1-Y0)*exp(-mu*eta).
  L.gain(~L.visible) = 0;
  L.qber_bb84 = NaN(size(e));
  detected = L.gain > 0;
  L.qber_bb84(detected) = (P.bb84_misalignment*signal(detected) + ...
                         0.5*background_only(detected)) ./ L.gain(detected);
  single_yield = L.eta+(1-L.eta)*P.dark_yield;
  single_error = zeros(size(e));
  single_present = single_yield > 0;
  single_error(single_present) = (P.bb84_misalignment*L.eta(single_present)+ ...
    0.5*P.dark_yield*(1-L.eta(single_present))) ./ single_yield(single_present);
  single_gain = P.mu_signal*exp(-P.mu_signal)*single_yield;
  h_error = zeros(size(e));
  h_error(detected) = entropy_binary(L.qber_bb84(detected));
  L.rate_bb84 = 0.5*L.gain.*max(1-(1+P.ec_efficiency)*h_error,0);
  L.rate_decoy = 0.5*max(single_gain.*(1-entropy_binary(single_error)) - ...
                       P.ec_efficiency*L.gain.*h_error,0);
  L.rate_bb84(~detected) = 0;
  L.rate_decoy(~detected) = 0;
  emitted_signals_hz = P.pulse_rate_hz*P.signal_duty_fraction;
  L.detected_rate_hz = emitted_signals_hz*L.gain;
  L.sifted_rate_hz = 0.5*L.detected_rate_hz;
  L.key_rate_bps = emitted_signals_hz*L.rate_decoy;
end

function h = entropy_binary(p)
  h = zeros(size(p));
  inside = p > 0 & p < 1;
  p = p(inside);
  h(inside) = -p.*log2(p)-(1-p).*log2(1-p);
end
