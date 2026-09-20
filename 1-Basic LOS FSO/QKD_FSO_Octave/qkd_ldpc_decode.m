function [error_estimate, converged, iterations, history] = qkd_ldpc_decode(H, target, p, max_iterations)
  % Sum-product belief propagation for H*error = target (mod 2).
  % history(1) is iteration zero; subsequent entries count unsatisfied checks.
  % CONVERGENCE means parity agreement. Verify the recovered key separately.
  [m,n] = size(H); target = double(target(:));
  if numel(target) ~= m || any(target ~= 0 & target ~= 1)
    error('QKD:syndrome', 'Target must contain one binary syndrome bit per check.');
  end
  if ~isscalar(p) || ~isfinite(p) || p < 0 || p > .5
    error('QKD:decoder', 'The crossover probability must be between 0 and 0.5.');
  end
  if ~isscalar(max_iterations) || max_iterations < 1 || max_iterations ~= fix(max_iterations)
    error('QKD:decoder', 'The iteration limit must be a positive integer.');
  end
  [checks,variables,values] = find(H);
  if any(values ~= 1), error('QKD:graph', 'H must be a binary parity-check matrix.'); end
  error_estimate = zeros(n,1); converged = false; iterations = 0;
  history = sum(target ~= 0);
  if history == 0, converged = true; return; end
  degree = full(sum(H ~= 0,2));
  max_degree = max([degree;1]);
  % Pad each check's edge list. Padding contributes multiplication by one.
  edge_table = zeros(m,max_degree); count = zeros(m,1);
  for k = 1:numel(checks)
    j = checks(k); count(j) = count(j)+1; edge_table(j,count(j)) = k;
  end
  valid = edge_table > 0;
  prior = log((1-min(max(p,1e-6),.499999))/min(max(p,1e-6),.499999));
  q = prior * ones(numel(checks),1);
  signs = 1-2*target;
  for iterations = 1:max_iterations
    % 1. Checks send parity-based evidence, excluding the recipient's message.
    v = ones(size(edge_table));
    v(valid) = tanh(min(max(q(edge_table(valid))/2,-10),10));
    left = [ones(m,1), cumprod(v(:,1:end-1),2)];
    right = [fliplr(cumprod(fliplr(v(:,2:end)),2)), ones(m,1)];
    products = bsxfun(@times, left.*right, signs);
    messages = 2*atanh(min(max(products,-.999999999),.999999999));
    r = zeros(numel(checks),1); r(edge_table(valid)) = messages(valid);
    % 2. Bits combine the prior and every incoming check message.
    totals = prior + accumarray(variables,r,[n,1]);
    error_estimate = double(totals < 0);
    unsatisfied = sum(mod(H*error_estimate,2) ~= target);
    history(end+1,1) = unsatisfied;
    if unsatisfied == 0, converged = true; return; end
    % 3. Send each check the combined evidence without its own contribution.
    q = totals(variables) - r;
  end
end
