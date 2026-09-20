function H = qkd_ldpc_graph(n, m, column_weight, seed)
  % Sparse teaching matrix: balance check degrees, attach each bit to c checks.
  if min(n,m) < 1 || any([n,m,column_weight] ~= fix([n,m,column_weight])) || ...
     column_weight < 1 || column_weight > m
    error('QKD:graph', 'Matrix sizes must be positive integers and 1 <= column_weight <= m.');
  end
  old_rng = rng(); cleanup = onCleanup(@() rng(old_rng));
  rng(seed, 'twister');
  row_counts = zeros(m,1);
  rows = zeros(n*column_weight,1); cols = rows;
  for i = 1:n
    [~, order] = sort(row_counts);
    candidates = order(1:min(m,max(30,column_weight*12)));
    chosen = candidates(randperm(numel(candidates),column_weight));
    slots = (i-1)*column_weight + (1:column_weight);
    rows(slots) = chosen; cols(slots) = i;
    row_counts(chosen) = row_counts(chosen) + 1;
  end
  H = sparse(rows, cols, 1, m, n);
end
