function axes_out = qkd_draw_page(R, page, fig, area)
% QKD_DRAW_PAGE  Draw one step-by-step result page in a figure.
%
% qkd_draw_page(R, page, fig) uses the full figure. The optional normalized
% area [left bottom width height] lets the same diagrams fit a dashboard.
% page is 1=link, 2=Eve, 3=LDPC, 4=privacy, 5=turbulence/process.
% Only objects tagged qkd_plot_axes / qkd_plot_legend are replaced.

  if nargin < 4, area = [0.08 0.105 0.875 0.79]; end
  if ~isscalar(page) || page ~= fix(page) || page < 1 || page > 5
    error('Plot page must be an integer from 1 to 5.');
  end
  delete(findall(fig, 'Tag', 'qkd_plot_legend'));
  delete(findall(fig, 'Tag', 'qkd_plot_axes'));
  C.blue = [0.07 0.34 0.59]; C.teal = [0.02 0.55 0.48];
  C.red = [0.78 0.19 0.24]; C.orange = [0.89 0.47 0.12];
  C.gray = [0.32 0.38 0.45]; C.pale = [0.89 0.94 0.98];
  % Leave a generous gap for labels and legends between the two rows.
  positions = [0 0.56 0.46 0.40; 0.54 0.56 0.46 0.40; ...
               0 0.04 0.46 0.40; 0.54 0.04 0.46 0.40];
  axes_out = zeros(1, 4);
  for k = 1:4
    pos = [area(1:2)+positions(k,1:2).*area(3:4), ...
           positions(k,3:4).*area(3:4)];
    axes_out(k) = axes('Parent', fig, 'Units', 'normalized', ...
        'Position', pos, 'Tag', 'qkd_plot_axes', ...
        'FontSize', 8.5, 'Box', 'on', 'LineWidth', 0.7, ...
        'XColor', C.gray, 'YColor', C.gray, 'Color', [1 1 1]);
  end
  switch page
    case 1, draw_link(R, axes_out, C);
    case 2, draw_eve(R, axes_out, C);
    case 3, draw_ldpc(R, axes_out, C);
    case 4, draw_privacy(R, axes_out, C);
    case 5, draw_process(R, axes_out, C);
  end
  % High-level plotting functions can reset axes properties, including Tag.
  % Retag after drawing so changing dashboard pages removes every old axes.
  set(axes_out, 'Tag', 'qkd_plot_axes');
  if strcmp(graphics_toolkit(fig), 'gnuplot')
    % Some Windows gnuplot builds mishandle literal newlines in labels.
    % Separate text objects preserve the same layout without that problem.
    split_multiline_text(axes_out);
  end
  drawnow();
end

function draw_link(R, A, C)
  P = R.parameters; L = R.link;
  ax = A(1);
  semilogy(ax, L.distance_km, max(L.eta, realmin), '-', 'Color', C.blue, 'LineWidth', 2);
  hold(ax, 'on');
  semilogy(ax, L.distance_km, max(R.comparison.eta, realmin), '--', ...
      'Color', C.orange, 'LineWidth', 1.6);
  title(ax, {'STEP 1  How much light reaches Bob?', 'More loss means a lower efficiency'}, 'FontSize', 11);
  xlabel(ax, 'Distance (km)'); ylabel(ax, 'Total efficiency (log scale)'); grid(ax, 'on');
  add_legend(ax, {sprintf('Set air loss: %.3g dB/km', P.atmospheric_loss_db_km), ...
      sprintf('Compare: %.3g dB/km', P.comparison_loss_db_km)}, 'southwest');

  ax = A(2);
  plot(ax, L.distance_km, 100*L.qber_bb84, '-', 'Color', C.blue, 'LineWidth', 2);
  hold(ax, 'on');
  plot(ax, L.distance_km, 100*L.qber_dps, '--', 'Color', C.teal, 'LineWidth', 1.7);
  title(ax, {'STEP 2  What fraction of detections are wrong?', 'QBER = mismatched bits / compared bits'}, 'FontSize', 11);
  xlabel(ax, 'Distance (km)'); ylabel(ax, 'Model QBER (%)'); grid(ax, 'on');
  add_legend(ax, {'BB84 model', 'DPS visibility model'}, 'northwest');
  ylim(ax, [0 max(1, min(55, 1.15*100*max([L.qber_bb84(:); L.qber_dps(:)])))]);

  ax = A(3); floor_rate = 1e-12;
  semilogy(ax, L.distance_km, max(L.rate_bb84, floor_rate), '-', 'Color', C.blue, 'LineWidth', 1.7);
  hold(ax, 'on');
  semilogy(ax, L.distance_km, max(L.rate_decoy, floor_rate), '-', 'Color', C.teal, 'LineWidth', 1.7);
  semilogy(ax, L.distance_km, max(L.rate_dps, floor_rate), '--', 'Color', C.orange, 'LineWidth', 1.7);
  title(ax, {'STEP 3  Compare the teaching rate formulas', 'Zero rates are displayed at 10^{-12}'}, 'FontSize', 11);
  xlabel(ax, 'Distance (km)'); ylabel(ax, 'Bits per transmitted pulse (log)'); grid(ax, 'on');
  add_legend(ax, {'BB84 reference', 'Decoy BB84', 'Legacy DPS proxy; no security proof'}, 'southwest');

  ax = A(4); diagram_axis(ax);
  title(ax, sprintf('STEP 1 diagram  |  Example distance %.3g km', P.demo_distance_km), 'FontSize', 11);
  box_text(ax, [0.02 0.40 0.17 0.25], {'Alice', 'Laser'}, C.pale);
  % A schematic expanding beam explains geometric collection. Its drawn
  % angle is deliberately exaggerated; the numbers below give actual radii.
  patch(ax, [0.21 0.77 0.77 0.21], [0.50 0.29 0.76 0.55], ...
      [0.98 0.90 0.67], 'EdgeColor', C.orange);
  line(ax, [0.79 0.79], [0.40 0.66], 'Color', C.blue, 'LineWidth', 6);
  box_text(ax, [0.84 0.40 0.15 0.25], {'Bob', 'Aperture'}, C.pale);
  text(ax, 0.47, 0.83, 'Beam spreads and air absorbs light', ...
      'HorizontalAlignment', 'center', 'FontSize', 10);
  text(ax, 0.5, 0.13, {sprintf('Beam radius: %.4g m | Receiver radius: %.4g m', ...
      R.example.beam_radius, P.receiver_radius_m), ...
      sprintf('Efficiency: %.4g | BB84 QBER: %.3f%%', R.example.eta, 100*R.example.qber_bb84), ...
      'Schematic only; beam width is not drawn to scale.'}, ...
      'HorizontalAlignment', 'center', 'FontSize', 9);
end

function draw_eve(R, A, C)
  P = R.parameters; E = R.eve_sweep;
  ax = A(1);
  plot(ax, 100*E.fractions, 100*E.expected_qber, '-', 'Color', C.gray, 'LineWidth', 1.5);
  hold(ax, 'on');
  plot(ax, 100*E.fractions, 100*E.qber, 'o', 'Color', C.blue, 'MarkerFaceColor', C.blue, 'MarkerSize', 4);
  ylim(ax, [0 max(5, 115*max([E.qber(:); E.expected_qber(:)]))]);
  selected_line(ax, 100*P.eve_intercept_fraction, C.orange);
  title(ax, {'STEP 4  Eve creates extra disturbance', sprintf('Channel flip probability: %.3f%%', 100*R.channel_qber)}, 'FontSize', 11);
  xlabel(ax, 'Signals intercepted by Eve (%)'); ylabel(ax, 'Sifted QBER (%)'); grid(ax, 'on');
  add_legend(ax, {'Expected QBER', 'Simulated QBER', 'Selected Eve setting'}, 'northwest');

  ax = A(2);
  plot(ax, 100*E.fractions, 50*E.fractions, '-', 'Color', C.gray, 'LineWidth', 1.5);
  hold(ax, 'on');
  plot(ax, 100*E.fractions, 100*E.known_fraction, 'o', 'Color', C.red, 'MarkerFaceColor', C.red, 'MarkerSize', 4);
  ylim(ax, [0 60]); selected_line(ax, 100*P.eve_intercept_fraction, C.orange);
  title(ax, {'STEP 5  Eve sometimes guesses the right basis', 'Known fraction BEFORE public syndrome disclosure'}, 'FontSize', 11);
  xlabel(ax, 'Signals intercepted by Eve (%)'); ylabel(ax, 'Sifted bits known to Eve (%)'); grid(ax, 'on');
  add_legend(ax, {'Expected: intercepted / 2', 'Simulated known fraction', 'Selected Eve setting'}, 'northwest');

  ax = A(3); n = min(80, R.n_key);
  if n > 0
    rows = [R.eve.alice_key(1:n)(:)' ; R.eve.bob_key(1:n)(:)' ; ...
            (R.eve.alice_key(1:n) ~= R.eve.bob_key(1:n))(:)' ; ...
            R.eve.eve_known_mask(1:n)(:)'];
    bit_image(ax, rows, {'Alice bit', 'Bob bit', 'Mismatch?', 'Eve knows?'}, C);
  else
    message_axis(ax, 'No sifted bits in this run. Increase the input signals.');
  end
  title(ax, {'STEP 6  Inspect individual sifted bits', 'Dark = 1 / yes; light = 0 / no'}, 'FontSize', 11);
  xlabel(ax, sprintf('Sifted bit position (first %d shown)', n));

  ax = A(4);
  values = [P.n_signals R.n_key sum(R.eve.alice_key ~= R.eve.bob_key) R.eve_known_bits];
  bar(ax, values, 'FaceColor', C.blue);
  set(ax, 'XTick', 1:4, 'XTickLabel', {'Detected', 'Sifted', 'Wrong', 'Eve knows'});
  ylabel(ax, 'Number of bits / signals'); grid(ax, 'on');
  ylim(ax, [0 max(1, 1.2*max(values))]);
  for k = 1:4
    text(ax, k, values(k)+0.025*max(1,max(values)), sprintf('%d', values(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
  end
  title(ax, {'STEP 7  Keep only matching Alice/Bob bases', ...
      sprintf('QBER: %.3f%% | Same noise without Eve: %.3f%%', ...
      100*R.observed_qber, 100*R.no_eve_qber)}, 'FontSize', 11);
end

function draw_ldpc(R, A, C)
  ax = A(1);
  values = 100*[R.observed_qber R.qber_after];
  bar(ax, values, 'FaceColor', C.blue);
  set(ax, 'XTick', [1 2], 'XTickLabel', {'Before LDPC', 'After LDPC'});
  ylabel(ax, 'Actual mismatched key bits (%)'); grid(ax, 'on');
  ylim(ax, [0 max(1, 1.35*max(values))]);
  for k = 1:2
    text(ax, k, values(k)+0.06*max(1,max(values)), sprintf('%.3f%%', values(k)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
  end
  title(ax, {'STEP 8  Try to correct Bob''s sifted key', ...
      sprintf('Exact Alice/Bob match: %s', yes_no(R.reconciliation_ok))}, 'FontSize', 11);

  ax = A(2); history = R.decoder_history(:)';
  if isempty(history)
    message_axis(ax, {'Decoder did not start for this block.', R.abort_reason});
  else
    plot(ax, 0:numel(history)-1, history, '-o', 'Color', C.teal, ...
        'LineWidth', 1.5, 'MarkerSize', 3);
    xlabel(ax, 'Decoder iteration (0 = before decoding)');
    ylabel(ax, 'Unsatisfied parity checks'); grid(ax, 'on');
    ylim(ax, [0 max(1, 1.15*max(history))]);
  end
  title(ax, {'STEP 9  Follow the decoder''s progress', ...
      sprintf('Parity convergence: %s | Iterations: %d', yes_no(R.converged), R.iterations)}, 'FontSize', 11);

  ax = A(3); m = min(100, size(R.H,1)); n = min(180, size(R.H,2));
  [check, bit] = find(R.H(1:m,1:n));
  plot(ax, bit, check, '.', 'Color', C.blue, 'MarkerSize', 5);
  set(ax, 'YDir', 'reverse');
  xlim(ax, [0.5 max(1.5,n+0.5)]); ylim(ax, [0.5 max(1.5,m+0.5)]);
  xlabel(ax, 'Sifted key bit (column)'); ylabel(ax, 'Parity check (row)');
  title(ax, {'STEP 10  Read the sparse parity-check matrix', ...
      sprintf('Dot = bit participates | Showing %d of %d rows', m, size(R.H,1))}, 'FontSize', 11);

  ax = A(4); n = min(150, R.n_key);
  if n > 0
    before = (R.eve.alice_key(1:n) ~= R.eve.bob_key(1:n));
    after = (R.eve.alice_key(1:n) ~= R.bob_corrected(1:n));
    rows = [before(:)'; R.estimated_error(1:n)(:)'; after(:)'];
    bit_image(ax, rows, {'True errors', 'Estimated', 'Remaining'}, C);
  else
    message_axis(ax, 'No sifted bits to correct.');
  end
  xlabel(ax, sprintf('Sifted bit position (first %d shown)', n));
  title(ax, {'STEP 11  Check actual correction, not just parity', 'Dark = error / flip; an empty last row is good'}, 'FontSize', 11);
end

function draw_privacy(R, A, C)
  P = R.parameters; ax = A(1);
  values = [P.n_signals R.n_key R.final_bits];
  bar(ax, values, 'FaceColor', C.blue);
  set(ax, 'XTick', 1:3, 'XTickLabel', {'Detected inputs', 'Sifted key', 'Final output'});
  ylabel(ax, 'Signal / bit count'); grid(ax, 'on');
  ylim(ax, [0 max(1, 1.2*max(values))]);
  for k = 1:3
    text(ax, k, values(k)+0.025*max(1,max(values)), sprintf('%d', values(k)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
  end
  title(ax, {'STEP 12  Follow the changing key length', 'Sifting and compression reduce usable output'}, 'FontSize', 11);

  ax = A(2); costs = [R.shannon_min R.leak_ec P.reserve_bits];
  bar(ax, costs, 'FaceColor', C.orange);
  set(ax, 'XTick', 1:3, 'XTickLabel', {'Entropy term', 'Public checks', 'Reserve'});
  ylabel(ax, 'Bits subtracted in teaching budget'); grid(ax, 'on');
  ylim(ax, [0 max(1, 1.25*max(costs))]);
  for k = 1:3
    text(ax, k, costs(k)+0.035*max(1,max(costs)), sprintf('%.1f', costs(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
  end
  title(ax, {'STEP 13  Account for uncertainty and disclosure', ...
      sprintf('Budget: %d bits | Requested: %d', R.demo_key_budget, P.requested_final_bits)}, 'FontSize', 11);

  ax = A(3);
  if R.final_bits > 0
    n = min(100, R.final_bits);
    rows = [R.alice_final(1:n)(:)'; R.bob_final(1:n)(:)'];
    bit_image(ax, rows, {'Alice output', 'Bob output'}, C);
    xlabel(ax, sprintf('Output bit position (first %d shown)', n));
    title(ax, {'STEP 14  Apply the shared Toeplitz hash', ...
        sprintf('Output match: %s | Dark = 1; light = 0', yes_no(R.final_key_match))}, 'FontSize', 11);
  else
    message_axis(ax, {'NO FINAL KEY OUTPUT', R.abort_reason, ...
        'The simulation keeps this result visible so you can diagnose it.'});
    title(ax, 'STEP 14  Stop when the output conditions fail', 'FontSize', 11);
  end

  ax = A(4); diagram_axis(ax);
  title(ax, 'STEP 15 diagram  |  The output decision', 'FontSize', 11);
  box_text(ax, [0.02 0.65 0.42 0.21], {'Alice + corrected Bob', 'Are the full keys equal?'}, C.pale);
  box_text(ax, [0.56 0.65 0.42 0.21], {'Check bit budget', 'Enough room to compress?'}, C.pale);
  arrow_line(ax, [0.45 0.76], [0.55 0.76], C.gray);
  arrow_line(ax, [0.77 0.64], [0.77 0.44], C.gray);
  if R.final_bits > 0
    outcome = {sprintf('%d teaching output bits', R.final_bits), 'Shared random Toeplitz hash'};
    fill = [0.85 0.96 0.91];
  else
    outcome = {'NO OUTPUT', 'Adjust parameters and run again'};
    fill = [1 0.90 0.88];
  end
  box_text(ax, [0.12 0.20 0.86 0.23], outcome, fill);
  text(ax, 0.5, 0.05, {'This budget is illustrative, not a finite-key security proof.', ...
      'Exact matching is checked using simulator access to both keys.'}, ...
      'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', C.gray);
end

function draw_process(R, A, C)
  P = R.parameters; ax = A(1);
  [count, center] = hist(R.turbulence.eta_samples(:), 35);
  bar(ax, center, count, 1, 'FaceColor', C.blue, 'EdgeColor', [1 1 1]);
  hold(ax, 'on'); selected_line(ax, R.example.eta, C.orange);
  xlabel(ax, 'Instantaneous total link efficiency'); ylabel(ax, 'Number of samples'); grid(ax, 'on');
  title(ax, {'STEP 16  Add random weak-turbulence fading', ...
      sprintf('Distance %.3g km | Strength %.3g | %d samples', ...
      P.demo_distance_km, P.turbulence_strength, P.mc_samples)}, 'FontSize', 11);
  add_legend(ax, {'Faded samples', 'Deterministic baseline'}, 'northeast');

  ax = A(2);
  [count, center] = hist(100*R.turbulence.qber_samples(:), 35);
  bar(ax, center, count, 1, 'FaceColor', C.teal, 'EdgeColor', [1 1 1]);
  hold(ax, 'on'); selected_line(ax, 100*R.example.qber_bb84, C.orange);
  xlabel(ax, 'Sample BB84 QBER (%)'); ylabel(ax, 'Number of samples'); grid(ax, 'on');
  title(ax, {'STEP 17  Observe the spread of QBER', ...
      sprintf('Mean %.3f%% | 95th percentile %.3f%%', ...
      100*R.turbulence.mean_qber, 100*R.turbulence.p95_qber)}, 'FontSize', 11);
  add_legend(ax, {'Unweighted samples', 'Deterministic baseline'}, 'northeast');

  ax = A(3); diagram_axis(ax);
  title(ax, 'PROCESS A  |  Distance-based optical model', 'FontSize', 11);
  box_text(ax, [0.08 0.73 0.84 0.18], {'1. Choose beam, aperture and air loss'}, C.pale);
  arrow_line(ax, [0.5 0.72], [0.5 0.60], C.gray);
  box_text(ax, [0.08 0.42 0.84 0.18], {'2. Calculate efficiency, gain and QBER'}, C.pale);
  arrow_line(ax, [0.5 0.41], [0.5 0.29], C.gray);
  box_text(ax, [0.08 0.11 0.84 0.18], {'3. Compare rates; sample random fading'}, C.pale);
  text(ax, 0.5, 0.005, 'These curves model the optical baseline without Eve.', ...
      'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', C.gray);

  ax = A(4); diagram_axis(ax);
  if P.use_fso_qber
    source = sprintf('Channel QBER from optical model: %.3f%%', 100*R.channel_qber);
  else
    source = sprintf('Independent demo channel QBER: %.3f%%', 100*R.channel_qber);
  end
  title(ax, {'PROCESS B  |  Detected-signal BB84 experiment', source}, 'FontSize', 11);
  box_text(ax, [0.015 0.69 0.44 0.20], {'1. Alice + Eve + Bob', 'Random bits and bases'}, C.pale);
  box_text(ax, [0.555 0.69 0.43 0.20], {'2. Sift and compare', 'Keep matching bases'}, C.pale);
  arrow_line(ax, [0.46 0.79], [0.55 0.79], C.gray);
  arrow_line(ax, [0.77 0.68], [0.77 0.43], C.gray);
  box_text(ax, [0.555 0.19 0.43 0.24], {'3. LDPC correction', 'Reveal parity checks', 'Verify full key match'}, C.pale);
  box_text(ax, [0.015 0.19 0.44 0.24], {'4. Budget + hash', 'Compress or abort'}, C.pale);
  arrow_line(ax, [0.55 0.31], [0.46 0.31], C.gray);
  text(ax, 0.5, 0.045, {'Input signals are already detected.', ...
      'FSO coupling changes the error probability only when enabled.'}, ...
      'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', C.gray);
end

function add_legend(ax, names, location)
  h = legend(ax, names, 'Location', location);
  set(h, 'FontSize', 8, 'Tag', 'qkd_plot_legend', 'Box', 'off');
end

function selected_line(ax, x, color)
% Octave-compatible replacement for newer xline functions.
  limits = ylim(ax);
  line(ax, [x x], limits, 'Color', color, 'LineStyle', ':', 'LineWidth', 1.5);
end

function bit_image(ax, bits, labels, C)
  imagesc(ax, double(bits), [0 1]);
  colormap(ax, [0.94 0.96 0.98; C.blue]);
  set(ax, 'YTick', 1:size(bits,1), 'YTickLabel', labels, 'YDir', 'reverse');
  xlim(ax, [0.5 size(bits,2)+0.5]); ylim(ax, [0.5 size(bits,1)+0.5]);
  set(ax, 'TickLength', [0 0]);
end

function diagram_axis(ax)
  axis(ax, [0 1 0 1]); axis(ax, 'off'); hold(ax, 'on');
end

function message_axis(ax, message)
  diagram_axis(ax);
  text(ax, 0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
      'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', [0.65 0.15 0.18], ...
      'Interpreter', 'none');
end

function box_text(ax, pos, words, fill)
  rectangle(ax, 'Position', pos, 'FaceColor', fill, ...
      'EdgeColor', [0.36 0.48 0.61], 'LineWidth', 1.0, 'Curvature', 0.12);
  text(ax, pos(1)+pos(3)/2, pos(2)+pos(4)/2, words, ...
      'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
      'FontSize', 9, 'Color', [0.08 0.19 0.30], 'Interpreter', 'none');
end

function arrow_line(ax, start, finish, color)
  line(ax, [start(1) finish(1)], [start(2) finish(2)], 'Color', color, 'LineWidth', 1.3);
  delta = finish-start; length_delta = norm(delta);
  if length_delta == 0, return; end
  u = delta/length_delta; normal = [-u(2) u(1)];
  base = finish-0.023*u;
  triangle = [finish; base+0.012*normal; base-0.012*normal];
  patch(ax, triangle(:,1), triangle(:,2), color, 'EdgeColor', color);
end

function answer = yes_no(condition)
  if condition, answer = 'YES'; else, answer = 'NO'; end
end

function split_multiline_text(axes_handles)
  for ax = axes_handles
    labels = findall(ax, 'Type', 'text');
    old_units = get(ax, 'Units'); set(ax, 'Units', 'pixels');
    ax_pixels = get(ax, 'Position'); set(ax, 'Units', old_units);
    for h = labels(:)'
      words = get(h, 'String');
      if ischar(words) && rows(words) > 1, words = cellstr(words); end
      if ~iscell(words) || numel(words) < 2, continue; end
      set(h, 'Units', 'normalized'); p = get(h, 'Position');
      spacing = get(h, 'FontSize')*get(0, 'ScreenPixelsPerInch')/72 ...
                *1.22/max(1, ax_pixels(4));
      alignment = get(h, 'VerticalAlignment'); n = numel(words);
      is_title = (h == get(ax, 'Title'));
      if is_title
        % Gnuplot positions its special title independently of Position.
        % Replace that title with ordinary text so both lines obey spacing.
        p = [0.5 1.045 0]; alignment = 'bottom';
      end
      % Each line retains its own vertical alignment. Adjust its anchor to
      % preserve the center/top/bottom anchor of the original text block.
      if strcmp(alignment, 'top') || strcmp(alignment, 'cap')
        offsets = -(0:n-1)*spacing;
      elseif strcmp(alignment, 'middle')
        offsets = ((n-1)/2-(0:n-1))*spacing;
      else
        offsets = (n-1:-1:0)*spacing;
      end
      for k = 1:n
        if k == 1 && ~is_title, label = h;
        else, label = copyobj(h, ax); set(label, 'Tag', ''); end
        position = p; position(2) = p(2)+offsets(k);
        set(label, 'String', words{k}, 'Position', position, ...
            'VerticalAlignment', alignment);
        if is_title && k > 1
          set(label, 'FontSize', 9, 'FontWeight', 'normal');
        end
      end
      if is_title, set(h, 'String', ''); end
    end
  end
end
