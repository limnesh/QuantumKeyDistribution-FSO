"""Restart/execute each notebook; replace notebook and HTML only after success."""
from pathlib import Path
import argparse,json,sys,time
import nbformat
from nbclient import NotebookClient
from nbconvert import HTMLExporter
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from integrate_extension import integrate

def main():
    p=argparse.ArgumentParser(); p.add_argument('--stage',type=int,choices=range(1,5)); p.add_argument('--skip-integration',action='store_true'); a=p.parse_args()
    if not a.skip_integration: integrate()
    log_path=ROOT/'validation'/'notebook_execution.json'
    record=json.loads(log_path.read_text()) if log_path.exists() else []
    for stage in ([a.stage] if a.stage else range(1,5)):
        path=next(next(ROOT.glob(f'{stage}-*')).glob('*.ipynb')); start=time.monotonic()
        try:
            nb=nbformat.read(path,as_version=4)
            NotebookClient(nb,timeout=600,kernel_name='python3',resources={'metadata':{'path':str(path.parent)}}).execute()
            html,_=HTMLExporter().from_notebook_node(nb)
            nbformat.write(nb,path); path.with_suffix('.html').write_text(html,encoding='utf-8')
            row=dict(stage=stage,status='passed',cells=len(nb.cells),elapsed_s=time.monotonic()-start)
        except Exception as e:
            row=dict(stage=stage,status='failed',error=str(e),elapsed_s=time.monotonic()-start)
            (ROOT/'validation'/f'notebook_stage{stage}_error.txt').write_text(str(e),encoding='utf-8')
        record=[old for old in record if old['stage']!=stage]+[row]; record.sort(key=lambda x:x['stage'])
        print(json.dumps(row),flush=True)
        (ROOT/'validation'/'notebook_execution.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
        if row['status']=='failed': raise RuntimeError(f'Notebook stage {stage} failed; original HTML retained')

if __name__=='__main__': main()
