program test_init_order;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  // 引用顺序很重要：先引用 winssl，让它注册
  nextpas.core.tls.winssl.lib,
  nextpas.core.tls.factory,
  nextpas.core.tls.base;

var
  libs: TSSLLibraryTypes;

begin
  WriteLn('=== 测试单元初始化顺序 ===');
  WriteLn;
  
  WriteLn('获取可用库列表...');
  libs := TSSLFactory.GetAvailableLibraries;
  
  if libs = [] then
    WriteLn('没有可用库')
  else
  begin
    WriteLn('可用库:');
    if sslWinSSL in libs then WriteLn('  - WinSSL');
    if sslOpenSSL in libs then WriteLn('  - OpenSSL');
  end;
  
  WriteLn;
  WriteLn('=== 测试完成 ===');
end.