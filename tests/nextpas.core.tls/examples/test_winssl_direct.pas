program test_winssl_direct;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

procedure TestWinSSLDirect;
var
  Lib: TWinSSLLibrary;
begin
  WriteLn('=== 测试 WinSSL 库直接创建 ===');
  WriteLn;
  
  // 直接创建 WinSSL 库实例
  WriteLn('创建 TWinSSLLibrary 实例...');
  try
    Lib := TWinSSLLibrary.Create;
    try
      WriteLn('成功创建 TWinSSLLibrary 实例');
      
      // 尝试初始化
      WriteLn('初始化 WinSSL 库...');
      if Lib.Initialize then
      begin
        WriteLn('WinSSL 库初始化成功');
        WriteLn('库类型: ', LibraryTypeToString(Lib.GetLibraryType));
        WriteLn('版本: ', Lib.GetVersionString);
      end
      else
        WriteLn('WinSSL 库初始化失败');
    finally
      Lib.Free;
    end;
  except
    on E: Exception do
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('=== 测试完成 ===');
end;

begin
  try
    TestWinSSLDirect;
  except
    on E: Exception do
      WriteLn('发生异常: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('按 Enter 键退出...');
  ReadLn;
end.