"""Integrate shared DPS/fading controls into the four existing Octave screens."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]

def replace_once(text,old,new):
    if old not in text: raise RuntimeError('Patch anchor missing: '+old[:100])
    return text.replace(old,new,1)

def main():
    for stage in range(1,5):
        folder=next(ROOT.glob(f'{stage}-*'))
        code=folder/'QKD_FSO_Octave' if stage==1 else folder
        name='qkd' if stage==1 else 'leo' if stage==2 else 'network'
        path=code/f'{name}_dashboard.m'; text=path.read_text(encoding='utf-8')
        if '% UNIFIED_DPS_DASHBOARD' in text: continue
        shared="fullfile(fileparts(mfilename('fullpath')),'..','..','shared')" if stage==1 else "fullfile(fileparts(mfilename('fullpath')),'..','shared')"
        if stage<3:
            text=replace_once(text,f'function fig = {name}_dashboard(P)',f"function fig = {name}_dashboard(P, visibility)\n  % UNIFIED_DPS_DASHBOARD\n  addpath({shared});\n  if nargin<2, visibility='on'; end")
            text=replace_once(text,f'  {name}_validate_parameters(P);',f'  P=extension_ui_defaults(P,{stage});\n  {name}_validate_parameters(P);')
        else:
            text=replace_once(text,'function fig = network_dashboard(stage, P)',f"function fig = network_dashboard(stage, P, visibility)\n  % UNIFIED_DPS_DASHBOARD\n  addpath({shared});\n  if nargin<3, visibility='on'; end")
            text=replace_once(text,'  P = network_validate_parameters(P);','  P=extension_ui_defaults(P,stage);\n  P = network_validate_parameters(P);')
        text=re.sub(r"^\s*uimenu\(fig,'Label','DPS / atmospheric fading'.*\n",'\n',text,flags=re.M)
        if stage<3:
            # Extension groups first; include them before automatic extra-field handling.
            text=replace_once(text,'  % If the parameter file gains a new field later, still make it accessible.',
                f'  groups=[extension_ui_groups({stage}),groups];\n  % If the parameter file gains a new field later, still make it accessible.')
            text=replace_once(text,"      set(S.ui.edits(k), 'String', sprintf('%.12g', S.P.(field)), ...\n          'Visible', 'on', 'TooltipString', tooltip);",
                f"      extension_ui_control(S.ui.edits(k),field,S.P.(field),{stage});\n      set(S.ui.edits(k),'TooltipString',G.labels{{k}});")
            text=replace_once(text,"    value = str2double(strtrim(get(S.ui.edits(k), 'String')));",'    value = extension_ui_value(S.ui.edits(k));')
            marker='  S.plot_area = [0.34 0.14 0.64 0.75];'
            text=replace_once(text,marker,f'  S.page_names=[S.page_names,extension_page_names({stage})];\n'+marker)
            text=replace_once(text,f'    R = {name}_simulate(S.P);',f'    R = {name}_simulate(S.P);\n    R.extension=extension_ui_run({stage},S.P);\n    if S.group<=3, set(S.ui.page,\'Value\',6); end')
            text=replace_once(text,f'  S.P = {name}_parameters(); S.group = 1;',f'  S.P = extension_ui_defaults({name}_parameters(),{stage}); S.group = 1;')
            if stage==1:
                text=replace_once(text,"    set(S.ui.status, 'String', 'Run complete. Choose a plot page, change one setting, or export this run.');", "    set(S.ui.status,'String',extension_ui_status(R.extension));")
            else:
                text=re.sub(r"    set\(S.ui.status, 'String', sprintf\('Contact .*?;\n", "    set(S.ui.status,'String',extension_ui_status(R.extension));\n",text,count=1)
            text=text.replace('  gui_maximize_qt(fig);',"  if strcmp(visibility,'on'), gui_maximize_qt(fig); else, set(fig,'visible','off'); end")
        else:
            # Insert at the end of make_groups, before its local constructor.
            text=replace_once(text,'  end\nend\nfunction G=group(name,fields,labels)',
                '  end\n  groups=[extension_ui_groups(stage),groups];\nend\nfunction G=group(name,fields,labels)')
            text=replace_once(text,"      set(S.ui.edits(k),'String',sprintf('%.12g',value),'Visible','on','TooltipString',field);",
                "      extension_ui_control(S.ui.edits(k),field,value,S.P.stage);\n      set(S.ui.edits(k),'TooltipString',G.labels{k});")
            text=replace_once(text,"    value=str2double(get(S.ui.edits(k),'String'));",'    value=extension_ui_value(S.ui.edits(k));')
            text=replace_once(text,"  S.ui.note=uicontrol(fig,", "  pages=get(S.ui.page,'String'); set(S.ui.page,'String',[pages(:);extension_page_names(stage)(:)]);\n  S.ui.note=uicontrol(fig,")
            text=replace_once(text,'    R=network_simulate(P);','    R=network_simulate(P);\n    R.extension=extension_ui_run(P.stage,P,S.mode,S.B);\n    if S.group<=3, set(S.ui.page,\'Value\',5+(P.stage==3)); end')
            text=replace_once(text,'  S.P=network_parameters(S.P.stage);','  S.P=extension_ui_defaults(network_parameters(S.P.stage),S.P.stage);')
            text=replace_once(text,"  set(S.ui.page,'Value',5); guidata(fig,S); run_model(fig);", "  set(S.ui.page,'Value',6); guidata(fig,S); run_model(fig);")
            text=replace_once(text,"    end\n  catch err, status(fig,['Simulation failed: ',err.message]); end", "    end\n    status(fig,extension_ui_status(R.extension));\n  catch err, status(fig,['Simulation failed: ',err.message]); end")
            text=text.replace('run_model(fig); gui_maximize_qt(fig);',"run_model(fig); if strcmp(visibility,'on'), gui_maximize_qt(fig); else, set(fig,'visible','off'); end")
        path.write_text(text,encoding='utf-8')
        # Dispatch additional pages into the same tagged axes area.
        path=code/f'{name}_draw_page.m'; text=path.read_text(encoding='utf-8')
        first=text.index('\n',text.index('if nargin < 4'))+1
        offset='5' if stage<3 else '4+(R.parameters.stage==3)'
        dispatch=f'''  delete(findall(fig,'Tag','extension_ui_summary'));
  base_pages={offset};
  if page>base_pages && isfield(R,'extension')
    axes_out=extension_draw_page(R.extension,page-base_pages,fig,area); return;
  end
'''
        text=text[:first]+dispatch+text[first:]; path.write_text(text,encoding='utf-8')
        # The existing export button writes both result branches into one run folder.
        path=code/f'{name}_export_results.m'; text=path.read_text(encoding='utf-8')
        anchor="  save('-mat7-binary',fullfile(output_folder,'results.mat'),'R');"
        text=replace_once(text,anchor,anchor+"\n  if isfield(R,'extension')\n    extension_export(R.extension,fullfile(output_folder,'dps_turbulence'));\n  end")
        # Add a stable pointer to the combined export root, independent of report layout.
        text=replace_once(text,"  if isfield(R,'extension')\n    extension_export", "  if isfield(R,'extension')\n    fid=fopen(fullfile(output_folder,'DPS_TURBULENCE.html'),'w');\n    fprintf(fid,'<!doctype html><meta charset=\"utf-8\"><a href=\"dps_turbulence/report.html\">Open the selected protocol and atmospheric turbulence results</a>'); fclose(fid);\n    extension_export")
        path.write_text(text,encoding='utf-8')
    # Every launcher opens the unified screens. Compatibility DPS entry points
    # select its DPS settings inside those screens.
    root=ROOT/'START_PROJECT.m'; text=root.read_text(encoding='utf-8')
    text=text.replace('Choose a project scenario to launch','Choose a scenario: BB84, DPS and turbulence in one dashboard')
    text=text.replace('Each option opens the corresponding START_HERE.m file','Each dashboard includes protocol / turbulence controls and result pages')
    root.write_text(text,encoding='utf-8')

if __name__=='__main__': main()
