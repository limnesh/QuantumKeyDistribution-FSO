% Run the separate satellite extension with ordinary figure windows.
leo_folder = fileparts(mfilename('fullpath'));
addpath(leo_folder);
addpath(fullfile(leo_folder, '..', '1-Basic LOS FSO', 'QKD_FSO_Octave'));
P_LEO = leo_parameters();
% Example: P_LEO.altitude_km = 800;
% Example: P_LEO.receiver_radius_m = 0.75;
R_LEO = leo_simulate(P_LEO);
fprintf('%s\n', leo_summary_text(R_LEO));
leo_figures = leo_plot_results(R_LEO);
% Optional: saved_folder = leo_export_results(R_LEO);
