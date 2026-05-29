program test_freepascal_context_server_name_inheritance;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  WithSNI / direct context ServerName compatibility on FreePascal. }

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

procedure Test_BuilderContextServerName_NotInheritedBySocketConnection;
var
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
begin
  TestHeader('Builder context server name is not inherited by socket connection');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithTLS13
    .WithSNI('ctx.example.com')
    .BuildClient;
  {$POP}

  Conn := Ctx.CreateConnection(THandle(-1));
  ClientConn := Conn as ISSLClientConnection;

  Assert(ClientConn.GetServerName = '',
    'Socket connection no longer inherits context server name from builder');
end;

procedure Test_DirectContextServerName_NotInheritedByStreamConnection;
var
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Stream: TMemoryStream;
begin
  TestHeader('Direct context server name is not inherited by stream connection');

  Ctx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx.SetServerName('stream.example.com');
  {$POP}

  Stream := TMemoryStream.Create;
  try
    Conn := Ctx.CreateConnection(Stream);
    ClientConn := Conn as ISSLClientConnection;

    Assert(ClientConn.GetServerName = '',
      'Stream connection no longer inherits context server name from direct context API');

    ClientConn := nil;
    Conn := nil;
  finally
    Stream.Free;
  end;
end;

begin
  try
    Test_BuilderContextServerName_NotInheritedBySocketConnection;
    Test_DirectContextServerName_NotInheritedByStreamConnection;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.Message);
      Halt(1);
    end;
  end;
end.
