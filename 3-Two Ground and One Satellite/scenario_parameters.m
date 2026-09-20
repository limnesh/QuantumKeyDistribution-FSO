function P = scenario_parameters()
  % Edit settings here, then run this folder's run_scenario.m.
  addpath(fileparts(mfilename('fullpath')),'-begin');
  P = network_parameters(3);
  P.ground_separation_km = 1000;
  P.link.altitude_km = 500;
  P.link.min_elevation_deg = 10;
end
