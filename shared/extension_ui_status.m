function text_out=extension_ui_status(X)
  suffix='asymptotic estimate'; if ~isempty(strfind(X.metadata.security_status,'proxy')), suffix='illustrative proxy'; end
  text_out=sprintf('%s / %s: mean %.5g bits/s; integral %.6g bits; outage %.2f%% (%s).', ...
    X.metadata.protocol,X.metadata.fading.mode,X.summary.mean_rate_bps,X.summary.integrated_rate_bits,100*X.summary.outage_fraction,suffix);
  if isfield(X.summary,'pooled_qber')
    text_out={text_out,sprintf('Mean QBER %.4g%%; pooled QBER %.4g%%. No composable DPS security bound.',100*X.summary.mean_qber,100*X.summary.pooled_qber)};
  else
    text_out={text_out,'Trusted classical pools and BBM92 pairs remain separate architectures. DPS budgets are proxies.'};
  end
end
