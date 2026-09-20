function B = bbm92_parameters()
  % Stage 3 CW pair source. Count rates aggregate all detectors per receiver.
  % Optics/detector efficiency, per-arm error and EC overhead reuse P.link.
  B.pair_rate_hz = 1e7;
  B.dark_count_rate_hz = 100;
  B.background_count_rate_hz = 100;
  B.coincidence_window_s = 1e-9; % Full width, after relative-delay correction.
  B.timing_fwhm_s = 0.5e-9;     % Combined A-B timestamp jitter distribution.
  B.basis_sift = 0.5;          % Unbiased bases; smaller values discard more.
end
