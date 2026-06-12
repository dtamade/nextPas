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

procedure CheckSequence(const ASource, AMessage: string;
  const ATokens: array of string);
var
  LIndex: SizeInt;
  LOffset: SizeInt;
  LFoundPos: SizeInt;
  LWindow: string;
begin
  LOffset := 1;
  for LIndex := Low(ATokens) to High(ATokens) do
  begin
    LWindow := Copy(ASource, LOffset, Length(ASource));
    LFoundPos := Pos(ATokens[LIndex], LWindow);
    Check(LFoundPos > 0, AMessage + ' token should exist in order: ' +
      ATokens[LIndex]);
    Inc(LOffset, LFoundPos + Length(ATokens[LIndex]) - 1);
  end;
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
  LCreateBody: string;
  LIocpBranch: string;
begin
  LPoller := LoadSourceText('src/nextpas.core.io.poller.pas');
  LCreateBody := ExtractBetween(LPoller, 'class function tpoller.create',
    'procedure tpoller.close');
  LIocpBranch := ExtractBetween(LCreateBody, 'pbiocp:', '{$endif}');

  CheckContains(LPoller, 'nextpas.core.io.reactor.iocp',
    'poller must consume the Windows IOCP reactor on Windows');
  CheckContains(LPoller, 'pbiocp',
    'poller backend enum must expose a Windows IOCP backend');
  CheckContains(LPoller, 'fiocp',
    'poller state must carry an IOCP reactor only for Windows');
  CheckContains(LPoller, '{$ifdef nextpas_windows}',
    'poller must select Windows dependencies behind a host branch');
  CheckContains(LIocpBranch, 'result.fiocp := tiocpreactor.create',
    'poller create must instantiate the IOCP backend on Windows');
  CheckContains(LIocpBranch, 'if not result.fiocp.isvalid then',
    'poller create must validate direct IOCP backend creation');
  CheckContains(LIocpBranch, 'result.fbackend := pbunsupported;',
    'poller create must stop reporting direct IOCP when IOCP create fails');
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
  CheckContains(LPoller, 'function pollersupportspositionedfileio',
    'poller must expose positioned file I/O capability truth');
  CheckContains(LPoller, 'pbiocp: result := true',
    'poller must advertise IOCP positioned file I/O capability');
  CheckContains(LPoller, 'pbepoll: result := false',
    'poller must keep epoll readiness fallback out of positioned file I/O capability');
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
  CheckContains(LIocp, 'closehandle(handle(lport))',
    'IOCP reactor close must release the retained completion port handle');
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
  LRunOnceBody: string;
  LStopBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LRunBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.run',
    'procedure tasyncloop.runonce');
  LRunOnceBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.runonce',
    'procedure tasyncloop.stop');
  LStopBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.stop',
    'function tasyncloop.asyncsleep');

  CheckContains(LAsyncLoop, 'function asyncidlewaketimeoutms(const apoller: tpoller;',
    'async loop must centralize idle wake timeout policy');
  CheckContains(LAsyncLoop, 'apoller.haspending',
    'async loop idle timeout policy must observe pending I/O truth');
  CheckContains(LAsyncLoop, 'async_pending_io_idle_poll_ms',
    'async loop must bound wake-only waits while completion work is pending');
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
  CheckContains(LRunBody, 'waitforwake(asyncidlewaketimeoutms(fpoller, lnext));',
    'async loop run must block through the platform wake seam with pending-I/O bounded idle waits');
  CheckContains(LRunOnceBody, 'waitforwake(asyncidlewaketimeoutms(fpoller, lnext));',
    'async loop run-once must use the same pending-I/O bounded wake timeout policy');
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
  CheckContains(LCloseBody, 'try',
    'IOCP Close must protect handle cleanup when abort callbacks raise');
  CheckContains(LCloseBody, 'finally',
    'IOCP Close must always release handles and port state after abort dispatch');
  CheckContains(LCloseBody, 'lport := fport;',
    'IOCP Close must retain the native port handle before closing submission');
  CheckBefore(LCloseBody, 'lport := fport;', 'fport := 0;',
    'IOCP Close must copy the port handle before marking the reactor closed');
  CheckBefore(LCloseBody, 'fport := 0;',
    'iocpreleasependingops(self, error_operation_aborted);',
    'IOCP Close must close the submit path before abort callbacks can re-enter');
  CheckBefore(LCloseBody, 'fmaxevents := 0;',
    'iocpreleasependingops(self, error_operation_aborted);',
    'IOCP Close must clear submit sizing state before abort callbacks can re-enter');
  CheckBefore(LCloseBody, 'iocpreleasependingops(self, error_operation_aborted);',
    'finally',
    'IOCP Close must dispatch abort callbacks before mandatory cleanup');
  CheckBefore(LCloseBody, 'finally',
    'iocpreleaseassociatedhandles(self);',
    'IOCP Close must release handle associations in the protected cleanup path');
  CheckBefore(LCloseBody, 'finally',
    'closehandle(handle(lport))',
    'IOCP Close must close the port handle in the protected cleanup path');
  CheckContains(LCloseBody, 'if lport <> 0 then',
    'IOCP Close must close the retained native port handle, not the closed-state field');
  CheckContains(LReleaseBody, 'areactor.fpendinghead := nil;',
    'IOCP pending release must detach the owned list before callbacks');
  CheckContains(LReleaseBody, 'areactor.fpendingcount := 0;',
    'IOCP pending release must clear the pending count before callbacks');
  CheckContains(LReleaseBody, 'cancelioex(lop^.handle, @lop^.overlapped);',
    'IOCP pending release must cancel each overlapped operation');
  CheckContains(LReleaseBody, 'case lop^.kind of',
    'IOCP pending release must branch by operation kind before waiting');
  CheckContains(LReleaseBody, 'opsend, oprecv:',
    'IOCP pending release must treat socket send/recv as socket operations');
  CheckContains(LReleaseBody, 'lflags := lop^.socketflags;',
    'IOCP pending release must preserve socket flags while waiting for socket completion');
  CheckContains(LReleaseBody,
    'wsagetoverlappedresult(tsocket(ptruint(lop^.handle)), @lop^.overlapped, @ldone, true, @lflags);',
    'IOCP pending release must wait for socket overlapped operations with WSAGetOverlappedResult');
  CheckContains(LReleaseBody,
    'getoverlappedresult(lop^.handle, @lop^.overlapped, @ldone, true);',
    'IOCP pending release must keep file operations on GetOverlappedResult');
  CheckBefore(LReleaseBody, 'cancelioex(lop^.handle, @lop^.overlapped);',
    'case lop^.kind of',
    'IOCP pending release must request cancellation before waiting for completion');
  CheckBefore(LReleaseBody,
    'case lop^.kind of',
    'lcallback := lop^.callback;',
    'IOCP pending release must settle OS overlapped ownership before callback dispatch');
  CheckContains(LReleaseBody, 'lcallback := lop^.callback;',
    'IOCP pending release must copy callback ownership before clearing the op');
  CheckContains(LReleaseBody, 'lcontext := lop^.context;',
    'IOCP pending release must copy callback context before clearing the op');
  CheckContains(LReleaseBody, 'luserdata := lop^.userdata;',
    'IOCP pending release must copy callback user data before clearing the op');
  CheckContains(LReleaseBody, 'try',
    'IOCP pending release must catch callback exceptions inside the batch');
  CheckContains(LReleaseBody, 'except',
    'IOCP pending release must preserve batch progress when a callback raises');
  CheckContains(LReleaseBody, 'finally',
    'IOCP pending release must free operation storage when callback dispatch raises');
  CheckContains(LReleaseBody, 'lhasexception',
    'IOCP pending release must remember whether any callback raised');
  CheckContains(LReleaseBody, 'lexceptionmessage',
    'IOCP pending release must retain the first callback exception message');
  CheckContains(LReleaseBody, 'if not lhasexception then',
    'IOCP pending release must retain the first callback exception');
  CheckContains(LReleaseBody,
    'lcallback(luserdata, -int32(aerror), lcontext);',
    'IOCP pending release must deliver the abort result to the owned callback');
  CheckContains(LReleaseBody, 'raise exception.create(lexceptionmessage);',
    'IOCP pending release must re-raise the first callback exception after the batch');
  CheckBefore(LReleaseBody,
    'case lop^.kind of',
    'dispose(lop);',
    'IOCP pending release must not free OVERLAPPED storage before completion settles');
  CheckContains(LReleaseBody, 'lop^.callback := nil;',
    'IOCP pending release must clear callback ownership before freeing the op');
  CheckContains(LReleaseBody, 'lop^.context := nil;',
    'IOCP pending release must clear callback context before freeing the op');
  CheckContains(LReleaseBody, 'lop^.next := nil;',
    'IOCP pending release must unlink op storage before freeing it');
  CheckContains(LReleaseBody, 'dispose(lop);',
    'IOCP pending release must free every owned operation');
end;

procedure TestAsyncLoopTimeoutCloseLifecycleContract;
var
  LAsyncLoop: string;
  LCloseBody: string;
  LTimeoutIoBody: string;
  LTimeoutTimerBody: string;
  LReadTimeoutBody: string;
  LWriteTimeoutBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LCloseBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.close',
    'function tasyncloop.isvalid');
  LTimeoutIoBody := ExtractBetween(LAsyncLoop, 'procedure timeoutiocallback',
    'procedure timeouttimercallback');
  LTimeoutTimerBody := ExtractBetween(LAsyncLoop, 'procedure timeouttimercallback',
    '{ tasyncloop }');
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

  CheckContains(LTimeoutIoBody, 'try',
    'timeout IO callback must protect cleanup on callback exceptions');
  CheckContains(LTimeoutIoBody, 'finally',
    'timeout IO callback must release ownership on every exit path');
  CheckContains(LTimeoutIoBody, 'timeoutctxrelease(lctx);',
    'timeout IO callback must release the I/O owner reference');
  CheckContains(LTimeoutTimerBody, 'try',
    'timeout timer callback must protect cleanup on callback exceptions');
  CheckContains(LTimeoutTimerBody, 'finally',
    'timeout timer callback must release ownership on every exit path');
  CheckContains(LTimeoutTimerBody, 'timeoutctxrelease(lctx);',
    'timeout timer callback must release the timer owner reference');

  CheckContains(LReadTimeoutBody, '@timeoutiocallback',
    'async read timeout must submit the owned timeout callback to poller');
  CheckContains(LReadTimeoutBody, 'if not result then',
    'async read timeout must reclaim context only on rejected submission');
  CheckContains(LWriteTimeoutBody, '@timeoutiocallback',
    'async write timeout must submit the owned timeout callback to poller');
  CheckContains(LWriteTimeoutBody, 'if not result then',
    'async write timeout must reclaim context only on rejected submission');
end;

procedure TestAsyncLoopTimeoutSingleFireCleanupContract;
var
  LAsyncLoop: string;
  LTimeoutCtxBody: string;
  LClaimBody: string;
  LReleaseBody: string;
  LTimeoutIoBody: string;
  LTimeoutTimerBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LTimeoutCtxBody := ExtractBetween(LAsyncLoop, 'ttimeoutctx = record',
    'end;');
  LClaimBody := ExtractBetween(LAsyncLoop, 'function timeoutctxclaimcompletion',
    'procedure timeoutctxrelease');
  LReleaseBody := ExtractBetween(LAsyncLoop, 'procedure timeoutctxrelease',
    'procedure timeoutiocallback');
  LTimeoutIoBody := ExtractBetween(LAsyncLoop, 'procedure timeoutiocallback',
    'procedure timeouttimercallback');
  LTimeoutTimerBody := ExtractBetween(LAsyncLoop, 'procedure timeouttimercallback',
    '{ tasyncloop }');

  CheckContains(LAsyncLoop, 'timeout_completion_pending',
    'timeout wrapper must name the pending single-fire state');
  CheckContains(LAsyncLoop, 'timeout_completion_io',
    'timeout wrapper must name the I/O completion winner state');
  CheckContains(LAsyncLoop, 'timeout_completion_timer',
    'timeout wrapper must name the timeout winner state');
  CheckContains(LTimeoutCtxBody, 'completionstate: int32',
    'timeout context must track one single-fire completion winner');
  CheckContains(LTimeoutCtxBody, 'refcount: int32',
    'timeout context must retain timer and I/O owner references separately');
  CheckAbsent(LTimeoutCtxBody, 'iocompleted',
    'timeout context must not rely on non-atomic I/O-completed booleans');
  CheckAbsent(LTimeoutCtxBody, 'timerfired',
    'timeout context must not rely on non-atomic timer-fired booleans');

  CheckContains(LClaimBody, 'atomiccompareexchange32',
    'timeout completion claim must be atomic');
  CheckContains(LClaimBody, 'timeout_completion_pending',
    'timeout completion claim must only win from pending state');
  CheckContains(LReleaseBody, 'atomicfetchsub32',
    'timeout cleanup release must be atomic');
  CheckContains(LReleaseBody, 'dispose(actx);',
    'timeout cleanup release must free the context only from the last owner');

  CheckContains(LTimeoutIoBody,
    'timeoutctxclaimcompletion(lctx, timeout_completion_io)',
    'timeout IO callback must atomically claim the real I/O result');
  CheckContains(LTimeoutIoBody,
    'timeoutctxdetachuserrefs(lctx, lusercallback, lusercontext);',
    'timeout IO callback must detach user refs before forwarding I/O result');
  CheckBefore(LTimeoutIoBody, 'timeoutctxcanceltimerowner(lctx);',
    'lusercallback(auserdata, aresult, lusercontext);',
    'timeout IO callback must cancel the timer before forwarding I/O result');
  CheckContains(LTimeoutIoBody, 'timeoutctxrelease(lctx);',
    'timeout IO callback must release its owner reference on every exit path');
  CheckContains(LTimeoutTimerBody,
    'timeoutctxclaimcompletion(lctx, timeout_completion_timer)',
    'timeout timer callback must atomically claim the timeout result');
  CheckContains(LTimeoutTimerBody,
    'timeoutctxdetachuserrefs(lctx, lusercallback, lusercontext);',
    'timeout timer callback must detach user refs before delivering timeout');
  CheckContains(LTimeoutTimerBody,
    'lusercallback(0, -etimedout_linux, lusercontext);',
    'timeout timer callback must still deliver exactly one timeout result');
  CheckContains(LTimeoutTimerBody, 'timeoutctxrelease(lctx);',
    'timeout timer callback must release its owner reference on every exit path');
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

procedure TestIocpSocketCompletionContract;
var
  LIocp: string;
  LAsyncLoop: string;
  LUnsupportedBody: string;
  LAcceptBody: string;
  LConnectBody: string;
  LSendBody: string;
  LRecvBody: string;
  LCloseBody: string;
  LSocketSubmitBody: string;
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
  LSocketSubmitBody := ExtractBetween(LIocp, 'function iocpsubmitsocketop',
    'function iocpdispatchcompletion');
  LRecvTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncrecvtimeout',
    'function tasyncloop.asyncsendtimeout');
  LSendTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncsendtimeout',
    'end.');

  CheckContains(LUnsupportedBody, 'function iocpunsupportedasync: boolean;',
    'IOCP unsupported helper must not accept callback ownership inputs');
  CheckContains(LUnsupportedBody, 'result := false;',
    'IOCP unsupported helper must reject ownership transfer');
  CheckContains(LUnsupportedBody, 'setlasterror(error_not_supported);',
    'IOCP unsupported helper must preserve explicit unsupported truth');
  CheckAbsent(LUnsupportedBody, 'iocpfail(',
    'IOCP unsupported helper must not reuse synchronous failure ownership semantics');
  CheckAbsent(LUnsupportedBody, 'acallback',
    'IOCP unsupported helper must not retain unused callback parameters');
  CheckAbsent(LUnsupportedBody, 'acontext',
    'IOCP unsupported helper must not retain unused callback context parameters');
  CheckAbsent(LUnsupportedBody, 'acallback(',
    'IOCP unsupported helper must not dispatch inline completion callbacks');
  CheckContains(LAcceptBody, 'result := iocpunsupportedasync;',
    'AsyncAccept must reject unsupported IOCP ownership through the helper');
  CheckContains(LConnectBody, 'result := iocpunsupportedasync;',
    'AsyncConnect must reject unsupported IOCP ownership through the helper');
  CheckContains(LCloseBody, 'result := iocpunsupportedasync;',
    'AsyncClose must reject unsupported IOCP ownership through the helper');
  CheckAbsent(LSendBody, 'iocpunsupportedasync',
    'AsyncSend must no longer be a generic unsupported stub');
  CheckAbsent(LRecvBody, 'iocpunsupportedasync',
    'AsyncRecv must no longer be a generic unsupported stub');
  CheckContains(LIocp, 'wsabuf: wsabuf',
    'socket pending operation must own stable WSABUF descriptor storage');
  CheckContains(LIocp, 'socketflags: dword',
    'socket pending operation must own stable flags storage');
  CheckContains(LIocp, 'function iocpsubmitsocketop',
    'IOCP socket send/recv should share one narrow submission helper');
  CheckContains(LIocp, 'iocpensureassociatedhandle(areactor, lhandle, lerror)',
    'socket operations must associate the socket handle with the IOCP port');
  CheckContains(LIocp, 'lop^.wsabuf.buf := pansichar(abuf);',
    'socket operations should keep caller buffer pointer in the owned WSABUF descriptor');
  CheckContains(LIocp, 'lop^.wsabuf.len := alen;',
    'socket operations should keep payload length in the owned WSABUF descriptor');
  CheckContains(LIocp, 'lop^.socketflags := dword(aflags);',
    'socket operations should keep mutable flags storage alive through overlapped submit');
  CheckContains(LSendBody, 'iocpsubmitsocketop(self, opsend',
    'AsyncSend must submit through the socket completion helper');
  CheckContains(LRecvBody, 'iocpsubmitsocketop(self, oprecv',
    'AsyncRecv must submit through the socket completion helper');
  CheckContains(LSendBody, 'if not isvalid then',
    'AsyncSend must reject closed reactors before callback ownership transfer');
  CheckBefore(LSendBody, 'if not isvalid then',
    'iocpsubmitsocketop',
    'AsyncSend must reject closed reactors before socket submission');
  CheckContains(LSendBody, 'exit(false);',
    'AsyncSend closed-reactor rejection must return False');
  CheckContains(LRecvBody, 'if not isvalid then',
    'AsyncRecv must reject closed reactors before callback ownership transfer');
  CheckBefore(LRecvBody, 'if not isvalid then',
    'iocpsubmitsocketop',
    'AsyncRecv must reject closed reactors before socket submission');
  CheckContains(LRecvBody, 'exit(false);',
    'AsyncRecv closed-reactor rejection must return False');
  CheckContains(LIocp, 'wsasend(',
    'AsyncSend must call platform-owned overlapped WSASend');
  CheckContains(LIocp, '@lop^.wsabuf, 1, nil,',
    'AsyncSend must submit overlapped WSASend using owned WSABUF storage');
  CheckContains(LIocp, 'wsarecv(',
    'AsyncRecv must call platform-owned overlapped WSARecv');
  CheckContains(LIocp, '@lop^.socketflags, @lop^.overlapped, nil);',
    'AsyncRecv must submit overlapped WSARecv using owned WSABUF storage');
  CheckContains(LIocp, 'wsagetlasterror',
    'socket submission failures must use WSAGetLastError');
  CheckContains(LIocp, 'wsa_io_pending',
    'socket submission must treat WSA_IO_PENDING as queued work');
  CheckSequence(LSocketSubmitBody,
    'socket submission synchronous failure must release the pending op before callback dispatch',
    [
      'lerror := dword(wsagetlasterror);',
      'if lerror = wsa_io_pending then',
      'luserdata := lop^.userdata;',
      'iocpfreeop(areactor, lop);',
      'result := iocpfail(acallback, acontext, luserdata, lerror);'
    ]);
  CheckAbsent(LIocp, 'external ''ws2_32''',
    'IOCP reactor must consume platform-owned WinSock FFI, not redeclare raw ABI');
  CheckContains(LRecvTimeoutBody, 'if not result then',
    'async recv timeout wrapper must reclaim timeout context only on rejected submission');
  CheckContains(LRecvTimeoutBody, 'timeoutctxcanceltimerowner(lctx);',
    'async recv timeout wrapper must release the timer owner when submission is rejected');
  CheckContains(LRecvTimeoutBody, 'timeoutctxrelease(lctx);',
    'async recv timeout wrapper must release the I/O owner when submission is rejected');
  CheckContains(LSendTimeoutBody, 'if not result then',
    'async send timeout wrapper must reclaim timeout context only on rejected submission');
  CheckContains(LSendTimeoutBody, 'timeoutctxcanceltimerowner(lctx);',
    'async send timeout wrapper must release the timer owner when submission is rejected');
  CheckContains(LSendTimeoutBody, 'timeoutctxrelease(lctx);',
    'async send timeout wrapper must release the I/O owner when submission is rejected');
end;

procedure TestIocpPendingOperationOwnershipContract;
var
  LIocp, LDispatchBody, LReadBody, LWriteBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LDispatchBody := ExtractBetween(LIocp, 'function iocpdispatchcompletion',
    'class function tiocpreactor.create');
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
  CheckBefore(LDispatchBody, 'iocpunlinkop(areactor, lop);',
    'lop^.callback(lop^.userdata, lresult, lop^.context);',
    'IOCP dispatch must detach the completed op before callbacks can re-enter Close');
  CheckBefore(LDispatchBody, 'iocpunlinkop(areactor, lop);',
    'iocpfreeop(areactor, lop);',
    'IOCP dispatch must detach the completed op before freeing it');
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

procedure TestIocpPostCloseFileSubmissionRejectContract;
var
  LIocp: string;
  LReadBody: string;
  LWriteBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LReadBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncread',
    'function tiocpreactor.asyncwrite');
  LWriteBody := ExtractBetween(LIocp, 'function tiocpreactor.asyncwrite',
    'function tiocpreactor.asyncaccept');

  CheckContains(LReadBody, 'if not isvalid then',
    'AsyncRead must reject post-close submissions before callback ownership transfer');
  CheckBefore(LReadBody, 'if not isvalid then',
    'iocpsubmitfileop',
    'AsyncRead must reject closed reactors before submitting file operations');
  CheckContains(LReadBody, 'exit(false);',
    'AsyncRead closed-reactor rejection must return False');
  CheckAbsent(LReadBody, 'iocpfail(',
    'AsyncRead closed-reactor rejection must not dispatch inline failure callbacks');

  CheckContains(LWriteBody, 'if not isvalid then',
    'AsyncWrite must reject post-close submissions before callback ownership transfer');
  CheckBefore(LWriteBody, 'if not isvalid then',
    'iocpsubmitfileop',
    'AsyncWrite must reject closed reactors before submitting file operations');
  CheckContains(LWriteBody, 'exit(false);',
    'AsyncWrite closed-reactor rejection must return False');
  CheckAbsent(LWriteBody, 'iocpfail(',
    'AsyncWrite closed-reactor rejection must not dispatch inline failure callbacks');
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
  T.Run('async loop timeout single-fire cleanup contract',
    @TestAsyncLoopTimeoutSingleFireCleanupContract);
  T.Run('IOCP synchronous failure ownership contract',
    @TestIocpSynchronousFailureOwnershipContract);
  T.Run('IOCP socket completion contract',
    @TestIocpSocketCompletionContract);
  T.Run('IOCP pending operation ownership contract',
    @TestIocpPendingOperationOwnershipContract);
  T.Run('IOCP post-close file submission reject contract',
    @TestIocpPostCloseFileSubmissionRejectContract);
  T.Run('Windows handle width contract', @TestPollerWindowsHandleWidthContract);
  T.Summary;
end.
