function R = qkd_simulate(P)
  % Run the complete project, independent of plotting or a GUI.
  % Example: P=qkd_parameters(); P.eve_intercept_fraction=.2; R=qkd_simulate(P);
  P = qkd_validate_parameters(P); R.parameters = P;
  distances = linspace(P.distance_min_km,P.distance_max_km,P.distance_points);
  R.link = qkd_link_model(distances,P);
  R.comparison = qkd_link_model(distances,P,P.comparison_loss_db_km);
  R.example = qkd_link_model(P.demo_distance_km,P);

  % STEP 1: Sample fading at the selected example distance.
  old_rng = rng(); cleanup = onCleanup(@() rng(old_rng));
  rng(P.fading_seed,'twister');
  sigma = P.turbulence_strength * sqrt(P.demo_distance_km/10);
  fading = exp(-.5*sigma^2 + sigma*randn(P.mc_samples,1));
  eta = min(max(R.example.eta*fading,0),1);
  signal = -expm1(-P.mu_signal*eta);
  qber = (P.bb84_misalignment*signal + .5*P.dark_yield) ./ max(signal+P.dark_yield,1e-30);
  R.turbulence.eta_samples = eta;
  R.turbulence.qber_samples = qber;
  R.turbulence.mean_qber = mean(qber);
  sorted = sort(qber); position = 1+.95*(numel(sorted)-1);
  lo = floor(position); hi = ceil(position);
  R.turbulence.p95_qber = sorted(lo)+(position-lo)*(sorted(hi)-sorted(lo));

  % STEP 2: Match the notebook's manual channel QBER unless linked mode is on.
  R.channel_qber = P.demo_channel_qber;
  if P.use_fso_qber
    if R.example.gain <= 0
      error('QKD:noDetection', 'The selected FSO link predicts no detections. Change the link before using FSO QBER.');
    end
    R.channel_qber = R.example.qber_bb84;
  end

  % STEP 3: Sweep Eve's attack fraction and compare with theoretical averages.
  fractions = unique([linspace(0,1,11),P.eve_intercept_fraction]);
  R.eve_sweep.fractions = fractions;
  R.eve_sweep.qber = zeros(size(fractions));
  R.eve_sweep.known_fraction = zeros(size(fractions));
  R.eve_sweep.expected_qber = R.channel_qber + fractions/4 - 2*R.channel_qber*fractions/4;
  for k = 1:numel(fractions)
    B = qkd_bb84_eve(P.eve_sweep_signals,fractions(k),R.channel_qber,P.sweep_seed);
    R.eve_sweep.qber(k) = mean(B.alice_key ~= B.bob_key);
    R.eve_sweep.known_fraction(k) = mean(B.eve_known_mask);
  end

  % STEP 4: Create the finite bit block, then sift matching bases.
  R.eve = qkd_bb84_eve(P.n_signals,P.eve_intercept_fraction,R.channel_qber,P.seed);
  A = R.eve.alice_key; B = R.eve.bob_key;
  R.n_key = numel(A); R.observed_qber = mean(A ~= B);
  R.no_eve_qber = mean(A ~= R.eve.bob_no_eve_key);
  R.eve_known_bits = sum(R.eve.eve_known_mask);
  R.m_checks = floor(P.ldpc_check_fraction*R.n_key);
  R.abort_reason = '';
  R.converged = false; R.iterations = 0; R.decoder_history = [];
  R.estimated_error = zeros(R.n_key,1); R.bob_corrected = B;
  R.H = sparse(R.m_checks,R.n_key);
  R.syndrome_alice = zeros(R.m_checks,1); R.syndrome_bob = R.syndrome_alice;
  R.delta_s = R.syndrome_alice;
  if R.n_key == 0 || R.m_checks < P.ldpc_column_weight
    R.abort_reason = 'Too few sifted bits for the selected LDPC graph.';
  else
    % STEP 5: Exchange syndrome, estimate flips, and correct Bob.
    R.H = qkd_ldpc_graph(R.n_key,R.m_checks,P.ldpc_column_weight,P.graph_seed);
    R.syndrome_alice = mod(R.H*A,2); R.syndrome_bob = mod(R.H*B,2);
    R.delta_s = double(xor(R.syndrome_alice,R.syndrome_bob));
    [R.estimated_error,R.converged,R.iterations,R.decoder_history] = ...
      qkd_ldpc_decode(R.H,R.delta_s,R.observed_qber,P.max_iterations);
    R.bob_corrected = double(xor(B,R.estimated_error));
  end
  R.qber_after = mean(A ~= R.bob_corrected);
  R.reconciliation_ok = R.converged && isequal(A,R.bob_corrected) && R.n_key > 0;

  % STEP 6: Count public leakage and choose an illustrative output budget.
  R.leak_ec = R.m_checks;
  if R.n_key > 0, R.shannon_min = R.n_key*qkd_entropy(R.observed_qber);
  else, R.shannon_min = 0; end
  if R.shannon_min > 0, R.f_ec = R.leak_ec/R.shannon_min;
  else, R.f_ec = NaN; end % The ratio is undefined at zero measured QBER.
  R.demo_key_budget = max(0,floor(R.n_key-R.shannon_min-R.leak_ec-P.reserve_bits));
  R.final_bits = 0; R.alice_final = zeros(0,1); R.bob_final = zeros(0,1);
  R.final_key_match = false; R.hash_first_col = []; R.hash_first_row = [];
  if ~R.reconciliation_ok
    if isempty(R.abort_reason), R.abort_reason = 'Reconciliation did not recover Alice''s complete key.'; end
  elseif R.demo_key_budget == 0
    R.abort_reason = 'No positive illustrative entropy budget remains.';
  elseif P.requested_final_bits == 0
    R.abort_reason = 'The requested output length is zero.';
  else
    % STEP 7: Hash only verified matching inputs, with the same public seed.
    R.final_bits = min(P.requested_final_bits,R.demo_key_budget);
    [R.alice_final,R.hash_first_col,R.hash_first_row] = ...
      qkd_toeplitz_hash(A,R.final_bits,P.hash_seed);
    R.bob_final = qkd_toeplitz_hash(R.bob_corrected,R.final_bits,P.hash_seed, ...
                                   R.hash_first_col,R.hash_first_row);
    R.final_key_match = isequal(R.alice_final,R.bob_final);
  end
end
