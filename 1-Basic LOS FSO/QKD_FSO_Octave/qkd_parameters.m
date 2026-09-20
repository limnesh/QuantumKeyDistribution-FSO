function P = qkd_parameters()
  % QKD_PARAMETERS  Start here to change the experiment.
  % Save this file, then run run_qkd_fso again. No extra packages are needed.
  % Alternatively, type qkd_dashboard for a window with editable controls.
  % Probabilities use fractions: 0.02 means 2%, not 0.02%.

  % STEP 1: Choose the optical link. All radii are in metres.
  P.w0_m = 0.05;                    % Initial beam radius: 5 cm.
  P.divergence_rad = 50e-6;         % Beam divergence: 50 microradians.
  P.receiver_radius_m = 0.10;      % Bob's aperture radius: 10 cm.
  P.atmospheric_loss_db_km = 0.20; % Selected atmospheric loss.
  P.comparison_loss_db_km = 0.60;  % Second atmosphere shown in plots.
  P.optical_efficiency = 0.70;
  P.detector_efficiency = 0.25;

  % STEP 2: Choose signal and detector assumptions.
  P.mu_signal = 0.50;             % MEAN photons per weak coherent pulse.
  P.dark_yield = 2e-6;            % Background click probability per gate.
  P.bb84_misalignment = 0.015;    % Signal error probability: 1.5%.
  P.dps_visibility = 0.98;        % 1 is ideal visibility.
  P.ec_efficiency = 1.16;         % Assumed overhead for the RATE CURVES.

  % STEP 3: Choose distances and the turbulence example.
  P.distance_min_km = 0.5;
  P.distance_max_km = 80;
  P.distance_points = 240;
  P.demo_distance_km = 20;        % Example link and turbulence distance.
  P.turbulence_strength = 0.25;   % Teaching-model fading strength.
  P.mc_samples = 5000;           % Samples in the turbulence histogram.

  % STEP 4: Choose the bit experiment and Eve's interception.
  P.n_signals = 2400;            % DETECTED signals BEFORE BB84 sifting.
  P.eve_intercept_fraction = 0.08;% Eve intercepts 8% on average.
  P.demo_channel_qber = 0.02;    % Manual channel flips BEFORE Eve.
  P.use_fso_qber = false;        % false: match the notebook's separate demo.
                                % true: use FSO BB84 QBER at demo_distance.
  P.eve_sweep_signals = 100000;   % Signals per point in the Eve graph.

  % STEP 5: Choose the teaching LDPC code and decoding limit.
  P.ldpc_check_fraction = 0.50;   % m = floor(this fraction * sifted bits).
  P.ldpc_column_weight = 3;      % Number of checks touching each key bit.
  P.max_iterations = 80;

  % STEP 6: Choose the privacy-amplification demonstration.
  P.requested_final_bits = 256;  % Upper limit, NOT guaranteed output length.
  P.reserve_bits = 32;           % Illustrative reserve, not a security proof.

  % STEP 7: Fixed seeds reproduce results WITHIN Octave.
  % Octave and NumPy use different random sampling; bit strings may differ.
  P.seed = 11;
  P.graph_seed = 7;
  P.fading_seed = 123;
  P.sweep_seed = 23;
  P.hash_seed = 2026;
end
