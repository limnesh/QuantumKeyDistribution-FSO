"""Compact Stage 3 comparison plots, data, report and numerical fixtures."""
import csv
from dataclasses import asdict, replace
import html
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from network_model import PROJECT_ROOT, json_safe, parameters_for_stage
from network_report import configure_plots
from stage3_model import BBM92Parameters, simulate_stage3


def plot_comparison(c):
    configure_plots()
    t=c['time_s']/60; r=c['network']; e=c['bbm92']; a=c['trusted']
    fig,axes=plt.subplots(3,2,figsize=(12.5,11),layout='constrained')
    ax=axes.ravel()
    if not e['available']:
        for axis in ax: axis.set_axis_off()
        ax[0].text(0,1,'Trusted BB84 completed. BBM92 comparison unavailable:\n'+e['reason'],
                   va='top',wrap=True,transform=ax[0].transAxes)
        return fig
    for values,label,color in [(e['visible_a'],'Ground A','#087f8c'),(e['visible_b'],'Ground B','#b05d28'),
                               (e['common_visibility'],'Common visibility','#20354f')]:
        ax[0].step(t,values.astype(float),where='mid',label=label,color=color)
    ax[0].set(title='Shared geometry: individual and common contact',ylabel='Available (0 / 1)',ylim=(-.1,1.4))
    for edge in r['edges']:
        with np.errstate(divide='ignore'): loss=-10*np.log10(edge['eta'])
        ax[1].plot(t,np.where(np.isfinite(loss),loss,np.nan),label=edge['label'])
    ax[1].set(title='Shared optical/detector loss (includes detector once)',ylabel='Total loss (dB)')
    for values,label in [(a['detection_a_hz'],'BB84 A clicks'),(a['detection_b_hz'],'BB84 B clicks'),
                         (e['singles_a_hz'],'BBM92 A singles'),(e['singles_b_hz'],'BBM92 B singles')]:
        ax[2].plot(t,values/1000,label=label)
    ax[2].set(title='Different transmitter resources; same link geometry',ylabel='Registered count rate (kcount/s)')
    for field,label in [('true_coincidence_hz','True before timing filter'),('accepted_true_hz','Accepted true'),
                        ('accidental_coincidence_hz','Accidental')]:
        ax[3].plot(t,e[field],label=label)
    ax[3].set(title='BBM92: coincidences only in common visibility',ylabel='Coincidences / s')
    ax[4].plot(t,100*a['qber_a'],label='BB84 link A'); ax[4].plot(t,100*a['qber_b'],label='BB84 link B')
    ax[4].plot(t,100*e['qber'],label='BBM92 coincidence QBER')
    ax[4].set(title='Per-link BB84 errors versus pair errors',ylabel='QBER (%)')
    for values,label in [(a['simultaneous_rate_bps'],'Trusted simultaneous benchmark'),(e['key_rate_bps'],'BBM92 asymptotic estimate')]:
        ax[5].semilogy(t,np.where(values>0,values,np.nan),label=label)
    ax[5].set(title='Asymptotic secret-key-rate estimate (zero omitted)',ylabel='Estimated key rate (bit/s, log)')
    for x in ax:
        x.set_xlabel('Time from orbit midpoint (min)'); x.legend(fontsize=8)
    p=r['parameters']; fig.suptitle(f'Stage 3: Trusted Satellite Relay / BBM92 | {p.ground_separation_km:g} km separation, {p.link.altitude_km:g} km altitude',fontsize=14)
    return fig


def plot_key_budgets(c):
    configure_plots(); t=c['time_s']/60; a=c['trusted']; e=c['bbm92']; i=a['inventory']
    fig,ax=plt.subplots(1,2,figsize=(12.5,4.5),layout='constrained')
    for name,label in [('generated_a_bits','Link A generated'),('generated_b_bits','Link B generated')]:
        ax[0].plot(t,i[name]/1e6,label=label)
    ax[0].step(t,i['delivered_bits']/1e6,where='post',label='Causal stored-key relay',linewidth=2)
    ax[0].plot(t,a['simultaneous_bits']/1e6,'--',label='Simultaneous benchmark')
    ax[0].set(title='Mode A: generation and consumption',ylabel='Expected key budget (Mbit)')
    ax[1].plot(t,e['cumulative_key_bits'],label='BBM92 asymptotic integral',color='#b05d28',linewidth=2)
    ax[1].set(title='Mode B: same-period coincidence key estimate',ylabel='Estimated bits (bit)')
    if not e['available']:
        ax[1].text(.02,.5,'BBM92 unavailable for these settings.\nSee comparison report for the reason.',transform=ax[1].transAxes)
    for x in ax: x.set_xlabel('Time (min)'); x.legend(fontsize=8)
    fig.suptitle('Stage 3: distinct source resources and security assumptions; neither mode is universally superior',fontsize=12)
    return fig


def comparison_rows(c):
    e=c['bbm92']; r=c['network']; a=c['trusted']
    return [
        ('Ground separation (km)',r['parameters'].ground_separation_km),
        ('Common visibility (s, sampled)',e['metrics']['common_visibility_s']),
        ('BB84 link A generated (bit)',a['inventory']['generated_a_bits'][-1]),
        ('BB84 link B generated (bit)',a['inventory']['generated_b_bits'][-1]),
        ('Trusted simultaneous benchmark (bit)',a['simultaneous_bits'][-1]),
        ('Trusted causal stored relay delivered (expected bit)',a['delivered_bits']),
        ('BBM92 peak true coincidences (/s)',np.max(e['true_coincidence_hz'])),
        ('BBM92 peak total coincidences (/s)',np.max(e['coincidence_hz'])),
        ('BBM92 pooled QBER (fraction)',e['metrics']['pooled_qber']),
        ('BBM92 peak asymptotic key estimate (bit/s)',e['metrics']['peak_key_rate_bps']),
        ('BBM92 integrated asymptotic estimate (bit)',e['metrics']['integrated_key_bits']),
    ]


def export_comparison(c, output_dir):
    folder=Path(output_dir);folder.mkdir(parents=True,exist_ok=True)
    for name,fn in [('comparison',plot_comparison),('key_budgets',plot_key_budgets)]:
        fig=fn(c);fig.savefig(folder/f'{name}.png',bbox_inches='tight');plt.close(fig)
    e=c['bbm92'];a=c['trusted'];r=c['network']
    series={'time_s':c['time_s']}
    for k in ('visible_a','visible_b','common_visibility','eta_a','eta_b','singles_a_hz','singles_b_hz',
              'true_coincidence_hz','accepted_true_hz','accidental_coincidence_hz','coincidence_hz',
              'qber','sifted_rate_bps','key_rate_bps','cumulative_key_bits'):
        series['bbm92_'+k]=e[k]
    for k in ('detection_a_hz','detection_b_hz','qber_a','qber_b','simultaneous_rate_bps','simultaneous_bits'):
        series['trusted_'+k]=a[k]
    series.update({'trusted_'+k:v for k,v in a['inventory'].items()})
    for side,edge in zip('ab',r['edges']):
        for field in ('elevation_deg','distance_km','key_rate_bps'): series[f'link_{side}_{field}']=edge[field]
    with (folder/'comparison.csv').open('w',newline='',encoding='utf8') as f:
        w=csv.writer(f);w.writerow(series)
        for row in zip(*series.values()):w.writerow([json_safe(v) for v in row])
    summary=dict(mode=c['mode'],architecture=c['architecture'],network_parameters=asdict(r['parameters']),
                 bbm92_parameters=asdict(c['parameters']),bbm92_available=e['available'],
                 bbm92_status=e['reason'],metrics=dict(comparison_rows(c)))
    (folder/'summary.json').write_text(json.dumps(json_safe(summary),indent=2,allow_nan=False)+'\n',encoding='utf8')
    # Same orbit/environment, change only station separation to show architecture dependence.
    separate=simulate_stage3(replace(r['parameters'],ground_separation_km=4000),'trusted',c['parameters'])
    unavailable = '' if e['available'] else '<p><strong>BBM92 comparison unavailable:</strong> '+html.escape(e['reason'])+'. NaN/null means unavailable, not zero.</p>'
    rows=''.join(f'<tr><th>{html.escape(k)}</th><td>{v:,.7g}</td></tr>' for k,v in comparison_rows(c))
    (folder/'report.html').write_text(f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Stage 3: Trusted BB84 / BBM92</title>
<style>body{{font:16px/1.6 system-ui;max-width:1200px;margin:35px auto;padding:0 24px;color:#20354f}}img{{width:100%}}td,th{{text-align:left;padding:7px 18px;border-bottom:1px solid #ddd}}table{{border-collapse:collapse}}code{{background:#eef3f6}}</style>
<h1>Stage 3: Trusted Satellite Relay and Entanglement-Based Satellite QKD</h1>
<p>One common circular orbit, atmosphere and optical/detector budget; two separate architectures.
Mode A uses 100 MHz weak-coherent-pulse clocks at the default settings, independently per downlink, with signal allocation 0.8 and mean 0.5 photons.
Mode B uses a CW pair source (default 10 million pairs/s), one photon to each station.
Exact settings are in <a href="summary.json">summary.json</a>; values are simulated expectations.</p>
{unavailable}<table>{rows}</table>
<p>At 4000 km separation with otherwise identical settings: common visibility = {separate['bbm92']['metrics']['common_visibility_s']:g} s;
trusted causal stored delivery = {separate['trusted']['delivered_bits']:,.3f} expected bits;
BBM92 = {separate['bbm92']['metrics']['integrated_key_bits']:g} estimated bits. No entangled pair is carried between passes.</p>
<img src="comparison.png" alt="Visibility, optical loss, singles, coincidences, QBER and asymptotic rates">
<img src="key_budgets.png" alt="Trusted generated and consumed key budgets, and BBM92 estimated key integral">
<p><strong>Mode A:</strong> The satellite is trusted and may know the final relayed key. Pools start empty; trapezoid-generated interval amounts become available at the interval end; each delivered bit consumes one bit from each pool. Unlimited demand, classical storage and negligible authenticated relay delay/cost are assumed.</p>
<p><strong>Mode B:</strong> The satellite distributes ideal Bell pairs; no satellite key is assigned.
The high-loss CW model includes noise/accidentals, Gaussian timing acceptance and independent per-arm misalignment.
The BBM92 rate is q C max[1-f h2(Ebit)-h2(Ephase),0], assuming Ephase=Ebit and basis-independent trusted receivers.
Both bases must be randomly measured and tested, classical messages authenticated, and the receiver/squashing and adversarial-source assumptions of a security proof satisfied. These requirements are assumed, not established by this numerical model.
This is an <strong>asymptotic secret-key-rate estimate</strong>, not a validated composably secure finite-key rate or a device-independent claim.</p>
<p>Equations: <a href="https://arxiv.org/abs/2103.14639">Neumann et al. (2021)</a> (CW coincidences, timing acceptance, BBM92);
<a href="https://arxiv.org/abs/quant-ph/0503005">Ma et al. (2005)</a> (ideal decoy BB84).</p>
<p>Data: <a href="comparison.csv">comparison.csv</a>. No quantum memory, swapping or repeater model. No wavelength parameter is introduced because divergence, losses and detector efficiency are already independent specified inputs. These source/hardware choices do not establish universal superiority.</p></html>''',encoding='utf8')
    return folder/'report.html'


def write_reference():
    cases=[]
    for name,sep,detector,pointing,pairs in [('default',1000,.5,1,1e7),('separate_contacts',4000,.5,1,1e7),
        ('zero_detection',1000,0,1,1e7),('more_loss',1000,.5,4,1e7),('zero_pairs',1000,.5,1,0)]:
        p=parameters_for_stage(3);p=replace(p,ground_separation_km=sep,link=replace(p.link,detector_efficiency=detector,pointing_loss_db=pointing))
        b=replace(BBM92Parameters(),pair_rate_hz=pairs);c=simulate_stage3(p,'bbm92',b);e=c['bbm92'];r=c['network']
        sample=[0,150,200,250,300,350,400,450,600]
        values={k:e[k][sample] for k in ['eta_a','eta_b','true_coincidence_hz','coincidence_hz','qber','key_rate_bps']}
        values.update(elevation_a_deg=r['edges'][0]['elevation_deg'][sample],range_a_km=r['edges'][0]['distance_km'][sample],
                      delivered_bits=c['trusted']['inventory']['delivered_bits'][sample])
        cases.append(dict(name=name,ground_separation_km=sep,detector_efficiency=detector,pointing_loss_db=pointing,
                          pair_rate_hz=pairs,sample_indices=sample,values=values,
                          bbm92_total=e['metrics']['integrated_key_bits'],trusted_total=c['trusted']['delivered_bits']))
    path=Path(__file__).with_name('stage3_python_reference.json')
    path.write_text(json.dumps(json_safe(dict(cases=cases)),indent=2,allow_nan=False)+'\n',encoding='utf8')
    return path


if __name__=='__main__':
    c=simulate_stage3(mode='bbm92')
    print(export_comparison(c,PROJECT_ROOT/'3-Two Ground and One Satellite'/'comparison_results'))
    print(write_reference())
    for key,value in comparison_rows(c): print(f'{key}: {value:.10g}')
