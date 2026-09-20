% Stage 3: two ground stations and one satellite, with trusted and BBM92 modes.
scenario_folder = fileparts(mfilename('fullpath'));
addpath(scenario_folder,'-begin');
addpath(scenario_folder,'-begin');
clear scenario_parameters;
stage_parameters = scenario_parameters();
network_dashboard(3,stage_parameters);
