function folder = network_stage_folder(stage)
  root = fileparts(fileparts(mfilename('fullpath')));
  if stage == 3
    folder = fullfile(root,'3-Two Ground and One Satellite');
  elseif stage == 4
    folder = fullfile(root,'4-Two Ground and Multiple Satellites');
  else
    error('Network stage must be 3 or 4.');
  end
end
