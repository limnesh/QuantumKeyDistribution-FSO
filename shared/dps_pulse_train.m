function R = dps_pulse_train(bits,mu)
  if nargin<2, mu=.1; end
  if isempty(bits) || ~isvector(bits) || any(bits(:)~=0 & bits(:)~=1) || ~isscalar(mu) || ~isfinite(mu) || mu<0
    error('Require binary relative bits and nonnegative mean photons');
  end
  bits=bits(:)'; R.relative_bits=bits; R.phase_rad=pi*[0,mod(cumsum(bits),2)];
  R.amplitude=sqrt(mu)*exp(1i*R.phase_rad);
  a=[R.amplitude,0]; b=[0,R.amplitude];
  R.port_mean_photons=[abs((a+b)/2).^2;abs((a-b)/2).^2]';
  % Octave indices; exported physical slot numbers start at zero.
  R.valid_slots=1:numel(bits); R.discarded_slots=[0,numel(bits)+1];
end
