function axes_out = network_draw_page(R,page,fig,area)
  if nargin < 4, area = [.08 .09 .87 .81]; end
  % legend() selects its implementation from the default toolkit, even when
  % its axes belong to a figure with a different toolkit (e.g. PNG export).
  prior_toolkit = graphics_toolkit();
  restore_toolkit = onCleanup(@() graphics_toolkit(prior_toolkit));
  graphics_toolkit(graphics_toolkit(fig));
  delete(findall(fig,'Tag','network_legend'));
  delete(findall(fig,'Tag','legend'));
  delete(findall(fig,'Tag','network_axes'));
  slots = [0 .56 .46 .40; .54 .56 .46 .40; 0 .04 .46 .40; .54 .04 .46 .40];
  axes_out = zeros(1,4);
  for k = 1:4
    pos = [area(1:2)+slots(k,1:2).*area(3:4),slots(k,3:4).*area(3:4)];
    axes_out(k) = axes('Parent',fig,'Units','normalized','Position',pos, ...
      'Tag','network_axes','FontSize',8.5,'Box','on');
  end
  A = axes_out; t = R.time_s/60; P = R.parameters;
  colors = lines(numel(R.edges));
  if page == 1
    k = R.best_index; xy = R.positions_km(:,:,k); Re = P.link.earth_radius_km;
    phi = linspace(0,2*pi,500);
    plot(A(1),Re*cos(phi),Re*sin(phi),'Color',[.5 .7 .8]); hold(A(1),'on');
    for j = 1:numel(R.edges)
      e = R.edges(j);
      if e.visible(k), plot(A(1),xy([e.i e.j],1),xy([e.i e.j],2),'-','Color',[.7 .7 .7]); end
    end
    route = R.route_nodes{k};
    if ~isempty(route), plot(A(1),xy(route,1),xy(route,2),'-','Color',[.02 .55 .4],'LineWidth',3); end
    plot(A(1),xy(:,1),xy(:,2),'o','MarkerFaceColor',[.08 .3 .6],'MarkerSize',7);
    for n = 1:numel(R.node_names)
      text(A(1),xy(n,1)+30,xy(n,2)+40,R.node_names{n},'FontSize',9);
    end
    axis(A(1),'equal');
    xlim(A(1),[min(xy(:,1))-500,max(xy(:,1))+650]);
    ylim(A(1),[min(xy(:,2))-500,max(xy(:,2))+500]);
    title(A(1),sprintf('Topology at t = %.1f s',R.time_s(k)));
    xlabel(A(1),'Earth-centred x (km)'); ylabel(A(1),'Earth-centred y (km)');
    ground = find(strcmp({R.edges.kind},'ground'));
    for j = ground
      e = R.edges(j); hold(A(2),'on'); plot(A(2),t,e.elevation_deg,'Color',colors(j,:));
    end
    plot(A(2),[t(1) t(end)],P.link.min_elevation_deg*[1 1],'k--');
    title(A(2),'Ground link elevations'); xlabel(A(2),'Time (min)'); ylabel(A(2),'Elevation (deg)'); grid(A(2),'on');
    imagesc(A(3),t,1:numel(R.edges),vertcat(R.edges.visible));
    set(A(3),'YTick',1:numel(R.edges),'YTickLabel',{R.edges.label});
    title(A(3),'Geometric availability: light = visible'); xlabel(A(3),'Time (min)');
    colormap(A(3),[.12 .2 .3;.77 .93 .88]); caxis(A(3),[0 1]);
    axis(A(4),'off');
    notes = {sprintf('%d ground stations + %d satellites',2,P.satellite_count), ...
      sprintf('Station separation: %.0f km',P.ground_separation_km), ...
      sprintf('Circular orbit altitude: %.0f km',P.link.altitude_km), ...
      'Green: selected widest route', 'Gray: other visible links', ...
      'Earth blocks links through the planet.', 'ISLs must clear the configured shell.'};
    draw_notes(A(4),notes);
  elseif page == 2
    for j = 1:numel(R.edges)
      e = R.edges(j);
      for a = 1:4, hold(A(a),'on'); end
      plot(A(1),t,e.key_rate_bps/1000,'Color',colors(j,:));
      plot(A(2),t,100*e.qber,'Color',colors(j,:));
      loss = -10*log10(e.eta); loss(~isfinite(loss)) = NaN;
      plot(A(3),t,loss,'Color',colors(j,:));
      plot(A(4),t,e.cumulative_key_bits/1e6,'Color',colors(j,:));
    end
    titles = {'Independent link rates','Per-link baseline QBER (no Eve)', ...
      'Detection path loss','Independent link key budgets'};
    labels = {'Model rate (kbit/s)','QBER (%)','Loss (dB)','Integrated model bits (Mbit)'};
    for a = 1:4
      title(A(a),titles{a}); xlabel(A(a),'Time (min)'); ylabel(A(a),labels{a}); grid(A(a),'on');
    end
    if numel(R.edges) <= 10
      lg = legend(A(1),{R.edges.label},'Location','northeast'); set(lg,'FontSize',8);
    end
  elseif page == 3
    plot(A(1),t,R.route_rate_bps/1000,'LineWidth',2,'Color',[.02 .5 .42]);
    title(A(1),'Widest simultaneous route'); ylabel(A(1),'Bottleneck rate (kbit/s)');
    plot(A(2),t,R.cumulative_key_bits/1e6,'LineWidth',2,'Color',[.1 .3 .6]);
    title(A(2),'Integral of instantaneous route capacity'); ylabel(A(2),'Model bits (Mbit)');
    hops = cellfun(@(v) max(0,numel(v)-1),R.route_nodes);
    stairs(A(3),t,hops,'LineWidth',1.5); title(A(3),'Selected route hop count (0 = no route)'); ylabel(A(3),'Hops');
    for a = 1:3, xlabel(A(a),'Time (min)'); grid(A(a),'on'); end
    axis(A(4),'off'); route = R.route_nodes{R.best_index};
    if isempty(route), name = 'No positive-rate route'; else, name = strjoin(R.node_names(route),' -> '); end
    notes = {sprintf('Peak: %.3f kbit/s',R.metrics.peak_rate_bps/1000), ...
      sprintf('Integrated: %.4f Mbit',R.metrics.integrated_key_bits/1e6), ...
      sprintf('Connected: %.1f s (sampled)',R.metrics.connected_duration_s), ...
      'Peak route:',name,'','One route selected at each sample.', ...
      'Capacity = weakest hop rate.','Independent simultaneous terminals.'};
    if P.stage == 3
      notes{end+1} = sprintf('Stored pair budget: %.4f Mbit',R.metrics.stored_pair_bits/1e6);
      notes{end+1} = 'Stored budget allows separate contacts.';
    end
    draw_notes(A(4),notes);
  elseif page == 4
    if ~isfield(R,'demonstration') || isempty(R.demonstration.hops)
      for a = 1:4, axis(A(a),'off'); end
      if isfield(R,'comparison') && strcmp(R.comparison.mode,'bbm92')
        message='BBM92 uses asymptotic rates on page 5; no trusted satellite key is generated.';
      else, message='No bit example: no positive-rate route.'; end
      text(A(1),0,.8,message,'Units','normalized'); return;
    end
    D = R.demonstration; count = numel(D.hops); before = zeros(1,count); after = before; bits = before;
    for h = 1:count
      B = D.hops{h}; before(h) = sum(B.eve.alice_key ~= B.eve.bob_key);
      after(h) = sum(B.eve.alice_key ~= B.bob_corrected); bits(h) = B.final_bits;
      hold(A(2),'on'); plot(A(2),0:numel(B.decoder_history)-1,B.decoder_history,'-o');
    end
    bar(A(1),[before(:),after(:)]); title(A(1),'Errors in each independent detected-bit block');
    xlabel(A(1),'Route hop'); ylabel(A(1),'Bit mismatches');
    lg=legend(A(1),{'Before LDPC','After LDPC'}); set(lg,'FontSize',8);
    title(A(2),'LDPC convergence by hop'); xlabel(A(2),'Iteration'); ylabel(A(2),'Unsatisfied checks'); grid(A(2),'on');
    bar(A(3),bits); title(A(3),'Verified hash output available per hop'); xlabel(A(3),'Route hop'); ylabel(A(3),'Demonstration bits');
    axis(A(4),'off');
    notes = {D.status,'','Hop 1 establishes the shared key K1.', ...
      'Later hops relay K1 using fresh pair keys.', ...
      'Each relay decrypts and re-encrypts K1.', ...
      'Every satellite on the route must be trusted.', ...
      'Authenticated classical messages are assumed.', ...
      'Default Eve interception: 8% per link.', ...
      'This finite bit example is separate from', ...
      'the ideal asymptotic network rate curves.'};
    draw_notes(A(4),notes);
  elseif page==5 && P.stage==3
    if ~isfield(R,'comparison')
      for a=1:4, axis(A(a),'off'); end
      text(A(1),0,.8,'BBM92 comparison unavailable for these settings.','Units','normalized');
      if isfield(R,'comparison_error'), text(A(3),0,.8,R.comparison_error,'Units','normalized'); end
      return;
    end
    C=R.comparison; E=C.bbm92;
    if isfield(E,'available') && ~E.available
      for a=1:4, axis(A(a),'off'); end
      draw_notes(A(1),{'Trusted BB84 calculation completed.','BBM92 comparison unavailable:',E.reason, ...
        'NaN means unavailable, not a zero-key prediction.'});
      return;
    end
    plot(A(1),t,E.true_coincidence_hz,'LineWidth',2); hold(A(1),'on');
    plot(A(1),t,E.accidental_coincidence_hz,'--','LineWidth',1.5);
    title(A(1),'Stage 3 BBM92: pair coincidences'); ylabel(A(1),'Coincidences / s');
    lg=legend(A(1),{'True before timing filter','Accidental'}); set(lg,'FontSize',8);
    plot(A(2),t,100*E.qber,'LineWidth',2); title(A(2),'Stage 3 BBM92: common-contact QBER'); ylabel(A(2),'QBER (%)');
    rates=[C.trusted.simultaneous_rate_bps;E.key_rate_bps]'; rates(rates==0)=NaN;
    if any(isfinite(rates(:))), semilogy(A(3),t,rates,'LineWidth',1.8);
    else, plot(A(3),t,zeros(size(t))); end
    title(A(3),'Stage 3: asymptotic rate comparison'); ylabel(A(3),'Key estimate (bit/s; positive log)');
    lg=legend(A(3),{'Trusted simultaneous','BBM92'}); set(lg,'FontSize',8);
    totals=[C.trusted.inventory.delivered_bits;E.cumulative_key_bits]'; totals(totals==0)=NaN;
    if any(isfinite(totals(:))), semilogy(A(4),t,totals,'LineWidth',1.8);
    else, plot(A(4),t,zeros(size(t))); end
    title(A(4),'Stage 3: expected/asymptotic key budgets'); ylabel(A(4),'Bits (positive log)');
    lg=legend(A(4),{'Trusted stored-key delivery','BBM92 integral'}); set(lg,'FontSize',8);
    for a=1:4, xlabel(A(a),'Time (min)'); grid(A(a),'on'); end
  else
    error('Result page must be 1 to 4, or Stage 3 comparison page 5.');
  end
  % High-level plot calls reset axes tags; restore ownership for page changes.
  set(axes_out,'Tag','network_axes');
  drawnow();
end
function draw_notes(ax,notes)
  % Separate single-line text objects avoid Windows gnuplot newline commands.
  lines={};
  for k=1:numel(notes)
    words=strsplit(notes{k}); current='';
    for j=1:numel(words)
      if length(current)+length(words{j})>54
        lines{end+1}=current; current=words{j};
      elseif isempty(current), current=words{j};
      else, current=[current,' ',words{j}]; end
    end
    lines{end+1}=current;
  end
  step=min(.11,.94/max(1,numel(lines)-1));
  for k=1:numel(lines)
    text(ax,0,1-(k-1)*step,lines{k},'Units','normalized','VerticalAlignment','top', ...
      'FontSize',10,'Interpreter','none');
  end
end
