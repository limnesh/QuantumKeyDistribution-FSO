function S = extension_summary(R,t)
  q=R.qber(isfinite(R.qber)); rate=R.rate_bits_per_second;
  S.mean_qber=mean(q); S.median_qber=percentile(q,50); S.p95_qber=percentile(q,95);
  S.mean_rate_bps=mean(rate); S.median_rate_bps=percentile(rate,50); S.p05_rate_bps=percentile(rate,5);
  S.outage_fraction=mean(rate<=0);
  if isempty(t), detections=sum(R.detection_rate_hz); errors=sum(R.error_rate_hz);
  else
    detections=trapz(t,R.detection_rate_hz); errors=trapz(t,R.error_rate_hz);
    S.integrated_rate_bits=trapz(t,rate);
    S.time_outage_fraction=trapz(t,double(rate<=0))/(t(end)-t(1));
  end
  S.pooled_qber=NaN; if detections>0, S.pooled_qber=errors/detections; end
end
function v=percentile(x,p)
  if isempty(x), v=NaN; return; end
  x=sort(x(:)); a=1+(numel(x)-1)*p/100;
  v=x(floor(a))+(a-floor(a))*(x(ceil(a))-x(floor(a)));
end
