function extension_ui_control(h,field,value,stage)
  options={};
  if strcmp(field,'x_protocol')
    if stage==1, options={'BB84','Decoy-state BB84','DPS QKD'};
    else, options={'Decoy-state BB84','DPS QKD'}; end
  elseif strcmp(field,'x_fading_mode')
    options={'None','Independent log-normal','Correlated log-normal'};
  elseif strcmp(field,'x_link_b_protocol')
    options={'Same as Ground A','Decoy-state BB84','DPS QKD'};
  end
  if isempty(options)
    set(h,'style','edit','value',1,'string',sprintf('%.12g',value));
  else
    if value<1 || value>numel(options) || fix(value)~=value, error('Invalid selection for %s',field); end
    set(h,'style','popupmenu','string',options,'value',value);
  end
  set(h,'visible','on');
end
