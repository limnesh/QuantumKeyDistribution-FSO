function P = qkd_validate_parameters(P)
  % Reject bad entries before starting a calculation or allocating big arrays.
  if ~isstruct(P) || ~isscalar(P)
    error('QKD:parameters', 'Parameters must be one struct from qkd_parameters().');
  end
  defaults = qkd_parameters();
  names = fieldnames(defaults);
  for k = 1:numel(names)
    name = names{k};
    if ~isfield(P, name)
      error('QKD:parameters', 'Missing parameter: %s.', name);
    end
    value = P.(name);
    if ~(isnumeric(value) || islogical(value)) || ~isscalar(value) || ...
       ~isreal(value) || ~isfinite(value)
      error('QKD:parameters', '%s must be one finite real number.', name);
    end
  end
  range(P, 'w0_m', 1e-9, 100);
  range(P, 'divergence_rad', 0, 1);
  range(P, 'receiver_radius_m', 1e-9, 100);
  range(P, 'atmospheric_loss_db_km', 0, 100);
  range(P, 'comparison_loss_db_km', 0, 100);
  range(P, 'optical_efficiency', 0, 1);
  range(P, 'detector_efficiency', 0, 1);
  range(P, 'mu_signal', 1e-9, 1);
  range(P, 'dark_yield', 0, 0.1);
  range(P, 'bb84_misalignment', 0, 0.5);
  range(P, 'dps_visibility', 0, 1);
  range(P, 'ec_efficiency', 1, 10);
  range(P, 'distance_min_km', 0, 10000);
  range(P, 'distance_max_km', 0, 10000);
  if P.distance_max_km <= P.distance_min_km
    error('QKD:parameters', 'distance_max_km must be greater than distance_min_km.');
  end
  range(P, 'demo_distance_km', 0, 10000);
  range(P, 'turbulence_strength', 0, 2);
  range(P, 'eve_intercept_fraction', 0, 1);
  range(P, 'demo_channel_qber', 0, 0.5);
  range(P, 'ldpc_check_fraction', 0.1, 0.9);
  integer(P, 'distance_points', 2, 10000);
  integer(P, 'mc_samples', 2, 1000000);
  integer(P, 'n_signals', 100, 100000);
  integer(P, 'eve_sweep_signals', 100, 1000000);
  integer(P, 'ldpc_column_weight', 1, 8);
  integer(P, 'max_iterations', 1, 500);
  integer(P, 'requested_final_bits', 0, 4096);
  integer(P, 'reserve_bits', 0, 100000);
  integer(P, 'use_fso_qber', 0, 1);
  seeds = {'seed','graph_seed','fading_seed','sweep_seed','hash_seed'};
  for k = 1:numel(seeds), integer(P, seeds{k}, 0, 2^32-1); end
  P.use_fso_qber = logical(P.use_fso_qber);
end

function range(P, name, low, high)
  if P.(name) < low || P.(name) > high
    error('QKD:parameters', '%s must be between %g and %g.', name, low, high);
  end
end

function integer(P, name, low, high)
  range(P, name, low, high);
  if P.(name) ~= fix(P.(name))
    error('QKD:parameters', '%s must be a whole number.', name);
  end
end
