function R = leo_simulate(P,baseP)
  % LEO_SIMULATE  Ideal pass, design sweeps and reuse of the existing bit demo.
  % R.postprocessing remains the original teaching experiment: n_signals
  % counts detected signals, not photons emitted during this satellite pass.
  % Its terrestrial R.link is retained as legacy output, not satellite data.
  if nargin < 1, P = leo_parameters(); end
  P = leo_validate_parameters(P);
  extension_dir = fileparts(mfilename('fullpath'));
  existing_dir = fullfile(extension_dir,'..','1-Basic LOS FSO','QKD_FSO_Octave');
  previous_path = path(); path_cleanup = onCleanup(@() path(previous_path));
  addpath(existing_dir);
  if nargin < 2, baseP = qkd_parameters(); end
  baseP = qkd_validate_parameters(baseP);
  R.parameters = P;
  R.base_parameters = baseP; % Keep requested legacy settings even when skipped.
  R.pass = make_pass(P);
  R.example = leo_link_model(P.example_elevation_deg,P);
  R.pass_duration_s = R.pass.time_s(end)-R.pass.time_s(1);
  R.expected_detections = trapz(R.pass.time_s,R.pass.detected_rate_hz);
  R.expected_sifted_bits = trapz(R.pass.time_s,R.pass.sifted_rate_hz);
  R.integrated_key_bits = R.pass.cumulative_key_bits(end);
  if R.expected_detections > 0
    errors_hz = zeros(size(R.pass.time_s));
    valid = R.pass.detected_rate_hz > 0;
    errors_hz(valid) = R.pass.qber_bb84(valid).*R.pass.detected_rate_hz(valid);
    R.pooled_qber = trapz(R.pass.time_s,errors_hz)/R.expected_detections;
  else
    R.pooled_qber = NaN;
  end

  R.sweeps.elevation = leo_link_model(linspace(P.min_elevation_deg,90,181),P);
  altitudes = unique([300,400,500,600,800,1000,1200,1500,2000,P.altitude_km]);
  R.sweeps.altitude.altitude_km = altitudes;
  R.sweeps.altitude.pass_duration_s = zeros(size(altitudes));
  R.sweeps.altitude.peak_key_rate_bps = zeros(size(altitudes));
  R.sweeps.altitude.integrated_key_bits = zeros(size(altitudes));
  for k = 1:numel(altitudes)
    varied = P; varied.altitude_km = altitudes(k);
    pass = make_pass(varied);
    R.sweeps.altitude.pass_duration_s(k) = pass.time_s(end)-pass.time_s(1);
    R.sweeps.altitude.peak_key_rate_bps(k) = max(pass.key_rate_bps);
    R.sweeps.altitude.integrated_key_bits(k) = pass.cumulative_key_bits(end);
  end

  R.postprocessing = [];
  if R.example.gain > 0 && P.pulse_rate_hz*P.signal_duty_fraction > 0
    baseP.use_fso_qber = false;
    baseP.demo_channel_qber = R.example.qber_bb84;
    R.postprocessing = qkd_simulate(baseP);
    R.postprocessing_status = 'completed';
  else
    R.postprocessing_status = 'skipped_no_detections';
  end
end

function L = make_pass(P)
  Re = P.earth_radius_km;
  orbit_radius = Re+P.altitude_km;
  e_min = P.min_elevation_deg*pi/180;
  theta_max = acos(Re*cos(e_min)/orbit_radius)-e_min;
  omega = sqrt(P.earth_mu_km3_s2/orbit_radius^3);
  time_s = linspace(-theta_max/omega,theta_max/omega,P.pass_points);
  theta = omega*time_s;
  elevation_deg = atan2(orbit_radius*cos(theta)-Re, ...
                       orbit_radius*sin(abs(theta)))*180/pi;
  % Set analytic boundaries explicitly to avoid roundoff-triggered masking.
  elevation_deg([1,end]) = P.min_elevation_deg;
  elevation_deg((P.pass_points+1)/2) = 90;
  L = leo_link_model(elevation_deg,P);
  L.time_s = time_s;
  L.cumulative_key_bits = cumtrapz(time_s,L.key_rate_bps);
end
