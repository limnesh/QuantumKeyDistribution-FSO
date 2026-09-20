function B = qkd_bb84_eve(n_signals, intercept_fraction, channel_qber, seed)
  % Sample ideal detected BB84 signals, Eve's measurement, then basis sifting.
  % All bit arrays are column vectors. Bases: 0=Z, 1=X.
  if ~isscalar(n_signals) || n_signals < 1 || n_signals ~= fix(n_signals)
    error('QKD:signals', 'n_signals must be a positive integer.');
  end
  if ~isscalar(intercept_fraction) || ~isfinite(intercept_fraction) || ...
     intercept_fraction < 0 || intercept_fraction > 1 || ...
     ~isscalar(channel_qber) || ~isfinite(channel_qber) || channel_qber < 0 || channel_qber > .5
    error('QKD:probability', 'Eve fraction must be 0..1 and channel QBER 0..0.5.');
  end
  old_rng = rng(); cleanup = onCleanup(@() rng(old_rng));
  rng(seed, 'twister');
  alice_bits = rand(n_signals,1) >= .5;
  B.alice_bases = rand(n_signals,1) >= .5;
  B.bob_bases = rand(n_signals,1) >= .5;
  B.eve_bases = rand(n_signals,1) >= .5;
  B.intercepted = rand(n_signals,1) < intercept_fraction;

  eve_measured = rand(n_signals,1) >= .5;
  matched = B.eve_bases == B.alice_bases;
  eve_measured(matched) = alice_bits(matched);
  arriving_bits = alice_bits; arriving_bases = B.alice_bases;
  arriving_bits(B.intercepted) = eve_measured(B.intercepted);
  arriving_bases(B.intercepted) = B.eve_bases(B.intercepted);

  bob_random = rand(n_signals,1) >= .5;
  bob_measured = bob_random;
  matched_bob = B.bob_bases == arriving_bases;
  bob_measured(matched_bob) = arriving_bits(matched_bob);
  channel_errors = rand(n_signals,1) < channel_qber;
  bob_bits = xor(bob_measured, channel_errors);

  B.sift_mask = B.alice_bases == B.bob_bases;
  no_eve = bob_random;
  no_eve(B.sift_mask) = alice_bits(B.sift_mask);
  no_eve = xor(no_eve, channel_errors);
  B.alice_key = double(alice_bits(B.sift_mask));
  B.bob_key = double(bob_bits(B.sift_mask));
  B.bob_no_eve_key = double(no_eve(B.sift_mask));
  measured = double(eve_measured); measured(~B.intercepted) = -1;
  B.eve_sifted_measurements = measured(B.sift_mask);
  known = B.intercepted & (B.eve_bases == B.alice_bases);
  B.eve_known_mask = known(B.sift_mask);
  B.sifted_intercepted = B.intercepted(B.sift_mask);
  B.expected_qber = channel_qber + intercept_fraction/4 ...
                    - 2*channel_qber*intercept_fraction/4;
end
