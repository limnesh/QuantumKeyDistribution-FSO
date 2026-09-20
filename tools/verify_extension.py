"""Execute existing/new tests, actual cross-language comparison and convergence."""
from pathlib import Path
from dataclasses import replace
import argparse,json,subprocess,sys,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT))
from shared.physics import *
from shared.scenarios import *
from shared.reporting import json_safe

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--octave',default=shutil.which('octave-cli')); args=parser.parse_args()
    dest=ROOT/'validation'; dest.mkdir(exist_ok=True)
    commands=[('python_extension',[sys.executable,'-m','unittest','shared.test_extension','shared.test_exports','-v'])]
    for stage in (2,3,4):
        folder=next(ROOT.glob(f'{stage}-*'))
        commands.append((f'python_stage{stage}',[sys.executable,'-m','unittest','discover','-s',str(folder),'-p','test_*model.py']))
    log={}
    for name,cmd in commands:
        r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True); (dest/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
        log[name]=dict(exit_code=r.returncode); print(name,r.returncode,flush=True)
        if r.returncode: raise RuntimeError(name+' failed; see log')
    if not args.octave: raise RuntimeError('Octave executable unavailable; supply --octave')
    for stage in range(1,5):
        folder=next(ROOT.glob(f'{stage}-*')); folder=folder/'QKD_FSO_Octave' if stage==1 else folder
        tests='test_qkd;' if stage==1 else 'test_leo;' if stage==2 else 'test_network; test_network_workflow; test_stage3;'
        expr=f"addpath('{folder.as_posix()}'); {tests}"
        r=subprocess.run([args.octave,'--quiet','--eval',expr],cwd=ROOT,capture_output=True,text=True)
        (dest/f'octave_stage{stage}.log').write_text(r.stdout+r.stderr,encoding='utf-8'); log[f'octave_stage{stage}']=dict(exit_code=r.returncode)
        print('octave_stage',stage,r.returncode,flush=True)
        if r.returncode: raise RuntimeError(f'Octave stage {stage} failed; see log')
    r=subprocess.run([args.octave,'--quiet','--eval',"addpath('shared'); test_extension;"],cwd=ROOT,capture_output=True,text=True)
    (dest/'octave_extension.log').write_text(r.stdout+r.stderr,encoding='utf-8'); print('octave_extension',r.returncode,flush=True)
    if r.returncode: raise RuntimeError('Octave extension tests failed; see log')
    o=json.loads((dest/'octave_extension.json').read_text()); comparisons={}
    def compare(label,a,b,rtol=1e-9,atol=1e-8):
        a,b=np.asarray(a,float),np.asarray(b,float)
        np.testing.assert_allclose(a,b,rtol=rtol,atol=atol,equal_nan=True)
        comparisons[label]=dict(max_absolute_error=float(np.nanmax(abs(a-b))) if a.size else 0,rtol=rtol,atol=atol)
    d=dps_statistics(o['eta_points'])
    for key in ['gain','qber','rate_bits_per_pulse','rate_bits_per_second']:
        compare('DPS '+key,d[key],o['dps'][key])
    f=FadingParameters('correlated_lognormal',.2,2)
    factors=fading_factors(6,f,np.arange(6),innovations=[1,-.2,.5,0,-1,.3]); compare('shared innovations',factors,o['shared_factors'])
    d=dps_statistics(.001*factors)
    for key in ['gain','qber','rate_bits_per_second']: compare('faded DPS '+key,d[key],o['shared_dps'][key])
    for stage in range(1,5):
        r=run_stage(stage); a=o['stages'][stage-1]
        compare(f'stage{stage} rate',r['rate_bits_per_second'],a['rate'],rtol=2e-7,atol=1e-6)
        compare(f'stage{stage} integral',r['summary']['integrated_rate_bits'],a['integrated_rate_bits'],rtol=1e-9,atol=1e-5)
        if stage<3: compare(f'stage{stage} qber',r['qber'],a['qber'],rtol=1e-9,atol=1e-10)
    stochastic=[]
    for row in o['stochastic']:
        f=FadingParameters('independent_lognormal',seed=row['seed']); factors=fading_factors(150000,f)
        s=summarize(dps_statistics(.001*factors),np.arange(len(factors))*.02)
        compare('RNG mean '+str(f.seed),factors.mean(),row['mean_factor'],rtol=0,atol=.008)
        compare('RNG variance '+str(f.seed),factors.var(),row['variance_factor'],rtol=0,atol=.008)
        for key in ['mean_qber','median_qber','p95_qber','mean_rate_bps','median_rate_bps','p05_rate_bps','outage_fraction','integrated_rate_bits']:
            compare('RNG '+key+' '+str(f.seed),s[key],row['summary'][key],rtol=.04,atol=.001)
        stochastic.append(dict(seed=f.seed,python=s,octave=row['summary']))
    convergence=[]
    for n in (201,401,801,1601):
        r=stage2(p=replace(LEOParameters(),sample_count=n))
        convergence.append(dict(stage=2,samples=n,dt_s=float(np.diff(r['time_s'])[0]),integral=r['summary']['integrated_rate_bits']))
    assert abs(convergence[-1]['integral']/convergence[-2]['integral']-1)<.001
    for n in (301,601,1201,2401):
        r=network(4,p=replace(parameters_for_stage(4),time_points=n))
        convergence.append(dict(stage=4,samples=n,dt_s=float(np.diff(r['time_s'])[0]),integral=r['summary']['integrated_rate_bits']))
    assert abs(convergence[-1]['integral']/convergence[-2]['integral']-1)<.01
    # One fixed fine correlated path, subsampled: changes dt without changing realization.
    t=np.linspace(0,100,10001); f=FadingParameters('correlated_lognormal'); fac=fading_factors(len(t),f,t)
    rate=dps_statistics(.001*fac)['rate_bits_per_second']; fine=cumulative_integral(rate,t)[-1]
    for stride in (20,10,5,2,1):
        value=cumulative_integral(rate[::stride],t[::stride])[-1]
        convergence.append(dict(stage='fixed correlated path',samples=len(t[::stride]),dt_s=float(t[stride]),integral=float(value),relative_to_fine=float(value/fine-1)))
    assert abs(convergence[-2]['relative_to_fine'])<.005
    (dest/'verification.json').write_text(json.dumps(json_safe(dict(status='passed',commands=log,cross_language=comparisons,stochastic=stochastic,convergence=convergence)),indent=2),encoding='utf-8')
    print('Cross-language comparison and convergence passed',flush=True)

if __name__=='__main__': main()
