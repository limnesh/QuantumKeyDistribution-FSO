"""DPS detector statistics and phenomenological weak log-normal fading.

The collision-inspired rate is an illustrative proxy, NOT a security proof.
See DPS_THEORY.md for derivation, conventions, sources and limitations.
"""
from dataclasses import dataclass, asdict
import numpy as np

SECURITY = 'DPS illustrative rate proxy; no composable security bound established'

def h2(x):
    x = np.asarray(x, float)
    y = np.zeros_like(x)
    inside = (x > 0) & (x < 1)
    y[inside] = -x[inside]*np.log2(x[inside])-(1-x[inside])*np.log2(1-x[inside])
    return y

@dataclass(frozen=True)
class DPSParameters:
    mean_photons: float = 0.1
    visibility: float = 0.98
    phase_error_rad: float = 0.0
    background_per_detector: float = 1e-6
    ec_efficiency: float = 1.16
    pulse_rate_hz: float = 1e8
    duty: float = 0.8
    train_pulses: int = 1024
    guard_slots: int = 1

    def validate(self):
        if not all(np.isscalar(v) and np.isfinite(v) for v in asdict(self).values()):
            raise ValueError('DPS parameters must be finite scalars')
        if not 0 <= self.mean_photons < 0.5:
            raise ValueError('DPS collision-inspired proxy requires 0 <= mean_photons < 0.5')
        if not 0 <= self.visibility <= 1 or not 0 <= self.background_per_detector <= 1:
            raise ValueError('Visibility and background probability must be in [0,1]')
        if abs(self.phase_error_rad) > np.pi/2 or self.ec_efficiency < 1:
            raise ValueError('Require |phase error| <= pi/2 and EC efficiency >= 1')
        if self.pulse_rate_hz < 0 or not 0 <= self.duty <= 1:
            raise ValueError('Invalid pulse clock or duty')
        if (self.train_pulses < 2 or int(self.train_pulses) != self.train_pulses
                or self.guard_slots < 1 or int(self.guard_slots) != self.guard_slots):
            raise ValueError('Require integer train_pulses >= 2 and guard_slots >= 1')
        return self

def pulse_train(bits, mean_photons=0.1):
    """N-1 relative bits -> N coherent amplitudes and N+1 output slots.

    Balanced delay interferometer: (a[k] +/- a[k-1])/2. End slots
    contain only one path and are discarded. This is optical statistics,
    not a finite-key DPS reconciliation or privacy-amplification procedure.
    """
    bits = np.asarray(bits)
    if bits.ndim != 1 or bits.size < 1 or np.any((bits != 0) & (bits != 1)):
        raise ValueError('Relative bits must be a nonempty binary vector')
    if not np.isfinite(mean_photons) or mean_photons < 0:
        raise ValueError('Mean photon number must be finite and nonnegative')
    phases = np.pi * np.r_[0, np.cumsum(bits) % 2]
    amplitude = np.sqrt(mean_photons)*np.exp(1j*phases)
    current, delayed = np.r_[amplitude, 0], np.r_[0, amplitude]
    power = np.stack((abs((current+delayed)/2)**2, abs((current-delayed)/2)**2), axis=-1)
    return dict(relative_bits=bits, phase_rad=phases, amplitude=amplitude,
                port_mean_photons=power, valid_slots=np.arange(1, len(bits)+1),
                discarded_slots=np.array([0,len(bits)+1]))

def dps_statistics(eta_total, p=None):
    """Two independent threshold detectors, random assignment of double clicks.

    eta_total ALREADY includes detector efficiency; background is registered
    per detector per gate. Visibility excludes any separately supplied phase
    offset. Fading is quasi-static across neighboring optical pulses.
    """
    p = (p or DPSParameters()).validate()
    eta = np.asarray(eta_total, float)
    if np.any(~np.isfinite(eta)) or np.any((eta < 0) | (eta > 1)):
        raise ValueError('Total efficiency must be in [0,1]')
    e = (1-p.visibility*np.cos(p.phase_error_rad))/2
    lam = p.mean_photons*eta
    # Stable independent no-click products, including signal/background overlap.
    pc = -np.expm1(-lam*(1-e)) + p.background_per_detector*np.exp(-lam*(1-e))
    pw = -np.expm1(-lam*e) + p.background_per_detector*np.exp(-lam*e)
    double = pc*pw
    gain = pc+pw-double
    error = pw*(1-pc)+0.5*double
    qber = np.divide(error,gain,out=np.full_like(gain,np.nan),where=gain>0)
    eb = np.minimum(np.nan_to_num(qber,nan=0.5),6/38)
    collision = 1-eb**2-(1-6*eb)**2/2
    fraction = np.maximum(-(1-2*p.mean_photons)*np.log2(collision)
                          -p.ec_efficiency*h2(np.nan_to_num(qber,nan=0.5)),0)
    fraction = np.where(np.nan_to_num(qber,nan=0.5) <= 6/38,fraction,0)
    valid_per_pulse = (p.train_pulses-1)/p.train_pulses
    emitted_hz = p.pulse_rate_hz*p.duty*p.train_pulses/(p.train_pulses+p.guard_slots)
    per_pulse = valid_per_pulse*gain*fraction
    return dict(protocol='DPS QKD', model_name='dps_threshold_collision_proxy',model_version='1.0',
                security_status=SECURITY,qber=qber,gain=gain,error_gain=error,
                double_click_gain=double,visibility_error=(1-p.visibility)/2,
                optical_error=e,valid_slot_fraction=valid_per_pulse,
                detection_rate_hz=emitted_hz*valid_per_pulse*gain,
                error_rate_hz=emitted_hz*valid_per_pulse*error,
                rate_bits_per_pulse=per_pulse,rate_bits_per_second=per_pulse*emitted_hz,
                parameters=asdict(p))

@dataclass(frozen=True)
class FadingParameters:
    mode: str = 'none'
    sigma: float = 0.3
    correlation_time_s: float = 2.0
    seed: int = 123

    def validate(self):
        if self.mode not in ('none','independent_lognormal','correlated_lognormal'):
            raise ValueError('Unknown fading mode')
        if not np.isfinite(self.sigma) or not 0 <= self.sigma <= 1:
            raise ValueError('Weak-turbulence teaching envelope requires sigma in [0,1]')
        if not np.isfinite(self.correlation_time_s) or self.correlation_time_s <= 0:
            raise ValueError('Correlation time must be positive')
        if not isinstance(self.seed,(int,np.integer)) or self.seed < 0:
            raise ValueError('Seed must be a nonnegative integer')
        return self

def fading_factors(n, p=None, time_s=None, stream=0, innovations=None):
    p = (p or FadingParameters()).validate()
    if not isinstance(n,(int,np.integer)) or n < 1 or int(stream)!=stream or stream<0:
        raise ValueError('Sample count and stream must be valid integers')
    if p.mode == 'none':
        return np.ones(n)
    if innovations is None:
        z = np.random.default_rng(np.random.SeedSequence([p.seed,int(stream)])).normal(size=n)
    else:
        z = np.asarray(innovations,float).copy()
        if z.shape != (n,) or not np.all(np.isfinite(z)):
            raise ValueError('Innovations must be a finite vector of length n')
    x = z.copy()
    if p.mode == 'correlated_lognormal':
        t = np.asarray(time_s,float)
        if t.shape != (n,) or not np.all(np.isfinite(t)) or np.any(np.diff(t)<=0):
            raise ValueError('Correlated fading needs increasing physical sample times')
        rho = np.exp(-np.diff(t)/p.correlation_time_s)
        for k in range(1,n):
            x[k] = rho[k-1]*x[k-1]+np.sqrt(-np.expm1(-2*(t[k]-t[k-1])/p.correlation_time_s))*z[k]
    return np.exp(p.sigma*x-p.sigma**2/2)

def fade_efficiency(eta_total, eta_detector, factors, atmospheric=True):
    """Fade collected optical transmission BEFORE the fixed detector factor.

    F is a normalized collected-power multiplier, not field amplitude. Cap
    optical transmission at unity, so total efficiency never exceeds detector
    efficiency. Clipping changes the mean; report its frequency explicitly.
    """
    eta, factor = np.broadcast_arrays(np.asarray(eta_total,float),np.asarray(factors,float))
    if (not np.isfinite(eta_detector) or not 0 <= eta_detector <= 1 or
            np.any(~np.isfinite(eta)) or np.any((eta<0)|(eta>eta_detector+1e-14)) or
            np.any(~np.isfinite(factor)) or np.any(factor<=0)):
        raise ValueError('Invalid baseline efficiency, detector factor or fading')
    if not atmospheric:
        factor = np.ones_like(eta)
    optical = eta/eta_detector if eta_detector else np.zeros_like(eta)
    clipped = optical*factor>1
    faded = np.minimum(optical*factor,1)*eta_detector
    # Exact no-fading compatibility, avoiding a gratuitous divide/multiply.
    faded = np.where(factor==1,eta,faded)
    return dict(eta_total_baseline=eta,eta_total_faded=faded,fading_factor=factor,
                clipping_fraction=float(np.mean(clipped)),clipped=clipped)

def cumulative_integral(rate, time_s):
    r,t=np.asarray(rate,float),np.asarray(time_s,float)
    if r.shape!=t.shape or r.ndim!=1 or len(r)<2 or np.any(np.diff(t)<=0) or not np.all(np.isfinite(t)) or np.any(~np.isfinite(r)) or np.any(r<0):
        raise ValueError('Integral needs increasing times and finite nonnegative rates')
    return np.r_[0,np.cumsum(np.diff(t)*(r[1:]+r[:-1])/2)]

def summarize(result,time_s=None):
    q,r=np.asarray(result['qber']),np.asarray(result['rate_bits_per_second'])
    valid=q[np.isfinite(q)]
    s=dict(mean_qber=float(np.mean(valid)) if valid.size else np.nan,
           median_qber=float(np.median(valid)) if valid.size else np.nan,
           p95_qber=float(np.percentile(valid,95)) if valid.size else np.nan,
           mean_rate_bps=float(np.mean(r)),median_rate_bps=float(np.median(r)),
           p05_rate_bps=float(np.percentile(r,5)),outage_fraction=float(np.mean(r<=0)))
    integrate=lambda x: cumulative_integral(x,time_s)[-1] if time_s is not None else np.sum(x)
    detections=integrate(result['detection_rate_hz']); errors=integrate(result['error_rate_hz'])
    s['pooled_qber']=float(errors/detections) if detections else np.nan
    if time_s is not None:
        s['integrated_rate_bits']=float(integrate(r))
        s['time_outage_fraction']=float(integrate((r<=0).astype(float))/(time_s[-1]-time_s[0]))
    return s
