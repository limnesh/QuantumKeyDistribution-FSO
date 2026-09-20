function figures = network_plot_results(R, visibility, toolkit)
  if nargin < 2, visibility = 'on'; end
  if nargin < 3, toolkit = graphics_toolkit(); end
  page_count=4;
  if isfield(R,'comparison'), page_count=5; end
  figures = zeros(1,page_count);
  for page = 1:page_count
    figures(page) = figure('Visible',visibility,'Color','white', ...
      'Position',[70 70 1320 850],'Name',sprintf('Scenario %d | page %d',R.parameters.stage,page), ...
      'NumberTitle','off');
    graphics_toolkit(figures(page),toolkit);
    network_draw_page(R,page,figures(page));
    if R.parameters.stage==3
      label='Stage 3 | Trusted Satellite Relay - Decoy-State BB84';
      if page==5, label='Stage 3 | Trusted BB84 / Entanglement-Based Satellite QKD - BBM92'; end
    else, label='Stage 4 | Multi-Satellite Trusted-Node QKD Network'; end
    % A normal text axes exports consistently with both Qt and gnuplot;
    % annotation textboxes can shift their center and clip long headings.
    header = axes('Parent',figures(page),'Units','normalized', ...
      'Position',[.04 .925 .92 .065],'Visible','off','Tag','network_header');
    text(header,.5,.5,label,'Units','normalized','FontSize',14, ...
      'FontWeight','bold','HorizontalAlignment','center', ...
      'VerticalAlignment','middle','Interpreter','none');
  end
end
