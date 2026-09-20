"""Stage 3 only: trusted BB84 relay and a limited BBM92 rate comparison.

CW high-loss coincidence model: Neumann et al., PRA 104, 022406 (2021),
https://arxiv.org/abs/2103.14639, equations 3, 6, 8, 10, 13--17.
Symmetric basis-independent errors imply E_phase = E_bit. This is an
asymptotic estimate, not a finite-key proof or hardware/source simulation.
"""

from dataclasses import asdict, dataclass
from math import erf, sqrt, log

import numpy as np

from network_model import parameters_for_stage, simulate_network, cumulative_trapezoid
from leo_model import binary_entropy, qkd_probabilities


ARCHITECTURES = {
    "trusted": "Trusted Satellite Relay - Decoy-State BB84",
    "bbm92": "Entanglement-Based Satellite QKD - BBM92",
}


@dataclass(frozen=True)
class BBM92Parameters:
    # Rates aggregate all detectors at ONE receiver, identical for A and B.
    pair_rate_hz: float = 1e7
    dark_count_rate_hz: float = 100.0
    background_count_rate_hz: float = 100.0
    coincidence_window_s: float = 1e-9  # full window width after delay alignment
    timing_fwhm_s: float = 0.5e-9      # relative A-B timestamp distribution
    basis_sift: float = 0.5           # unbiased two bases; <= .5 allows discard

    def validate(self):
        if not all(isinstance(v, (int, float, np.number)) and np.isreal(v) and np.isfinite(v)
                   for v in asdict(self).values()):
            raise ValueError("BBM92 parameters must be finite real scalars.")
        if min(self.pair_rate_hz, self.dark_count_rate_hz, self.background_count_rate_hz) < 0:
            raise ValueError("Pair and receiver count rates must be nonnegative.")
        if min(self.coincidence_window_s, self.timing_fwhm_s) <= 0:
            raise ValueError("Coincidence window and timing FWHM must be positive seconds.")
        if not 0 <= self.basis_sift <= 0.5:
            raise ValueError("Use 0 <= basis_sift <= 0.5 for this unbiased two-basis model.")
        return self


def bbm92_rates(eta_a, eta_b, visible_a, visible_b, link, b=None):
    """Analytic expected rates; eta already includes optics AND detector once.

    No satellite measurement/key is constructed. Noise rates are registered
    counts, not photon flux or per-gate probabilities. Receiver singles may
    exist during individual contact; coincidences require common visibility.
    """
    b = (b or BBM92Parameters()).validate()
    link.validate()
    eta_a, eta_b, va, vb = np.broadcast_arrays(
        np.asarray(eta_a, float), np.asarray(eta_b, float),
        np.asarray(visible_a, bool), np.asarray(visible_b, bool))
    if any(np.any(~np.isfinite(e)) or np.any((e < 0) | (e > 1)) for e in (eta_a, eta_b)):
        raise ValueError("Total efficiencies must be finite probabilities in [0, 1].")
    eta_a, eta_b = np.where(va, eta_a, 0), np.where(vb, eta_b, 0)
    common = va & vb
    noise = b.dark_count_rate_hz + b.background_count_rate_hz
    singles_a = np.where(va, b.pair_rate_hz * eta_a + noise, 0)
    singles_b = np.where(vb, b.pair_rate_hz * eta_b + noise, 0)
    # A declared validity envelope prevents extrapolating this simple high-loss,
    # low-occupancy model into low-loss or saturation hardware regimes.
    if (np.any(eta_a[common] > 0.1) or np.any(eta_b[common] > 0.1)
            or np.any(np.maximum(singles_a, singles_b)[common] * b.coincidence_window_s > 0.1)):
        raise ValueError("BBM92 approximation requires eta <= 0.1 and singles*window <= 0.1 during common contact.")
    acceptance = erf(sqrt(log(2)) * b.coincidence_window_s / b.timing_fwhm_s)
    true = np.where(common, b.pair_rate_hz * eta_a * eta_b, 0)
    accepted = acceptance * true
    accidental = np.where(common, (-np.expm1(-singles_a*b.coincidence_window_s))
                          * (-np.expm1(-singles_b*b.coincidence_window_s)) / b.coincidence_window_s, 0)
    coincidence = accepted + accidental
    # Independent identical per-arm polarization flips. Reuse the existing
    # per-link error input, not a second conflicting misalignment parameter.
    error_true = 2 * link.optical_error_probability * (1-link.optical_error_probability)
    error_rate = error_true * accepted + 0.5 * accidental
    qber = np.divide(error_rate, coincidence, out=np.full_like(coincidence, np.nan), where=coincidence > 0)
    entropy = binary_entropy(np.nan_to_num(qber, nan=0.5))
    sifted = b.basis_sift * coincidence
    key_rate = sifted * np.maximum(1-(1+link.error_correction_efficiency)*entropy, 0)
    return dict(eta_a=eta_a, eta_b=eta_b, visible_a=va, visible_b=vb,
                common_visibility=common, singles_a_hz=singles_a, singles_b_hz=singles_b,
                true_coincidence_hz=true, accepted_true_hz=accepted,
                accidental_coincidence_hz=accidental, coincidence_hz=coincidence,
                qber=qber, sifted_rate_bps=sifted, key_rate_bps=key_rate,
                timing_acceptance=acceptance, true_pair_error=error_true)


def trusted_inventory(time_s, rate_a, rate_b):
    """Classical two-pool greedy relay with zero initial keys and unlimited demand.

    Interval arrivals are credited only at each interval's END. One key bit is
    consumed from EACH pool per delivered endpoint bit. No latency, expiry or
    authentication cost. Fractional values are asymptotic expected budgets.
    """
    time_s, rate_a, rate_b = (np.asarray(v, float) for v in (time_s, rate_a, rate_b))
    if (time_s.ndim != 1 or time_s.size < 2 or rate_a.shape != time_s.shape
            or rate_b.shape != time_s.shape or np.any(np.diff(time_s) <= 0)
            or not all(np.all(np.isfinite(v)) for v in (time_s, rate_a, rate_b))
            or np.any(rate_a < 0) or np.any(rate_b < 0)):
        raise ValueError("Inventory requires increasing times and finite nonnegative link rates.")
    generated_a = cumulative_trapezoid(rate_a, time_s)
    generated_b = cumulative_trapezoid(rate_b, time_s)
    delivered = np.minimum(generated_a, generated_b)
    delivery_step = np.diff(delivered, prepend=0)
    return dict(generated_a_bits=generated_a, generated_b_bits=generated_b,
                delivered_bits=delivered, delivered_step_bits=delivery_step,
                pool_a_bits=np.maximum(generated_a-delivered, 0),
                pool_b_bits=np.maximum(generated_b-delivered, 0))


def compare_stage3(network, b=None, mode="trusted"):
    """Reuse one network result for both modes; selection changes interpretation."""
    if mode not in ARCHITECTURES:
        raise ValueError("mode must be 'trusted' or 'bbm92'.")
    p = network["parameters"].validate()
    if p.stage != 3:
        raise ValueError("BBM92 comparison is restricted to Stage 3.")
    b = b or BBM92Parameters()
    a, other = network["edges"]
    time = network["time_s"]
    try:
        bb = bbm92_rates(a["eta"], other["eta"], a["visible"], other["visible"], p.link, b)
        bb['available'] = True
        bb['reason'] = ''
    except ValueError as error:
        if mode == 'bbm92':
            raise
        # Preserve all valid trusted settings. Unavailable estimates are NaN,
        # never a fabricated zero-key prediction or a relaxed BBM92 guard.
        bb = {key: np.full_like(time, np.nan) for key in (
            'singles_a_hz','singles_b_hz','true_coincidence_hz','accepted_true_hz',
            'accidental_coincidence_hz','coincidence_hz','qber','sifted_rate_bps','key_rate_bps')}
        bb.update(available=False, reason=str(error), eta_a=a['eta'], eta_b=other['eta'],
                  visible_a=a['visible'], visible_b=other['visible'],
                  common_visibility=a['visible'] & other['visible'])
    bb["cumulative_key_bits"] = cumulative_trapezoid(bb["key_rate_bps"], time)
    counts = cumulative_trapezoid(bb["coincidence_hz"], time)[-1]
    errors = cumulative_trapezoid(np.nan_to_num(bb["qber"])*bb["coincidence_hz"], time)[-1]
    bb["metrics"] = dict(peak_key_rate_bps=float(np.max(bb["key_rate_bps"])),
                         integrated_key_bits=float(bb["cumulative_key_bits"][-1]),
                         true_coincidences=float(cumulative_trapezoid(bb["true_coincidence_hz"], time)[-1]),
                         measured_coincidences=float(counts), pooled_qber=float(errors/counts) if counts > 0 else np.nan,
                         common_visibility_s=float(cumulative_trapezoid(bb["common_visibility"].astype(float), time)[-1]))
    inv = trusted_inventory(time, a["key_rate_bps"], other["key_rate_bps"])
    # Recalculate only detector probabilities, reusing already computed eta.
    detections = [np.where(e["visible"], qkd_probabilities(e["eta"], p.link)["gain"]
                            * p.link.pulse_rate_hz * p.link.signal_duty, 0) for e in (a, other)]
    trusted = dict(inventory=inv, detection_a_hz=detections[0], detection_b_hz=detections[1],
                   qber_a=a["qber"], qber_b=other["qber"],
                   simultaneous_rate_bps=network["route_rate_bps"],
                   simultaneous_bits=network["cumulative_key_bits"],
                   delivered_bits=float(inv["delivered_bits"][-1]))
    selected_bits = trusted["delivered_bits"] if mode == "trusted" else bb["metrics"]["integrated_key_bits"]
    return dict(mode=mode, architecture=ARCHITECTURES[mode], parameters=b, network=network,
                time_s=time, trusted=trusted, bbm92=bb, selected_key_bits=selected_bits)


def simulate_stage3(p=None, mode="trusted", b=None):
    return compare_stage3(simulate_network(p or parameters_for_stage(3)), b, mode)


def simulate_with_dps_fading(**kwargs):
    """Shared protocol/fading extension; existing deterministic API is unchanged."""
    import sys
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from shared.scenarios import run_stage
    return run_stage(3, **kwargs)
