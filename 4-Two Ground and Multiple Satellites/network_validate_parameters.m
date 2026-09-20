function P = network_validate_parameters(P)
  % Validate before allocating node, edge or sampled-time arrays.
  if ~isstruct(P) || ~isscalar(P)
    error('Network:parameters','Parameters must be one struct from network_parameters().');
  end
  defaults = network_parameters(3);
  names = fieldnames(defaults);
  for k = 1:numel(names)
    name = names{k};
    if ~isfield(P,name)
      error('Network:parameters','Missing parameter: %s.',name);
    end
    if strcmp(name,'link'), continue; end
    value = P.(name);
    if ~(isnumeric(value) || islogical(value)) || ~isscalar(value) || ...
       ~isreal(value) || ~isfinite(value)
      error('Network:parameters','%s must be one finite real number.',name);
    end
  end
  P.link = leo_validate_parameters(P.link);
  if ~any(P.stage == [3,4])
    error('Network:parameters','stage must be 3 or 4.');
  end
  in_range(P,'satellite_count',1,12);
  if P.satellite_count ~= fix(P.satellite_count)
    error('Network:parameters','satellite_count must be a whole number.');
  end
  if P.stage == 3 && (P.satellite_count ~= 1 || P.satellite_span_deg ~= 0)
    error('Network:parameters','Stage 3 requires one satellite and satellite_span_deg = 0.');
  end
  if P.stage == 4 && (P.satellite_count < 2 || P.satellite_span_deg <= 0)
    error('Network:parameters','Stage 4 requires at least two satellites and positive satellite_span_deg.');
  end
  in_range(P,'satellite_span_deg',0,180);
  in_range(P,'ground_separation_km',0,pi*P.link.earth_radius_km);
  if P.ground_separation_km <= 0
    error('Network:parameters','ground_separation_km must be positive.');
  end
  in_range(P,'duration_s',0,86400);
  if P.duration_s <= 0
    error('Network:parameters','duration_s must be positive.');
  end
  in_range(P,'time_points',3,10001);
  if P.time_points ~= fix(P.time_points) || mod(P.time_points,2) ~= 1
    error('Network:parameters','time_points must be an odd whole number.');
  end
  in_range(P,'isl_divergence_rad',0,1);
  in_range(P,'isl_receiver_radius_m',1e-9,100);
  in_range(P,'isl_pointing_loss_db',0,1000);
  in_range(P,'isl_background_yield',0,0.1);
  in_range(P,'isl_clearance_km',0,P.link.earth_radius_km);
  if ~any(P.enable_isl == [0,1])
    error('Network:parameters','enable_isl must be 0 or 1.');
  end
end

function in_range(P,name,low,high)
  if P.(name) < low || P.(name) > high
    error('Network:parameters','%s must be between %g and %g.',name,low,high);
  end
end
