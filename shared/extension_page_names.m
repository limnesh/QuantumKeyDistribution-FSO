function names=extension_page_names(stage)
  names={'Protocol / turbulence: time series','Protocol / turbulence: distributions'};
  if stage==1
    names=[names,{'DPS: distance and visibility','DPS: receiver and noise sensitivity'}];
  elseif stage==2
    names=[names,{'Protocol / turbulence: elevation and geometry'}];
  elseif stage==3
    names=[names,{'Trusted relay: faded links and classical pools','BBM92: two-arm atmospheric fading','Network: fading-adjusted routes'}];
  else
    names=[names,{'Network: fading-adjusted routes'}];
  end
  if stage>=2, names{end+1}='Protocol / turbulence: strength and design sensitivity'; end
  names{end+1}='Protocol / turbulence: independent realizations';
end
