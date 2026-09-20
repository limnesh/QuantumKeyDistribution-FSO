function P = leo_parameters()
  % LEO_PARAMETERS  Independent extension: an ideal LEO optical downlink.
  % Edit these settings, then run run_leo_fso. Existing stages are unchanged.
  % This is a circular overhead pass above a stationary ground station.
  % No orbit propagator, TLE, Earth rotation, weather or finite-key proof is used.

  P.altitude_km = 500;
  P.earth_radius_km = 6371;
  P.earth_mu_km3_s2 = 398600.4418;
  P.min_elevation_deg = 10;
  P.pass_points = 401;              % Odd count includes exact closest approach.

  P.atmosphere_height_km = 20;        % Homogeneous effective attenuation shell.
  P.zenith_atmospheric_loss_db = 2;  % Total loss through the shell at zenith.
  P.pointing_loss_db = 1;            % Constant illustrative tracking penalty.
  P.w0_m = 0.05;
  P.divergence_rad = 10e-6;          % Gaussian 1/e^2 intensity radius divergence.
  P.receiver_radius_m = 0.50;        % Radius, hence one-metre receiver diameter.
  P.optical_efficiency = 0.70;
  P.detector_efficiency = 0.50;

  P.mu_signal = 0.50;
  P.dark_yield = 2e-6;               % Background click probability per gate.
  P.bb84_misalignment = 0.015;
  P.ec_efficiency = 1.16;
  P.pulse_rate_hz = 1e8;
  P.signal_duty_fraction = 0.80;     % Time/pulse allocation to signal states.
  P.example_elevation_deg = 60;      % Channel QBER for the existing bit demo.
end
