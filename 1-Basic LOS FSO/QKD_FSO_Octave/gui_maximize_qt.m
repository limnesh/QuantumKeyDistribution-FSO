function gui_maximize_qt(fig)
  set(fig,'Units','pixels','Visible','on'); drawnow();
  if ispc()
    title = get(fig,'Name');
    command = sprintf(['powershell.exe -NoProfile -Command ', ...
      '"$w=New-Object -ComObject WScript.Shell; ', ...
      '$w.AppActivate(''%s''); $w.SendKeys(''%% x'')" >NUL 2>&1'], title);
    system(command);
    drawnow();
  else
    set(fig,'WindowState','maximized'); drawnow();
  end
end
