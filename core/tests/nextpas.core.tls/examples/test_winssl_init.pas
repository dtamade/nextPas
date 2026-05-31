program test_winssl_init;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.lib;

procedure TestWinSSLInit;
var
  Libs: TSSLLibraryTypes;
  Lib: ISSLLibrary;
begin
  WriteLn('=== 测试 WinSSL 库初始化 ===');
  WriteLn;
  
  // 检查可用的库
  WriteLn('检查可用的 SSL 库...');
  try
    Libs := TSSLFactory.GetAvailableLibraries;
  except
    on E: Exception do
    begin
      WriteLn('GetAvailableLibraries 错误: ', E.ClassName, ': ', E.Message);
      Libs := [];
    end;
  end;
  
  if Libs = [] then
    WriteLn('没有找到可用的 SSL 库')
  else
  begin
    WriteLn('找到以下 SSL 库:');
    if sslWinSSL in Libs then
      WriteLn('  - Windows Schannel (WinSSL)');
    if sslOpenSSL in Libs then
      WriteLn('  - OpenSSL');
    if sslWolfSSL in Libs then
      WriteLn('  - WolfSSL');
    if sslMbedTLS in Libs then
      WriteLn('  - MbedTLS');
  end;
  
  WriteLn;
  
  // 尝试获取 WinSSL 库实例
  WriteLn('尝试创建 WinSSL 库实例...');
  try
    WriteLn('  1. 调用 GetLibraryInstance...');
    Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);
    if Lib <> nil then
    begin
      WriteLn('成功创建 WinSSL 库实例');
      WriteLn('库类型: ', LibraryTypeToString(Lib.GetLibraryType));
      WriteLn('版本: ', Lib.GetVersionString);
      
      // 尝试初始化
      WriteLn;
      WriteLn('初始化 WinSSL 库...');
      if Lib.Initialize then
      begin
        WriteLn('WinSSL 库初始化成功');
        WriteLn('库已准备就绪');
      end
      else
        WriteLn('WinSSL 库初始化失败');
    end
    else
      WriteLn('无法创建 WinSSL 库实例');
  except
    on E: Exception do
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('=== 测试完成 ===');
end;

begin
  try
    TestWinSSLInit;
  except
    on E: Exception do
      WriteLn('发生异常: ', E.ClassName, ': ', E.Message);
  end;
end.
