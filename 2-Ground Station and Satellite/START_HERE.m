% Stage 2: One ground station and one LEO satellite.
% Open in the GNU Octave graphical application and press F5.
leo_stage_folder = fileparts(mfilename('fullpath'));
addpath(leo_stage_folder);
addpath(fullfile(leo_stage_folder, '..', '1-Basic LOS FSO', 'QKD_FSO_Octave'));
leo_dashboard();
