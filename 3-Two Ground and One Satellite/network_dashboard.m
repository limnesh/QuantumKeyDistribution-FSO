function fig = network_dashboard(stage, P)
  if nargin < 1, stage = 3; end
  if nargin < 2, P = network_parameters(stage); end
  P = network_validate_parameters(P);
  if P.stage ~= stage, error('Dashboard stage and parameter stage must agree.'); end
  if ~any(strcmp(available_graphics_toolkits(),'qt'))
    error('Open the normal Octave GUI for the dashboard. run_scenario.m supports ordinary plots.');
  end
  prior = graphics_toolkit(); graphics_toolkit('qt');
  fig = figure('Name',sprintf('Scenario %d | Satellite QKD network',stage), ...
    'NumberTitle','off','Color',[.95 .97 .985], ...
    'Units','normalized','Position',[.02 .04 .96 .92], ...
    'MenuBar','none','ResizeFcn',@(src,e) resize_dashboard(src),'Visible','off');
  graphics_toolkit(prior);
  % DPS_EXTENSION_ENTRY
  addpath(fullfile(fileparts(mfilename('fullpath')),'..','shared'));
  uimenu(fig,'Label','DPS / atmospheric fading','Callback',@(src,evt) extension_dashboard(3,guidata(fig).P));
  S.P=P; S.R=[]; S.busy=false; S.group=1; S.groups=make_groups(stage);
  S.B=bbm92_parameters(); S.mode='trusted';
  S.plot_area=[.36 .14 .62 .75]; S.resizing=false;
  % A pipe in a Qt text-control String means a NEW LINE in Octave.
  % Use ordinary punctuation so headings and notices fit their text boxes.
  S.ui.title=uicontrol(fig,'Style','text','Units','normalized','Position',[.02 .93 .96 .055], ...
    'String',sprintf('%d - Two ground stations and satellite relay nodes',stage), ...
    'FontSize',18,'FontWeight','bold','HorizontalAlignment','left','BackgroundColor',get(fig,'Color'));
  S.ui.panel=uipanel(fig,'Title','Adjust parameters, then run','Units','normalized', ...
    'Position',[.015 .14 .28 .77],'BackgroundColor','white','FontSize',12);
  S.ui.group=uicontrol(S.ui.panel,'Style','popupmenu','Units','normalized','Position',[.04 .9 .92 .06], ...
    'String',cellfun(@(g) g.name,S.groups,'UniformOutput',false),'Callback',@(s,e) change_group(fig));
  S.ui.labels=zeros(1,8); S.ui.edits=zeros(1,8);
  for k=1:8
    y=.81-(k-1)*.083;
    S.ui.labels(k)=uicontrol(S.ui.panel,'Style','text','Units','normalized','Position',[.04 y .57 .06], ...
      'HorizontalAlignment','left','FontSize',10,'BackgroundColor','white');
    S.ui.edits(k)=uicontrol(S.ui.panel,'Style','edit','Units','normalized','Position',[.62 y+.01 .34 .055], ...
      'BackgroundColor',[.96 .98 1],'FontSize',11,'Callback',@(s,e) mark_pending(fig));
  end
  S.ui.run=uicontrol(S.ui.panel,'Style','pushbutton','Units','normalized','Position',[.04 .1 .92 .07], ...
    'String','RUN SIMULATION','FontSize',12,'FontWeight','bold','Callback',@(s,e) run_model(fig));
  S.ui.reset=uicontrol(S.ui.panel,'Style','pushbutton','Units','normalized','Position',[.04 .02 .43 .055], ...
    'String','Reset defaults','Callback',@(s,e) reset_model(fig));
  S.ui.export=uicontrol(S.ui.panel,'Style','pushbutton','Units','normalized','Position',[.51 .02 .45 .055], ...
    'String','Export last run','Callback',@(s,e) export_model(fig));
  S.ui.page=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.36 .88 .60 .045], ...
    'String',{'1. Topology and contact','2. Link rates, losses and QBER', ...
      '3. Routes and end-to-end capacity','4. Per-hop BB84, LDPC and key relay'}, ...
    'FontSize',12,'Callback',@(s,e) change_page(fig));
  if stage==3
    set(S.ui.title,'String','3 - Two ground stations / one satellite','Position',[.02 .93 .54 .055]);
    S.ui.mode=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.56 .94 .42 .038], ...
      'String',{'Trusted Satellite Relay - Decoy-State BB84','Entanglement-Based Satellite QKD - BBM92'}, ...
      'Callback',@(s,e) change_mode(fig));
    set(S.ui.page,'String',{'1. Shared geometry / Mode A route','2. Mode A: link rates, loss and QBER', ...
      '3. Mode A: simultaneous route benchmark','4. Mode A: finite BB84 / LDPC relay example', ...
      '5. Stage 3: trusted BB84 / BBM92 comparison'});
  else
    set(S.ui.title,'String','4 - Multi-Satellite Trusted-Node QKD Network');
  end
  S.ui.note=uicontrol(fig,'Style','text','Units','normalized','Position',[.34 .084 .63 .045], ...
    'String','Independent terminals; asymptotic estimates. Bit examples: trusted BB84 only.', ...
    'FontSize',10,'HorizontalAlignment','left','BackgroundColor',get(fig,'Color'));
  S.ui.status=uicontrol(fig,'Style','text','Units','normalized','Position',[.02 .012 .96 .06], ...
    'String','Preparing simulation...','FontSize',11,'HorizontalAlignment','left', ...
    'BackgroundColor',get(fig,'Color'));
  S.ui.controls=[S.ui.group S.ui.edits S.ui.run S.ui.reset S.ui.export S.ui.page];
  if stage==3, S.ui.controls=[S.ui.controls S.ui.mode]; end
  guidata(fig,S); populate(fig); layout_dashboard(fig);
  run_model(fig); gui_maximize_qt(fig);
end

function resize_dashboard(fig)
  if ~ishandle(fig), return; end
  S=guidata(fig);
  if isempty(S) || ~isfield(S,'ui') || S.resizing, return; end
  S.resizing=true; guidata(fig,S);
  layout_dashboard(fig);
  S=guidata(fig);
  if ~isempty(S.R) && isfield(S.ui,'page')
    network_draw_page(S.R,get(S.ui.page,'Value'),fig,S.plot_area);
  end
  S=guidata(fig); S.resizing=false; guidata(fig,S);
end

function layout_dashboard(fig)
  S=guidata(fig);
  set(S.ui.title,'Position',[.02 .935 .96 .045]);
  set(S.ui.panel,'Position',[.015 .14 .30 .78]);
  set(S.ui.group,'Position',[.04 .90 .92 .055]);
  for k=1:8
    y=.735-(k-1)*.081;
    set(S.ui.labels(k),'Position',[.04 y .57 .055]);
    set(S.ui.edits(k),'Position',[.62 y+.006 .34 .052]);
  end
  set(S.ui.run,'Position',[.04 .067 .92 .069]);
  set(S.ui.reset,'Position',[.04 .008 .43 .045]);
  set(S.ui.export,'Position',[.51 .008 .45 .045]);
  set(S.ui.page,'Position',[.36 .895 .62 .045]);
  set(S.ui.note,'Position',[.34 .088 .63 .045]);
  set(S.ui.status,'Position',[.02 .018 .96 .055]);
  if S.P.stage==3 && isfield(S.ui,'mode')
    set(S.ui.title,'Position',[.02 .935 .54 .045]);
    set(S.ui.mode,'Position',[.56 .94 .42 .038]);
  end
  S.plot_area=[.36 .14 .62 .75]; guidata(fig,S);
end
function groups=make_groups(stage)
  groups={ ...
    group('Network geometry',{'satellite_count','ground_separation_km','satellite_span_deg','duration_s','time_points','enable_isl'}, ...
      {'Satellite nodes (2 or more)','Ground separation (km)','Satellite arc span (deg)','Window duration (s)','Time samples (odd integer)','Inter-satellite links (0 / 1)'}), ...
    group('Orbit and ground visibility',{'link.altitude_km','link.min_elevation_deg','link.earth_radius_km','link.earth_mu_km3_s2'}, ...
      {'Altitude (km)','Minimum elevation (deg)','Earth radius (km)','Earth GM (km^3/s^2)'}), ...
    group('Ground link optics',{'link.w0_m','link.divergence_rad','link.receiver_radius_m','link.atmosphere_height_km', ...
      'link.zenith_atmospheric_loss_db','link.pointing_loss_db','link.optical_efficiency','link.detector_efficiency'}, ...
      {'Initial beam radius (m)','Divergence (rad)','Receiver radius (m)','Atmospheric shell (km)', ...
      'Zenith atmospheric loss (dB)','Pointing loss (dB)','Optical efficiency (0-1)','Detector efficiency (0-1)'}), ...
    group('QKD and pulse timing',{'link.mu_signal','link.dark_yield','link.bb84_misalignment','link.ec_efficiency', ...
      'link.pulse_rate_hz','link.signal_duty_fraction'}, ...
      {'Mean photons / signal','Ground background / gate','Signal error fraction','Rate correction factor', ...
      'Pulse clock per link (Hz)','Signal allocation (0-1)'}), ...
    group('Inter-satellite links',{'isl_divergence_rad','isl_receiver_radius_m','isl_pointing_loss_db','isl_background_yield','isl_clearance_km'}, ...
      {'ISL divergence (rad)','ISL receiver radius (m)','ISL pointing loss (dB)','ISL background / gate','Clearance above Earth (km)'})};
  if stage==3
    groups{1}=group('Two-station geometry',{'ground_separation_km','duration_s','time_points'}, ...
      {'Ground separation (km)','Observation window (s)','Time samples (odd integer)'});
    groups{5}=group('BBM92 source and detection',{'bbm.pair_rate_hz','bbm.dark_count_rate_hz','bbm.background_count_rate_hz', ...
      'bbm.coincidence_window_s','bbm.timing_fwhm_s','bbm.basis_sift'}, ...
      {'Generated pairs / s','Dark counts / s / receiver','Background counts / s / receiver', ...
      'Coincidence full window (s)','Relative timing FWHM (s)','Sift fraction (0-0.5)'});
  end
end
function G=group(name,fields,labels)
  G.name=name; G.fields=fields; G.labels=labels;
end
function populate(fig)
  S=guidata(fig); G=S.groups{S.group}; set(S.ui.group,'Value',S.group);
  for k=1:8
    if k <= numel(G.fields)
      field=G.fields{k};
      if strncmp(field,'link.',5), value=S.P.link.(field(6:end));
      elseif strncmp(field,'bbm.',4), value=S.B.(field(5:end)); else, value=S.P.(field); end
      set(S.ui.labels(k),'String',G.labels{k},'Visible','on');
      set(S.ui.edits(k),'String',sprintf('%.12g',value),'Visible','on','TooltipString',field);
    else, set(S.ui.labels(k),'Visible','off'); set(S.ui.edits(k),'Visible','off'); end
  end
end
function ok=read_group(fig)
  S=guidata(fig); G=S.groups{S.group}; P=S.P; B=S.B; ok=false;
  for k=1:numel(G.fields)
    value=str2double(get(S.ui.edits(k),'String'));
    if ~isscalar(value) || ~isreal(value) || ~isfinite(value)
      status(fig,['Enter one finite number for ',G.labels{k}]); return;
    end
    field=G.fields{k};
    if strncmp(field,'link.',5), P.link.(field(6:end))=value;
    elseif strncmp(field,'bbm.',4), B.(field(5:end))=value; else, P.(field)=value; end
  end
  S.P=P; S.B=B; guidata(fig,S); ok=true;
end
function change_group(fig)
  S=guidata(fig); if S.busy, return; end
  next=get(S.ui.group,'Value');
  if ~read_group(fig), set(S.ui.group,'Value',S.group); return; end
  S=guidata(fig); S.group=next; guidata(fig,S); populate(fig);
end
function mark_pending(fig)
  status(fig,'Settings changed. Press RUN SIMULATION to update results.');
end
function run_model(fig)
  S=guidata(fig); if S.busy || ~read_group(fig), return; end
  S=guidata(fig);
  try, P=network_validate_parameters(S.P); catch err, status(fig,err.message); return; end
  busy(fig,true); cleanup=onCleanup(@() busy(fig,false));
  status(fig,'Computing contacts, link capacities, routes and per-hop bit processing...'); drawnow();
  try
    R=network_simulate(P);
    if P.stage==3
      try, R.comparison=stage3_compare(R,S.B,S.mode);
      catch err
        if strcmp(S.mode,'bbm92'), rethrow(err); end
        R.comparison_error=err.message;
      end
    end
    if strcmp(S.mode,'trusted'), R.demonstration=network_postprocess(R); end
    if ~ishandle(fig), return; end
    S=guidata(fig); S.R=R; guidata(fig,S);
    network_draw_page(R,get(S.ui.page,'Value'),fig,S.plot_area);
    if P.stage==3 && isfield(R,'comparison')
      status(fig,sprintf('%s; selected expected/asymptotic budget %.3f bits; comparison on page 5', ...
        R.comparison.architecture,R.comparison.selected_key_bits));
    else
      status(fig,sprintf('Trusted peak %.3f kbit/s; simultaneous benchmark %.4f Mbit; %s', ...
        R.metrics.peak_rate_bps/1000,R.metrics.integrated_key_bits/1e6,R.demonstration.status));
    end
  catch err, status(fig,['Simulation failed: ',err.message]); end
end
function change_page(fig)
  S=guidata(fig); if S.busy || isempty(S.R), return; end
  try, network_draw_page(S.R,get(S.ui.page,'Value'),fig,S.plot_area);
  catch err, status(fig,err.message); end
end
function reset_model(fig)
  S=guidata(fig); if S.busy, return; end
  S.P=network_parameters(S.P.stage); S.B=bbm92_parameters(); S.group=1; guidata(fig,S); populate(fig); run_model(fig);
end
function change_mode(fig)
  S=guidata(fig); if S.busy, return; end
  modes={'trusted','bbm92'}; S.mode=modes{get(S.ui.mode,'Value')};
  set(S.ui.page,'Value',5); guidata(fig,S); run_model(fig);
end
function export_model(fig)
  S=guidata(fig); if S.busy || isempty(S.R), return; end
  busy(fig,true); cleanup=onCleanup(@() busy(fig,false)); status(fig,'Exporting completed run...'); drawnow();
  try, folder=network_export_results(S.R); status(fig,['Saved: ',folder]);
  catch err, status(fig,['Export failed: ',err.message]); end
end
function busy(fig,value)
  if ~ishandle(fig), return; end
  S=guidata(fig); S.busy=value; guidata(fig,S);
  if value, state='off'; else, state='on'; end
  set(S.ui.controls,'Enable',state);
end
function status(fig,message)
  if ishandle(fig), S=guidata(fig); set(S.ui.status,'String',message); end
end
