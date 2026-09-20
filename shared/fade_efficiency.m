function A = fade_efficiency(eta,detector,factor,atmospheric)
  if nargin<4, atmospheric=true; end
  if ~isscalar(detector) || ~isfinite(detector) || detector<0 || detector>1 || ...
    any(~isfinite(eta(:))) || any(eta(:)<0 | eta(:)>detector+1e-14) || ...
    any(~isfinite(factor(:))) || any(factor(:)<=0), error('Invalid fading input'); end
  if ~atmospheric, factor=ones(size(eta)); end
  optical=zeros(size(eta)); if detector>0, optical=eta/detector; end
  A.eta_total_baseline=eta; A.fading_factor=factor;
  A.clipped=optical.*factor>1; A.clipping_fraction=mean(A.clipped(:));
  A.eta_total_faded=min(optical.*factor,1)*detector;
  same=factor==1; A.eta_total_faded(same)=eta(same);
end
