% Scenario 3 calculation, optional trusted bit demonstration and five plots.
scenario_folder = fileparts(mfilename('fullpath'));
addpath(scenario_folder,'-begin');
addpath(scenario_folder,'-begin');
clear scenario_parameters;
P_NETWORK = scenario_parameters();
R_NETWORK = network_simulate(P_NETWORK);
architecture_mode = 'trusted'; % Select 'trusted' or 'bbm92'.
B_BBM92 = bbm92_parameters();
R_NETWORK.comparison = stage3_compare(R_NETWORK,B_BBM92,architecture_mode);
if strcmp(architecture_mode,'trusted')
  R_NETWORK.demonstration = network_postprocess(R_NETWORK);
end
fprintf('%s\n',network_summary_text(R_NETWORK));
network_plot_results(R_NETWORK);
% Save the completed run with: network_export_results(R_NETWORK)
