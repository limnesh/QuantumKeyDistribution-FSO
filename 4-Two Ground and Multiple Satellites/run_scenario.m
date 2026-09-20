% Scenario 4 calculation, separate per-hop bit demonstration and four plots.
scenario_folder = fileparts(mfilename('fullpath'));
addpath(scenario_folder,'-begin');
addpath(scenario_folder,'-begin');
clear scenario_parameters;
P_NETWORK = scenario_parameters();
R_NETWORK = network_simulate(P_NETWORK);
R_NETWORK.demonstration = network_postprocess(R_NETWORK);
fprintf('%s\n',network_summary_text(R_NETWORK));
network_plot_results(R_NETWORK);
% Save the completed run with: network_export_results(R_NETWORK)
