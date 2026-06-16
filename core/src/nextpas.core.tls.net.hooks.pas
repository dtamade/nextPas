unit nextpas.core.tls.net.hooks;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

{
  HTTP transport hooks (no networking implementation).

  This unit provides thread-local HTTP hooks used by modules that need HTTP
  (e.g. OCSP online checks, CT log list download). The actual network stack
  must be implemented by the caller/framework.
}

interface

uses
  nextpas.core.base,
  nextpas.core.tls.base;

type
  { Thread-local HTTP hooks bundle }
  TSSLHTTPHooks = record
    HTTPGet: TSSLHTTPGetCallback;
    HTTPPost: TSSLHTTPPostCallback;

    class function Empty: TSSLHTTPHooks; static;
    class function Create(AHTTPGet: TSSLHTTPGetCallback;
      AHTTPPost: TSSLHTTPPostCallback): TSSLHTTPHooks; static;
    function IsEmpty: Boolean;
  end;

  { Scope helper: push hooks and restore previous on Pop/finalization }
  TSSLHTTPHooksScope = record
  private
    FPrev: TSSLHTTPHooks;
    FActive: Boolean;
  public
    class function Push(const AHooks: TSSLHTTPHooks): TSSLHTTPHooksScope; static;
    procedure Pop;

    class operator Initialize(var ARecord: TSSLHTTPHooksScope);
    class operator Finalize(var ARecord: TSSLHTTPHooksScope);
  end;

function SSLGetThreadHTTPHooks: TSSLHTTPHooks;
procedure SSLSetThreadHTTPHooks(const AHooks: TSSLHTTPHooks);

function SSLHTTPGet(const AURL: string; ATimeoutMs: Integer = 10000): TSSLDataResult;
function SSLHTTPPost(const AURL, AContentType: string; const ABody: TBytes;
  ATimeoutMs: Integer = 10000): TSSLDataResult;

implementation

threadvar
  GThreadHTTPHooks: TSSLHTTPHooks;

class function TSSLHTTPHooks.Empty: TSSLHTTPHooks;
begin
  Result.HTTPGet := nil;
  Result.HTTPPost := nil;
end;

class function TSSLHTTPHooks.Create(AHTTPGet: TSSLHTTPGetCallback;
  AHTTPPost: TSSLHTTPPostCallback): TSSLHTTPHooks;
begin
  Result.HTTPGet := AHTTPGet;
  Result.HTTPPost := AHTTPPost;
end;

function TSSLHTTPHooks.IsEmpty: Boolean;
begin
  Result := (not Assigned(HTTPGet)) and (not Assigned(HTTPPost));
end;

class operator TSSLHTTPHooksScope.Initialize(var ARecord: TSSLHTTPHooksScope);
begin
  ARecord.FPrev := TSSLHTTPHooks.Empty;
  ARecord.FActive := False;
end;

class operator TSSLHTTPHooksScope.Finalize(var ARecord: TSSLHTTPHooksScope);
begin
  ARecord.Pop;
end;

class function TSSLHTTPHooksScope.Push(const AHooks: TSSLHTTPHooks): TSSLHTTPHooksScope;
begin
  Result.FPrev := SSLGetThreadHTTPHooks;
  Result.FActive := True;
  SSLSetThreadHTTPHooks(AHooks);
end;

procedure TSSLHTTPHooksScope.Pop;
begin
  if not FActive then
    Exit;

  SSLSetThreadHTTPHooks(FPrev);
  FActive := False;
end;

function SSLGetThreadHTTPHooks: TSSLHTTPHooks;
begin
  Result := GThreadHTTPHooks;
end;

procedure SSLSetThreadHTTPHooks(const AHooks: TSSLHTTPHooks);
begin
  GThreadHTTPHooks := AHooks;
end;

function SSLHTTPGet(const AURL: string; ATimeoutMs: Integer): TSSLDataResult;
var
  LHooks: TSSLHTTPHooks;
begin
  LHooks := SSLGetThreadHTTPHooks;
  if not Assigned(LHooks.HTTPGet) then
    Exit(TSSLDataResult.Err(sslErrUnsupported, 'HTTP GET hooks not provided'));

  Result := LHooks.HTTPGet(AURL, ATimeoutMs);
end;

function SSLHTTPPost(const AURL, AContentType: string; const ABody: TBytes;
  ATimeoutMs: Integer): TSSLDataResult;
var
  LHooks: TSSLHTTPHooks;
begin
  LHooks := SSLGetThreadHTTPHooks;
  if not Assigned(LHooks.HTTPPost) then
    Exit(TSSLDataResult.Err(sslErrUnsupported, 'HTTP POST hooks not provided'));

  Result := LHooks.HTTPPost(AURL, AContentType, ABody, ATimeoutMs);
end;

initialization
  GThreadHTTPHooks := TSSLHTTPHooks.Empty;

end.
