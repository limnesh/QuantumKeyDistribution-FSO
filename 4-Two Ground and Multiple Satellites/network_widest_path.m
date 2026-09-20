function [nodes, bottleneck] = network_widest_path(capacities, source, target)
  % NETWORK_WIDEST_PATH  Maximise the minimum positive edge capacity.
  % Zero means no edge. Ties select the lowest node index, with the first
  % equally good predecessor retained. This does not add parallel routes.
  if ~isnumeric(capacities) || ~isreal(capacities) || ndims(capacities) ~= 2 || ...
     isempty(capacities) || size(capacities,1) ~= size(capacities,2) || ...
     any(~isfinite(capacities(:))) || any(capacities(:) < 0)
    error('Network:graph','Capacities must be a finite nonnegative square matrix.');
  end
  count = size(capacities,1);
  if nargin < 2, source = 1; end
  if nargin < 3, target = count; end
  if ~valid_node(source,count) || ~valid_node(target,count)
    error('Network:graph','Source and target must each be one valid whole node index.');
  end
  nodes = [];
  bottleneck = 0;
  width = zeros(1,count);
  predecessor = zeros(1,count);
  visited = false(1,count);
  width(source) = Inf;
  for iteration = 1:count
    available = width;
    available(visited) = -1;
    [best,current] = max(available);
    if best <= 0, break; end
    visited(current) = true;
    if current == target, break; end
    for neighbor = 1:count
      if visited(neighbor) || capacities(current,neighbor) <= 0, continue; end
      candidate = min(best,capacities(current,neighbor));
      if candidate > width(neighbor)
        width(neighbor) = candidate;
        predecessor(neighbor) = current;
      end
    end
  end
  if ~visited(target), return; end
  bottleneck = width(target);
  nodes = target;
  while nodes(1) ~= source
    nodes = [predecessor(nodes(1)),nodes];
  end
end

function valid = valid_node(index,count)
  valid = isnumeric(index) && isscalar(index) && isreal(index) && ...
    isfinite(index) && index == fix(index) && index >= 1 && index <= count;
end
