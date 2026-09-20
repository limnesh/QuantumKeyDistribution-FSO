function fig = qkd_dashboard(P)
% QKD_DASHBOARD  Change parameters and explore the complete teaching process.
%
%   qkd_dashboard                 Open the dashboard with default parameters.
%   qkd_dashboard(P)              Open it with your own parameter structure.
%
% Use the parameter-group menu to reach every setting. Changes are saved
% when you switch groups. Press RUN SIMULATION to calculate new results.
% The plot menu changes the page without recalculating the experiment.
% This GUI uses Octave's standard Qt controls; no extra package is needed.

  if nargin < 1, P = qkd_parameters(); end
  qkd_validate_parameters(P);
  available = available_graphics_toolkits();
  if ~any(strcmp(available, 'qt'))
    error(['The interactive dashboard needs Octave''s Qt graphics toolkit. ', ...
           'Start Octave in GUI mode. You can also run run_qkd_fso from ', ...
           'the command window to use ordinary plots.']);
  end

  previous_toolkit = graphics_toolkit();
  graphics_toolkit('qt');
  fig = figure('Name', 'QKD + FSO + LDPC | Interactive study lab', ...
      'NumberTitle', 'off', 'Color', [0.955 0.968 0.984], ...
      'Units', 'normalized', 'Position', [0.02 0.04 0.96 0.92], 'MenuBar', 'none', ...
      'ToolBar', 'figure', 'ResizeFcn', @(src, evt) resize_dashboard(src), ...
      'Visible', 'off');
  if ~strcmp(previous_toolkit, 'qt'), graphics_toolkit(previous_toolkit); end

  % DPS_EXTENSION_ENTRY
  addpath(fullfile(fileparts(mfilename('fullpath')),'..','..','shared'));
  uimenu(fig,'Label','DPS / atmospheric fading','Callback',@(src,evt) extension_dashboard(1,guidata(fig).P));
  S.P = P; S.R = []; S.busy = false; S.group = 1;
  S.groups = parameter_groups(P);
  S.page_names = {'1. Optical link and distance', ...
                  '2. Eve, sifting and bit errors', ...
                  '3. LDPC error correction', ...
                  '4. Privacy amplification', ...
                  '5. Turbulence and process diagram'};
  S.plot_area = [0.34 0.14 0.64 0.75];
  S.resizing = false;
  S.ui.title = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
      'Position', [0.025 0.925 0.94 0.05], ...
      'String', 'QKD study lab - Change a setting. Run. Read the diagrams.', ...
      'FontSize', 18, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
      'BackgroundColor', get(fig, 'Color'), 'ForegroundColor', [0.06 0.14 0.27]);
  S.ui.panel = uipanel(fig, 'Title', '1  Adjust the parameters', ...
      'Units', 'normalized', 'Position', [0.02 0.15 0.27 0.755], ...
      'BackgroundColor', [1 1 1], 'FontSize', 12, 'FontWeight', 'bold');
  names = cellfun(@(g) g.name, S.groups, 'UniformOutput', false);
  S.ui.group = uicontrol(S.ui.panel, 'Style', 'popupmenu', 'Units', 'normalized', ...
      'Position', [0.04 0.905 0.92 0.055], 'String', names, 'FontSize', 11, ...
      'BackgroundColor', [1 1 1], 'Callback', @(src, evt) change_group(fig));
  S.ui.hint = uicontrol(S.ui.panel, 'Style', 'text', 'Units', 'normalized', ...
      'Position', [0.045 0.81 0.91 0.085], 'String', '', ...
      'HorizontalAlignment', 'left', 'FontSize', 10, ...
      'BackgroundColor', [1 1 1], 'ForegroundColor', [0.25 0.32 0.41]);
  S.ui.labels = zeros(1, 8); S.ui.edits = zeros(1, 8);
  for k = 1:8
    row_y = 0.747 - (k-1)*0.084;
    S.ui.labels(k) = uicontrol(S.ui.panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.045 row_y 0.575 0.052], ...
        'String', '', 'HorizontalAlignment', 'left', 'FontSize', 10, ...
        'BackgroundColor', [1 1 1]);
    S.ui.edits(k) = uicontrol(S.ui.panel, 'Style', 'edit', ...
        'Units', 'normalized', 'Position', [0.63 row_y+0.006 0.325 0.052], ...
        'String', '', 'HorizontalAlignment', 'left', 'FontSize', 11, ...
        'BackgroundColor', [0.965 0.978 1], ...
        'Callback', @(src, evt) mark_pending(fig));
  end
  S.ui.run = uicontrol(S.ui.panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
      'Position', [0.045 0.067 0.91 0.069], 'String', '2  RUN SIMULATION', ...
      'FontSize', 12, 'FontWeight', 'bold', 'ForegroundColor', [1 1 1], ...
      'BackgroundColor', [0.08 0.34 0.56], 'Callback', @(src, evt) run_simulation(fig));
  S.ui.reset = uicontrol(S.ui.panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
      'Position', [0.045 0.008 0.44 0.045], 'String', 'Reset defaults', ...
      'FontSize', 10, 'Callback', @(src, evt) reset_parameters(fig));
  S.ui.export = uicontrol(S.ui.panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
      'Position', [0.51 0.008 0.445 0.045], 'String', 'Export last run', ...
      'FontSize', 10, 'Callback', @(src, evt) export_results(fig));
  S.ui.page = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
      'Position', [0.345 0.883 0.62 0.045], 'String', S.page_names, ...
      'FontSize', 12, 'BackgroundColor', [1 1 1], ...
      'Callback', @(src, evt) change_page(fig));
  S.ui.note = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
      'Position', [0.33 0.091 0.65 0.045], ...
      'String', ['3  Read pages 1 to 5 in order. Hover over a setting for help. ', ...
                 'Plots always show the last completed run.'], ...
      'FontSize', 10, 'HorizontalAlignment', 'left', ...
      'BackgroundColor', get(fig, 'Color'), 'ForegroundColor', [0.2 0.28 0.38]);
  S.ui.status = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
      'Position', [0.025 0.018 0.95 0.061], 'String', 'Preparing the first simulation...', ...
      'HorizontalAlignment', 'left', 'FontSize', 11, 'FontWeight', 'bold', ...
      'BackgroundColor', get(fig, 'Color'), 'ForegroundColor', [0.09 0.25 0.38]);
  S.ui.all_controls = [S.ui.group S.ui.edits S.ui.run S.ui.reset S.ui.export S.ui.page];
  guidata(fig, S);
  layout_dashboard(fig);
  populate_group(fig);
  run_simulation(fig);
  gui_maximize_qt(fig);
end

function resize_dashboard(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig);
  if isempty(S) || ~isfield(S,'ui') || S.resizing, return; end
  S.resizing = true; guidata(fig,S);
  layout_dashboard(fig);
  S = guidata(fig);
  if ~isempty(S.R) && isfield(S.ui,'page')
    qkd_draw_page(S.R, get(S.ui.page,'Value'), fig, S.plot_area);
  end
  S = guidata(fig); S.resizing = false; guidata(fig,S);
end

function layout_dashboard(fig)
  S = guidata(fig);
  set(S.ui.title, 'Position', [0.02 0.935 0.96 0.045]);
  set(S.ui.panel, 'Position', [0.02 0.14 0.285 0.78]);
  set(S.ui.group, 'Position', [0.04 0.90 0.92 0.055]);
  set(S.ui.hint, 'Position', [0.045 0.80 0.91 0.10]);
  for k = 1:8
    row_y = 0.735 - (k-1)*0.081;
    set(S.ui.labels(k), 'Position', [0.045 row_y 0.575 0.052]);
    set(S.ui.edits(k), 'Position', [0.63 row_y+0.006 0.325 0.052]);
  end
  set(S.ui.run, 'Position', [0.045 0.067 0.91 0.069]);
  set(S.ui.reset, 'Position', [0.045 0.008 0.44 0.045]);
  set(S.ui.export, 'Position', [0.51 0.008 0.445 0.045]);
  set(S.ui.page, 'Position', [0.34 0.895 0.64 0.045]);
  set(S.ui.note, 'Position', [0.34 0.088 0.64 0.045]);
  set(S.ui.status, 'Position', [0.02 0.018 0.96 0.055]);
  S.plot_area = [0.34 0.14 0.64 0.75];
  guidata(fig,S);
end

function groups = parameter_groups(P)
% Each group has at most eight fields, so nothing needs a hidden scrollbar.
  groups = { ...
    make_group('Optical path', 'Lengths use metres; distance uses kilometres.', ...
      {'w0_m','divergence_rad','receiver_radius_m','atmospheric_loss_db_km', ...
       'optical_efficiency','detector_efficiency','comparison_loss_db_km'}, ...
      {'Initial beam radius (m)','Beam divergence (rad)','Receiver radius (m)', ...
       'Air loss (dB/km)','Optical efficiency (0-1)','Detector efficiency (0-1)', ...
       'Comparison air loss (dB/km)'}), ...
    make_group('QKD and detector noise', 'Probabilities use decimals: 0.02 means 2%.', ...
      {'mu_signal','dark_yield','bb84_misalignment','dps_visibility', ...
       'ec_efficiency','turbulence_strength','demo_channel_qber','use_fso_qber'}, ...
      {'Mean photons per pulse','Dark/background yield','BB84 misalignment (0-0.5)', ...
       'DPS visibility (0-1)','Error correction factor','Turbulence strength', ...
       'Demo channel QBER (0-0.5)','Use FSO QBER? (0=no, 1=yes)'}), ...
    make_group('Eve, LDPC and privacy', 'These settings control the detected-signal bit experiment.', ...
      {'eve_intercept_fraction','n_signals','ldpc_check_fraction','ldpc_column_weight', ...
       'max_iterations','requested_final_bits','reserve_bits'}, ...
      {'Eve intercept fraction (0-1)','Detected input signals', ...
       'LDPC checks / key bits','LDPC checks per column', ...
       'Maximum decoder iterations','Requested final bits','Illustrative reserve bits'}), ...
    make_group('Distance and sample counts', 'More samples make the curves smoother but take longer.', ...
      {'distance_min_km','distance_max_km','distance_points','demo_distance_km', ...
       'mc_samples','eve_sweep_signals'}, ...
      {'Minimum distance (km)','Maximum distance (km)','Number of distance points', ...
       'Example distance (km)','Turbulence samples','Signals per Eve sweep point'}), ...
    make_group('Random seeds', 'Keep seeds unchanged for repeatable comparisons. Integers only.', ...
      {'seed','graph_seed','fading_seed','sweep_seed','hash_seed'}, ...
      {'BB84 bits seed','LDPC graph seed','Turbulence seed','Eve sweep seed','Toeplitz hash seed'})};
  % If the parameter file gains a new field later, still make it accessible.
  known = {};
  for k = 1:numel(groups), known = [known groups{k}.fields]; end
  fields = fieldnames(P)';
  extra = fields(~ismember(fields, known));
  for first = 1:8:numel(extra)
    chunk = extra(first:min(first+7, numel(extra)));
    groups{end+1} = make_group('Additional parameters', ...
      'Additional numerical settings from qkd_parameters.m.', chunk, chunk);
  end
end

function G = make_group(name, hint, fields, labels)
  G.name = name; G.hint = hint; G.fields = fields; G.labels = labels;
end

function populate_group(fig)
  S = guidata(fig); G = S.groups{S.group};
  set(S.ui.group, 'Value', S.group); set(S.ui.hint, 'String', G.hint);
  for k = 1:8
    if k <= numel(G.fields)
      field = G.fields{k};
      tooltip = [G.labels{k}, ' | Parameter: ', field, ...
                 ' | Use a number, for example 0.02 or 50e-6.'];
      set(S.ui.labels(k), 'String', G.labels{k}, 'Visible', 'on', 'TooltipString', tooltip);
      set(S.ui.edits(k), 'String', sprintf('%.12g', S.P.(field)), ...
          'Visible', 'on', 'TooltipString', tooltip);
    else
      set(S.ui.labels(k), 'Visible', 'off');
      set(S.ui.edits(k), 'Visible', 'off');
    end
  end
end

function ok = save_current_group(fig)
% Parse numbers only. Never evaluate text entered in a parameter box.
  S = guidata(fig); G = S.groups{S.group}; next_P = S.P; ok = false;
  for k = 1:numel(G.fields)
    value = str2double(strtrim(get(S.ui.edits(k), 'String')));
    if ~isscalar(value) || ~isreal(value) || ~isfinite(value)
      show_error(fig, [G.labels{k}, ': enter one finite real number.']);
      return;
    end
    next_P.(G.fields{k}) = value;
  end
  S.P = next_P; guidata(fig, S); ok = true;
end

function change_group(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy, return; end
  new_group = get(S.ui.group, 'Value');
  if ~save_current_group(fig)
    set(S.ui.group, 'Value', S.group); return;
  end
  S = guidata(fig); S.group = new_group; guidata(fig, S);
  populate_group(fig);
end

function mark_pending(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy, return; end
  set(S.ui.status, 'String', 'Settings edited. Press RUN SIMULATION to update the plots.');
end

function run_simulation(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy, return; end
  if ~save_current_group(fig), return; end
  S = guidata(fig);
  try
    qkd_validate_parameters(S.P);
  catch err
    show_error(fig, err.message); return;
  end
  set_busy(fig, true);
  cleanup = onCleanup(@() set_busy(fig, false));
  set(S.ui.status, 'String', 'Running optical link, Eve, LDPC and privacy steps. Please wait...');
  drawnow();
  if ~ishandle(fig), return; end
  try
    R = qkd_simulate(S.P);
    if ~ishandle(fig), return; end
    S = guidata(fig); S.R = R; guidata(fig, S);
    qkd_draw_page(R, get(S.ui.page, 'Value'), fig, S.plot_area);
    set(S.ui.status, 'String', 'Run complete. Choose a plot page, change one setting, or export this run.');
  catch err
    show_error(fig, ['Simulation could not finish: ', err.message]);
  end
end

function change_page(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy || isempty(S.R), return; end
  try
    qkd_draw_page(S.R, get(S.ui.page, 'Value'), fig, S.plot_area);
  catch err
    show_error(fig, ['Could not draw this page: ', err.message]);
  end
end

function reset_parameters(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy, return; end
  S.P = qkd_parameters(); S.group = 1; guidata(fig, S);
  populate_group(fig); run_simulation(fig);
end

function export_results(fig)
  if ~ishandle(fig), return; end
  S = guidata(fig); if S.busy || isempty(S.R), return; end
  set_busy(fig, true); cleanup = onCleanup(@() set_busy(fig, false));
  set(S.ui.status, 'String', 'Exporting plots and numerical results from the last completed run...');
  drawnow();
  try
    output_folder = qkd_export_results(S.R);
    if ishandle(fig)
      S = guidata(fig);
      set(S.ui.status, 'String', ['Export complete: ', output_folder]);
    end
  catch err
    show_error(fig, ['Export could not finish: ', err.message]);
  end
end

function set_busy(fig, busy)
  if ~ishandle(fig), return; end
  S = guidata(fig); S.busy = busy; guidata(fig, S);
  if busy, state = 'off'; pointer = 'watch';
  else, state = 'on'; pointer = 'arrow'; end
  set(S.ui.all_controls, 'Enable', state); set(fig, 'Pointer', pointer);
end

function show_error(fig, message)
  if ~ishandle(fig), return; end
  S = guidata(fig); set(S.ui.status, 'String', ['Please check: ', message]);
  errordlg(message, 'Check simulation settings');
end
