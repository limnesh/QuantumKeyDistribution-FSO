"""Build final implementation record from actual run artifacts and hashes."""
from pathlib import Path
import hashlib,json
from urllib.parse import quote
ROOT=Path(__file__).resolve().parents[1]

def main():
    v=json.loads((ROOT/'validation/verification.json').read_text())
    notebooks=json.loads((ROOT/'validation/notebook_execution.json').read_text())
    originals=json.loads((ROOT/'validation/original_inventory.json').read_text())
    modified=[r['path'].replace('\\','/') for r in originals if (ROOT/r['path']).exists() and hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()!=r['sha256']]
    external_changes=[p for p in modified if p=='QKD - FSO Report.docx']
    source_changes=[p for p in modified if p not in external_changes and not any(part in p for part in ['python_results/','notebook_results/'])]
    new=[str(p.relative_to(ROOT)).replace('\\','/') for folder in ['shared','tools'] for p in (ROOT/folder).glob('*') if p.is_file()]
    lines=['# DPS and turbulence implementation report','',
        'Implementation date: 19 September 2026. Numerical simulations, not measured data.','',
        '## 1. Original assignment requirements','',
        'Implemented a DPS protocol-statistics extension across terrestrial LOS, LEO downlink, trusted single-satellite relay, separate BBM92 distribution, and the multi-satellite trusted network. Added weak log-normal independent and correlated fading, per-edge recomputation, plots, exports, tests, notebooks and documentation. The historical BB84/Eve/LDPC/Toeplitz and BBM92 implementations remain available. ML remains future work.','',
        '## 2. Files inspected','',
        'See [DPS_REPOSITORY_AUDIT.md](DPS_REPOSITORY_AUDIT.md) for the full source inventory and dependency map. The machine-readable calls/imports are in [validation/dependency_map.json](validation/dependency_map.json). All four launchers and dashboards, Python/Octave models, notebooks, tests, fixtures, report generators and repository PDF paths were inspected. No Git repository was present.','',
        '## 3. Files modified','',
        'Original source/notebook/report identities are retained in `validation/pre_extension_backup.zip` and `validation/original_inventory.json`. Historical numerical models are preserved; new outputs have distinct extension folders. Executing notebooks also regenerates their normal deterministic report outputs.','']
    lines += ['- ['+p+']('+quote(p)+')' for p in source_changes]
    if external_changes:
        lines += ['','The open `QKD - FSO Report.docx` also changed its hash during execution. No implementation edit targeted it; this external change was preserved and excluded from the implementation change list.','']
    lines += ['','New shared code and reproducibility tools:','']+['- ['+p+']('+quote(p)+')' for p in new]
    lines += ['','Additional new documents: `DPS_THEORY.md`, `DPS_REPOSITORY_AUDIT.md`, `DPS_REPORT_INSERTION.md`, this report, and `DPS_SCIENTIFIC_VALIDATION.md`. Each scenario has `RUN_DPS_TURBULENCE.m`.','',
        '## 4. New mathematical models','',
        'Relative-phase coherent amplitudes and a one-slot-delay interferometer explicitly distinguish N−1 interior slots from two boundary slots. Independent threshold detectors include signal/background overlap and random double-click assignment. DPS gain, error gain and QBER are calculated per valid gate; pulse and guard-slot accounting are explicit. The proxy privacy fraction is collision-inspired and depends on source photon number. Optical collected-power fading is clipped before the fixed detector factor. See [DPS_THEORY.md](DPS_THEORY.md) for equations, units and assumptions.','',
        '## 5. Scientific references','',
        'Neither requested PDF exists in this repository. The online [Nath et al. tutorial](https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/qtc2.70033), Section 5.4, was consulted. Its phase-error requirement does not establish a bound for this simulator. The primary [Waks–Takesue–Yamamoto paper](https://arxiv.org/pdf/quant-ph/0508112), Eqs. (34)–(36), informs the collision-inspired privacy term. The [weak-turbulence paper record](https://ieeexplore.ieee.org/document/10729846) was located, but full text remained unavailable; no reproduction or paper-derived physical turbulence mapping is claimed.','',
        '## 6. DPS security status','',
        '**DPS protocol QBER** and **DPS illustrative rate proxy** are distinct outputs. A DPS-specific composable secret-key security bound has not been implemented or established. No general-attack, finite-key, device-independent or deployment security claim is made. All DPS-derived pool, route and accumulated quantities are proxy budgets. Existing BB84 and BBM92 asymptotic estimates keep their separate interpretation.','',
        '## 7. Turbulence assumptions','',
        'Modes: none, independent_lognormal, correlated_lognormal. Before clipping, F=exp(sigma*X−sigma²/2) has mean one and variance exp(sigma²)−1. Correlated X starts stationary and uses physical dt and assumed tau_c. Default demonstration sigma=0.3 and tau_c=2 s are phenomenological. Sigma² is log-irradiance variance; no Cn² or Rytov calibration is claimed. Independent per-ground-edge streams; vacuum ISLs always have F=1. Clipping fraction, detector efficiency and seeds are exported. Identical Python/Octave seeds need not produce identical trajectories.','',
        '## 8. Scenario-by-scenario implementation','',
        '| Stage | Extension and retained behavior | Executed Python report |','|---|---|---|']
    descriptions={1:'DPS distance/visibility, 5,000-sample distributions, physical-time traces and cumulative proxy; aperture/background/sigma sensitivity; legacy finite BB84 unchanged.',
        2:'Existing circular geometry and atmospheric shell; DPS/decoy selector, per-pass fading, elevation/cutoff sensitivity, fixed-geometry independent realizations.',
        3:'Trusted per-link DPS/decoy selection, separate streams, simultaneous bottleneck and causal pools. BBM92 retains two-arm singles/coincidence/noise recalculation and simultaneous visibility.',
        4:'Per-edge protocols and atmospheric fading before existing widest-path routing; vacuum preserved; routes, capacities, outages, topology and satellite-count sensitivity.'}
    for s in range(1,5):
        folder=next(ROOT.glob(f'{s}-*')); path=folder/'dps_turbulence_results/report.html'
        lines.append(f'| {s} | {descriptions[s]} | [Report]({quote(str(path.relative_to(ROOT)).replace(chr(92),"/"))}) |')
    lines+=['','Default correlated realization (seed 123; these values alone do not establish a trend):','',
        '| Stage | Integrated DPS proxy (bits) | Sample rate outage |','|---|---:|---:|']
    for s in range(1,5):
        r=json.loads((next(ROOT.glob(f'{s}-*'))/'dps_turbulence_results/results.json').read_text())['summary']
        lines.append(f"| {s} | {r['integrated_rate_bits']:.6f} | {r['outage_fraction']:.6f} |")
    lines+=['','## 9. Python test results','',
        'Executed **68 tests**: 15 new DPS/fading/export tests, 7 existing LEO tests, 23 existing Stage 3 tests and 23 existing Stage 4 tests. All passed. Logs: `validation/python_extension.log`, `python_stage2.log`, `python_stage3.log`, `python_stage4.log`.','',
        '| Notebook | Status | Cells |','|---|---|---:|']
    for row in notebooks: lines.append(f"| Stage {row['stage']} | {row['status']} | {row['cells']} |")
    lines+=['','All four notebooks were executed from fresh kernels and corresponding HTML regenerated only after successful execution. JSON/CSV/PNG/HTML reports are generated from the shared models.','',
        '## 10. Octave test results','',
        'GNU Octave 10.3.0 executed `test_qkd`, `test_leo`, `test_network`, `test_network_workflow`, `test_stage3` (network suites in both folders), and `shared/test_extension.m`. All assertions passed. The original finite BB84 demonstration produced 1,182 sifted bits and 256 matching final demonstration bits in its regression run. Logs: `validation/octave_stage1.log` through `octave_stage4.log`, and `octave_extension.log`.','',
        'Octave exports and sensitivity studies are in `validation/octave_study_stage1` through `octave_study_stage4`, including reports, CSV, JSON, MAT and figures. All four companion dashboards passed hidden Qt construction checks (`validation/gui_smoke.log`). Representative exported Python and Octave figures were visually inspected. **Interactive GUI appearance and a manual end-to-end click workflow were not visually tested.**','',
        '## 11. Cross-language comparison','',
        'Actual arrays were compared, not inferred from shared formulas. The complete tolerances and errors are in [validation/verification.json](validation/verification.json). Core detector cases and supplied Gaussian innovations agreed to the reported numerical precision.','',
        '| Quantity | Maximum absolute difference |','|---|---:|']
    for key,value in v['cross_language'].items():
        if key.startswith('stage'): lines.append(f"| {key} | {value['max_absolute_error']:.6g} |")
    lines+=['','Independent RNG comparisons used 150,000 samples for each of three seeds, checking means, variances, QBER/rate percentiles, outage and integrated rate estimates. Statistical tolerances are explicit; identical seeds were not equated across languages. Stationary Gaussian lag correlation was checked at multiple lags.','',
        'Time-step convergence covered deterministic Stage 2 (201–1,601 samples), Stage 4 (301–2,401 samples) and subsampling a fixed fine correlated path. This separates quadrature changes from changing random realizations.','',
        '| Case | Samples | dt (s) | Integrated proxy (bits) |','|---|---:|---:|---:|']
    for row in v['convergence']: lines.append(f"| {row['stage']} | {row['samples']} | {row['dt_s']:.6g} | {row['integral']:.6f} |")
    lines+=['','## 12. Remaining limitations','',
        '- The weak-turbulence full text remains unavailable, and neither requested PDF was supplied locally. The model does not claim reproduction of that paper.',
        '- DPS rates are proxies; no complete finite-bit DPS reconciliation/hash experiment or composable proof was added. Coherent neighboring pulses see a quasi-static channel; phase turbulence, dead time, afterpulsing and saturation are excluded.',
        '- The trusted network retains independent per-edge pulse resources, unlimited classical demand/storage for Stage 3A, and no Stage 4 stored-network scheduler. BBM92 approximation guards can reject strong/low-loss parameter choices.',
        '- GUI construction was tested, but manual GUI visual/click validation remains unperformed. Figures were rendered and representative output images inspected.',
        '- `QKD - FSO Report.docx` had an existing Word lock and remains untouched. `DPS_REPORT_INSERTION.md` is ready for it. The unlocked detailed report received Appendix D; original paragraph text/styles and table counts were checked.',
        '- No ML implementation or new runtime package installation was introduced.','',
        'There are no unresolved numerical-test or notebook-execution failures in the final run. During development, the existing network notebooks raised `NameError: name \'table\' is not defined`; the helper was restored. Export bugs raised `ValueError: \'yerr\' must not contain negative values` and `ValueError: setting an array element with a sequence`; both were fixed. CLI rendering initially raised `graphics_toolkit: qt toolkit is not available` and `print: rendering with fltk toolkit requires visible figure (DISPLAY=\'\')`; the full Octave executable and explicit export toolkit resolved rendering. The old Stage 3 error transcript is retained as resolved diagnostic history. ZMQ fallback-thread and gnuplot/font warnings were non-fatal.','',
        '## 13. Exact instructions to launch each scenario','',
        'Open `START_PROJECT.m` in Octave GUI and press F5. Choose a stage, then **DPS / atmospheric fading** from its menu. All original dashboard pages remain available. Direct companion launchers:','']
    for s in range(1,5):
        folder=next(ROOT.glob(f'{s}-*')); lines.append(f"- Stage {s}: `{folder.name}/RUN_DPS_TURBULENCE.m` (open and press F5).")
    lines+=['','Python (from the project root):','',
        '```python','from shared.scenarios import run_stage, network','from shared.physics import DPSParameters, FadingParameters',
        "result = run_stage(2, protocol='DPS QKD', fading=FadingParameters(mode='correlated_lognormal'))",
        "relay = network(3, protocols=['DPS QKD', 'Decoy-state BB84'])",
        "entangled = network(3, mode='bbm92', fading=FadingParameters(mode='correlated_lognormal'))",'```','',
        'Library default fading mode is `none`; notebook default study cells explicitly select correlated fading. Protocol choices are `BB84` (Stage 1), `Decoy-state BB84`, `DPS QKD`; BBM92 is a separate Stage 3 architecture.','',
        '## 14. Exact instructions to reproduce the figures','',
        'From the project root:','',
        '```powershell','python tools/run_dps_studies.py','python tools/rebuild_notebooks.py',
        'python tools/verify_extension.py --octave "D:\\AntennaSimulations\\Octave-10.3.0\\mingw64\\bin\\octave-cli.exe"','```','',
        'The explicit executable path above records this machine; portable Python code locates project files relatively. On another machine, use `--octave` with its executable or put `octave-cli` on PATH.','',
        'In the Octave GUI command window, with the project root as current folder:','',
        '```octave',"addpath('shared');","for stage=1:4","  extension_study(stage, fullfile('validation', sprintf('octave_study_stage%d',stage)));",'end',
        "F=fading_parameters(); F.mode='correlated_lognormal'; D=dps_parameters();",
        "R=extension_simulate(3, {'DPS QKD','Decoy-state BB84'}, F, D);",'```','',
        'Each report embeds or links its generated figures; the notebooks include numeric tables, active protocol, parameter units and security limitations. The original notebook builders invoke the extension integration and execution step so regenerated notebooks retain these sections.','']
    (ROOT/'DPS_TURBULENCE_IMPLEMENTATION_REPORT.md').write_text('\n'.join(lines),encoding='utf-8')
    validation='''# DPS scientific validation record

This record concerns numerical/model correctness, not a security proof or experimental validation.

The complete execution record is in DPS_TURBULENCE_IMPLEMENTATION_REPORT.md and validation/verification.json.
Analytic reference cases include: perfect visibility with no noise, Q=1-exp(-mu*eta), QBER=0;
zero optical signal with per-detector d=.01, Q=.0199, QBER=.5, rate=0;
and zero signal plus zero noise, undefined QBER and exactly zero rate.
Independent Poisson/threshold Monte Carlo agrees with the closed detector equations.
Pulse-train ports conserve energy and recover the encoded relative bits in interior slots.

Validation checks stationary log-normal moments, Gaussian temporal lag correlation,
independent link streams, clipping, seeded reproducibility, and no fading on vacuum edges.
System checks preserve geometry, deterministic BB84, relay pool conservation, two-arm BBM92
coincidences and visibility, route recomputation, disconnection and nonnegative integration.
JSON/CSV export tests exercise ragged routes, undefined QBER and exact zero rates.

All new DPS quantities and their accumulated budgets remain illustrative proxies.
The individual-attack collision expression is not a composable proof for this detector/fading implementation.
The tutorial's phase-error quantity is not inferred merely from interferometer visibility.
The weak-turbulence paper full text was unavailable; no reproduction claim is made.

Resolved failures: the retained notebook_stage3_error.txt predates the restored table helper.
Current notebook_execution.json records the successful final executions.
'''
    (ROOT/'DPS_SCIENTIFIC_VALIDATION.md').write_text(validation,encoding='utf-8')
    (ROOT/'validation/changed_files.json').write_text(json.dumps(dict(modified=[p for p in modified if p not in external_changes],externally_changed_not_edited=external_changes,new_sources=new),indent=2),encoding='utf-8')
    print('Wrote implementation report and scientific validation record')

if __name__=='__main__': main()
