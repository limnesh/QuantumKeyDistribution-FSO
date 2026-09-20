function A=extension_draw_page(X,page,fig,area)
  % Draw directly inside the existing dashboard; no extra figures or windows.
  if nargin<4, area=[.08 .10 .88 .82]; end
  names=extension_page_names(X.stage);
  if page<1 || page>numel(names) || fix(page)~=page, error('Invalid DPS / turbulence page'); end
  for tag={'qkd_plot_axes','qkd_plot_legend','network_axes','network_legend','extension_ui_summary','legend'}
    delete(findall(fig,'tag',tag{1}));
  end
  old=graphics_toolkit(); cleanup=onCleanup(@() graphics_toolkit(old)); graphics_toolkit(graphics_toolkit(fig));
  slots=[.03 .62 .42 .29;.56 .62 .42 .29;.03 .19 .42 .29;.56 .19 .42 .29];
  A=zeros(1,4); tag='qkd_plot_axes'; if X.stage>=3, tag='network_axes'; end
  for k=1:4
    pos=[area(1:2)+slots(k,1:2).*area(3:4),slots(k,3:4).*area(3:4)];
    A(k)=axes('parent',fig,'units','normalized','position',pos,'fontsize',9,'box','on','tag',tag);
  end
  t=X.time_s; base=X.deterministic;
  if page==1
    lines_on(A(1),t,[X.rate_bits_per_second;base.rate_bits_per_second]','Time (s)','Rate (bits/s)',{'Selected fading','No turbulence'});
    title(A(1),[X.metadata.protocol,'; DPS rates are proxies'],'interpreter','none');
    lines_on(A(2),t,[X.cumulative_rate_integral_bits;base.cumulative_rate_integral_bits]','Time (s)','Integrated bits (DPS proxy)',{'Selected fading','No turbulence'});
    title(A(2),'Accumulated rate integral');
    if X.stage<3
      lines_on(A(3),t,100*X.qber,'Time (s)','QBER (%)',{}); title(A(3),'Protocol detection errors');
      lines_on(A(4),t,X.fading_factor,'Time (s)','Power multiplier (1)',{}); title(A(4),'Atmospheric fading');
    else
      values=cellfun(@(e) e.qber*100,X.edges,'UniformOutput',false);
      lines_on(A(3),t,vertcat(values{:})','Time (s)','Link QBER (%)',cellfun(@(e) e.label,X.edges,'UniformOutput',false)); title(A(3),'Per-link errors');
      values=cellfun(@(e) e.fading_factor,X.edges,'UniformOutput',false);
      lines_on(A(4),t,vertcat(values{:})','Time (s)','Power multiplier (1)',{}); title(A(4),'Independent ground-link fading; ISL = 1');
    end
  elseif page==2
    if X.stage==1
      M=X.monte_carlo; factor=M.fading_factor; q=M.qber; rate=M.rate_bits_per_second;
      note='Independent DPS Monte Carlo (no elapsed time)';
    elseif X.stage==2
      factor=X.fading_factor; q=X.qber; rate=X.rate_bits_per_second; note='Marginal samples from this pass';
    else
      values=cellfun(@(e) e.fading_factor,X.edges,'UniformOutput',false); factor=[values{:}];
      values=cellfun(@(e) e.qber,X.edges,'UniformOutput',false); q=[values{:}]; rate=X.rate_bits_per_second;
      note='Link samples and route rate samples';
    end
    hist(A(1),factor,35); xlabel(A(1),'Collected-power factor (1)'); ylabel(A(1),'Samples'); title(A(1),note);
    q=q(isfinite(q)); if isempty(q), q=NaN; end
    hist(A(2),q*100,35); xlabel(A(2),'QBER (%)'); ylabel(A(2),'Samples'); title(A(2),'Defined QBER samples');
    hist(A(3),rate,35); xlabel(A(3),'Rate (bits/s; proxy for DPS)'); ylabel(A(3),'Samples'); title(A(3),'Rate distribution, including exact zeros');
    axis(A(4),'off');
    if X.stage==1, S=M.summary; else, S=X.summary; end
    notes={sprintf('Mean rate: %.6g bits/s',S.mean_rate_bps),sprintf('Median rate: %.6g bits/s',S.median_rate_bps), ...
      sprintf('5th percentile rate: %.6g bits/s',S.p05_rate_bps),sprintf('Zero-rate fraction: %.4f',S.outage_fraction), ...
      'DPS values and integrals are illustrative proxies.'};
    if isfield(S,'pooled_qber'), notes=[notes,{sprintf('Mean QBER: %.5g%%',100*S.mean_qber),sprintf('Pooled QBER: %.5g%%',100*S.pooled_qber)}]; end
    write_notes(A(4),notes);
  elseif page==numel(names)
    E=X.ensemble;
    lines_on(A(1),E(:,1),E(:,2),'Independent seed','Integrated bits (DPS proxy)',{}); title(A(1),'Same geometry; independent realizations');
    lines_on(A(2),E(:,1),E(:,3),'Independent seed','Zero-rate sample fraction',{}); title(A(2),'Rate outages');
    hist(A(3),E(:,2),min(10,rows(E))); xlabel(A(3),'Integrated bits (DPS proxy)'); ylabel(A(3),'Realizations'); title(A(3),'Distribution of accumulated rate');
    axis(A(4),'off'); write_notes(A(4),{sprintf('Realizations: %d',rows(E)),sprintf('Mean integral: %.6g bits',mean(E(:,2))), ...
      sprintf('Standard deviation: %.6g bits',std(E(:,2))), 'Independent seeds; fixed geometry.', ...
      'No-turbulence runs are identical.', 'One realization does not establish a trend.'});
  elseif X.stage>=2 && page==numel(names)-1
    S=X.sensitivity;
    lines_on(A(1),S.sigma,S.integrated_bits,'Log-irradiance sigma (1)','Integrated bits (DPS proxy)',{}); title(A(1),'Independent log-normal strength sweep');
    if isfield(S,'design_values')
      label='Elevation cutoff (deg)'; if X.stage==4, label='Satellite count'; end
      lines_on(A(2),S.design_values,S.design_bits,label,'Integrated bits (DPS proxy)',{}); title(A(2),'Design sensitivity at selected fading');
    else
      lines_on(A(2),t,[X.edges{1}.fading_factor;X.edges{2}.fading_factor]','Time (s)','Power multiplier (1)',{'Ground A','Ground B'}); title(A(2),'Independent ground-link processes');
    end
    lines_on(A(3),X.ensemble(:,1),X.ensemble(:,2),'Independent seed','Integrated bits (DPS proxy)',{}); title(A(3),'Nominal setting across independent seeds');
    axis(A(4),'off'); write_notes(A(4),{'Sensitivity curves use one fixed seed.', 'Compare with independent realizations.', 'A single curve does not establish a trend.', 'Geometry and detector settings are preserved.'});
  elseif X.stage==1 && page==3
    S=X.distance_sweep; V=X.visibility_sweep;
    lines_on(A(1),S.distance_km,S.qber*100,'Distance (km)','DPS QBER (%)',{}); title(A(1),'DPS protocol QBER vs distance');
    lines_on(A(2),S.distance_km,S.rate_bits_per_second,'Distance (km)','DPS proxy rate (bits/s)',{}); title(A(2),'DPS proxy rate vs distance');
    lines_on(A(3),V.visibility,V.qber*100,'Visibility (1)','DPS QBER (%)',{}); title(A(3),'Interferometer visibility sensitivity');
    lines_on(A(4),V.visibility,V.rate,'Visibility (1)','DPS proxy rate (bits/s)',{}); title(A(4),'Visibility and usable proxy');
  elseif X.stage==1 && page==4
    S=X.design;
    lines_on(A(1),S.aperture,S.aperture_rate,'Receiver radius (m)','DPS proxy rate (bits/s)',{}); title(A(1),'Aperture sensitivity');
    lines_on(A(2),S.background,S.background_rate,'Background / detector / gate','DPS proxy rate (bits/s)',{}); set(A(2),'xscale','log'); title(A(2),'Background sensitivity');
    lines_on(A(3),X.sensitivity.sigma,X.sensitivity.integrated_bits,'Log-irradiance sigma (1)','Integrated bits (DPS proxy)',{}); title(A(3),'One fixed seed; independent log-normal sweep');
    axis(A(4),'off'); write_notes(A(4),{'Coherent neighboring-pulse phase encoding.', 'Balanced one-slot-delay interferometer.', ...
      'Double clicks receive a random bit.', 'No composable DPS bound established.', 'Original finite BB84 / LDPC is separate.'});
  elseif X.stage==2 && page==3
    lines_on(A(1),t,X.elevation_deg,'Time (s)','Elevation (deg)',{}); title(A(1),'Preserved satellite geometry');
    lines_on(A(2),t,[X.distance_m;X.atmospheric_path_m]'/1000,'Time (s)','Path length (km)',{'Slant range','Atmospheric shell'}); title(A(2),'Atmosphere is a finite shell');
    lines_on(A(3),X.elevation_deg,X.qber*100,'Elevation (deg)','Protocol QBER (%)',{}); title(A(3),'QBER through the pass');
    lines_on(A(4),X.elevation_deg,X.rate_bits_per_second,'Elevation (deg)','Rate (bits/s; DPS proxy)',{}); title(A(4),'Protocol rate through the pass');
  elseif X.stage==3 && page==3
    I=X.inventory;
    lines_on(A(1),t,[X.edges{1}.rate_bits_per_second;X.edges{2}.rate_bits_per_second]','Time (s)','Link rate (bits/s; DPS proxy)',{'Ground A','Ground B'}); title(A(1),'Separate pairwise links');
    lines_on(A(2),t,[I.pool_a_bits;I.pool_b_bits]','Time (s)','Pool bits (DPS proxy)',{'Pool A','Pool B'}); title(A(2),'Remaining classical key pools');
    lines_on(A(3),t,I.delivered_bits,'Time (s)','Delivered bits (DPS proxy)',{}); title(A(3),'Causal stored-key budget');
    lines_on(A(4),t,min(X.edges{1}.rate_bits_per_second,X.edges{2}.rate_bits_per_second),'Time (s)','Bottleneck (bits/s; DPS proxy)',{}); title(A(4),'Simultaneous route capacity');
  elseif X.stage==3 && page==4
    if ~X.bbm92.available
      for ax=A, axis(ax,'off'); end
      write_notes(A(1),{'BBM92 estimate unavailable:',X.bbm92.reason});
    else
      B=X.bbm92;
      lines_on(A(1),t,[B.true_coincidence_hz;B.accidental_coincidence_hz]','Time (s)','Coincidences / s',{'True','Accidental'}); title(A(1),'Both photon arms are required');
      lines_on(A(2),t,[B.singles_a_hz;B.singles_b_hz]','Time (s)','Singles / s',{'Ground A','Ground B'}); title(A(2),'Fading-adjusted singles');
      lines_on(A(3),t,B.qber*100,'Time (s)','BBM92 QBER (%)',{}); title(A(3),'Paired errors');
      rates=B.key_rate_bps; labels={'Selected fading'};
      if base.bbm92.available, rates=[rates;base.bbm92.key_rate_bps]; labels{end+1}='No turbulence'; end
      lines_on(A(4),t,rates','Time (s)','BBM92 estimate (bits/s)',labels); title(A(4),'Separate BBM92 asymptotic estimate');
    end
  else
    vals=cellfun(@(e) e.rate_bits_per_second,X.edges,'UniformOutput',false);
    lines_on(A(1),t,vertcat(vals{:})','Time (s)','Edge capacity (bits/s)',cellfun(@(e) e.label,X.edges,'UniformOutput',false)); title(A(1),'Capacities before route selection');
    labels=cellfun(@(p) sprintf('%d-',p),X.route_nodes,'UniformOutput',false); [unique_labels,~,ids]=unique(labels);
    stairs(A(2),t,ids); set(A(2),'ytick',1:numel(unique_labels),'yticklabel',unique_labels); xlabel(A(2),'Time (s)'); ylabel(A(2),'Route node indices'); title(A(2),'Selected widest route; empty = disconnected');
    stairs(A(3),t,double(X.rate_bits_per_second<=0)); xlabel(A(3),'Time (s)'); ylabel(A(3),'Rate outage (0/1)'); title(A(3),'Zero-rate intervals');
    lines_on(A(4),t,X.cumulative_rate_integral_bits,'Time (s)','Integrated bits (DPS proxy)',{}); title(A(4),'Route-rate integral');
  end
  set(A,'tag',tag);
  summary=axes('parent',fig,'units','normalized','position',[area(1),area(2),area(3),.075*area(4)],'visible','off','tag','extension_ui_summary');
  message=extension_ui_status(X);
  text(summary,0,1,message,'units','normalized','verticalalignment','top','fontsize',9,'interpreter','none');
  drawnow();
end
function lines_on(ax,x,y,xlabel_text,ylabel_text,labels)
  plot(ax,x,y,'linewidth',1.4); xlabel(ax,xlabel_text); ylabel(ax,ylabel_text); grid(ax,'on');
  if ~isempty(labels), l=legend(ax,labels,'location','best'); set(l,'fontsize',7,'tag','qkd_plot_legend','interpreter','none'); end
end
function write_notes(ax,notes)
  for k=1:numel(notes), text(ax,0,1-(k-1)*.13,notes{k},'units','normalized','fontsize',9,'verticalalignment','top','interpreter','none'); end
end
