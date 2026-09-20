"""Run from any working directory: python tools/run_dps_studies.py [--stage 1]."""
import argparse,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT))
import matplotlib
matplotlib.use('Agg')
from shared.reporting import study
p=argparse.ArgumentParser(); p.add_argument('--stage',type=int,choices=range(1,5)); a=p.parse_args()
for stage in ([a.stage] if a.stage else range(1,5)):
    folder=next(ROOT.glob(f'{stage}-*'))/'dps_turbulence_results'
    r,_,_=study(stage,folder); print(stage,r['summary'],flush=True)
