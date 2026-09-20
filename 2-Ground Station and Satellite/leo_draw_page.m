function axes_out = leo_draw_page(R, page, fig, area)
  % Satellite pages followed by the existing bit-processing visualizations.
  if nargin < 4, area = [0.08 0.105 0.875 0.79]; end
  if ~isscalar(page) || page ~= fix(page) || page < 1 || page > 5
    error('LEO plot page must be an integer from 1 to 5.');
  end
  delete(findall(fig, 'Tag', 'qkd_plot_legend'));
  delete(findall(fig, 'Tag', 'qkd_plot_axes'));
  if page >= 3 && ~isempty(R.postprocessing)
    previous_path=path(); cleanup_path=onCleanup(@() path(previous_path));
    addpath(fullfile(fileparts(mfilename('fullpath')),'..','1-Basic LOS FSO','QKD_FSO_Octave'));
    axes_out = qkd_draw_page(R.postprocessing, page-1, fig, area);
    return;
  end
  positions = [0 .56 .46 .40; .54 .56 .46 .40; 0 .04 .46 .40; .54 .04 .46 .40];
  axes_out = zeros(1,4); blue = [.07 .34 .59]; teal = [.02 .55 .48];
  for k=1:4
    pos = [area(1:2)+positions(k,1:2).*area(3:4), positions(k,3:4).*area(3:4)];
    axes_out(k) = axes('Parent',fig,'Units','normalized','Position',pos, ...
      'FontSize',8.5,'Box','on','Tag','qkd_plot_axes');
  end
  L = R.pass; P = R.parameters; A = axes_out;
  if page == 1
    plot(A(1),L.time_s/60,L.elevation_deg,'Color',blue,'LineWidth',2);
    title(A(1),{'LEO satellite-to-ground downlink','Ideal circular overhead pass'},'FontSize',11);
    xlabel(A(1),'Time from zenith (minutes)'); ylabel(A(1),'Elevation (degrees)');
    ylim(A(1),[0 95]); grid(A(1),'on');
    plot(A(2),L.time_s/60,L.slant_range_km,'Color',blue,'LineWidth',2);
    title(A(2),sprintf('Altitude %.0f km | contact %.1f minutes',P.altitude_km,R.pass_duration_s/60),'FontSize',11);
    xlabel(A(2),'Time from zenith (minutes)'); ylabel(A(2),'Satellite slant range (km)'); grid(A(2),'on');
    E=R.sweeps.elevation;
    plot(A(3),E.elevation_deg,E.atmosphere_path_km,'Color',teal,'LineWidth',2);
    title(A(3),{'Atmospheric loss applies inside the shell',sprintf('Effective shell height %.0f km',P.atmosphere_height_km)},'FontSize',11);
    xlabel(A(3),'Elevation (degrees)'); ylabel(A(3),'Path inside atmospheric shell (km)'); grid(A(3),'on');
    plot(A(4),E.elevation_deg,-10*log10(max(E.eta_geo,realmin)),'Color',blue,'LineWidth',2); hold(A(4),'on');
    plot(A(4),E.elevation_deg,-10*log10(max(E.eta_atm,realmin)),'Color',teal,'LineWidth',2);
    plot(A(4),E.elevation_deg,-10*log10(max(E.eta,realmin)),'k--','LineWidth',1.5);
    title(A(4),{'Loss decreases toward zenith','Total includes pointing, optics and detector'},'FontSize',11);
    xlabel(A(4),'Elevation (degrees)'); ylabel(A(4),'Loss (dB)'); grid(A(4),'on');
    lg=legend(A(4),{'Geometric','Atmospheric','Total'},'Location','northeast'); set(lg,'Tag','qkd_plot_legend');
  elseif page == 2
    plot(A(1),L.time_s/60,100*L.qber_bb84,'Color',blue,'LineWidth',2);
    title(A(1),{'Baseline QBER through the satellite pass','No Eve in these optical rate curves'},'FontSize',11);
    xlabel(A(1),'Time from zenith (minutes)'); ylabel(A(1),'QBER (%)'); grid(A(1),'on');
    plot(A(2),L.time_s/60,L.key_rate_bps/1000,'Color',teal,'LineWidth',2);
    title(A(2),{'Ideal decoy asymptotic estimate','Signal allocation and 1/2 basis sifting included'},'FontSize',11);
    xlabel(A(2),'Time from zenith (minutes)'); ylabel(A(2),'Model key rate (kbit/s)'); grid(A(2),'on');
    plot(A(3),L.time_s/60,L.cumulative_key_bits/1e6,'Color',teal,'LineWidth',2);
    title(A(3),{'Integral of instantaneous asymptotic rates','Not a finite-key certified output length'},'FontSize',11);
    xlabel(A(3),'Time from zenith (minutes)'); ylabel(A(3),'Integrated model bits (millions)'); grid(A(3),'on');
    S=R.sweeps.altitude;
    plot(A(4),S.altitude_km,S.integrated_key_bits/1e6,'-o','Color',blue,'LineWidth',1.7,'MarkerSize',4);
    title(A(4),{'Compare ideal overhead passes','All other settings held fixed'},'FontSize',11);
    xlabel(A(4),'Satellite altitude (km)'); ylabel(A(4),'Integrated model bits (millions)'); grid(A(4),'on');
  else
    for k=1:4, axis(A(k),'off'); end
    text(A(1),0,.8,'No detected signals at the selected example elevation.', ...
      'Units','normalized','FontSize',11);
    text(A(1),0,.5,'The bit-processing demonstration was skipped.', ...
      'Units','normalized','FontSize',11);
  end
  set(axes_out,'Tag','qkd_plot_axes');
  if strcmp(graphics_toolkit(fig),'gnuplot'), split_multiline_titles(axes_out); end
  drawnow();
end

function split_multiline_titles(axes_handles)
  % Windows gnuplot may send a literal newline as a new plotting command.
  % Ordinary single-line text retains both title lines when exporting.
  for ax=axes_handles
    title_handle=get(ax,'Title'); words=get(title_handle,'String');
    if ischar(words) && rows(words)>1, words=cellstr(words); end
    if ~iscell(words) || numel(words)<2, continue; end
    old_units=get(ax,'Units'); set(ax,'Units','pixels');
    ax_pixels=get(ax,'Position'); set(ax,'Units',old_units);
    spacing=get(title_handle,'FontSize')*get(0,'ScreenPixelsPerInch')/72*1.22/max(1,ax_pixels(4));
    for k=1:numel(words)
      line=text(ax,.5,1.045+(numel(words)-k)*spacing,words{k}, ...
        'Units','normalized','HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize',11,'FontWeight','bold');
      if k>1, set(line,'FontSize',9,'FontWeight','normal'); end
    end
    set(title_handle,'String','');
  end
end
