function h = dps_entropy(p)
  h=zeros(size(p)); k=p>0 & p<1;
  h(k)=-p(k).*log2(p(k))-(1-p(k)).*log2(1-p(k));
end
