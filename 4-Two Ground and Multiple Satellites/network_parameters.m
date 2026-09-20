function P = network_parameters(stage)
  % NETWORK_PARAMETERS  Teaching models for two ground stations and relays.
  % Stage 3 uses one trusted satellite relay. Stage 4 uses 2..12 satellites.
  % All satellites share a circular coplanar orbit; Earth does not rotate.
  if nargin < 1, stage = 3; end
  if ~isnumeric(stage) || ~isscalar(stage) || ~isreal(stage) || ...
     ~isfinite(stage) || ~any(stage == [3,4])
    error('Network:stage','stage must be 3 or 4.');
  end
  network_setup_path();
  P.stage = stage;
  P.satellite_count = 1;
  P.ground_separation_km = 1000;
  P.satellite_span_deg = 0;
  P.duration_s = 1200;
  P.time_points = 601;
  P.isl_divergence_rad = 2e-6;
  P.isl_receiver_radius_m = 0.30;
  P.isl_pointing_loss_db = 1;
  P.isl_background_yield = 1e-7;
  P.isl_clearance_km = 20;
  P.enable_isl = 1;
  P.link = leo_parameters();
  if stage == 4
    P.satellite_count = 2;
    P.ground_separation_km = 3000;
    P.satellite_span_deg = P.ground_separation_km/P.link.earth_radius_km*180/pi;
  end
end
