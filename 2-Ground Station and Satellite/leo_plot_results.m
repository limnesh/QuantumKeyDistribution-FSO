function figures = leo_plot_results(R, visibility, toolkit)
  if nargin < 2, visibility = 'on'; end
  if nargin < 3, toolkit = graphics_toolkit(); end
  names = {'LEO geometry and losses','LEO QBER and pass rates', ...
    'LEO example: Eve and BB84','LEO example: LDPC','LEO example: privacy amplification'};
  figures = zeros(1,5);
  try
    for k=1:5
      figures(k)=figure('Name',names{k},'NumberTitle','off','Color',[1 1 1], ...
        'Position',[70+15*k 65+12*k 1180 800],'Visible',visibility);
      % Some Windows builds initialize a first figure using FLTK despite
      % the selected default. Set the backend on every figure explicitly.
      graphics_toolkit(figures(k),toolkit);
      leo_draw_page(R,k,figures(k));
    end
  catch failure
    % The caller cannot own handles until this function returns. Clean up
    % all allocated figures if creating any later page fails.
    for k=1:numel(figures)
      if figures(k) ~= 0 && isgraphics(figures(k),'figure'), close(figures(k)); end
    end
    rethrow(failure);
  end
end
