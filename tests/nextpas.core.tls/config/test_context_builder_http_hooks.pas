program test_context_builder_http_hooks;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.openssl.backed; // ensure OpenSSL backend registration

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('❌ FAIL: ', AMessage);
    Halt(1);
  end;
  WriteLn('✅ PASS: ', AMessage);
end;

type
  TTestHooks = class
  public
    CalledGet: Boolean;
    CalledPost: Boolean;
    LastURL: string;
    LastContentType: string;
    LastTimeoutMs: Integer;
    function HTTPGet(const AURL: string; ATimeoutMs: Integer): TSSLDataResult;
    function HTTPPost(const AURL, AContentType: string; const ABody: TBytes;
      ATimeoutMs: Integer): TSSLDataResult;
  end;

function TTestHooks.HTTPGet(const AURL: string; ATimeoutMs: Integer): TSSLDataResult;
var
  LBytes: TBytes;
begin
  CalledGet := True;
  LastURL := AURL;
  LastTimeoutMs := ATimeoutMs;
  LBytes := TEncoding.UTF8.GetBytes('stub-get');
  Result := TSSLDataResult.Ok(LBytes);
end;

function TTestHooks.HTTPPost(const AURL, AContentType: string; const ABody: TBytes;
  ATimeoutMs: Integer): TSSLDataResult;
var
  LBytes: TBytes;
begin
  CalledPost := True;
  LastURL := AURL;
  LastContentType := AContentType;
  LastTimeoutMs := ATimeoutMs;
  LBytes := TEncoding.UTF8.GetBytes('stub-post');
  Result := TSSLDataResult.Ok(LBytes);
end;

procedure TestBuilderInjectsHTTPHooksIntoContext;
var
  LHooks: TTestHooks;
  LCtx: ISSLContext;
  LHttp: ISSLHttpHooksAccess;
  LGet: TSSLHTTPGetCallback;
  LPost: TSSLHTTPPostCallback;
  LRes: TSSLDataResult;
  LBody: TBytes;
begin
  WriteLn('--- Test: builder injects HTTP hooks into context (OpenSSL) ---');

  LHooks := TTestHooks.Create;
  try
    LCtx := TSSLContextBuilder.Create
      .WithBackend(sslOpenSSL)
      .WithHTTPHooks(@LHooks.HTTPGet, @LHooks.HTTPPost)
      .BuildClient;

    Check(LCtx <> nil, 'Context created');
    Check(Supports(LCtx, ISSLHttpHooksAccess, LHttp), 'Context supports ISSLHttpHooksAccess');
    LGet := LHttp.GetHTTPGetCallback;
    LPost := LHttp.GetHTTPPostCallback;
    Check(Assigned(LGet), 'HTTP GET callback is assigned');
    Check(Assigned(LPost), 'HTTP POST callback is assigned');

    LRes := LGet('https://example.test/get', 111);
    Check(LRes.Success, 'HTTP GET hook returns success');
    Check(LHooks.CalledGet, 'HTTP GET hook called');
    Check(LHooks.LastURL = 'https://example.test/get', 'HTTP GET URL forwarded');
    Check(LHooks.LastTimeoutMs = 111, 'HTTP GET timeout forwarded');

    SetLength(LBody, 1);
    LBody[0] := 7;
    LRes := LPost('https://example.test/post', 'application/test', LBody, 222);
    Check(LRes.Success, 'HTTP POST hook returns success');
    Check(LHooks.CalledPost, 'HTTP POST hook called');
    Check(LHooks.LastURL = 'https://example.test/post', 'HTTP POST URL forwarded');
    Check(LHooks.LastContentType = 'application/test', 'HTTP POST Content-Type forwarded');
    Check(LHooks.LastTimeoutMs = 222, 'HTTP POST timeout forwarded');
  finally
    LHooks.Free;
  end;
end;

begin
  try
    TestBuilderInjectsHTTPHooksIntoContext;
    WriteLn;
    WriteLn('All builder HTTP hooks tests passed.');
    Halt(0);
  except
    on E: Exception do
    begin
      WriteLn('❌ Unhandled exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
