function factor = fading_factors(n,F,time_s,stream,innovations)
  if nargin<2, F=fading_parameters(); end
  if nargin<3, time_s=[]; end
  if nargin<4, stream=0; end
  if ~any(strcmp(F.mode,{'none','independent_lognormal','correlated_lognormal'})) || ...
    ~isscalar(F.sigma) || ~isfinite(F.sigma) || F.sigma<0 || F.sigma>1 || ...
    ~isscalar(F.correlation_time_s) || ~isfinite(F.correlation_time_s) || F.correlation_time_s<=0 || ...
    ~isscalar(F.seed) || ~isfinite(F.seed) || F.seed<0 || fix(F.seed)~=F.seed || ...
    ~isscalar(n) || ~isfinite(n) || n<1 || fix(n)~=n || ...
    ~isscalar(stream) || ~isfinite(stream) || stream<0 || fix(stream)~=stream
    error('Invalid fading parameters');
  end
  if strcmp(F.mode,'none'), factor=ones(1,n); return; end
  if nargin<5
    previous=rng(); cleanup=onCleanup(@() rng(previous));
    rng(mod(F.seed+104729*stream,2^32),'twister'); z=randn(1,n);
  else
    z=innovations(:)';
    if numel(z)~=n || any(~isfinite(z)), error('Invalid innovations'); end
  end
  x=z;
  if strcmp(F.mode,'correlated_lognormal')
    t=time_s(:)';
    if numel(t)~=n || any(~isfinite(t)) || any(diff(t)<=0), error('Need increasing physical times'); end
    for k=2:n
      a=(t(k)-t(k-1))/F.correlation_time_s; rho=exp(-a);
      x(k)=rho*x(k-1)+sqrt(-expm1(-2*a))*z(k);
    end
  end
  factor=exp(F.sigma*x-F.sigma^2/2);
end
