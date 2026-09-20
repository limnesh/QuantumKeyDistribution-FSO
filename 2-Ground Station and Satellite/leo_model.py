"""Independent NumPy reference for the educational LEO FSO downlink extension.

All losses apply to the downlink. Model-known single-photon quantities give an
ideal infinite-decoy asymptotic benchmark, not a finite-key security result.
Run this file to regenerate leo_python_reference.json beside it.
"""

from dataclasses import asdict, dataclass
import json
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class LEOParameters:
    earth_radius_km: float = 6371.0
    altitude_km: float = 500.0
    gravitational_parameter_km3_s2: float = 398600.4418
    minimum_elevation_deg: float = 10.0
    sample_count: int = 401
    atmosphere_height_km: float = 20.0
    zenith_atmosphere_loss_db: float = 2.0
    beam_waist_m: float = 0.05
    divergence_rad: float = 10e-6
    receiver_radius_m: float = 0.5
    pointing_loss_db: float = 1.0
    optical_efficiency: float = 0.7
    detector_efficiency: float = 0.5
    mean_photons: float = 0.5
    background_yield: float = 2e-6
    optical_error_probability: float = 0.015
    error_correction_efficiency: float = 1.16
    pulse_rate_hz: float = 1e8
    signal_duty: float = 0.8
    basis_sift: float = 0.5

    def validate(self):
        values = asdict(self)
        if not all(np.isscalar(v) and np.isfinite(v) for v in values.values()):
            raise ValueError("All parameters must be finite scalar numbers.")
        positive = (
            "earth_radius_km", "altitude_km", "gravitational_parameter_km3_s2",
            "atmosphere_height_km", "beam_waist_m", "receiver_radius_m",
        )
        if any(values[k] <= 0 for k in positive):
            raise ValueError("Radii, lengths and gravitational parameter must be positive.")
        if self.altitude_km <= self.atmosphere_height_km:
            raise ValueError("The satellite must be above the effective atmospheric shell.")
        if not 0 <= self.minimum_elevation_deg <= 89.9:
            raise ValueError("Minimum elevation must lie between 0 and 89.9 degrees.")
        if (not 3 <= self.sample_count <= 10001 or int(self.sample_count) != self.sample_count
                or self.sample_count % 2 != 1):
            raise ValueError("Sample count must be an odd integer between 3 and 10001.")
        bounded = ("optical_efficiency", "detector_efficiency", "background_yield", "signal_duty", "basis_sift")
        if any(not 0 <= values[k] <= 1 for k in bounded):
            raise ValueError("Efficiencies, yields and pulse fractions must lie in [0, 1].")
        if not 0 <= self.optical_error_probability <= 0.5:
            raise ValueError("Optical error probability must lie in [0, 0.5].")
        if self.error_correction_efficiency < 1:
            raise ValueError("Error correction inefficiency must be at least 1.")
        if min(self.divergence_rad, self.pointing_loss_db, self.zenith_atmosphere_loss_db,
               self.mean_photons, self.pulse_rate_hz) < 0:
            raise ValueError("Divergence, losses, photon number and pulse rate must be nonnegative.")
        return self


def binary_entropy(probability):
    """Binary entropy; endpoints are exactly zero and NaN remains NaN."""
    probability = np.asarray(probability, dtype=float)
    if np.any((probability < 0) | (probability > 1)):
        raise ValueError("Entropy probability must lie in [0, 1].")
    result = np.zeros_like(probability)
    interior = (probability > 0) & (probability < 1)
    result[interior] = -(probability[interior] * np.log2(probability[interior])
                         + (1 - probability[interior]) * np.log2(1 - probability[interior]))
    return np.where(np.isnan(probability), np.nan, result)


def qkd_probabilities(eta, p):
    """Gains and ideal asymptotic rates per emitted signal pulse.

    Independent background clicks fill gates with no signal detection, avoiding
    double counting. Basis sifting is included here, signal duty is applied later.
    """
    eta = np.asarray(eta, dtype=float)
    if np.any(~np.isfinite(eta)) or np.any((eta < 0) | (eta > 1)):
        raise ValueError("Total detection efficiency must be finite and in [0, 1].")
    signal = -np.expm1(-p.mean_photons * eta)
    noise = (1 - signal) * p.background_yield
    gain = signal + noise
    qber = np.divide(p.optical_error_probability * signal + 0.5 * noise, gain,
                     out=np.full_like(gain, np.nan), where=gain > 0)
    y1 = eta + (1 - eta) * p.background_yield
    e1 = np.divide(p.optical_error_probability * eta + 0.5 * (1 - eta) * p.background_yield,
                   y1, out=np.full_like(y1, np.nan), where=y1 > 0)
    q1 = p.mean_photons * np.exp(-p.mean_photons) * y1
    # Undefined QBER in an empty channel cannot generate key.
    h_total = binary_entropy(np.nan_to_num(qber, nan=0.5))
    h_single = binary_entropy(np.nan_to_num(e1, nan=0.5))
    reference = p.basis_sift * gain * np.maximum(1 - (1 + p.error_correction_efficiency) * h_total, 0)
    decoy = p.basis_sift * np.maximum(q1 * (1 - h_single) - p.error_correction_efficiency * gain * h_total, 0)
    return dict(signal_gain=signal, gain=gain, qber=qber, single_photon_yield=y1,
                single_photon_qber=e1, single_photon_gain=q1,
                rate_bb84_reference_per_pulse=reference, rate_decoy_per_pulse=decoy,
                key_rate_bps=decoy * p.pulse_rate_hz * p.signal_duty)


def link_at_elevation(elevation_deg, p=None, slant_range_km=None):
    """Link at elevation in [0, 90] degrees, gated by the minimum-elevation cutoff."""
    p = (p or LEOParameters()).validate()
    elevation = np.asarray(elevation_deg, dtype=float)
    if np.any(~np.isfinite(elevation)) or np.any((elevation < 0) | (elevation > 90)):
        raise ValueError("Elevation must be finite and in [0, 90] degrees.")
    angle = np.deg2rad(elevation)
    re = p.earth_radius_km
    # A line of sight intersects the satellite orbit and the atmospheric shell.
    if slant_range_km is None:
        slant_range_km = np.sqrt((re + p.altitude_km)**2 - (re * np.cos(angle))**2) - re * np.sin(angle)
    slant_range_km = np.asarray(slant_range_km, dtype=float)
    atmosphere_path_km = np.sqrt((re + p.atmosphere_height_km)**2 - (re * np.cos(angle))**2) - re * np.sin(angle)
    atmosphere_loss_db = p.zenith_atmosphere_loss_db * atmosphere_path_km / p.atmosphere_height_km
    beam_radius_m = np.hypot(p.beam_waist_m, p.divergence_rad * slant_range_km * 1000)
    geometric_efficiency = -np.expm1(-2 * p.receiver_radius_m**2 / beam_radius_m**2)
    eta = (geometric_efficiency * 10**(-atmosphere_loss_db / 10)
           * 10**(-p.pointing_loss_db / 10) * p.optical_efficiency * p.detector_efficiency)
    visible = elevation >= p.minimum_elevation_deg - 1e-10
    eta = np.where(visible, eta, 0)
    with np.errstate(divide="ignore"):
        total_loss_db = -10 * np.log10(eta)
        geometric_loss_db = -10 * np.log10(geometric_efficiency)
    result = dict(elevation_deg=elevation, slant_range_km=slant_range_km,
                  atmosphere_path_km=atmosphere_path_km, beam_radius_m=beam_radius_m,
                  geometric_efficiency=geometric_efficiency, geometric_loss_db=geometric_loss_db,
                  atmosphere_loss_db=atmosphere_loss_db, total_loss_db=total_loss_db, eta=eta)
    result.update(qkd_probabilities(eta, p))
    # An unavailable contact has no open detection gates, including background.
    result["gain"] = np.where(visible, result["gain"], 0)
    result["qber"] = np.where(visible, result["qber"], np.nan)
    for key in ("rate_bb84_reference_per_pulse", "rate_decoy_per_pulse", "key_rate_bps"):
        result[key] = np.where(visible, result[key], 0)
    return result


def simulate_pass(p=None):
    """Circular overhead pass, ideal static spherical Earth, no rotation or refraction."""
    p = (p or LEOParameters()).validate()
    re = p.earth_radius_km
    orbit_radius = re + p.altitude_km
    minimum_elevation = np.deg2rad(p.minimum_elevation_deg)
    theta_max = np.arccos(re / orbit_radius * np.cos(minimum_elevation)) - minimum_elevation
    omega = np.sqrt(p.gravitational_parameter_km3_s2 / orbit_radius**3)
    time_s = np.linspace(-theta_max / omega, theta_max / omega, int(p.sample_count))
    theta = omega * time_s
    slant = np.sqrt(p.altitude_km**2 + 2 * re * orbit_radius * (1 - np.cos(theta)))
    elevation = np.clip(np.rad2deg(np.arctan2(orbit_radius * np.cos(theta) - re,
                                             orbit_radius * np.sin(np.abs(theta)))), 0, 90)
    result = link_at_elevation(elevation, p, slant)
    result.update(time_s=time_s, central_angle_rad=theta, angular_speed_rad_s=omega)
    integrate = getattr(np, "trapezoid", None)
    if integrate is None:
        integrate = np.trapz
    counts = p.pulse_rate_hz * p.signal_duty
    result["metrics"] = dict(
        pass_duration_s=float(time_s[-1] - time_s[0]),
        minimum_range_km=float(np.min(slant)), maximum_range_km=float(np.max(slant)),
        peak_key_rate_bps=float(np.max(result["key_rate_bps"])),
        expected_detections=float(integrate(result["gain"] * counts, time_s)),
        expected_sifted_bits=float(integrate(p.basis_sift * result["gain"] * counts, time_s)),
        asymptotic_key_bits=float(integrate(result["key_rate_bps"], time_s)),
    )
    return result


def reference_fixture(p=None):
    p = (p or LEOParameters()).validate()
    points = link_at_elevation([10, 30, 60, 90], p)
    return dict(schema_version=1, parameters=asdict(p),
                elevation_points=[{k: float(v[i]) for k, v in points.items()} for i in range(4)],
                pass_metrics=simulate_pass(p)["metrics"])


if __name__ == "__main__":
    destination = Path(__file__).resolve().with_name("leo_python_reference.json")
    fixture = reference_fixture()
    destination.write_text(json.dumps(fixture, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps(fixture["pass_metrics"], indent=2))
    print(f"Reference fixture: {destination}")


def simulate_with_dps_fading(**kwargs):
    """Shared protocol/fading extension; existing deterministic API is unchanged."""
    import sys
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from shared.scenarios import run_stage
    return run_stage(2, **kwargs)
