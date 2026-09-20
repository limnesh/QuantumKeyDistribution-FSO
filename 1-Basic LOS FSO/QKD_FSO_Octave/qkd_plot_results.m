function figures = qkd_plot_results(R, visible)
% QKD_PLOT_RESULTS  Open five illustrated result pages from one simulation.
%
%   figures = qkd_plot_results(R)         Show all five pages.
%   figures = qkd_plot_results(R, 'off')  Create hidden figures for export.
%
% R is the structure returned by qkd_simulate. This function calculates no
% new random samples, so every page belongs to exactly the same experiment.
% Close only the returned figures when finished; other windows are untouched.
  if nargin < 2, visible = 'on'; end
  if ~ischar(visible) || ~any(strcmp(visible, {'on', 'off'}))
    error('visible must be ''on'' or ''off''.');
  end
  names = {'01 Optical link', '02 Eve and sifted bits', '03 LDPC correction', ...
           '04 Privacy amplification', '05 Turbulence and process'};
  figures = zeros(1, numel(names));
  try
    for page = 1:numel(names)
      figures(page) = figure('Name', ['QKD study lab | ', names{page}], ...
          'NumberTitle', 'off', 'Color', [1 1 1], 'Visible', visible, ...
          'Position', [80+20*page 70+12*page 1260 800], ...
          'PaperPositionMode', 'auto');
      qkd_draw_page(R, page, figures(page));
    end
  catch err
    % If drawing fails, clean up only windows created by this call.
    for k = 1:numel(figures)
      if figures(k) ~= 0 && ishandle(figures(k)), close(figures(k)); end
    end
    rethrow(err);
  end
end
