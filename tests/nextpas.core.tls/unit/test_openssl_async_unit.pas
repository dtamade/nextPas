unit test_openssl_async_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  test_base,
  nextpas.core.tls.openssl.api.async;

type
  TTestOpenSSLAsync = class(TTestBase)
  private
    type
      TGetWaitCtxFn = function(job: PASYNC_JOB): PASYNC_WAIT_CTX; cdecl;
      TGetAllFdsFn = function(ctx: PASYNC_WAIT_CTX; var fd: OSSL_ASYNC_FD; var numfds: NativeUInt): Integer; cdecl;
  private
    FSavedGetWaitCtx: TGetWaitCtxFn;
    FSavedGetAllFds: TGetAllFdsFn;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWaitForAsyncJob_UnixPendingFD_ShouldReturnFalse;
    procedure TestWaitForAsyncJob_NoFds_ShouldReturnTrue;
  end;

implementation

var
  GStubWaitCtx: PASYNC_WAIT_CTX;
  GStubFD: OSSL_ASYNC_FD;
  GStubNumFds: NativeUInt;

function StubGetWaitCtx(job: PASYNC_JOB): PASYNC_WAIT_CTX; cdecl;
begin
  Result := GStubWaitCtx;
end;

function StubGetAllFds(ctx: PASYNC_WAIT_CTX; var fd: OSSL_ASYNC_FD; var numfds: NativeUInt): Integer; cdecl;
begin
  if numfds = 0 then
  begin
    Result := 0;
    Exit;
  end;

  fd := GStubFD;
  numfds := GStubNumFds;
  Result := 1;
end;

procedure TTestOpenSSLAsync.SetUp;
begin
  inherited SetUp;

  FSavedGetWaitCtx := ASYNC_get_wait_ctx;
  FSavedGetAllFds := ASYNC_WAIT_CTX_get_all_fds;

  ASYNC_get_wait_ctx := @StubGetWaitCtx;
  ASYNC_WAIT_CTX_get_all_fds := @StubGetAllFds;
end;

procedure TTestOpenSSLAsync.TearDown;
begin
  ASYNC_get_wait_ctx := FSavedGetWaitCtx;
  ASYNC_WAIT_CTX_get_all_fds := FSavedGetAllFds;

  inherited TearDown;
end;

procedure TTestOpenSSLAsync.TestWaitForAsyncJob_UnixPendingFD_ShouldReturnFalse;
var
  LResult: Boolean;
begin
  {$IFNDEF UNIX}
  Ignore('Unix-only test');
  Exit;
  {$ENDIF}

  GStubWaitCtx := PASYNC_WAIT_CTX(PtrUInt(2));
  GStubFD := OSSL_ASYNC_FD(42);
  GStubNumFds := 1;

  LResult := WaitForAsyncJob(PASYNC_JOB(PtrUInt(1)), 0);

  AssertFalse('Unix WaitForAsyncJob should not return true for pending fd without polling implementation',
    LResult);
end;


procedure TTestOpenSSLAsync.TestWaitForAsyncJob_NoFds_ShouldReturnTrue;
var
  LResult: Boolean;
begin
  GStubWaitCtx := PASYNC_WAIT_CTX(PtrUInt(2));
  GStubFD := OSSL_ASYNC_FD(0);
  GStubNumFds := 0;

  LResult := WaitForAsyncJob(PASYNC_JOB(PtrUInt(1)), 0);

  AssertTrue('WaitForAsyncJob should return true when wait context reports zero fds',
    LResult);
end;

initialization
  RegisterTest(TTestOpenSSLAsync);

end.
