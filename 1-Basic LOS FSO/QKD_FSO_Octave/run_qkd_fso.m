% RUN_QKD_FSO  Run the full project and show the visual result pages.
% 1. Edit qkd_parameters.m and save it.
% 2. Run this script (F5 in the Octave editor).
% 3. Read the Command Window summary and inspect the figure windows.
% For editable controls inside a window, run qkd_dashboard instead.

qkd_folder = fileparts(mfilename('fullpath'));
addpath(qkd_folder);

P = qkd_parameters();
% You can also override individual settings here, for example:
% P.eve_intercept_fraction = 0.20;
% P.receiver_radius_m = 0.15;
% P.use_fso_qber = true;
% P.demo_distance_km = 30;

fprintf('Running the QKD over FSO project...\n');
R = qkd_simulate(P);
qkd_print_summary(R);
qkd_figures = qkd_plot_results(R);

% Optional: uncomment the next line to save figures, CSV tables and a report.
% saved_folder = qkd_export_results(R);

fprintf('\nR contains all results; P contains the settings used.\n');
fprintf('To save: qkd_export_results(R)\n');
