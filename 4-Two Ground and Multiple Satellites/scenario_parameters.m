function P = scenario_parameters()
  % Edit settings here, then run this folder's run_scenario.m.
  addpath(fileparts(mfilename('fullpath')),'-begin');
  P = network_parameters(4);
  P.satellite_count = 2; % Set 3, 4, ... up to 12 nodes.
  P.ground_separation_km = 3000;
  P.satellite_span_deg = P.ground_separation_km/P.link.earth_radius_km*180/pi;
  P.link.altitude_km = 500;
end
