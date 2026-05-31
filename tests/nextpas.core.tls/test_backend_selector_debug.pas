{**
 * 调试程序: 检查可用后端和评分
 *}

program test_backend_selector_debug;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.openssl.backed;  // 注册 OpenSSL 后端

procedure CheckAvailableBackends;
var
  AvailableBackends: TSSLLibraryTypes;
  BackendType: TSSLLibraryType;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  WriteLn('=== 检查可用后端 ===');

  AvailableBackends := TSSLFactory.GetAvailableLibraries;

  WriteLn('可用后端数量: ', Integer(AvailableBackends));

  if AvailableBackends = [] then
  begin
    WriteLn('❌ 没有可用的后端!');
    Exit;
  end;

  for BackendType in AvailableBackends do
  begin
    WriteLn;
    WriteLn('后端类型: ', Ord(BackendType));
    try
      Lib := TSSLFactory.GetLibrary(BackendType);
      WriteLn('  版本: ', Lib.GetVersionString);

      Caps := Lib.GetCapabilities;
      WriteLn('  支持 TLS 1.2: ', Caps.MinTLSVersion <= sslProtocolTLS12);
      WriteLn('  支持 TLS 1.3: ', Caps.SupportsTLS13);
      WriteLn('  安全评分: ', GetSecurityScore(Caps), '/100');
      WriteLn('  性能评分: ', GetPerformanceScore(Caps), '/100');
    except
      on E: Exception do
        WriteLn('  ❌ 错误: ', E.Message);
    end;
  end;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║  后端选择调试                                              ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    CheckAvailableBackends;
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
