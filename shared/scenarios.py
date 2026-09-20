"""Adapters retaining existing geometry, BB84 baselines, BBM92 and routing."""
from dataclasses import asdict, replace
from pathlib import Path
import sys
import numpy as np
from .physics import (DPSParameters,FadingParameters,dps_statistics,fading_factors,
                      fade_efficiency,cumulative_integral,summarize,SECURITY,h2)

ROOT=Path(__file__).resolve().parent.parent
for folder in ('2-Ground Station and Satellite','3-Two Ground and One Satellite'):
    path=str(ROOT/folder)
    if path not in sys.path: sys.path.insert(0,path)
from leo_model import LEOParameters,simulate_pass,qkd_probabilities
from network_model import parameters_for_stage,simulate_network,widest_path
from stage3_model import bbm92_rates,trusted_inventory,BBM92Parameters

def metadata(protocol,fading,dps):
    return dict(model_name='dps_fso_extension',model_version='1.0',protocol=protocol,
        security_status=SECURITY if protocol=='DPS QKD' else 'BB84 asymptotic estimate',
        assumptions=['quasi-static fading across adjacent optical pulses','independent edge terminals',
                     'phenomenological weak log-normal collected-power fluctuations',
                     'fixed detector efficiency; registered background counts'],
        units={'time_s':'s','distance_m':'m','qber':'fraction','gain':'per valid gate',
               'rate_bits_per_pulse':'bits/emitted pulse','rate_bits_per_second':'bits/s',
               'cumulative_rate_integral_bits':'bits (proxy for DPS)'},
        random_seed=fading.seed,fading=asdict(fading),dps=asdict(dps))

def evaluate_link(eta,detector,time_s=None,protocol='DPS QKD',fading=None,dps=None,
                  link=None,visible=True,stream=0,atmospheric=True,stage1=False,factors=None):
    f=(fading or FadingParameters()).validate(); d=(dps or DPSParameters()).validate()
    eta=np.atleast_1d(np.asarray(eta,float)); visible=np.broadcast_to(visible,eta.shape)
    factors=(fading_factors(len(eta),f,time_s,stream) if factors is None else factors)
    a=fade_efficiency(eta,detector,factors,atmospheric)
    if protocol=='DPS QKD':
        r=dps_statistics(a['eta_total_faded'],d)
    elif protocol in ('BB84','Decoy-state BB84'):
        p=link or LEOParameters(detector_efficiency=detector)
        b=qkd_probabilities(a['eta_total_faded'],p)
        if stage1:
            # Original terrestrial additive-background convention retained.
            sig=-np.expm1(-p.mean_photons*a['eta_total_faded']); gain=sig+p.background_yield
            q=np.divide(p.optical_error_probability*sig+.5*p.background_yield,gain,
                        out=np.full_like(gain,np.nan),where=gain>0)
            y1=1-(1-p.background_yield)*(1-a['eta_total_faded'])
            e1=np.divide(p.optical_error_probability*a['eta_total_faded']+.5*p.background_yield,
                         y1,out=np.zeros_like(y1),where=y1>0)
            entropy=h2(np.nan_to_num(q,nan=.5))
            b.update(gain=gain,qber=q,
                rate_bb84_reference_per_pulse=.5*gain*np.maximum(1-(1+p.error_correction_efficiency)*entropy,0),
                rate_decoy_per_pulse=.5*np.maximum(p.mean_photons*np.exp(-p.mean_photons)*y1*(1-h2(np.minimum(e1,1)))-p.error_correction_efficiency*gain*entropy,0))
        key='rate_decoy_per_pulse' if protocol=='Decoy-state BB84' else 'rate_bb84_reference_per_pulse'
        r=dict(protocol=protocol,qber=b['qber'],gain=b['gain'],rate_bits_per_pulse=b[key],
               rate_bits_per_second=b[key]*p.pulse_rate_hz*p.signal_duty,
               detection_rate_hz=b['gain']*p.pulse_rate_hz*p.signal_duty,
               error_rate_hz=np.nan_to_num(b['qber'])*b['gain']*p.pulse_rate_hz*p.signal_duty)
    else: raise ValueError('Unknown trusted-link protocol')
    for key in ('gain','rate_bits_per_pulse','rate_bits_per_second','detection_rate_hz','error_rate_hz','error_gain','double_click_gain'):
        if key in r: r[key]=np.where(visible,r[key],0)
    r['qber']=np.where(visible,r['qber'],np.nan)
    r.update(a,visible=visible,fading_mode=f.mode,eta_detector=detector)
    r['metadata']=metadata(protocol,f,d)
    r['summary']=summarize(r,time_s)
    if time_s is not None:
        r['time_s']=np.asarray(time_s)
        r['cumulative_rate_integral_bits']=cumulative_integral(r['rate_bits_per_second'],time_s)
    if protocol=='DPS QKD':
        r['summary']['rate_at_mean_efficiency_bps']=float(dps_statistics(np.mean(a['eta_total_faded']),d)['rate_bits_per_second'])
        r['summary']['rate_at_mean_efficiency_scope']='single continuously open gate at mean eta; includes unavailable samples in mean eta'
    return r

def terrestrial_eta(distance_m,receiver_radius_m=.1,detector=.25):
    distance=np.asarray(distance_m,float)
    if np.any(~np.isfinite(distance)) or np.any(distance<0) or not np.isfinite(receiver_radius_m) or receiver_radius_m<=0:
        raise ValueError('Distance must be nonnegative; aperture radius positive')
    geo=-np.expm1(-2*receiver_radius_m**2/(.05**2+(50e-6*distance)**2))
    atm=10**(-.2*distance/1000/10)
    return geo*atm*.7*detector

def stage1(protocol='DPS QKD',fading=None,dps=None,samples=5000,dt_s=.02,
           distance_m=20000,receiver_radius_m=.1):
    if not isinstance(samples,int) or samples<2 or not np.isfinite(dt_s) or dt_s<=0:
        raise ValueError('Need >=2 samples and positive dt_s')
    f=fading or FadingParameters(); t=np.arange(samples)*dt_s
    eta=np.full(samples,terrestrial_eta(distance_m,receiver_radius_m))
    r=evaluate_link(eta,.25,t,protocol,f,dps,stage1=True)
    r.update(stage=1,distance_m=np.full(samples,distance_m),scenario_parameters=dict(
        distance_m=distance_m,receiver_radius_m=receiver_radius_m,detector_efficiency=.25,
        beam_waist_m=.05,divergence_rad=50e-6,atmospheric_loss_db_km=.2,optical_efficiency=.7,
        samples=samples,dt_s=dt_s,bb84_mean_photons=.5,bb84_background_yield=2e-6,
        bb84_optical_error=.015,bb84_ec_efficiency=1.16,bb84_pulse_rate_hz=1e8,bb84_signal_duty=.8))
    r.update(eta_geometric=np.full(samples,-np.expm1(-2*receiver_radius_m**2/(.05**2+(50e-6*distance_m)**2))),
             eta_atmospheric=np.full(samples,10**(-.2*distance_m/1000/10)),eta_optical=np.full(samples,.7))
    return r

def stage2(protocol='DPS QKD',fading=None,dps=None,p=None):
    p=(p or LEOParameters()).validate(); base=simulate_pass(p)
    r=evaluate_link(base['eta'],p.detector_efficiency,base['time_s'],protocol,fading,dps,p)
    r.update(stage=2,distance_m=base['slant_range_km']*1000,
             elevation_deg=base['elevation_deg'],atmospheric_path_m=base['atmosphere_path_km']*1000,
             eta_geometric=base['geometric_efficiency'],eta_atmospheric=10**(-base['atmosphere_loss_db']/10),
             eta_pointing=np.full_like(base['eta'],10**(-p.pointing_loss_db/10)),
             eta_optical=np.full_like(base['eta'],p.optical_efficiency),baseline=base,scenario_parameters=asdict(p))
    return r

def network(stage=3,protocol='DPS QKD',fading=None,dps=None,p=None,mode='trusted',protocols=None,bbm92=None):
    if stage not in (3,4) or mode not in ('trusted','bbm92') or (stage==4 and mode=='bbm92'):
        raise ValueError('BBM92 is restricted to the stage 3 two-arm architecture')
    p=(p or parameters_for_stage(stage)).validate()
    if p.stage!=stage: raise ValueError('Parameter stage mismatch')
    f=fading or FadingParameters(); d=dps or DPSParameters(); base=simulate_network(p)
    edges=[]; t=base['time_s']
    if protocols is not None and len(protocols)!=len(base['edges']):
        raise ValueError('Provide exactly one protocol for each edge')
    for k,e in enumerate(base['edges']):
        selected=protocol if protocols is None else protocols[k]
        lp=replace(p.link,background_yield=p.isl_background_yield) if e['kind']=='isl' else p.link
        dp=replace(d,background_per_detector=p.isl_background_yield/2) if e['kind']=='isl' else d
        r=evaluate_link(e['eta'],p.link.detector_efficiency,t,selected,f,dp,lp,e['visible'],k,
                        e['kind']=='ground')
        r.update(i=e['i'],j=e['j'],label=e['label'],kind=e['kind'],distance_m=e['distance_km']*1000,
                 elevation_deg=e['elevation_deg'])
        if e['kind']=='ground':
            angle=np.deg2rad(np.clip(e['elevation_deg'],0,90)); re=p.link.earth_radius_km
            r['atmospheric_path_m']=1000*(np.sqrt((re+p.link.atmosphere_height_km)**2-(re*np.cos(angle))**2)-re*np.sin(angle))
            r['eta_atmospheric']=10**(-p.link.zenith_atmosphere_loss_db*r['atmospheric_path_m']/1000/p.link.atmosphere_height_km/10)
            divergence,aperture,pointing=p.link.divergence_rad,p.link.receiver_radius_m,p.link.pointing_loss_db
        else:
            divergence,aperture,pointing=p.isl_divergence_rad,p.isl_receiver_radius_m,p.isl_pointing_loss_db
        r['eta_geometric']=-np.expm1(-2*aperture**2/(p.link.beam_waist_m**2+(divergence*r['distance_m'])**2))
        r['eta_pointing']=np.full_like(t,10**(-pointing/10))
        r['eta_optical']=np.full_like(t,p.link.optical_efficiency)
        edges.append(r)
    rates=np.zeros(len(t)); routes=[]
    for j in range(len(t)):
        a=np.zeros((len(base['node_names']),)*2)
        for e in edges: a[e['i'],e['j']]=a[e['j'],e['i']]=e['rate_bits_per_second'][j]
        route,rates[j]=widest_path(a); routes.append(route)
    meta=metadata(protocol,f,d)
    if any(e['protocol']=='DPS QKD' for e in edges): meta['security_status']=SECURITY+'; route and inventory are proxy budgets'
    meta['edge_protocols']=[e['protocol'] for e in edges]
    r=dict(stage=stage,mode=mode,time_s=t,edges=edges,route_nodes=routes,rate_bits_per_second=rates,
           cumulative_rate_integral_bits=cumulative_integral(rates,t),
           node_names=base['node_names'],positions_km=base['positions_km'],baseline=base,metadata=meta,scenario_parameters=asdict(p))
    if stage==3:
        a,b=edges
        r['inventory']=trusted_inventory(t,a['rate_bits_per_second'],b['rate_bits_per_second'])
        # Existing validity guards remain active; no clipping to the BBM92 envelope.
        try:
            bb=bbm92_rates(a['eta_total_faded'],b['eta_total_faded'],a['visible'],b['visible'],p.link,bbm92)
            bb['cumulative_rate_integral_bits']=cumulative_integral(bb['key_rate_bps'],t)
            bb['available']=True
        except ValueError as exc:
            if mode=='bbm92': raise
            bb=dict(available=False,reason=str(exc))
        r['bbm92']=bb
        if mode=='bbm92':
            r['rate_bits_per_second']=bb['key_rate_bps']; r['cumulative_rate_integral_bits']=bb['cumulative_rate_integral_bits']
            meta.update(protocol='BBM92',security_status='BBM92 asymptotic estimate; existing high-loss coincidence model')
    rates=r['rate_bits_per_second']
    r['summary']=dict(mean_rate_bps=float(np.mean(rates)),median_rate_bps=float(np.median(rates)),
        p05_rate_bps=float(np.percentile(rates,5)),outage_fraction=float(np.mean(rates<=0)),
        time_outage_fraction=float(cumulative_integral((rates<=0).astype(float),t)[-1]/(t[-1]-t[0])),
        integrated_rate_bits=float(r['cumulative_rate_integral_bits'][-1]))
    return r

def run_stage(stage,**kwargs):
    if stage==1: return stage1(**kwargs)
    if stage==2: return stage2(**kwargs)
    return network(stage,**kwargs)
