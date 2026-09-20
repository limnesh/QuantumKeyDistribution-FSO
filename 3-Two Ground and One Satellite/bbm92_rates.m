function E = bbm92_rates(eta_a,eta_b,visible_a,visible_b,L,B)
  % BBM92_RATES  Independent Octave high-loss CW reference.
  % Neumann et al., PRA104 022406, arxiv.org/abs/2103.14639, Eqs3,6,8,10,13-17.
  % Symmetric basis-independent errors: E_phase=E_bit. Asymptotic only.
  % eta includes detection efficiency ONCE. Noise is registered counts/s.
  if nargin < 6, B=bbm92_parameters(); end
  names=fieldnames(bbm92_parameters());
  if ~isstruct(B) || ~isscalar(B), error('BBM92:parameters','Use bbm92_parameters().'); end
  for k=1:numel(names)
    if ~isfield(B,names{k}), error('BBM92:parameters','Missing %s.',names{k}); end
    v=B.(names{k});
    if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v)
      error('BBM92:parameters','Each BBM92 parameter must be a finite real scalar.');
    end
  end
  if min([B.pair_rate_hz B.dark_count_rate_hz B.background_count_rate_hz])<0 || ...
     min([B.coincidence_window_s B.timing_fwhm_s])<=0 || B.basis_sift<0 || B.basis_sift>.5
    error('BBM92:parameters','Rates must be nonnegative, timing positive, and basis_sift in [0,0.5].');
  end
  network_setup_path(); L=leo_validate_parameters(L);
  if ~isequal(size(eta_a),size(eta_b),size(visible_a),size(visible_b)) || ...
      ~isreal(eta_a) || ~isreal(eta_b) || any(~isfinite([eta_a(:);eta_b(:)])) || ...
      any([eta_a(:);eta_b(:)]<0 | [eta_a(:);eta_b(:)]>1) || ...
      any(~ismember([visible_a(:);visible_b(:)],[0,1]))
    error('BBM92:efficiency','Efficiencies must be equal-sized finite probabilities with boolean visibility arrays.');
  end
  E.visible_a=logical(visible_a); E.visible_b=logical(visible_b);
  E.common_visibility=E.visible_a & E.visible_b;
  E.eta_a=eta_a; E.eta_b=eta_b; E.eta_a(~E.visible_a)=0; E.eta_b(~E.visible_b)=0;
  noise=B.dark_count_rate_hz+B.background_count_rate_hz;
  E.singles_a_hz=B.pair_rate_hz*E.eta_a+noise; E.singles_a_hz(~E.visible_a)=0;
  E.singles_b_hz=B.pair_rate_hz*E.eta_b+noise; E.singles_b_hz(~E.visible_b)=0;
  common=E.common_visibility;
  if any(E.eta_a(common)>.1) || any(E.eta_b(common)>.1) || ...
     any(max(E.singles_a_hz(common),E.singles_b_hz(common))*B.coincidence_window_s>.1)
    error('BBM92:domain','BBM92 approximation requires eta <= 0.1 and singles*window <= 0.1 during common contact.');
  end
  E.timing_acceptance=erf(sqrt(log(2))*B.coincidence_window_s/B.timing_fwhm_s);
  E.true_coincidence_hz=B.pair_rate_hz*E.eta_a.*E.eta_b;
  E.true_coincidence_hz(~common)=0;
  E.accepted_true_hz=E.timing_acceptance*E.true_coincidence_hz;
  E.accidental_coincidence_hz=(-expm1(-E.singles_a_hz*B.coincidence_window_s)).* ...
    (-expm1(-E.singles_b_hz*B.coincidence_window_s))/B.coincidence_window_s;
  E.accidental_coincidence_hz(~common)=0;
  E.coincidence_hz=E.accepted_true_hz+E.accidental_coincidence_hz;
  E.true_pair_error=2*L.bb84_misalignment*(1-L.bb84_misalignment);
  errors=E.true_pair_error*E.accepted_true_hz+.5*E.accidental_coincidence_hz;
  E.qber=NaN(size(eta_a)); detected=E.coincidence_hz>0;
  E.qber(detected)=errors(detected)./E.coincidence_hz(detected);
  h=ones(size(eta_a)); p=E.qber(detected); values=zeros(size(p)); inside=p>0 & p<1;
  values(inside)=-p(inside).*log2(p(inside))-(1-p(inside)).*log2(1-p(inside));
  h(detected)=values;
  E.sifted_rate_bps=B.basis_sift*E.coincidence_hz;
  E.key_rate_bps=E.sifted_rate_bps.*max(1-(1+L.ec_efficiency)*h,0);
end
