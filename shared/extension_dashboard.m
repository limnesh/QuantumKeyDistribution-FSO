function fig=extension_dashboard(stage,P,visibility)
  % Compatibility launcher: use the same dashboard with DPS selected.
  if nargin<2, P=[]; end
  if nargin<3, visibility='on'; end
  root=fileparts(fileparts(mfilename('fullpath')));
  folders={'1-Basic LOS FSO','2-Ground Station and Satellite','3-Two Ground and One Satellite','4-Two Ground and Multiple Satellites'};
  addpath(fullfile(root,folders{stage}),'-begin');
  if stage==1
    addpath(fullfile(root,folders{stage},'QKD_FSO_Octave'),'-begin');
    if isempty(P), P=qkd_parameters(); end
  elseif stage==2
    if isempty(P), P=leo_parameters(); end
  else
    if isempty(P), P=network_parameters(stage); end
  end
  P=extension_ui_defaults(P,stage); P.x_protocol=2+(stage==1); P.x_fading_mode=3;
  if stage==1, fig=qkd_dashboard(P,visibility);
  elseif stage==2, fig=leo_dashboard(P,visibility);
  else, fig=network_dashboard(stage,P,visibility); end
end
