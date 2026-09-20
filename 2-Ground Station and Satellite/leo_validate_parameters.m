function P = leo_validate_parameters(P)
  % Reject malformed or unsupported settings before allocating pass arrays.
  if ~isstruct(P) || ~isscalar(P)
    error('LEO:parameters','Parameters must be one struct from leo_parameters().');
  end
  names = fieldnames(leo_parameters());
  for k = 1:numel(names)
    name = names{k};
    if ~isfield(P,name)
      error('LEO:parameters','Missing parameter: %s.',name);
    end
    x = P.(name);
    if ~(isnumeric(x) || islogical(x)) || ~isscalar(x) || ~isreal(x) || ~isfinite(x)
      error('LEO:parameters','%s must be one finite real number.',name);
    end
  end
  in_range(P,'altitude_km',100,2000);
  in_range(P,'earth_radius_km',6000,7000);
  in_range(P,'earth_mu_km3_s2',1,1e7);
  in_range(P,'min_elevation_deg',0,89.9);
  in_range(P,'pass_points',3,10001);
  if P.pass_points ~= fix(P.pass_points) || mod(P.pass_points,2) ~= 1
    error('LEO:parameters','pass_points must be an odd whole number.');
  end
  in_range(P,'atmosphere_height_km',1e-6,100);
  if P.atmosphere_height_km >= P.altitude_km
    error('LEO:parameters','atmosphere_height_km must be below altitude_km.');
  end
  in_range(P,'zenith_atmospheric_loss_db',0,1000);
  in_range(P,'pointing_loss_db',0,1000);
  in_range(P,'w0_m',1e-9,100);
  in_range(P,'divergence_rad',0,1);
  in_range(P,'receiver_radius_m',1e-9,100);
  in_range(P,'optical_efficiency',0,1);
  in_range(P,'detector_efficiency',0,1);
  in_range(P,'mu_signal',0,1);
  in_range(P,'dark_yield',0,0.1);
  in_range(P,'bb84_misalignment',0,0.5);
  in_range(P,'ec_efficiency',1,10);
  in_range(P,'pulse_rate_hz',0,1e12);
  in_range(P,'signal_duty_fraction',0,1);
  in_range(P,'example_elevation_deg',0,90);
end

function in_range(P,name,low,high)
  if P.(name) < low || P.(name) > high
    error('LEO:parameters','%s must be between %g and %g.',name,low,high);
  end
end
