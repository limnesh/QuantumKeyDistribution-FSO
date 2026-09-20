% Stage 4: two ground stations and multiple satellite trusted nodes.
scenario_folder = fileparts(mfilename('fullpath'));
addpath(scenario_folder,'-begin');
addpath(scenario_folder,'-begin');
clear scenario_parameters;
stage_parameters = scenario_parameters();
network_dashboard(4,stage_parameters);
