program test_poller_windows_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

function ExtractBetween(const ASource, AStartToken, AEndToken: string): string;
var
  LStartPos, LEndPos: SizeInt;
begin
  LStartPos := Pos(AStartToken, ASource);
  Check(LStartPos > 0, 'source range start should exist: ' + AStartToken);
  LEndPos := Pos(AEndToken, Copy(ASource, LStartPos + Length(AStartToken),
    Length(ASource)));
  Check(LEndPos > 0, 'source range end should exist: ' + AEndToken);
  Result := Copy(ASource, LStartPos, Length(AStartToken) + LEndPos - 1);
end;

procedure TestPollerWindowsBackendContract;
var
  LPoller: string;
begin
  LPoller := LoadSourceText('src/nextpas.core.io.poller.pas');

  CheckContains(LPoller, 'nextpas.core.io.reactor.iocp',
    'poller must consume the Windows IOCP reactor on Windows');
  CheckContains(LPoller, 'pbiocp',
    'poller backend enum must expose a Windows IOCP backend');
  CheckContains(LPoller, 'fiocp',
    'poller state must carry an IOCP reactor only for Windows');
  CheckContains(LPoller, '{$ifdef nextpas_windows}',
    'poller must select Windows dependencies behind a host branch');
  CheckContains(LPoller, 'pbiocp: result.fiocp := tiocpreactor.create',
    'poller create must instantiate the IOCP backend on Windows');
  CheckContains(LPoller, 'pbiocp: fiocp.close',
    'poller close must release the IOCP backend');
  CheckContains(LPoller, 'pbiocp: result := fiocp.isvalid',
    'poller validity must delegate to the IOCP backend');
  CheckContains(LPoller, 'pbiocp: result := fiocp.poll',
    'poller poll must delegate to the IOCP backend');
  CheckContains(LPoller, 'pbunsupported',
    'poller must report explicit unsupported semantics for unpromoted hosts');
end;

procedure TestIocpLifecycleContract;
var
  LIocp: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');

  CheckContains(LIocp, 'createiocompletionport',
    'IOCP reactor create must allocate a completion port');
  CheckContains(LIocp, 'closehandle(handle(fport))',
    'IOCP reactor close must release the completion port handle');
  CheckContains(LIocp, 'getqueuedcompletionstatus',
    'IOCP reactor poll must consume completion port events');
  CheckContains(LIocp, 'postqueuedcompletionstatus',
    'IOCP reactor stop must wake the completion port');
  CheckContains(LIocp, 'error_not_supported',
    'unimplemented async operations must return explicit unsupported truth');
  CheckAbsent(LIocp, '{ stub }',
    'IOCP reactor run must not remain a stub body');
end;

procedure TestIocpSynchronousFailureOwnershipContract;
var
  LIocp: string;
  LFailBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LFailBody := ExtractBetween(LIocp, 'function iocpfail',
    'function iocpunsupportedasync');

  CheckContains(LFailBody, 'acallback(auserdata, -int32(aerror), acontext);',
    'IOCP synchronous failure helper must deliver the callback inline');
  CheckContains(LFailBody, 'result := true;',
    'IOCP synchronous failure helper must report callback ownership transfer');
end;

procedure TestIocpUnsupportedAsyncOwnershipContract;
var
  LIocp: string;
  LAsyncLoop: string;
  LUnsupportedBody: string;
  LAcceptBody: string;
  LConnectBody: string;
  LSendBody: string;
  LRecvBody: string;
  LCloseBody: string;
  LRecvTimeoutBody: string;
  LSendTimeoutBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LUnsupportedBody := ExtractBetween(LIocp, 'function iocpunsupportedasync',
    'function iocpallocop');
  LAcceptBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncaccept',
    'function tiocpreactor.asyncconnect');
  LConnectBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncconnect',
    'function tiocpreactor.asyncsend');
  LSendBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncsend',
    'function tiocpreactor.asyncrecv');
  LRecvBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncrecv',
    'function tiocpreactor.asyncclose');
  LCloseBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncclose',
    'function tiocpreactor.poll');
  LRecvTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncrecvtimeout',
    'function tasyncloop.asyncsendtimeout');
  LSendTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncsendtimeout',
    'end.');

  CheckContains(LUnsupportedBody, 'result := false;',
    'IOCP unsupported helper must reject ownership transfer');
  CheckContains(LUnsupportedBody, 'setlasterror(error_not_supported);',
    'IOCP unsupported helper must preserve explicit unsupported truth');
  CheckAbsent(LUnsupportedBody, 'iocpfail(',
    'IOCP unsupported helper must not reuse synchronous failure ownership semantics');
  CheckAbsent(LUnsupportedBody, 'acallback(',
    'IOCP unsupported helper must not dispatch inline completion callbacks');
  CheckContains(LAcceptBody, 'result := iocpunsupportedasync(acallback, acontext);',
    'AsyncAccept must reject unsupported IOCP ownership through the helper');
  CheckContains(LConnectBody, 'result := iocpunsupportedasync(acallback, acontext);',
    'AsyncConnect must reject unsupported IOCP ownership through the helper');
  CheckContains(LSendBody, 'result := iocpunsupportedasync(acallback, acontext);',
    'AsyncSend must reject unsupported IOCP ownership through the helper');
  CheckContains(LRecvBody, 'result := iocpunsupportedasync(acallback, acontext);',
    'AsyncRecv must reject unsupported IOCP ownership through the helper');
  CheckContains(LCloseBody, 'result := iocpunsupportedasync(acallback, acontext);',
    'AsyncClose must reject unsupported IOCP ownership through the helper');
  CheckContains(LRecvTimeoutBody, 'if not result then',
    'async recv timeout wrapper must reclaim timeout context only on rejected submission');
  CheckContains(LRecvTimeoutBody, 'dispose(lctx);',
    'async recv timeout wrapper must still reclaim context when submission is rejected');
  CheckContains(LSendTimeoutBody, 'if not result then',
    'async send timeout wrapper must reclaim timeout context only on rejected submission');
  CheckContains(LSendTimeoutBody, 'dispose(lctx);',
    'async send timeout wrapper must still reclaim context when submission is rejected');
end;

procedure TestIocpPendingOperationOwnershipContract;
var
  LIocp, LReadBody, LWriteBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LReadBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncread',
    'function tiocpreactor.asyncwrite');
  LWriteBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncwrite',
    'function tiocpreactor.asyncaccept');

  CheckContains(LIocp, 'tiocppendingop = record',
    'IOCP reactor must define a pending operation record');
  CheckContains(LIocp, 'overlapped: overlapped',
    'pending operation must own OVERLAPPED storage');
  CheckContains(LIocp, 'callback: tiocompletion',
    'pending operation must retain callback ownership until dispatch');
  CheckContains(LIocp, 'context: pointer',
    'pending operation must retain callback context until dispatch');
  CheckContains(LIocp, 'next: piocppendingop',
    'pending operation records must be trackable by the reactor');
  CheckContains(LIocp, 'fpendinghead',
    'reactor state must track pending IOCP operations');
  CheckContains(LIocp, 'iocpallocop',
    'IOCP reactor must allocate operation records before submission');
  CheckContains(LIocp, 'iocpfreeop',
    'IOCP reactor must free operation records after completion');
  CheckContains(LIocp, 'iocpdispatchcompletion',
    'IOCP reactor must dispatch completion packets to callbacks');
  CheckContains(LIocp, 'readfile(lhandle',
    'AsyncRead must submit Windows overlapped ReadFile operations');
  CheckContains(LIocp, 'writefile(lhandle',
    'AsyncWrite must submit Windows overlapped WriteFile operations');
  CheckContains(LIocp, 'error_io_pending',
    'AsyncRead/AsyncWrite must treat ERROR_IO_PENDING as queued work');
  CheckContains(LIocp, 'getlasterror',
    'IOCP dispatch must surface Windows completion errors');
  CheckAbsent(LReadBody, 'iocpunsupportedasync',
    'AsyncRead must not remain a generic unsupported stub');
  CheckAbsent(LWriteBody, 'iocpunsupportedasync',
    'AsyncWrite must not remain a generic unsupported stub');
end;

procedure TestPollerWindowsHandleWidthContract;
var
  LIocp, LPoller, LAsyncLoop: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LPoller := LoadSourceText('src/nextpas.core.io.poller.pas');
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');

  CheckContains(LIocp, 'function asyncread(afd: ptrint',
    'IOCP reactor read entry must accept pointer-sized Windows handles');
  CheckContains(LIocp, 'function asyncwrite(afd: ptrint',
    'IOCP reactor write entry must accept pointer-sized Windows handles');
  CheckContains(LPoller, 'function asyncread(afd: ptrint',
    'poller read facade must preserve pointer-sized Windows handles');
  CheckContains(LPoller, 'function asyncwrite(afd: ptrint',
    'poller write facade must preserve pointer-sized Windows handles');
  CheckContains(LAsyncLoop, 'function asyncread(afd: ptrint',
    'async loop read facade must preserve pointer-sized Windows handles');
  CheckContains(LAsyncLoop, 'function asyncwrite(afd: ptrint',
    'async loop write facade must preserve pointer-sized Windows handles');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.poller.windows_contract');
  T.Run('poller Windows backend contract', @TestPollerWindowsBackendContract);
  T.Run('IOCP lifecycle contract', @TestIocpLifecycleContract);
  T.Run('IOCP synchronous failure ownership contract',
    @TestIocpSynchronousFailureOwnershipContract);
  T.Run('IOCP unsupported async ownership contract',
    @TestIocpUnsupportedAsyncOwnershipContract);
  T.Run('IOCP pending operation ownership contract',
    @TestIocpPendingOperationOwnershipContract);
  T.Run('Windows handle width contract', @TestPollerWindowsHandleWidthContract);
  T.Summary;
end.
