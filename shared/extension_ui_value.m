function value=extension_ui_value(h)
  if strcmp(get(h,'style'),'popupmenu'), value=get(h,'value');
  else, value=str2double(strtrim(get(h,'string'))); end
end
