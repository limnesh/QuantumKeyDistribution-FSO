"""Common CSV/JSON exports and figures. Zero rates remain exactly zero."""
from dataclasses import asdict,is_dataclass,replace
from pathlib import Path
import csv,json
import numpy as np
import matplotlib.pyplot as plt
from .physics import DPSParameters,FadingParameters,dps_statistics,fading_factors,pulse_train
from .scenarios import run_stage,stage2,network,evaluate_link,terrestrial_eta,LEOParameters,parameters_for_stage

def json_safe(x):
    if is_dataclass(x): return json_safe(asdict(x))
    if isinstance(x,dict): return {k:json_safe(v) for k,v in x.items() if k!='baseline'}
    if isinstance(x,(list,tuple)): return [json_safe(v) for v in x]
    if isinstance(x,np.ndarray): return json_safe(x.tolist())
    if isinstance(x,np.generic): return json_safe(x.item())
    if isinstance(x,float) and not np.isfinite(x): return None
    return x

def export_result(r,folder):
    folder=Path(folder); folder.mkdir(parents=True,exist_ok=True)
    (folder/'results.json').write_text(json.dumps(json_safe(r),indent=2,allow_nan=False),encoding='utf-8')
    def table(data,path):
        n=len(r['time_s']); cols={k:v for k,v in data.items()
              if isinstance(v,np.ndarray) and v.shape==(n,) and v.dtype.kind in 'biuf'}
        with path.open('w',newline='',encoding='utf-8') as f:
            w=csv.writer(f); w.writerow(cols); w.writerows(zip(*cols.values()))
    table(r,folder/'timeseries.csv')
    for k,e in enumerate(r.get('edges',[])): table(e,folder/f'edge_{k+1}.csv')
    if 'inventory' in r: table(dict(time_s=r['time_s'],**r['inventory']),folder/'trusted_inventory.csv')
    if r.get('bbm92',{}).get('available'): table(dict(time_s=r['time_s'],**r['bbm92']),folder/'bbm92.csv')
    if 'route_nodes' in r:
        with (folder/'routes.csv').open('w',newline='',encoding='utf-8') as f:
            w=csv.writer(f); w.writerow(['time_s','route','rate_bits_per_second'])
            w.writerows((t,' -> '.join(r['node_names'][n] for n in route) or 'disconnected',rate)
                        for t,route,rate in zip(r['time_s'],r['route_nodes'],r['rate_bits_per_second']))

def plot_result(r,baseline=None):
    figs=[]; stage=r['stage']; t=r['time_s']; proxy='proxy ' if 'proxy' in r['metadata']['security_status'] else ''
    def new(title,n=4):
        fig,axes=plt.subplots((n+1)//2,2,figsize=(12,3.6*((n+1)//2)),squeeze=False,layout='constrained')
        fig.suptitle(title); figs.append(fig); return axes.ravel()
    def line(ax,x,y,xlabel,ylabel,label=None):
        ax.plot(x,y,label=label); ax.set(xlabel=xlabel,ylabel=ylabel); ax.grid(alpha=.25)
        if label: ax.legend(fontsize=8)
    a=new(f'Stage {stage}: {r["metadata"]["protocol"]} — {r["metadata"]["security_status"]}')
    line(a[0],t,r['rate_bits_per_second'],'Time (s)',f'Rate ({proxy}bits/s)',r['metadata']['fading']['mode'])
    if baseline: line(a[0],t,baseline['rate_bits_per_second'],'Time (s)',f'Rate ({proxy}bits/s)','deterministic')
    line(a[1],t,r['cumulative_rate_integral_bits'],'Time (s)',f'Integrated rate ({proxy}bits)')
    if stage<3:
        line(a[2],t,r['qber']*100,'Time (s)','DPS protocol QBER (%)' if r['protocol']=='DPS QKD' else 'QBER (%)')
        line(a[3],t,r['fading_factor'],'Time (s)','Collected-power factor (1)')
    else:
        for e in r['edges']:
            line(a[2],t,e['rate_bits_per_second'],'Time (s)',f'Edge rate ({proxy}bits/s)',e['label'])
            line(a[3],t,e['fading_factor'],'Time (s)','Collected-power factor (1)',e['label'])
    if stage==1:
        d=DPSParameters(**r['metadata']['dps']); f=FadingParameters(**r['metadata']['fading'])
        a=new('DPS distance and visibility sensitivity')
        distance=np.linspace(1000,80000,301); vis=np.linspace(.8,1,101)
        base=dps_statistics(terrestrial_eta(distance),d)
        for ax,key,y in [(a[0],'qber','QBER (fraction)'),(a[1],'rate_bits_per_second','DPS proxy rate (bits/s)')]:
            line(ax,distance/1000,base[key],'Distance (km)',y)
        results=[dps_statistics(terrestrial_eta(20000),replace(d,visibility=v)) for v in vis]
        line(a[2],vis,[b['qber'] for b in results],'Visibility (1)','DPS QBER (fraction)')
        line(a[3],vis,[b['rate_bits_per_second'] for b in results],'Visibility (1)','DPS proxy rate (bits/s)')
        # Distribution study deliberately has no elapsed-time/integral claim.
        mc=evaluate_link(np.full(5000,terrestrial_eta(20000)),.25,fading=replace(f,mode='independent_lognormal'),dps=d)
        a=new('Independent Monte Carlo: 5,000 samples, no elapsed-time interpretation')
        for ax,key,label in zip(a,['fading_factor','qber','rate_bits_per_second'],['Power factor (1)','DPS QBER (fraction)','DPS proxy rate (bits/s)']):
            ax.hist(mc[key],bins=45); ax.set(xlabel=label,ylabel='Sample count (1)')
        a[3].axis('off'); a[3].text(0,1,'\n'.join(f'{k}: {v:.6g}' for k,v in mc['summary'].items() if isinstance(v,float)),va='top',fontsize=9)
        a=new('Terrestrial design sensitivity — simulated parameters')
        for ax,values,change,label in [
            (a[0],np.linspace(.05,.3,30),'aperture','Receiver radius (m)'),
            (a[1],np.geomspace(1e-8,1e-3,35),'background','Registered background / detector / gate (1)')]:
            rr=[dps_statistics(terrestrial_eta(20000,v) if change=='aperture' else terrestrial_eta(20000),
                 replace(d,background_per_detector=v) if change=='background' else d)['rate_bits_per_second'] for v in values]
            line(ax,values,rr,label,'DPS proxy rate (bits/s)')
            if change=='background': ax.set_xscale('log')
        strengths=np.linspace(0,.8,9); means=[]; p05=[]
        for s in strengths:
            m=evaluate_link(np.full(5000,terrestrial_eta(20000)),.25,fading=replace(f,mode='independent_lognormal',sigma=s),dps=d)
            means.append(m['summary']['mean_rate_bps']); p05.append(m['summary']['p05_rate_bps'])
        line(a[2],strengths,means,'Log-irradiance standard deviation sigma (1)','DPS proxy rate (bits/s)','mean')
        line(a[2],strengths,p05,'Log-irradiance standard deviation sigma (1)','DPS proxy rate (bits/s)','5th percentile')
        train=pulse_train([0,1,1,0,1]); line(a[3],np.arange(7),train['port_mean_photons'][:,0],'Output slot (1)','Mean photons (1)','port 0')
        line(a[3],np.arange(7),train['port_mean_photons'][:,1],'Output slot (1)','Mean photons (1)','port 1; boundary slots discarded')
    if stage==2:
        a=new('LEO geometry and DPS elevation dependence')
        line(a[0],t,r['elevation_deg'],'Time (s)','Elevation (deg)')
        line(a[1],t,r['distance_m']/1000,'Time (s)','Path length (km)','slant range')
        line(a[1],t,r['atmospheric_path_m']/1000,'Time (s)','Path length (km)','atmospheric shell')
        line(a[2],r['elevation_deg'],r['qber']*100,'Elevation (deg)','DPS QBER (%)')
        line(a[3],r['elevation_deg'],r['rate_bits_per_second'],'Elevation (deg)',f'DPS {proxy}rate (bits/s)')
    if stage>=3:
        a=new('Link errors, availability and routing')
        for e in r['edges']:
            line(a[0],t,e['qber']*100,'Time (s)','Link QBER (%)',e['label'])
            line(a[1],t,e['visible'].astype(float),'Time (s)','Geometric availability (0/1)',e['label'])
        keys=[tuple(x) for x in r['route_nodes']]; unique=list(dict.fromkeys(keys)); ids=[unique.index(x) for x in keys]
        a[2].step(t,ids,where='mid'); a[2].set(xlabel='Time (s)',ylabel='Selected route (categorical)',yticks=range(len(unique)),
            yticklabels=['-'.join(r['node_names'][n] for n in k) or 'disconnected' for k in unique])
        a[3].fill_between(t,0,(r['rate_bits_per_second']<=0).astype(float),step='mid')
        a[3].set(xlabel='Time (s)',ylabel='Rate outage (0/1)')
        a=new('Network topology and edge capacities',2); idx=int(np.argmax(r['rate_bits_per_second'])); pos=r['positions_km'][idx]
        angle=np.linspace(0,2*np.pi,300); a[0].plot(6371*np.cos(angle),6371*np.sin(angle),label='Earth')
        a[0].scatter(pos[:,0],pos[:,1]);
        for k,name in enumerate(r['node_names']): a[0].annotate(name,pos[k,:2])
        for e in r['edges']:
            a[0].plot(pos[[e['i'],e['j']],0],pos[[e['i'],e['j']],1],'-' if e['visible'][idx] else ':')
        a[0].set(xlabel='Orbital plane x (km)',ylabel='Orbital plane y (km)',aspect='equal')
        for e in r['edges']: line(a[1],t,e['rate_bits_per_second'],'Time (s)',f'Capacity ({proxy}bits/s)',e['label'])
    if stage==3:
        a=new('Trusted relay: stored classical pools and simultaneous benchmark')
        inv=r['inventory']
        for key in ('generated_a_bits','generated_b_bits'): line(a[0],t,inv[key],'Time (s)',f'Generated ({proxy}bits)',key)
        for key in ('pool_a_bits','pool_b_bits'): line(a[1],t,inv[key],'Time (s)',f'Remaining pool ({proxy}bits)',key)
        line(a[2],t,inv['delivered_bits'],'Time (s)',f'Delivered ({proxy}bits)')
        line(a[3],t,np.minimum(*[e['rate_bits_per_second'] for e in r['edges']]),'Time (s)',f'Simultaneous bottleneck ({proxy}bits/s)')
        if r['bbm92']['available']:
            b=r['bbm92']; a=new('BBM92: two-arm fading and coincidences (separate source and security assumptions)',6)
            for e in r['edges']: line(a[0],t,e['fading_factor'],'Time (s)','Power factor (1)',e['label'])
            for key in ('singles_a_hz','singles_b_hz'): line(a[1],t,b[key],'Time (s)','Singles (counts/s)',key)
            for key in ('true_coincidence_hz','accidental_coincidence_hz'): line(a[2],t,b[key],'Time (s)','Coincidences (counts/s)',key)
            line(a[3],t,b['qber']*100,'Time (s)','BBM92 QBER (%)')
            line(a[4],t,b['key_rate_bps'],'Time (s)','BBM92 asymptotic rate (bits/s)','faded')
            if baseline and baseline.get('bbm92',{}).get('available'): line(a[4],t,baseline['bbm92']['key_rate_bps'],'Time (s)','BBM92 asymptotic rate (bits/s)','deterministic')
            line(a[5],t,b['cumulative_rate_integral_bits'],'Time (s)','BBM92 integrated estimate (bits)')
    return figs

def study(stage,folder=None,realizations=12,show=False):
    """Execute default DPS comparison plus seed ensemble and design sweeps."""
    f=FadingParameters(mode='correlated_lognormal'); d=DPSParameters()
    base=run_stage(stage,fading=replace(f,mode='none'),dps=d)
    r=run_stage(stage,fading=f,dps=d); figs=plot_result(r,base)
    rows=[]
    for seed in range(realizations):
        x=run_stage(stage,fading=replace(f,seed=1000+seed),dps=d)
        rows.append(dict(seed=1000+seed,**x['summary']))
    strengths=[0,.2,.4,.6,.8]; sweep=[]
    for sigma in strengths:
        totals=[run_stage(stage,fading=replace(f,sigma=sigma,seed=2000+seed),dps=d)['summary']['integrated_rate_bits'] for seed in range(5)]
        sweep.append(dict(sigma=sigma,mean_bits=float(np.mean(totals)),p05_bits=float(np.percentile(totals,5)),p95_bits=float(np.percentile(totals,95))))
    fig,ax=plt.subplots(1,2,figsize=(12,4),layout='constrained'); figs.append(fig)
    ax[0].hist([x['integrated_rate_bits'] for x in rows],bins=min(realizations,10)); ax[0].set(xlabel='Integrated DPS proxy (bits)',ylabel='Realization count (1)',title='Fixed geometry, independent realizations')
    ax[1].plot(strengths,[x['mean_bits'] for x in sweep],'o-',label='mean')
    ax[1].fill_between(strengths,[x['p05_bits'] for x in sweep],[x['p95_bits'] for x in sweep],alpha=.2,label='5–95% sample interval')
    ax[1].legend()
    ax[1].set(xlabel='Log-irradiance standard deviation sigma (1)',ylabel='Integrated DPS proxy (bits)',title='Five seeds: mean and 5–95% sample interval')
    extra=[]
    if stage in (2,4):
        vals=[5,10,20,30] if stage==2 else [2,3,4,6]
        for val in vals:
            kwargs={'p':replace(LEOParameters(),minimum_elevation_deg=val)} if stage==2 else {'p':replace(parameters_for_stage(4),satellite_count=val)}
            for seed in range(5):
                x=run_stage(stage,fading=replace(f,seed=3000+seed),**kwargs)
                extra.append(dict(parameter=val,seed=3000+seed,integrated_rate_bits=x['summary']['integrated_rate_bits']))
        fig,ax=plt.subplots(figsize=(7,4),layout='constrained'); figs.append(fig)
        means=[np.mean([x['integrated_rate_bits'] for x in extra if x['parameter']==v]) for v in vals]
        ax.plot(vals,means,'o-'); ax.set(xlabel='Elevation cutoff (deg)' if stage==2 else 'Satellite count (1)',ylabel='Mean integrated DPS proxy (bits)',title='Five independent realizations per setting')
    if folder is not None:
        folder=Path(folder); export_result(r,folder); export_result(base,folder/'deterministic')
        for name,data in [('ensemble',rows),('turbulence_sensitivity',sweep),('design_sensitivity',extra)]:
            if data:
                with (folder/(name+'.csv')).open('w',newline='',encoding='utf-8') as file:
                    writer=csv.DictWriter(file,fieldnames=data[0]); writer.writeheader(); writer.writerows(data)
        for k,fig in enumerate(figs,1): fig.savefig(folder/f'figure_{k:02d}.png',dpi=140)
        import html
        table=''.join(f'<tr><td>{html.escape(k)}</td><td>{html.escape(str(v))}</td></tr>' for k,v in r['summary'].items())
        (folder/'report.html').write_text('<!doctype html><meta charset="utf-8"><title>DPS / turbulence study</title><h1>Stage '+str(stage)+'</h1><p>'+html.escape(r['metadata']['security_status'])+'</p><p>Simulated data. Independent per-edge resources. No certified secret key. Parameters and units: results.json. Ensemble: ensemble.csv.</p><table>'+table+'</table>'+''.join(f'<img style="max-width:100%" src="figure_{k:02d}.png" alt="Stage {stage} analysis figure {k}">' for k in range(1,len(figs)+1)),encoding='utf-8')
    if show: plt.show()
    else:
        for fig in figs: plt.close(fig)
    return r,rows,sweep
