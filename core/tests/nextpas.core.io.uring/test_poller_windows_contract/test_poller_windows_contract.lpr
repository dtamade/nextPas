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

procedure CheckBefore(const ASource, AFirstToken, ASecondToken,
  AMessage: string);
var
  LFirstPos, LSecondPos: SizeInt;
begin
  LFirstPos := Pos(AFirstToken, ASource);
  LSecondPos := Pos(ASecondToken, ASource);
  Check(LFirstPos > 0, AMessage + ' first token should exist: ' + AFirstToken);
  Check(LSecondPos > 0, AMessage + ' second token should exist: ' + ASecondToken);
  Check(LFirstPos < LSecondPos, AMessage + ': ' + AFirstToken + ' before ' +
    ASecondToken);
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
  CheckContains(LPoller, 'pbiocp: result := fiocp.pollone',
    'poller poll-one must delegate to the IOCP backend');
  CheckContains(LPoller, 'pbiocp: fiocp.run',
    'poller run must delegate to the IOCP backend');
  CheckContains(LPoller, 'pbiocp: fiocp.stop',
    'poller stop must delegate to the IOCP backend');
  CheckContains(LPoller, 'pbiocp: result := fiocp.flush',
    'poller flush must delegate to the IOCP backend');
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

procedure TestIocpRunStopFlushLifecycleContract;
var
  LIocp: string;
  LPollBody: string;
  LPollOneBody: string;
  LRunBody: string;
  LStopBody: string;
  LFlushBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LPollBody := ExtractBetween(LIocp, 'function tiocpreactor.poll',
    'function tiocpreactor.pollone');
  LPollOneBody := ExtractBetween(LIocp, 'function tiocpreactor.pollone',
    'procedure tiocpreactor.run');
  LRunBody := ExtractBetween(LIocp, 'procedure tiocpreactor.run',
    'procedure tiocpreactor.stop');
  LStopBody := ExtractBetween(LIocp, 'procedure tiocpreactor.stop',
    'function tiocpreactor.flush');
  LFlushBody := ExtractBetween(LIocp, 'function tiocpreactor.flush',
    'end.');

  CheckContains(LPollBody, 'while pollone do',
    'IOCP Poll must drain immediately available completion packets');
  CheckContains(LPollOneBody, 'getqueuedcompletionstatus(handle(fport), @lbytes, @lkey',
    'IOCP PollOne must consume at most one completion packet');
  CheckContains(LPollOneBody, '@loverlapped, 0)',
    'IOCP PollOne must use nonblocking zero-timeout completion polling');
  CheckContains(LPollOneBody, 'iocpdispatchcompletion(self, lbytes, lok, loverlapped)',
    'IOCP PollOne must dispatch real overlapped completions');
  CheckContains(LRunBody, 'atomicstore32(frunning, 1, morelease);',
    'IOCP Run must publish running state before blocking');
  CheckContains(LRunBody, 'getqueuedcompletionstatus(handle(fport), @lbytes, @lkey',
    'IOCP Run must block on the completion port');
  CheckContains(LRunBody, '@loverlapped, infinite)',
    'IOCP Run must use the blocking completion wait');
  CheckContains(LRunBody, 'finally',
    'IOCP Run must clear running state when it returns');
  CheckContains(LRunBody, 'atomicstore32(frunning, 0, morelease);',
    'IOCP Run must leave running state cleared on every exit path');
  CheckContains(LStopBody, 'atomicstore32(frunning, 0, morelease);',
    'IOCP Stop must publish stopped state');
  CheckContains(LStopBody, 'postqueuedcompletionstatus(handle(fport), 0, 0, nil)',
    'IOCP Stop must wake the blocking completion wait with a control packet');
  CheckContains(LFlushBody, 'result := 0;',
    'IOCP Flush must be explicit no-batch truth because file ops submit immediately');
  CheckAbsent(LFlushBody, 'iocpunsupportedasync',
    'IOCP Flush must not be reported as an unsupported operation');
end;

procedure TestAsyncLoopRunLifecycleContract;
var
  LAsyncLoop: string;
  LRunBody: string;
  LStopBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LRunBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.run',
    'procedure tasyncloop.runonce');
  LStopBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.stop',
    'function tasyncloop.asyncsleep');

  CheckContains(LRunBody, 'atomicstore32(frunning, 1, morelease);',
    'async loop run must publish running state before entering the event loop');
  CheckContains(LRunBody, 'drainwake;',
    'async loop run must continue to drain the platform wake seam');
  CheckContains(LRunBody, 'drainpending;',
    'async loop run must continue to drain pending callbacks');
  CheckContains(LRunBody, 'fpoller.flush;',
    'async loop run must flush the poller before nonblocking completion polling');
  CheckContains(LRunBody, 'lio := fpoller.poll;',
    'async loop run must poll completion work through the poller facade');
  CheckContains(LRunBody, 'waitforwake(ltimeoutms);',
    'async loop run must block only through the platform wake seam');
  CheckContains(LRunBody, 'finally',
    'async loop run must clear running state when it returns');
  CheckContains(LRunBody, 'atomicstore32(frunning, 0, morelease);',
    'async loop run must leave running state cleared on every exit path');
  CheckContains(LStopBody, 'atomicstore32(frunning, 0, morelease);',
    'async loop stop must publish stopped state');
end;

procedure TestIocpCloseAbortOwnershipContract;
var
  LIocp: string;
  LCloseBody: string;
  LReleaseBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LReleaseBody := ExtractBetween(LIocp, 'procedure iocpreleasependingops',
    'function iocphasassociatedhandle');
  LCloseBody := ExtractBetween(LIocp, 'procedure tiocpreactor.close',
    'function tiocpreactor.isvalid');

  CheckContains(LCloseBody, 'iocpreleasependingops(self, error_operation_aborted);',
    'IOCP Close must abort owned pending file operations');
  CheckBefore(LCloseBody, 'iocpreleasependingops(self, error_operation_aborted);',
    'iocpreleaseassociatedhandles(self);',
    'IOCP Close must abort pending operations before releasing handle associations');
  CheckBefore(LCloseBody, 'iocpreleasependingops(self, error_operation_aborted);',
    'closehandle(handle(fport))',
    'IOCP Close must dispatch abort callbacks before closing the port handle');
  CheckContains(LReleaseBody, 'areactor.fpendinghead := nil;',
    'IOCP pending release must detach the owned list before callbacks');
  CheckContains(LReleaseBody, 'areactor.fpendingcount := 0;',
    'IOCP pending release must clear the pending count before callbacks');
  CheckContains(LReleaseBody, 'cancelioex(lop^.handle, @lop^.overlapped);',
    'IOCP pending release must cancel each overlapped operation');
  CheckContains(LReleaseBody,
    'lop^.callback(lop^.userdata, -int32(aerror), lop^.context);',
    'IOCP pending release must deliver the abort result to the owned callback');
  CheckContains(LReleaseBody, 'dispose(lop);',
    'IOCP pending release must free every owned operation');
end;

procedure TestAsyncLoopTimeoutCloseLifecycleContract;
var
  LAsyncLoop: string;
  LCloseBody: string;
  LTimeoutIoBody: string;
  LTimeoutIoAfterTimerBody: string;
  LTimerFiredIoBody: string;
  LTimeoutTimerBody: string;
  LIoCompletedTimerBody: string;
  LReadTimeoutBody: string;
  LWriteTimeoutBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LCloseBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.close',
    'function tasyncloop.isvalid');
  LTimeoutIoBody := ExtractBetween(LAsyncLoop, 'procedure timeoutiocallback',
    'procedure timeouttimercallback');
  LTimeoutIoAfterTimerBody := ExtractBetween(LTimeoutIoBody,
    'lctx^.iocompleted := true;', 'end;');
  LTimerFiredIoBody := ExtractBetween(LTimeoutIoBody,
    'if lctx^.timerfired then', 'lctx^.iocompleted := true;');
  LTimeoutTimerBody := ExtractBetween(LAsyncLoop, 'procedure timeouttimercallback',
    '{ tasyncloop }');
  LIoCompletedTimerBody := ExtractBetween(LTimeoutTimerBody,
    'if lctx^.iocompleted then', 'lctx^.timerfired := true;');
  LReadTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncreadtimeout',
    'function tasyncloop.asyncwritetimeout');
  LWriteTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncwritetimeout',
    'function tasyncloop.asyncrecvtimeout');

  CheckBefore(LCloseBody, 'fpoller.close;', 'ftimers.clear;',
    'async loop close must keep timers alive while poller close aborts I/O');
  CheckBefore(LCloseBody, 'fpoller.close;', 'platform_mutex_destroy(fpendinglock);',
    'async loop close must keep pending callback lock alive while poller close aborts I/O');
  CheckBefore(LCloseBody, 'fpoller.close;', 'platform_poller_close(fwakepoller);',
    'async loop close must keep wake resources alive while abort callbacks can re-enter');

  CheckContains(LTimerFiredIoBody, 'dispose(lctx);',
    'timeout IO callback must free context when timer already fired');
  CheckContains(LTimerFiredIoBody, 'exit;',
    'timeout IO callback must stop after timer-fired cleanup');
  CheckAbsent(LTimerFiredIoBody, 'usercallback',
    'timeout IO callback must not notify user twice after timer fired');
  CheckBefore(LTimeoutIoAfterTimerBody, 'ftimers.cancel(lctx^.timerhandle);',
    'lctx^.usercallback(auserdata, aresult, lctx^.usercontext);',
    'timeout IO callback must cancel timer before forwarding user callback');
  CheckBefore(LTimeoutIoAfterTimerBody,
    'lctx^.usercallback(auserdata, aresult, lctx^.usercontext);',
    'dispose(lctx);',
    'timeout IO callback must release context after forwarding user callback');

  CheckContains(LIoCompletedTimerBody, 'dispose(lctx);',
    'timeout timer callback must free context when I/O already completed');
  CheckContains(LIoCompletedTimerBody, 'exit;',
    'timeout timer callback must stop after I/O-completed cleanup');
  CheckAbsent(LIoCompletedTimerBody, 'usercallback',
    'timeout timer callback must not notify user twice after I/O completed');
  CheckContains(LTimeoutTimerBody,
    'lctx^.usercallback(0, -etimedout_linux, lctx^.usercontext);',
    'timeout timer callback must deliver exactly one timeout result');

  CheckContains(LReadTimeoutBody, '@timeoutiocallback',
    'async read timeout must submit the owned timeout callback to poller');
  CheckContains(LReadTimeoutBody, 'if not result then',
    'async read timeout must reclaim context only on rejected submission');
  CheckContains(LWriteTimeoutBody, '@timeoutiocallback',
    'async write timeout must submit the owned timeout callback to poller');
  CheckContains(LWriteTimeoutBody, 'if not result then',
    'async write timeout must reclaim context only on rejected submission');
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
  T.Run('IOCP run/stop/flush lifecycle contract',
    @TestIocpRunStopFlushLifecycleContract);
  T.Run('async loop run lifecycle contract',
    @TestAsyncLoopRunLifecycleContract);
  T.Run('IOCP close abort ownership contract',
    @TestIocpCloseAbortOwnershipContract);
  T.Run('async loop timeout close lifecycle contract',
    @TestAsyncLoopTimeoutCloseLifecycleContract);
  T.Run('IOCP synchronous failure ownership contract',
    @TestIocpSynchronousFailureOwnershipContract);
  T.Run('IOCP unsupported async ownership contract',
    @TestIocpUnsupportedAsyncOwnershipContract);
  T.Run('IOCP pending operation ownership contract',
    @TestIocpPendingOperationOwnershipContract);
  T.Run('Windows handle width contract', @TestPollerWindowsHandleWidthContract);
  T.Summary;
end.
