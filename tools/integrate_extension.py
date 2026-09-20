"""Idempotent integration of shared extension into existing entry points."""
from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import nbformat

def append_notebook(path,stage):
    nb=nbformat.read(path,as_version=4)
    nb.cells=[c for c in nb.cells if 'dps_extension_v1' not in c.metadata.get('tags',[])]
    # Existing network notebooks omitted a helper that their builders defined.
    if stage>=3 and not any('def table(' in c.source for c in nb.cells):
        first=next(c for c in nb.cells if c.cell_type=='code')
        first.source+='''\n\ndef table(headers, rows):
    def cell(value):
        return str(value).replace("|", "&#124;").replace("\\n", "<br>")
    display(Markdown("| " + " | ".join(map(cell, headers)) + " |\\n| " +
                     " | ".join("---" for _ in headers) + " |\\n" +
                     "\\n".join("| " + " | ".join(map(cell, row)) + " |" for row in rows)))
'''
    number={1:17,2:10,3:11,4:10}[stage]
    intro=f'''## {number}. DPS protocol statistics and atmospheric fading

This extension uses `shared/physics.py`, `shared/scenarios.py` and `shared/reporting.py`.
Earlier sections retain their historical deterministic models and finite BB84 demonstrations.
**DPS uses relative phases between coherent pulses, a one-pulse delay interferometer,
two threshold detectors and explicit valid-slot accounting.** It is not the earlier DPS teaching curve.

**DPS protocol QBER** is a detection statistic. **DPS illustrative rate proxy** uses a
collision-inspired privacy term from the restricted individual-attack analysis, combined
with the detector model described in `DPS_THEORY.md`. A DPS-specific composable secret-key
security bound has not been implemented or established. Its integral is an integrated
proxy, not certified secret-key material. The old BB84/Eve/LDPC/Toeplitz example is not DPS.

Fading is a normalized collected-power multiplier: `exp(sigma*X - sigma**2/2)`;
`sigma**2` is log-irradiance variance. Temporal correlation is phenomenological,
with `rho=exp(-dt/tau_c)` and stationary initialization. The detector factor is fixed;
optical clipping is reported. Ground links have independent random streams; vacuum
inter-satellite links do not receive atmospheric fading. No measured data are used.

Change the protocol and mode below, then restart and run all. Defaults here explicitly
select correlated fading for comparison; library defaults remain `none`.
Stage 3 retains trusted BB84/DPS and separate BBM92 operation. BBM92 always requires
simultaneous visibility and recalculates singles and accidental coincidences on both arms.
Hardware, source, clock resources and security assumptions differ across protocols.
'''
    code=f'''from pathlib import Path
import sys, json
from dataclasses import asdict
from IPython.display import display, Markdown, Image
project_root = next(p for p in (Path.cwd(), *Path.cwd().parents) if (p / "shared" / "physics.py").is_file())
if str(project_root) not in sys.path: sys.path.insert(0, str(project_root))
from shared.physics import DPSParameters, FadingParameters
from shared.scenarios import run_stage
from shared.reporting import export_result, plot_result, study
import matplotlib.pyplot as plt

active_protocol = "DPS QKD"  # Stage 1: BB84, Decoy-state BB84, DPS QKD; others: latter two
architecture = "trusted"    # Stage 3 only: trusted or bbm92
dps_settings = DPSParameters()
fading_settings = FadingParameters(mode="correlated_lognormal", sigma=0.3, correlation_time_s=2.0, seed=123)
extra = {{"mode": architecture}} if {stage} == 3 else {{}}
extension_result = run_stage({stage}, protocol=active_protocol, fading=fading_settings, dps=dps_settings, **extra)
extension_baseline = run_stage({stage}, protocol=active_protocol, dps=dps_settings, **extra)
print("Active protocol:", extension_result["metadata"]["protocol"])
print("DPS parameters:", json.dumps(asdict(dps_settings), indent=2))
print("Fading parameters:", json.dumps(asdict(fading_settings), indent=2))
print(extension_result["metadata"]["security_status"])
summary_rows = "\\n".join(f"| {{k}} | {{v}} |" for k,v in extension_result["summary"].items())
display(Markdown("| Quantity (units in field name) | Value |\\n|---|---|\\n" + summary_rows))
extension_figures = plot_result(extension_result, extension_baseline)
plt.show()
for extension_figure in extension_figures: plt.close(extension_figure)
extension_folder = project_root / {path.parent.name!r} / "dps_turbulence_notebook_results"
export_result(extension_result, extension_folder)
print("Exports:", extension_folder)
'''
    interpretation='''### Interpretation, ensemble study and exports

Mean instantaneous QBER excludes undefined zero-detection samples. Pooled QBER is total
expected errors divided by total expected detections. They generally differ. Sample outage
and time-weighted outage are both exported. Mean instantaneous rate and the rate at mean
efficiency also differ; the latter is a hypothetical continuously open link, not a pass average.
For unavailable satellite contacts, the detection gates are closed and rates are zero.

The following reproducible **default DPS design study** is separate from the selected run above.
It uses fixed geometry and 12 independent seeds, plus five seeds at each turbulence strength.
The plotted sample intervals are descriptive, not confidence bounds or proof of a general trend.
Monte Carlo histograms have sample-count axes, not seconds. All zero rates remain zero.
Reports contain parameters, assumptions, units, seeds, CSV arrays and JSON metadata.
'''
    study_code=f'''default_study_folder = project_root / {path.parent.name!r} / "dps_turbulence_results"
default_study_result, realization_rows, sensitivity_rows = study({stage}, default_study_folder)
display(Markdown("| Seed | Integrated DPS proxy (bits) | Outage sample fraction |\\n|---|---|---|\\n" +
    "\\n".join(f"| {{row['seed']}} | {{row['integrated_rate_bits']:.6g}} | {{row['outage_fraction']:.4f}} |" for row in realization_rows)))
for image_path in sorted(default_study_folder.glob("figure_*.png")):
    display(Image(filename=str(image_path)))
print("Default study HTML:", default_study_folder / "report.html")
'''
    for cell in [nbformat.v4.new_markdown_cell(intro),nbformat.v4.new_code_cell(code),nbformat.v4.new_markdown_cell(interpretation),nbformat.v4.new_code_cell(study_code)]:
        cell.metadata['tags']=['dps_extension_v1']; nb.cells.append(cell)
    # Clarify old text without removing original mathematical/bit examples.
    for cell in nb.cells:
        if 'dps_extension_v1' not in cell.metadata.get('tags',[]):
            cell.source=cell.source.replace('DPS teaching proxy','Legacy DPS teaching proxy').replace('Legacy Legacy','Legacy')
    nbformat.write(nb,path)

def integrate():
    for stage in range(1,5):
        folder=next(ROOT.glob(f'{stage}-*'))
        path=next(folder.glob('*.ipynb')); append_notebook(path,stage)
        dash=folder/('QKD_FSO_Octave/qkd_dashboard.m' if stage==1 else 'leo_dashboard.m' if stage==2 else 'network_dashboard.m')
        text=dash.read_text(encoding='utf-8'); marker='% DPS_EXTENSION_ENTRY'
        if marker not in text:
            root_expr="fullfile(fileparts(mfilename('fullpath')),'..','..','shared')" if stage==1 else "fullfile(fileparts(mfilename('fullpath')),'..','shared')"
            target='  S.P = P;' if stage<3 else '  S.P=P;'
            insert=f'''  {marker}
  addpath({root_expr});
  uimenu(fig,'Label','DPS / atmospheric fading','Callback',@(src,evt) extension_dashboard({stage},guidata(fig).P));
'''
            text=text.replace(target,insert+target,1); dash.write_text(text,encoding='utf-8')
        launch=folder/'RUN_DPS_TURBULENCE.m'
        launch.write_text(f"% Direct companion dashboard; original START_HERE remains available.\naddpath(fullfile(fileparts(mfilename('fullpath')),'..','shared'));\nextension_dashboard({stage});\n",encoding='utf-8')
        # Stable entry points in existing Python modules, importing new math lazily.
        if stage>=2:
            module=folder/('leo_model.py' if stage==2 else 'stage3_model.py' if stage==3 else 'network_model.py')
            text=module.read_text(encoding='utf-8')
            if 'def simulate_with_dps_fading(' not in text:
                text+=f'''\n\ndef simulate_with_dps_fading(**kwargs):
    """Shared protocol/fading extension; existing deterministic API is unchanged."""
    import sys
    root = Path(__file__).resolve().parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from shared.scenarios import run_stage
    return run_stage({stage}, **kwargs)
'''
                # stage3_model does not necessarily import Path.
                text=text.replace('    root = Path(__file__).resolve().parent.parent','    from pathlib import Path\n    root = Path(__file__).resolve().parent.parent')
                module.write_text(text,encoding='utf-8')
    # New generator remains the authoritative extension append step.
    for folder in ROOT.glob('[234]-*'):
        for builder in folder.glob('build_*notebook*.py'):
            text=builder.read_text(encoding='utf-8')
            if '# DPS_EXTENSION_REBUILD' in text:
                text=text.split('# DPS_EXTENSION_REBUILD')[0].rstrip()+'\n'
            if '# DPS_EXTENSION_REBUILD' not in text:
                text+='''\n# DPS_EXTENSION_REBUILD: preserve new sections when rebuilding legacy sources.
if __name__ == "__main__":
    import subprocess, sys
    subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "tools" / "integrate_extension.py")], check=True)
    subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "tools" / "rebuild_notebooks.py"), "--skip-integration"], check=True)
'''
                builder.write_text(text,encoding='utf-8')

if __name__=='__main__': integrate()
