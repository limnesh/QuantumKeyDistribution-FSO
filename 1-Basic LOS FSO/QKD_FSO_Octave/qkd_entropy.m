function h = qkd_entropy(p)
  % Binary entropy, in bits. h2(0)=h2(1)=0 exactly.
  if any(~isfinite(p(:))) || any(p(:) < 0 | p(:) > 1)
    error('QKD:entropy', 'Entropy probabilities must be finite and between 0 and 1.');
  end
  h = zeros(size(p));
  inside = p > 0 & p < 1;
  x = p(inside);
  h(inside) = -x .* log2(x) - (1-x) .* log2(1-x);
end
