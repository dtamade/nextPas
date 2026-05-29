program test_capability_serialization;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.capability.serializer;

procedure TestJSONSerialization;
var
  Lib: TOpenSSLLibrary;
  Caps: TSSLBackendCapabilities;
  JSONStr: string;
begin
  WriteLn('==============================================');
  WriteLn('JSON 序列化测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TOpenSSLLibrary.Create;
  try
    if not Lib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    // 获取能力矩阵
    Caps := Lib.GetCapabilities;

    // 序列化为 JSON
    WriteLn('序列化为 JSON (pretty format)...');
    JSONStr := CapabilitiesToJSON(Caps, True);

    WriteLn(JSONStr);
    WriteLn;

    WriteLn('✓ JSON 序列化成功');
    WriteLn('  JSON 长度: ', Length(JSONStr), ' 字符');
    WriteLn;

    // 测试紧凑格式
    WriteLn('序列化为 JSON (compact format)...');
    JSONStr := CapabilitiesToJSON(Caps, False);
    WriteLn('  Compact 长度: ', Length(JSONStr), ' 字符');
    WriteLn('  ✓ 紧凑格式序列化成功');
    WriteLn;

    Lib.Finalize;
  finally
    Lib.Free;
  end;
end;

procedure TestXMLSerialization;
var
  Lib: TOpenSSLLibrary;
  Caps: TSSLBackendCapabilities;
  XMLStr: string;
begin
  WriteLn('==============================================');
  WriteLn('XML 序列化测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TOpenSSLLibrary.Create;
  try
    if not Lib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    // 获取能力矩阵
    Caps := Lib.GetCapabilities;

    // 序列化为 XML
    WriteLn('序列化为 XML...');
    XMLStr := CapabilitiesToXML(Caps, True);

    WriteLn(XMLStr);
    WriteLn;

    WriteLn('✓ XML 序列化成功');
    WriteLn('  XML 长度: ', Length(XMLStr), ' 字符');
    WriteLn;

    Lib.Finalize;
  finally
    Lib.Free;
  end;
end;

procedure TestFileSerialization;
var
  Lib: TOpenSSLLibrary;
  Caps: TSSLBackendCapabilities;
  JSONFile, XMLFile: string;
begin
  WriteLn('==============================================');
  WriteLn('文件序列化测试');
  WriteLn('==============================================');
  WriteLn;

  JSONFile := 'capability_openssl.json';
  XMLFile := 'capability_openssl.xml';

  Lib := TOpenSSLLibrary.Create;
  try
    if not Lib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    Caps := Lib.GetCapabilities;

    // 保存为 JSON
    WriteLn('保存为 JSON 文件: ', JSONFile);
    try
      SaveCapabilitiesToFile(Caps, JSONFile, 'json');
      WriteLn('  ✓ JSON 文件保存成功');
    except
      on E: Exception do
        WriteLn('  ✗ 保存失败: ', E.Message);
    end;

    // 保存为 XML
    WriteLn('保存为 XML 文件: ', XMLFile);
    try
      SaveCapabilitiesToFile(Caps, XMLFile, 'xml');
      WriteLn('  ✓ XML 文件保存成功');
    except
      on E: Exception do
        WriteLn('  ✗ 保存失败: ', E.Message);
    end;

    WriteLn;
    WriteLn('提示: 使用以下命令查看生成的文件:');
    WriteLn('  cat ', JSONFile);
    WriteLn('  cat ', XMLFile);
    WriteLn;

    Lib.Finalize;
  finally
    Lib.Free;
  end;
end;

procedure TestMultipleBackends;
var
  Backends: array[0..2] of TSSLLibraryType;
  I: Integer;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  FileName: string;
begin
  WriteLn('==============================================');
  WriteLn('多后端序列化测试');
  WriteLn('==============================================');
  WriteLn;

  Backends[0] := sslOpenSSL;
  Backends[1] := sslWolfSSL;
  Backends[2] := sslMbedTLS;

  for I := Low(Backends) to High(Backends) do
  begin
    try
      WriteLn('Processing backend: ', SSL_LIBRARY_NAMES[Backends[I]]);

      Lib := TSSLFactory.GetLibrary(Backends[I]);
      if not Assigned(Lib) then
      begin
        WriteLn('  Backend not available, skipping');
        WriteLn;
        Continue;
      end;

      Caps := Lib.GetCapabilities;

      // 保存为 JSON
      FileName := Format('capability_%s.json',
        [LowerCase(SSL_LIBRARY_NAMES[Backends[I]])]);
      SaveCapabilitiesToFile(Caps, FileName, 'json');
      WriteLn('  ✓ Saved to: ', FileName);

    except
      on E: Exception do
        WriteLn('  ✗ Error: ', E.Message);
    end;

    WriteLn;
  end;
end;

begin
  WriteLn('fafafa.ssl - 能力矩阵序列化测试');
  WriteLn('==============================================');
  WriteLn;

  try
    TestJSONSerialization;
    WriteLn;
    TestXMLSerialization;
    WriteLn;
    TestFileSerialization;
    WriteLn;
    TestMultipleBackends;

    WriteLn('==============================================');
    WriteLn('所有测试完成！');
    WriteLn('==============================================');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('[ERROR] ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
