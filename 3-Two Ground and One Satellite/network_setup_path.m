function network_setup_path()
  % Resolve the existing optical model relative to this file, not the cwd.
  folder = fileparts(mfilename('fullpath'));
  stage2 = fullfile(folder,'..','2-Ground Station and Satellite');
  if exist(fullfile(stage2,'leo_parameters.m'),'file') ~= 2
    error('Network:dependency','Cannot find the stage 2 optical model at %s.',stage2);
  end
  addpath(stage2);
end
