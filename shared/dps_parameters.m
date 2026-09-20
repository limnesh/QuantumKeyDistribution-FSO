function D = dps_parameters()
  D.mean_photons=.1; D.visibility=.98; D.phase_error_rad=0;
  D.background_per_detector=1e-6; D.ec_efficiency=1.16;
  D.pulse_rate_hz=1e8; D.duty=.8; D.train_pulses=1024; D.guard_slots=1;
end
