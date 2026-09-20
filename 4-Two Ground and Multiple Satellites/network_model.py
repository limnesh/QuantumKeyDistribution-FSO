"""Numerical reference for the two-ground-station trusted QKD network stages.

Ground links reuse the independently implemented Python stage-2 downlink model.
Satellites are trusted classical key relays, not quantum repeaters. Every edge
has its own terminals/pulse budget; rates are undirected shared key capacities.
No inventory or simultaneous multipath scheduling is used by the route model.
"""

from dataclasses import asdict, dataclass, field, replace
import json
from pathlib import Path
import sys

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parent.parent
LEO_DIRECTORY = PROJECT_ROOT / "2-Ground Station and Satellite"
if str(LEO_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(LEO_DIRECTORY))
from leo_model import LEOParameters, link_at_elevation, qkd_probabilities


@dataclass(frozen=True)
class NetworkParameters:
    stage: int = 3
    satellite_count: int = 1
    ground_separation_km: float = 1000.0
    satellite_span_deg: float = 0.0
    duration_s: float = 1200.0
    time_points: int = 601
    isl_divergence_rad: float = 2e-6
    isl_receiver_radius_m: float = 0.3
    isl_pointing_loss_db: float = 1.0
    isl_background_yield: float = 1e-7
    isl_clearance_km: float = 20.0
    enable_isl: bool = True
    link: LEOParameters = field(default_factory=LEOParameters)

    def validate(self):
        if not isinstance(self.link, LEOParameters):
            raise ValueError("link must be a LEOParameters instance.")
        self.link.validate()
        values = asdict(self)
        values.pop("link")
        if not all(np.isscalar(v) and np.isreal(v) and np.isfinite(v)
                   for v in values.values()):
            raise ValueError("Network parameters must be finite real scalar numbers.")
        if self.stage not in (3, 4):
            raise ValueError("Network stage must be 3 or 4.")
        if self.satellite_count != int(self.satellite_count):
            raise ValueError("Satellite count must be an integer.")
        if self.stage == 3 and (self.satellite_count != 1 or self.satellite_span_deg != 0):
            raise ValueError("Stage 3 requires exactly one satellite and zero satellite span.")
        if self.stage == 4 and (not 2 <= self.satellite_count <= 12
                               or not 0 < self.satellite_span_deg <= 180):
            raise ValueError("Stage 4 requires 2 to 12 satellites and span in (0, 180] degrees.")
        if not 0 < self.ground_separation_km <= np.pi * self.link.earth_radius_km:
            raise ValueError("Ground separation must be in (0, pi*Earth radius] km.")
        if not 0 < self.duration_s <= 86400:
            raise ValueError("Duration must be in (0, 86400] seconds.")
        if (self.time_points != int(self.time_points) or not 3 <= self.time_points <= 10001
                or self.time_points % 2 != 1):
            raise ValueError("Time points must be an odd integer between 3 and 10001.")
        if not 0 <= self.isl_divergence_rad <= 1 or not 0 <= self.isl_pointing_loss_db <= 1000:
            raise ValueError("ISL divergence must be in [0, 1] rad and pointing loss in [0, 1000] dB.")
        if not 1e-9 <= self.isl_receiver_radius_m <= 100 or not 0 <= self.isl_background_yield <= 0.1:
            raise ValueError("ISL receiver radius must be in [1e-9, 100] m and background yield in [0, 0.1].")
        if not 0 <= self.isl_clearance_km <= self.link.earth_radius_km:
            raise ValueError("ISL clearance must be between zero and Earth radius.")
        if self.enable_isl not in (False, True):
            raise ValueError("enable_isl must be a boolean or 0/1.")
        return self


def parameters_for_stage(stage):
    """Return useful illustrative defaults; stage 4 starts with two satellites."""
    if stage == 3:
        return NetworkParameters()
    if stage == 4:
        return NetworkParameters(stage=4, satellite_count=2, ground_separation_km=3000.0,
                                 satellite_span_deg=np.rad2deg(3000.0 / 6371.0))
    raise ValueError("Network stage must be 3 or 4.")


def cumulative_trapezoid(values, time_s):
    """Integral at each sample, with the initial value exactly zero."""
    values, time_s = np.asarray(values), np.asarray(time_s)
    return np.concatenate(([0.0], np.cumsum(np.diff(time_s) * (values[1:] + values[:-1]) / 2)))


def widest_path(capacities, start=0, target=None):
    """Maximum-bottleneck route for a symmetric nonnegative capacity matrix.

    Equal choices select the lowest-index next node; equal relaxations preserve
    their existing predecessor. Zero-capacity edges are absent. No route returns
    ([], 0). Indices are zero-based, including the returned path.
    """
    capacities = np.asarray(capacities, dtype=float)
    if (capacities.ndim != 2 or capacities.shape[0] != capacities.shape[1]
            or capacities.shape[0] < 1 or np.any(~np.isfinite(capacities))
            or np.any(capacities < 0) or not np.allclose(capacities, capacities.T)
            or np.any(np.diag(capacities) != 0)):
        raise ValueError("Capacities must be square, finite, symmetric, nonnegative, with zero diagonal.")
    count = len(capacities)
    target = count - 1 if target is None else target
    if (start != int(start) or target != int(target)
            or not 0 <= start < count or not 0 <= target < count):
        raise ValueError("Route endpoints must be valid node indices.")
    start, target = int(start), int(target)
    if start == target:
        return [start], float("inf")
    bandwidth = np.zeros(count)
    bandwidth[start] = np.inf
    visited = np.zeros(count, dtype=bool)
    previous = np.full(count, -1, dtype=int)
    for _ in range(count):
        node = int(np.argmax(np.where(visited, -1.0, bandwidth)))
        if bandwidth[node] <= 0:
            break
        visited[node] = True
        if node == target:
            path = [target]
            while path[-1] != start:
                path.append(int(previous[path[-1]]))
            return path[::-1], float(bandwidth[target])
        for neighbor in range(count):
            candidate = min(bandwidth[node], capacities[node, neighbor])
            if not visited[neighbor] and candidate > bandwidth[neighbor]:
                bandwidth[neighbor] = candidate
                previous[neighbor] = node
    return [], 0.0


def simulate_network(p=None):
    """Compute contacts, independent edge capacities and one route per instant.

    positions_km has shape (time, node, xyz). Orbit coordinates use x=r*cos(theta),
    y=r*sin(theta), z=0. Nodes are Ground A, Sat 1..N, Ground B. Satellite phases
    span [-span/2,+span/2]; stations sit at +/-separation/(2*Earth radius).
    """
    p = (p or parameters_for_stage(3)).validate()
    re, orbit_radius = p.link.earth_radius_km, p.link.earth_radius_km + p.link.altitude_km
    sat_count, sample_count = int(p.satellite_count), int(p.time_points)
    node_names = ["Ground A"] + [f"Sat {index + 1}" for index in range(sat_count)] + ["Ground B"]
    node_count = len(node_names)
    time_s = np.linspace(-p.duration_s / 2, p.duration_s / 2, sample_count)
    omega = np.sqrt(p.link.gravitational_parameter_km3_s2 / orbit_radius**3)
    phases = np.deg2rad(np.linspace(-p.satellite_span_deg / 2, p.satellite_span_deg / 2, sat_count))
    angles = np.zeros((sample_count, node_count))
    angles[:, 0] = -p.ground_separation_km / (2 * re)
    angles[:, -1] = p.ground_separation_km / (2 * re)
    angles[:, 1:-1] = omega * time_s[:, None] + phases
    radii = np.full(node_count, orbit_radius)
    radii[[0, -1]] = re
    positions = np.stack((np.cos(angles) * radii, np.sin(angles) * radii, np.zeros_like(angles)), axis=-1)
    edges = []

    def append_edge(i, j, kind):
        vector = positions[:, j] - positions[:, i]
        distance = np.linalg.norm(vector, axis=-1)
        if kind == "ground":
            ground = i if i == 0 else j
            satellite = j if i == 0 else i
            up = positions[:, ground] / re
            ray = positions[:, satellite] - positions[:, ground]
            radial = np.sum(ray * up, axis=-1)
            tangent = up[:, 0] * ray[:, 1] - up[:, 1] * ray[:, 0]
            elevation = np.rad2deg(np.arctan2(radial, np.abs(tangent)))
            visible = (elevation >= p.link.minimum_elevation_deg - 1e-10) & (elevation >= 0)
            link = link_at_elevation(np.clip(elevation, 0, 90), p.link, distance)
        else:
            # Closest point on the finite line segment, not its infinite line.
            numerator = -np.sum(positions[:, i] * vector, axis=-1)
            fraction = np.clip(np.divide(numerator, distance**2, out=np.zeros_like(distance),
                                         where=distance > 0), 0, 1)
            clearance = np.linalg.norm(positions[:, i] + fraction[:, None] * vector, axis=-1)
            visible = bool(p.enable_isl) & (clearance > re + p.isl_clearance_km)
            elevation = np.full(sample_count, np.nan)
            beam_radius = np.hypot(p.link.beam_waist_m, p.isl_divergence_rad * distance * 1000)
            collection = -np.expm1(-2 * p.isl_receiver_radius_m**2 / beam_radius**2)
            eta = (collection * 10**(-p.isl_pointing_loss_db / 10)
                   * p.link.optical_efficiency * p.link.detector_efficiency)
            link = qkd_probabilities(eta, replace(p.link, background_yield=p.isl_background_yield))
            link["eta"] = eta
        rate = np.where(visible, link["key_rate_bps"], 0)
        edges.append(dict(i=i, j=j, label=f"{node_names[i]} - {node_names[j]}", kind=kind,
                          distance_km=distance, elevation_deg=elevation, visible=visible,
                          eta=np.where(visible, link["eta"], 0),
                          qber=np.where(visible, link["qber"], np.nan), key_rate_bps=rate,
                          cumulative_key_bits=cumulative_trapezoid(rate, time_s)))

    for satellite in range(1, sat_count + 1):
        append_edge(0, satellite, "ground")
        append_edge(satellite, node_count - 1, "ground")
    for left in range(1, sat_count):
        for right in range(left + 1, sat_count + 1):
            append_edge(left, right, "isl")
    routes, route_rate = [], np.zeros(sample_count)
    for index in range(sample_count):
        adjacency = np.zeros((node_count, node_count))
        for edge in edges:
            adjacency[edge["i"], edge["j"]] = adjacency[edge["j"], edge["i"]] = edge["key_rate_bps"][index]
        path, route_rate[index] = widest_path(adjacency)
        routes.append(path)
    cumulative = cumulative_trapezoid(route_rate, time_s)
    best_index = int(np.argmax(route_rate))
    if route_rate[best_index] == 0:
        best_index = sample_count // 2
    stored_pair_bits = min(edge["cumulative_key_bits"][-1] for edge in edges) if p.stage == 3 else np.nan
    metrics = dict(peak_rate_bps=float(route_rate[best_index]), integrated_key_bits=float(cumulative[-1]),
                   connected_duration_s=float(cumulative_trapezoid((route_rate > 0).astype(float), time_s)[-1]),
                   stored_pair_bits=float(stored_pair_bits), best_index=best_index)
    return dict(parameters=p, time_s=time_s, node_names=node_names, positions_km=positions,
                edges=edges, route_nodes=routes, route_rate_bps=route_rate,
                cumulative_key_bits=cumulative, metrics=metrics)


def json_safe(value):
    """Convert arrays/dataclasses and undefined floats to portable JSON values."""
    if isinstance(value, NetworkParameters):
        return json_safe(asdict(value))
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, np.ndarray)):
        return [json_safe(item) for item in value]
    if isinstance(value, (float, np.floating)):
        return float(value) if np.isfinite(value) else None
    if isinstance(value, (np.bool_, bool)):
        return bool(value)
    if isinstance(value, np.integer):
        return int(value)
    return value


def reference_fixture(stage=3, satellite_count=None, enable_isl=True):
    """Deterministic compact cross-language fixture, with zero-based node indices."""
    p = parameters_for_stage(stage)
    p = replace(p, enable_isl=enable_isl)
    if satellite_count is not None:
        p = replace(p, satellite_count=satellite_count)
    result = simulate_network(p)
    midpoint = p.time_points // 2
    points = []
    for edge in result["edges"]:
        points.append({key: (value[midpoint] if isinstance(value, np.ndarray) else value)
                       for key, value in edge.items()})
    return json_safe(dict(parameters=p, metrics=result["metrics"], midpoint=dict(
        time_s=result["time_s"][midpoint], route_nodes=result["route_nodes"][midpoint],
        route_rate_bps=result["route_rate_bps"][midpoint], edges=points)))


if __name__ == "__main__":
    cases = []
    for name, stage, count, isl in [("stage3", 3, 1, True), ("stage4", 4, 2, True),
                                   ("stage4_3sat", 4, 3, True), ("stage4_4sat", 4, 4, True),
                                   ("stage4_no_isl", 4, 2, False)]:
        cases.append(dict(name=name, **reference_fixture(stage, count, isl)))
    destination = Path(__file__).with_name("network_python_reference.json")
    destination.write_text(json.dumps(dict(schema_version=1, index_base=0, cases=cases),
                                      indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(f"Reference fixture: {destination}")
    for case in cases:
        print(case["name"], case["metrics"])


def simulate_with_dps_fading(**kwargs):
    """Shared protocol/fading extension; existing deterministic API is unchanged."""
    import sys
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from shared.scenarios import run_stage
    return run_stage(4, **kwargs)
