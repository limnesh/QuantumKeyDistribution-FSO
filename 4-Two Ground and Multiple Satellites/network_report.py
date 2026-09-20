"""Readable plots and portable report export for the trusted network reference.

Example: python "4-Two Ground and Multiple Satellites/network_report.py" --stage 4 --satellites 3
"""

import argparse
import csv
from dataclasses import replace
import html
import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Circle
import numpy as np

from network_model import PROJECT_ROOT, json_safe, parameters_for_stage, simulate_network


STAGE_FOLDERS = {3: "3-Two Ground and One Satellite", 4: "4-Two Ground and Multiple Satellites"}
COLORS = ["#087f8c", "#b05d28", "#4e68a5", "#9776a4", "#5f8871", "#b58032"]


def configure_plots():
    plt.rcParams.update({"figure.dpi": 120, "savefig.dpi": 160, "font.size": 10,
                         "axes.titlesize": 12, "axes.spines.top": False,
                         "axes.spines.right": False, "axes.grid": True, "grid.alpha": 0.18,
                         "axes.prop_cycle": plt.cycler(color=COLORS)})


def route_label(result, index):
    route = result["route_nodes"][index]
    return " → ".join(result["node_names"][node] for node in route) if route else "No simultaneous positive-key route"


def plot_topology(result, index=None):
    """Orbit-plane snapshot: spherical-Earth cross section, terminals and links."""
    configure_plots()
    index = result["metrics"]["best_index"] if index is None else int(index)
    p = result["parameters"]
    points = result["positions_km"][index]
    re = p.link.earth_radius_km
    # Rotate the displayed plane so the station midpoint is above Earth's centre.
    x, y = points[:, 1], points[:, 0] - re
    fig, ax = plt.subplots(figsize=(11.5, 4.8), layout="constrained")
    ax.add_patch(Circle((0, -re), re, color="#e8ece7", zorder=0))
    orbit_angles = np.linspace(-np.pi / 2, np.pi / 2, 300)
    orbit_radius = re + p.link.altitude_km
    ax.plot(orbit_radius * np.sin(orbit_angles), orbit_radius * np.cos(orbit_angles) - re,
            color="#8e9aac", linestyle=":", linewidth=1, label="Circular orbit")
    route = result["route_nodes"][index]
    path_edges = {frozenset(pair) for pair in zip(route, route[1:])}
    for edge in result["edges"]:
        i, j = edge["i"], edge["j"]
        chosen = frozenset((i, j)) in path_edges
        positive = edge["key_rate_bps"][index] > 0
        if not positive and len(result["edges"]) > 10:
            continue
        ax.plot(x[[i, j]], y[[i, j]], color="#cd722f" if chosen else ("#087f8c" if positive else "#b7bdc5"),
                linewidth=2.8 if chosen else 1, linestyle="-" if positive else "--", alpha=1 if chosen else 0.55)
        if chosen:
            ax.annotate(f'{edge["key_rate_bps"][index] / 1000:.2f} kbit/s',
                        ((x[i] + x[j]) / 2, (y[i] + y[j]) / 2),
                        xytext=(0, 8), textcoords="offset points", ha="center", fontsize=8,
                        bbox=dict(facecolor="white", edgecolor="none", alpha=0.9, pad=2))
    for node, name in enumerate(result["node_names"]):
        ground = node in (0, len(points) - 1)
        ax.scatter(x[node], y[node], marker="^" if ground else "o", s=75 if ground else 65,
                   color="#20354f", edgecolors="white", linewidths=1, zorder=5)
        ax.annotate(name, (x[node], y[node]), xytext=(0, -22 if ground else 13),
                    textcoords="offset points", ha="center", weight="bold", fontsize=9)
    padding = max(float(np.ptp(x)) * 0.12, 250)
    ax.set(xlim=(float(np.min(x) - padding), float(np.max(x) + padding)),
           ylim=(float(np.min(y) - 260), float(np.max(y) + 230)),
           xlabel="Distance transverse to station midpoint (km)",
           ylabel="Radial offset from midpoint surface (km)",
           title=f'Stage {p.stage}: {route_label(result, index)}\n'
                 f't = {result["time_s"][index]:g} s; route = {result["route_rate_bps"][index]/1000:.2f} kbit/s')
    ax.set_aspect("equal", adjustable="box")
    ax.legend(handles=[Line2D([0], [0], color="#cd722f", lw=3, label="Selected route"),
                       Line2D([0], [0], color="#087f8c", lw=1, label="Other positive-key edge"),
                       Line2D([0], [0], color="#b7bdc5", ls="--", label="Unavailable / zero key")],
              loc="lower center", ncol=3, fontsize=8, framealpha=0.95)
    return fig


def plot_links(result):
    """Show contact windows separately from QKD rates and conditional QBER."""
    configure_plots()
    fig = plt.figure(figsize=(11.5, 8), layout="constrained")
    axes = fig.subplots(2, 2, gridspec_kw={"height_ratios": [1, 1.25]})
    time_min = result["time_s"] / 60
    edges = result["edges"]
    contact = np.array([edge["visible"] for edge in edges], dtype=float)
    axes[0, 0].imshow(contact, aspect="auto", interpolation="nearest", origin="lower",
                      extent=[time_min[0], time_min[-1], -0.5, len(edges) - 0.5],
                      cmap="Greens", vmin=0, vmax=1)
    axes[0, 0].set_yticks(range(len(edges)), [edge["label"] for edge in edges], fontsize=8)
    axes[0, 0].set(title="Geometric contacts: green = available", xlabel="Time from orbit midpoint (min)")
    for index, edge in enumerate(edges):
        color = COLORS[index % len(COLORS)]
        style = "--" if edge["kind"] == "isl" else "-"
        if edge["kind"] == "ground":
            axes[0, 1].plot(time_min, edge["elevation_deg"], color=color, lw=1.6)
        axes[1, 0].plot(time_min, edge["key_rate_bps"] / 1000, color=color, ls=style,
                        linewidth=1.8, label=edge["label"])
        axes[1, 1].plot(time_min, edge["qber"] * 100, color=color, ls=style, linewidth=1.8)
    axes[0, 1].axhline(result["parameters"].link.minimum_elevation_deg, color="#20354f", ls=":", lw=1)
    axes[0, 1].set(title="Ground-contact elevation", ylabel="Elevation (degrees)",
                   xlabel="Time from orbit midpoint (min)")
    axes[1, 0].set(title="Independent per-edge key capacities", ylabel="Ideal asymptotic rate (kbit/s)",
                   xlabel="Time from orbit midpoint (min)")
    axes[1, 0].legend(fontsize=7, loc="upper right", ncol=2 if len(edges) > 5 else 1)
    axes[1, 1].set(title="QBER only during available contacts", ylabel="QBER (%)",
                   xlabel="Time from orbit midpoint (min)")
    fig.suptitle(f'Stage {result["parameters"].stage} | Trusted-node BB84: link geometry and performance', fontsize=14)
    return fig


def plot_delivery(result):
    """Selected route capacity and its integral; optional single-relay store bound."""
    configure_plots()
    fig, axes = plt.subplots(1, 2, figsize=(11.5, 4), layout="constrained")
    time_min = result["time_s"] / 60
    axes[0].plot(time_min, result["route_rate_bps"] / 1000, color="#087f8c", lw=2.5)
    axes[0].set(title="Maximum-bottleneck simultaneous route", ylabel="Route capacity (kbit/s)",
                xlabel="Time from orbit midpoint (min)")
    axes[1].plot(time_min, result["cumulative_key_bits"] / 1e6, color="#20354f", lw=2.5,
                 label="Simultaneous route integral")
    if result["parameters"].stage == 3:
        bound = result["metrics"]["stored_pair_bits"] / 1e6
        axes[1].axhline(bound, color="#b05d28", ls="--", label="Post-window stored-pair bound")
    axes[1].set(title="Integrated ideal asymptotic benchmark", ylabel="Benchmark key amount (Mbit)",
                xlabel="Time from orbit midpoint (min)")
    axes[1].legend(fontsize=8)
    fig.suptitle(f'Stage {result["parameters"].stage} | Trusted-node BB84: simultaneous-route benchmark', fontsize=14)
    return fig


def export_report(result, output_dir):
    """Export three figures, route/edge CSVs, parameters/summary JSON and HTML."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = {}
    for name, plot in (("topology", plot_topology), ("links", plot_links), ("delivery", plot_delivery)):
        fig = plot(result)
        paths[name] = output_dir / f"{name}.png"
        fig.savefig(paths[name], bbox_inches="tight", facecolor="white")
        plt.close(fig)
    paths["routes"] = output_dir / "routes.csv"
    with paths["routes"].open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["time_s", "route_rate_bps", "cumulative_key_bits", "route"])
        for index, time in enumerate(result["time_s"]):
            writer.writerow([time, result["route_rate_bps"][index], result["cumulative_key_bits"][index],
                             route_label(result, index)])
    paths["edges"] = output_dir / "edges.csv"
    with paths["edges"].open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        fields = ["distance_km", "elevation_deg", "visible", "eta", "qber", "key_rate_bps", "cumulative_key_bits"]
        writer.writerow(["time_s", "i_zero_based", "j_zero_based", "label", "kind"] + fields)
        for edge in result["edges"]:
            for index, time in enumerate(result["time_s"]):
                writer.writerow([time, edge["i"], edge["j"], edge["label"], edge["kind"]]
                                + [json_safe(edge[key][index]) for key in fields])
    paths["summary"] = output_dir / "summary.json"
    paths["summary"].write_text(json.dumps(json_safe(dict(parameters=result["parameters"], metrics=result["metrics"])),
                                          indent=2, allow_nan=False) + "\n", encoding="utf-8")
    rows = "".join(f"<tr><th>{html.escape(key)}</th><td>{value:,.6g}</td></tr>"
                   for key, value in result["metrics"].items() if np.isfinite(value))
    p = result["parameters"]
    paths["html"] = output_dir / "report.html"
    paths["html"].write_text(f"""<!doctype html><html lang="en"><meta charset="utf-8">
<title>Stage {p.stage} trusted QKD network</title><style>
body{{font:16px system-ui,sans-serif;max-width:1100px;margin:40px auto;padding:0 20px;color:#20354f}}
h1{{font-size:30px}}img{{max-width:100%}}table{{border-collapse:collapse}}th,td{{padding:8px 18px;border-bottom:1px solid #dde3e8;text-align:left}}
code{{background:#f0f4f7;padding:2px 5px}}</style>
<h1>Stage {p.stage}: Two ground stations, {p.satellite_count} satellite(s)</h1>
<p>Illustrative trusted QKD relay network. Ground separation {p.ground_separation_km:g} km;
circular orbit altitude {p.link.altitude_km:g} km; independent terminals and pulse budget per edge.</p>
<table>{rows}</table><p>Rates and integrals are model-known infinite-decoy asymptotic benchmarks.
The route integral assumes simultaneous independent link operation, one selected route, and negligible
relay overhead. Trusted satellites learn relayed keys; this is not a quantum repeater simulation.
Finite-key effects, clouds, Earth rotation, terminal scheduling, authentication costs and actual key generation are omitted.</p>
<img src="topology.png" alt="Satellite and station geometry with chosen route">
<img src="links.png" alt="Contact windows, elevations, per-link rates and QBER">
<img src="delivery.png" alt="Route rate and cumulative ideal benchmark">
<p>Data: <a href="routes.csv">routes.csv</a> · <a href="edges.csv">edges.csv</a> ·
<a href="summary.json">parameters and summary</a>. CSV edge indices and best_index are zero-based.</p>
<p>The stage-3 stored-pair bound is the smaller full-window ground-link integral, assuming independent
terminals, unlimited classical key storage and later authenticated relay. Stage 4 does not schedule key inventories.</p>
</html>""", encoding="utf-8")
    return paths


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", type=int, choices=[3, 4], default=3)
    parser.add_argument("--satellites", type=int, help="Stage 4 satellite count, from 2 to 12")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    parameters = parameters_for_stage(args.stage)
    if args.satellites is not None:
        parameters = replace(parameters, satellite_count=args.satellites)
    destination = args.output or PROJECT_ROOT / STAGE_FOLDERS[args.stage] / "python_results"
    outputs = export_report(simulate_network(parameters), destination)
    print(outputs["html"])
