program test_factory_simple;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.lib;

var
  libs: TSSLLibraryTypes;

begin
  WriteLn('=== 测试工厂初始化 ===');
  WriteLn;
  
  try
    // 直接检查 WinSSL 是否可用（这应该在初始化时已经注册）
    WriteLn('1. 检查 WinSSL 是否可用...');
    if TSSLFactory.IsLibraryAvailable(sslWinSSL) then
      WriteLn('   WinSSL 可用')
    else
      WriteLn('   WinSSL 不可用');
      
    // 获取可用库列表
    WriteLn('2. 获取可用库列表...');
    libs := TSSLFactory.GetAvailableLibraries;
    if libs = [] then
      WriteLn('   没有可用库')
    else
    begin
      WriteLn('   可用库:');
      if sslWinSSL in libs then WriteLn('     - WinSSL');
      if sslOpenSSL in libs then WriteLn('     - OpenSSL');
    end;
      
  except
    on E: Exception do
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('=== 测试完成 ===');
end.