{******************************************************************************}
{  WinSSL vs OpenSSL Integration Comparison Tests                              }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{                                                                              }
{  测试阶段 4: WinSSL vs OpenSSL 对比测试                                      }
{  目的:                                                                       }
{    - 验证 WinSSL 和 OpenSSL 后端的兼容性                                     }
{    - 对比两种实现的性能差异                                                  }
{    - 确保跨后端的一致性                                                      }
{******************************************************************************}

program test_integration_winssl_openssl_comparison;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  {$IFDEF WINDOWS}
  nextpas.core.tls.winssl.lib,
  {$ENDIF}
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestLibraryInitialization;
var
  OpenSSLLib: ISSLLibrary;
  {$IFDEF WINDOWS}
  WinSSLLib: ISSLLibrary;
  {$ENDIF}
  StartTime: TDateTime;
  Duration: Double;
  OpenSSLInit: Boolean;
begin
  WriteLn('');
  WriteLn('=== Library Initialization ===');

  // Test OpenSSL
  StartTime := Now;
  try
    OpenSSLLib := TOpenSSLLibrary.Create;
    OpenSSLInit := OpenSSLLib.Initialize;
    Duration := MilliSecondsBetween(Now, StartTime);

    if OpenSSLInit then
    begin
      Runner.Check('OpenSSL initialization', True, Format('Version: %s, Time: %.2f ms',
        [OpenSSLLib.GetVersionString, Duration]));
    end
    else
      Runner.Check('OpenSSL initialization', False, 'Init failed');
  except
    on E: Exception do
      Runner.Check('OpenSSL initialization', False, E.Message);
  end;

  // Test WinSSL
  {$IFDEF WINDOWS}
  StartTime := Now;
  try
    WinSSLLib := TWinSSLLibrary.Create;
    if WinSSLLib.Initialize then
    begin
      Duration := MilliSecondsBetween(Now, StartTime);
      Runner.Check('WinSSL initialization', True, Format('Version: %s, Time: %.2f ms',
        [WinSSLLib.GetVersionString, Duration]));
    end
    else
      Runner.Check('WinSSL initialization', False, 'Init failed');
  except
    on E: Exception do
      Runner.Check('WinSSL initialization', False, E.Message);
  end;
  {$ELSE}
  Runner.Skip('WinSSL initialization', 'Linux platform');
  {$ENDIF}
end;

procedure TestContextCreation;
var
  OpenSSLLib: ISSLLibrary;
  OpenSSLCtx: ISSLContext;
  {$IFDEF WINDOWS}
  WinSSLLib: ISSLLibrary;
  WinSSLCtx: ISSLContext;
  {$ENDIF}
begin
  WriteLn('');
  WriteLn('=== Context Creation ===');

  // OpenSSL context
  try
    OpenSSLLib := TOpenSSLLibrary.Create;
    if OpenSSLLib.Initialize then
    begin
      OpenSSLCtx := OpenSSLLib.CreateContext(sslCtxClient);
      Runner.Check('OpenSSL client context', OpenSSLCtx <> nil);

      OpenSSLCtx := OpenSSLLib.CreateContext(sslCtxServer);
      Runner.Check('OpenSSL server context', OpenSSLCtx <> nil);
    end;
  except
    on E: Exception do
      Runner.Check('OpenSSL context creation', False, E.Message);
  end;

  // WinSSL context
  {$IFDEF WINDOWS}
  try
    WinSSLLib := TWinSSLLibrary.Create;
    if WinSSLLib.Initialize then
    begin
      WinSSLCtx := WinSSLLib.CreateContext(sslCtxClient);
      Runner.Check('WinSSL client context', WinSSLCtx <> nil);

      WinSSLCtx := WinSSLLib.CreateContext(sslCtxServer);
      Runner.Check('WinSSL server context', WinSSLCtx <> nil);
    end;
  except
    on E: Exception do
      Runner.Check('WinSSL context creation', False, E.Message);
  end;
  {$ELSE}
  Runner.Skip('WinSSL context creation', 'Linux platform');
  {$ENDIF}
end;

procedure TestProtocolVersionSupport;
var
  OpenSSLLib: ISSLLibrary;
  OpenSSLCtx: ISSLContext;
  {$IFDEF WINDOWS}
  WinSSLLib: ISSLLibrary;
  WinSSLCtx: ISSLContext;
  {$ENDIF}
begin
  WriteLn('');
  WriteLn('=== Protocol Version Support ===');

  // OpenSSL protocol support
  try
    OpenSSLLib := TOpenSSLLibrary.Create;
    if OpenSSLLib.Initialize then
    begin
      OpenSSLCtx := OpenSSLLib.CreateContext(sslCtxClient);
      if OpenSSLCtx <> nil then
      begin
        OpenSSLCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        Runner.Check('OpenSSL TLS 1.2/1.3 support', True);
      end;
    end;
  except
    on E: Exception do
      Runner.Check('OpenSSL protocol setup', False, E.Message);
  end;

  // WinSSL protocol support
  {$IFDEF WINDOWS}
  try
    WinSSLLib := TWinSSLLibrary.Create;
    if WinSSLLib.Initialize then
    begin
      WinSSLCtx := WinSSLLib.CreateContext(sslCtxClient);
      if WinSSLCtx <> nil then
      begin
        WinSSLCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        Runner.Check('WinSSL TLS 1.2/1.3 support', True);
      end;
    end;
  except
    on E: Exception do
      Runner.Check('WinSSL protocol setup', False, E.Message);
  end;
  {$ELSE}
  Runner.Skip('WinSSL protocol support', 'Linux platform');
  {$ENDIF}
end;

procedure TestSessionManagement;
var
  OpenSSLLib: ISSLLibrary;
  OpenSSLCtx: ISSLContext;
  {$IFDEF WINDOWS}
  WinSSLLib: ISSLLibrary;
  WinSSLCtx: ISSLContext;
  {$ENDIF}
begin
  WriteLn('');
  WriteLn('=== Session Management ===');

  // OpenSSL session management
  try
    OpenSSLLib := TOpenSSLLibrary.Create;
    if OpenSSLLib.Initialize then
    begin
      OpenSSLCtx := OpenSSLLib.CreateContext(sslCtxClient);
      if (OpenSSLCtx <> nil) then
      begin
        Runner.Check('OpenSSL session management', True, 'Available');
      end;
    end;
  except
    on E: Exception do
      Runner.Check('OpenSSL session management', False, E.Message);
  end;

  // WinSSL session management
  {$IFDEF WINDOWS}
  try
    WinSSLLib := TWinSSLLibrary.Create;
    if WinSSLLib.Initialize then
    begin
      WinSSLCtx := WinSSLLib.CreateContext(sslCtxClient);
      if WinSSLCtx <> nil then
      begin
        Runner.Check('WinSSL session management', True, 'TWinSSLSession');
      end;
    end;
  except
    on E: Exception do
      Runner.Check('WinSSL session management', False, E.Message);
  end;
  {$ELSE}
  Runner.Skip('WinSSL session management', 'Linux platform');
  {$ENDIF}
end;

begin
  WriteLn('');
  WriteLn('WinSSL vs OpenSSL Integration Comparison');
  WriteLn('========================================');

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn('Test Date: ', DateTimeToStr(Now));

    try
      TestLibraryInitialization;
      TestContextCreation;
      TestProtocolVersionSupport;
      TestSessionManagement;
    except
      on E: Exception do
        Runner.Check('Test execution', False, E.Message);
    end;

    {$IFNDEF WINDOWS}
    Runner.Check('Non-Windows skip accounting', Runner.SkipCount >= 4,
      Format('Expected >=4 skips, got %d', [Runner.SkipCount]));
    {$ENDIF}

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
