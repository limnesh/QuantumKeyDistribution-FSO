QKD OVER FREE-SPACE OPTICAL (FSO) CHANNELS
=======================================

This project simulates quantum key distribution across four scenarios: a ground-to-ground FSO link, a ground-to-LEO-satellite link, two ground stations with one satellite, and two ground stations with multiple satellites. It includes BB84/decoy-state models, selected DPS illustrations, and QKD post-processing. See the Word report for methodology, results and limitations.

PROJECT REPORT
  QKD_FSO_Project_Report-v1.0.pdf

PYTHON / JUPYTER (open the notebook and select Run All)
  1-Basic LOS FSO/QKD_FSO_LDPC_Project.ipynb
  2-Ground Station and Satellite/QKD_FSO_LEO_Extension.ipynb
  3-Two Ground and One Satellite/Two_Ground_One_Satellite.ipynb
  4-Two Ground and Multiple Satellites/Two_Ground_Multiple_Satellites.ipynb

GNU OCTAVE (graphical interface)
  Start here: open START_PROJECT.m in GNU Octave and press F5.
  Select the scenario in the launcher.

  Alternatively, open the appropriate file below in Octave and press F5:
  1-Basic LOS FSO/START_HERE.m
  2-Ground Station and Satellite/START_HERE.m
  3-Two Ground and One Satellite/START_HERE.m
  4-Two Ground and Multiple Satellites/START_HERE.m

Keep the four stage folders and the shared/ folder in their supplied locations: the notebooks and Octave launchers depend on supporting .py and .m source files. Run the project from the extracted folder rather than moving individual files.
