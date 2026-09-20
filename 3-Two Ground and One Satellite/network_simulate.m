function R = network_simulate(P)
  % NETWORK_SIMULATE  Two fixed stations sharing keys via trusted relays.
  % Each edge has an independent simultaneous optical terminal and pulse
  % budget. Ground photons are downlinks; the shared key capacity is treated
  % as undirected. There is no direct ground edge or quantum repeater model.
  if nargin < 1, P = network_parameters(3); end
  P = network_validate_parameters(P);
  R.parameters = P;
  R.time_s = linspace(-P.duration_s/2,P.duration_s/2,P.time_points);
  satellite_count = P.satellite_count;
  node_count = satellite_count+2;
  earth_radius = P.link.earth_radius_km;
  orbit_radius = earth_radius+P.link.altitude_km;
  omega = sqrt(P.link.earth_mu_km3_s2/orbit_radius^3);
  station_angles = [-1,1]*P.ground_separation_km/(2*earth_radius);
  if satellite_count == 1
    phases = 0;
  else
    phases = linspace(-P.satellite_span_deg/2,P.satellite_span_deg/2,satellite_count)*pi/180;
  end
  R.node_names = cell(1,node_count);
  R.node_names{1} = 'Ground A';
  R.node_names{end} = 'Ground B';
  R.positions_km = zeros(node_count,2,P.time_points);
  R.positions_km(1,1,:) = earth_radius*cos(station_angles(1));
  R.positions_km(1,2,:) = earth_radius*sin(station_angles(1));
  R.positions_km(end,1,:) = earth_radius*cos(station_angles(2));
  R.positions_km(end,2,:) = earth_radius*sin(station_angles(2));
  for satellite = 1:satellite_count
    node = satellite+1;
    R.node_names{node} = sprintf('Sat %d',satellite);
    angle = phases(satellite)+omega*R.time_s;
    R.positions_km(node,1,:) = reshape(orbit_radius*cos(angle),1,1,[]);
    R.positions_km(node,2,:) = reshape(orbit_radius*sin(angle),1,1,[]);
  end

  edge_count = 2*satellite_count+satellite_count*(satellite_count-1)/2;
  empty = struct('i',0,'j',0,'label','','kind','','distance_km',[], ...
    'elevation_deg',[],'visible',[],'eta',[],'qber',[], ...
    'key_rate_bps',[],'cumulative_key_bits',[]);
  R.edges = repmat(empty,1,edge_count);
  edge_index = 0;
  for satellite = 1:satellite_count
    for station = 1:2
      edge_index = edge_index+1;
      station_node = 1+(station-1)*(node_count-1);
      satellite_node = satellite+1;
      edge = empty;
      edge.i = min(station_node,satellite_node);
      edge.j = max(station_node,satellite_node);
      edge.label = [R.node_names{edge.i},' - ',R.node_names{edge.j}];
      edge.kind = 'ground';
      difference = squeeze(R.positions_km(satellite_node,:,:)-R.positions_km(station_node,:,:));
      edge.distance_km = sqrt(sum(difference.^2,1));
      angle = station_angles(station);
      radial = cos(angle)*difference(1,:)+sin(angle)*difference(2,:);
      tangential = -sin(angle)*difference(1,:)+cos(angle)*difference(2,:);
      edge.elevation_deg = atan2(radial,abs(tangential))*180/pi;
      edge.visible = edge.elevation_deg >= P.link.min_elevation_deg-1e-10 & edge.elevation_deg >= 0;
      link = leo_link_model(min(90,max(0,edge.elevation_deg)),P.link);
      edge.eta = link.eta;
      edge.qber = link.qber_bb84;
      edge.key_rate_bps = link.key_rate_bps;
      edge.eta(~edge.visible) = 0;
      edge.qber(~edge.visible) = NaN;
      edge.key_rate_bps(~edge.visible) = 0;
      edge.cumulative_key_bits = cumtrapz(R.time_s,edge.key_rate_bps);
      R.edges(edge_index) = edge;
    end
  end
  for first = 1:satellite_count-1
    for second = first+1:satellite_count
      edge_index = edge_index+1;
      edge = empty;
      edge.i = first+1;
      edge.j = second+1;
      edge.label = [R.node_names{edge.i},' - ',R.node_names{edge.j}];
      edge.kind = 'isl';
      start_point = squeeze(R.positions_km(edge.i,:,:));
      end_point = squeeze(R.positions_km(edge.j,:,:));
      segment = end_point-start_point;
      distance_squared = sum(segment.^2,1);
      edge.distance_km = sqrt(distance_squared);
      fraction = zeros(size(distance_squared));
      nonzero = distance_squared > 0;
      numerator = -sum(start_point.*segment,1);
      fraction(nonzero) = min(1,max(0,numerator(nonzero)./distance_squared(nonzero)));
      closest = start_point+segment.*repmat(fraction,2,1);
      clearance = sqrt(sum(closest.^2,1));
      edge.elevation_deg = NaN(size(R.time_s));
      edge.visible = logical(P.enable_isl) & clearance > earth_radius+P.isl_clearance_km;
      [edge.eta,edge.qber,edge.key_rate_bps] = vacuum_link(edge.distance_km,edge.visible,P);
      edge.cumulative_key_bits = cumtrapz(R.time_s,edge.key_rate_bps);
      R.edges(edge_index) = edge;
    end
  end

  R.route_nodes = cell(1,P.time_points);
  R.route_rate_bps = zeros(1,P.time_points);
  for sample = 1:P.time_points
    capacities = zeros(node_count);
    for k = 1:numel(R.edges)
      edge = R.edges(k);
      capacities(edge.i,edge.j) = edge.key_rate_bps(sample);
      capacities(edge.j,edge.i) = edge.key_rate_bps(sample);
    end
    [R.route_nodes{sample},R.route_rate_bps(sample)] = network_widest_path(capacities,1,node_count);
  end
  R.cumulative_key_bits = cumtrapz(R.time_s,R.route_rate_bps);
  [R.metrics.peak_rate_bps,R.best_index] = max(R.route_rate_bps);
  if R.metrics.peak_rate_bps == 0, R.best_index = (P.time_points+1)/2; end
  R.metrics.integrated_key_bits = R.cumulative_key_bits(end);
  R.metrics.connected_duration_s = trapz(R.time_s,double(R.route_rate_bps > 0));
  R.metrics.stored_pair_bits = NaN;
  if P.stage == 3
    % Post-window independent pair-key pools can support later trusted relay.
    % This does not require both links to be available simultaneously and is
    % distinct from the instantaneous route integral above.
    R.metrics.stored_pair_bits = min(R.edges(1).cumulative_key_bits(end), ...
                                    R.edges(2).cumulative_key_bits(end));
  end
end

function [eta,qber,rate] = vacuum_link(distance_km,visible,P)
  link = P.link;
  beam_radius = hypot(link.w0_m,P.isl_divergence_rad*distance_km*1000);
  eta = -expm1(-2*P.isl_receiver_radius_m^2./beam_radius.^2) * ...
    10^(-P.isl_pointing_loss_db/10)*link.optical_efficiency*link.detector_efficiency;
  eta(~visible) = 0;
  signal = -expm1(-link.mu_signal*eta);
  background = P.isl_background_yield*(1-signal);
  gain = signal+background;
  gain(~visible) = 0;
  qber = NaN(size(distance_km));
  detected = gain > 0;
  qber(detected) = (link.bb84_misalignment*signal(detected)+0.5*background(detected))./gain(detected);
  single_yield = eta+(1-eta)*P.isl_background_yield;
  single_error = zeros(size(distance_km));
  single_present = single_yield > 0;
  single_error(single_present) = (link.bb84_misalignment*eta(single_present)+ ...
    0.5*P.isl_background_yield*(1-eta(single_present)))./single_yield(single_present);
  single_gain = link.mu_signal*exp(-link.mu_signal)*single_yield;
  error_entropy = zeros(size(distance_km));
  error_entropy(detected) = entropy_binary(qber(detected));
  rate = 0.5*max(single_gain.*(1-entropy_binary(single_error))- ...
    link.ec_efficiency*gain.*error_entropy,0)*link.pulse_rate_hz*link.signal_duty_fraction;
  rate(~detected) = 0;
end

function entropy = entropy_binary(probability)
  entropy = zeros(size(probability));
  inside = probability > 0 & probability < 1;
  values = probability(inside);
  entropy(inside) = -values.*log2(values)-(1-values).*log2(1-values);
end
