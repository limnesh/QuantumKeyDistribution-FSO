function D = network_postprocess(R, baseP)
  % Separate detected-bit teaching example at the peak instantaneous route.
  % The integrated network rate is NOT the length of this example key.
  root = fileparts(fileparts(mfilename('fullpath')));
  old_path = path(); cleanup = onCleanup(@() path(old_path));
  addpath(fullfile(root,'1-Basic LOS FSO','QKD_FSO_Octave'));
  if nargin < 2, baseP = qkd_parameters(); end
  D.status = 'No positive-rate route: bit processing skipped.';
  D.route = R.route_nodes{R.best_index}; D.hops = {};
  D.edge_indices = []; D.final_bits = 0; D.final_key_match = false;
  D.alice_final = []; D.bob_final = []; D.relay_ciphertexts = {};
  D.time_s = R.time_s(R.best_index);
  if isempty(D.route), return; end
  for h = 1:numel(D.route)-1
    edge = find(arrayfun(@(e) (e.i == D.route(h) && e.j == D.route(h+1)) || ...
      (e.j == D.route(h) && e.i == D.route(h+1)), R.edges),1);
    P = baseP; P.use_fso_qber = false;
    P.demo_channel_qber = R.edges(edge).qber(R.best_index);
    % Separate independent seeded bit blocks, parity graphs and hash seeds.
    P.seed = baseP.seed + 100*(h-1);
    P.graph_seed = baseP.graph_seed + 100*(h-1);
    P.hash_seed = baseP.hash_seed + 100*(h-1);
    D.hops{h} = qkd_simulate(P); D.edge_indices(h) = edge;
  end
  lengths = cellfun(@(B) B.final_bits,D.hops);
  if any(lengths == 0) || ~all(cellfun(@(B) B.final_key_match,D.hops))
    D.status = 'A hop failed reconciliation or its output budget; no relay key.';
    return;
  end
  D.final_bits = min(lengths);
  D.alice_final = D.hops{1}.alice_final(1:D.final_bits);
  received = D.hops{1}.bob_final(1:D.final_bits);
  % First pair already shares K1. Each later hop transports K1 with a fresh
  % independent pair key using a one-time pad over an authenticated channel.
  for h = 2:numel(D.hops)
    ciphertext = xor(received,D.hops{h}.alice_final(1:D.final_bits));
    received = double(xor(ciphertext,D.hops{h}.bob_final(1:D.final_bits)));
    D.relay_ciphertexts{h-1} = double(ciphertext);
  end
  D.bob_final = received;
  D.final_key_match = isequal(D.alice_final,D.bob_final);
  D.status = sprintf('%d matching demonstration bits; every relay knows the key.',D.final_bits);
end
