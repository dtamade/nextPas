program test_registration;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.lib;

procedure TestRegistration;
var
  lib: TWinSSLLibrary;
  intf: ISSLLibrary;
begin
  WriteLn('=== 测试库注册 ===');
  WriteLn;
  
  // 手动创建并初始化一个 WinSSL 库实例
  WriteLn('1. 直接创建 WinSSL 实例...');
  lib := TWinSSLLibrary.Create;
  try
    WriteLn('   创建成功');
    WriteLn('   库类型: ', LibraryTypeToString(lib.GetLibraryType));
    
    WriteLn('2. 初始化库...');
    if lib.Initialize then
      WriteLn('   初始化成功')
    else
      WriteLn('   初始化失败');
      
    WriteLn('3. 通过接口引用...');
    if Supports(lib, ISSLLibrary, intf) then
    begin
      WriteLn('   支持 ISSLLibrary 接口');
      WriteLn('   版本: ', intf.GetVersionString);
    end
    else
      WriteLn('   不支持 ISSLLibrary 接口');
      
  finally
    lib.Free;
  end;
end;

begin
  try
    TestRegistration;
  except
    on E: Exception do
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('=== 测试完成 ===');
end.