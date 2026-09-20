function [key, first_col, first_row] = qkd_toeplitz_hash(bits, output_bits, seed, first_col, first_row)
  % Public Toeplitz universal-hash arithmetic over binary values.
  % Optional first_col/first_row let you verify a hand-worked matrix example.
  % Process one output row at a time, avoiding a large dense matrix.
  bits = double(bits(:)); n = numel(bits);
  if any(bits ~= 0 & bits ~= 1) || ~isscalar(output_bits) || ...
     output_bits < 0 || output_bits ~= fix(output_bits)
    error('QKD:hash', 'Input must be binary and output_bits a nonnegative integer.');
  end
  if output_bits == 0
    key = zeros(0,1); first_col = zeros(0,1); first_row = zeros(0,1); return;
  end
  if n == 0, error('QKD:hash', 'A positive output needs a nonempty input.'); end
  if nargin < 5
    old_rng = rng(); cleanup = onCleanup(@() rng(old_rng));
    rng(seed, 'twister');
    first_col = double(rand(output_bits,1) >= .5);
    first_row = double(rand(n,1) >= .5); first_row(1) = first_col(1);
  else
    first_col = double(first_col(:)); first_row = double(first_row(:));
    if numel(first_col) ~= output_bits || numel(first_row) ~= n || ...
       first_col(1) ~= first_row(1) || any([first_col;first_row] ~= 0 & [first_col;first_row] ~= 1)
      error('QKD:hash', 'The Toeplitz borders must be binary, correctly sized, and share their first bit.');
    end
  end
  diagonal_seed = [flipud(first_col(2:end)); first_row];
  key = zeros(output_bits,1);
  for i = 1:output_bits
    row = diagonal_seed(output_bits-i+(1:n));
    key(i) = mod(row(:)'*bits,2);
  end
end
