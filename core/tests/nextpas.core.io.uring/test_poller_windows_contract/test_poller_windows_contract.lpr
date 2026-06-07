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
  CheckContains(LIocp, 'closehandle(handle(lport))',
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
  CheckContains(LStopBody, 'wake;',
    'async loop stop must wake the platform wait seam');
  CheckBefore(LStopBody, 'atomicstore32(frunning, 0, morelease);', 'wake;',
    'async loop stop must publish stopped state before waking waiters');
end;

procedure TestAsyncLoopWakeSeamContract;
var
  LAsyncLoop: string;
  LWakeBody: string;
  LWaitBody: string;
  LPostBody: string;
  LScheduleBody: string;
  LScheduleAtBody: string;
  LCancelBody: string;
  LSleepBody: string;
  LTimeoutCreateBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LWakeBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.wake',
    'procedure tasyncloop.post');
  LPostBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.post',
    'procedure tasyncloop.drainwake');
  LWaitBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.waitforwake',
    'procedure tasyncloop.drainpending');
  LScheduleBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.schedule',
    'function tasyncloop.scheduleat');
  LScheduleAtBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.scheduleat',
    'function tasyncloop.canceltimer');
  LCancelBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.canceltimer',
    'function tasyncloop.asyncread');
  LSleepBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.asyncsleep',
    'function tasyncloop.asyncreadtimeout');
  LTimeoutCreateBody := ExtractBetween(LAsyncLoop, 'function timeoutctxcreate',
    '{ tasyncloop }');

  CheckContains(LWakeBody, 'platform_poller_wake(fwakepoller);',
    'async loop Wake must target the platform poller wake seam');
  CheckContains(LWaitBody,
    'platform_poller_wait(fwakepoller, @lentry, 1, atimeoutms, lcount);',
    'async loop WaitForWake must block only through the platform poller wait seam');
  CheckContains(LPostBody, 'wake;',
    'async loop Post must wake waiters after enqueuing pending callbacks');

  CheckBefore(LScheduleBody, 'result := ftimers.scheduleafter',
    'wake;',
    'async loop Schedule must wake waiters after adding a timer');
  CheckBefore(LScheduleAtBody, 'result := ftimers.schedule',
    'wake;',
    'async loop ScheduleAt must wake waiters after adding a timer');
  CheckBefore(LCancelBody, 'result := ftimers.cancel(ahandle);',
    'wake;',
    'async loop CancelTimer must wake waiters after changing timer state');
  CheckContains(LCancelBody, 'if result then',
    'async loop CancelTimer must wake only when a timer was actually cancelled');
  CheckBefore(LSleepBody, 'result := ftimers.scheduleafter',
    'wake;',
    'async sleep must wake waiters after adding a sleep timer');
  CheckBefore(LTimeoutCreateBody, 'result^.timerhandle := aloop^.ftimers.schedule',
    'aloop^.wake;',
    'timeout context creation must wake waiters after adding its deadline timer');
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

  CheckContains(LCloseBody, 'lport := fport;',
    'IOCP Close must keep the completion port owner handle in local close scope');
  CheckContains(LCloseBody, 'fport := 0;',
    'IOCP Close must detach public submission state before abort callbacks can re-enter');
  CheckBefore(LCloseBody, 'fport := 0;',
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'IOCP Close must reject re-entrant submissions before abort callbacks');
  CheckContains(LCloseBody,
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'IOCP Close must abort owned pending file operations');
  CheckBefore(LCloseBody,
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'iocpreleaseassociatedhandles(self);',
    'IOCP Close must abort pending operations before releasing handle associations');
  CheckBefore(LCloseBody,
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'closehandle(handle(lport))',
    'IOCP Close must dispatch abort callbacks before closing the port handle');
  CheckContains(LReleaseBody, 'iocpcancelpendingops(areactor, aerror);',
    'IOCP pending release must first request cancellation for owned file operations');
  CheckContains(LReleaseBody, 'iocpdraincancelledpendingops(areactor, aport, aerror);',
    'IOCP pending release must drain cancellation completions before freeing owners');
  CheckBefore(LReleaseBody, 'iocpcancelpendingops(areactor, aerror);',
    'iocpdraincancelledpendingops(areactor, aport, aerror);',
    'IOCP pending release must cancel before draining completion ownership');
  CheckAbsent(LReleaseBody, 'areactor.fpendinghead := nil;',
    'IOCP pending release must keep pending ops linked until completion settle');
  CheckAbsent(LReleaseBody, 'areactor.fpendingcount := 0;',
    'IOCP pending release must not clear pending count before completion settle');
  CheckAbsent(LReleaseBody, 'lop^.callback(lop^.userdata, -int32(aerror), lop^.context);',
    'IOCP pending release must not dispatch abort callbacks before completion settle');
  CheckAbsent(LReleaseBody, 'dispose(lop);',
    'IOCP pending release must not free OVERLAPPED storage before completion settle');
end;

procedure TestIocpCloseRunWakeHandoffContract;
var
  LIocp: string;
  LPollOneBody: string;
  LRunBody: string;
  LCloseBody: string;
  LCloseAfterDrainBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LPollOneBody := ExtractBetween(LIocp, 'function tiocpreactor.pollone',
    'procedure tiocpreactor.run');
  LRunBody := ExtractBetween(LIocp, 'procedure tiocpreactor.run',
    'procedure tiocpreactor.stop');
  LCloseBody := ExtractBetween(LIocp, 'procedure tiocpreactor.close',
    'function tiocpreactor.isvalid');
  LCloseAfterDrainBody := ExtractBetween(LCloseBody,
    'iocpreleaseassociatedhandles(self);', 'closehandle(handle(lport))');

  CheckContains(LCloseBody,
    'postqueuedcompletionstatus(handle(lport), 0, 0, nil)',
    'IOCP Close must wake a blocking Run before releasing the completion port');
  CheckBefore(LCloseBody, 'atomicstore32(frunning, 0, morelease);',
    'postqueuedcompletionstatus(handle(lport), 0, 0, nil)',
    'IOCP Close must publish stopped state before posting the close wake');
  CheckBefore(LCloseBody, 'postqueuedcompletionstatus(handle(lport), 0, 0, nil)',
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'IOCP Close must wake Run before draining abort completions');
  CheckBefore(LCloseBody,
    'iocpreleasependingops(self, handle(lport), error_operation_aborted);',
    'iocpreleaseassociatedhandles(self);',
    'IOCP Close must drain abort completions before releasing association metadata');
  CheckContains(LCloseAfterDrainBody,
    'postqueuedcompletionstatus(handle(lport), 0, 0, nil);',
    'IOCP Close must repost the control wake after close-side abort draining');
  CheckAbsent(LCloseBody, 'postqueuedcompletionstatus(handle(fport), 0, 0, nil)',
    'IOCP Close must not post through detached public FPort state');

  CheckContains(LPollOneBody, 'if loverlapped = nil then',
    'IOCP PollOne must recognize control packets without pending operation owners');
  CheckBefore(LPollOneBody, 'if loverlapped = nil then',
    'iocpdispatchcompletion(self, lbytes, lok, loverlapped)',
    'IOCP PollOne must reject nil-overlapped control packets before dispatch');
  CheckContains(LRunBody, 'if loverlapped = nil then',
    'IOCP Run must recognize close/stop control packets');
  CheckContains(LRunBody, 'continue;',
    'IOCP Run must re-check running state after a successful control packet');
  CheckBefore(LRunBody, 'if loverlapped = nil then',
    'continue;',
    'IOCP Run must handle successful control packets by re-checking running state');
  CheckBefore(LRunBody, 'continue;',
    'iocpdispatchcompletion(self, lbytes, lok, loverlapped)',
    'IOCP Run must not dispatch close/stop control packets as file completions');
end;

procedure TestIocpCloseAbortCompletionDrainOwnershipContract;
var
  LIocp: string;
  LCancelBody: string;
  LAbortDispatchBody: string;
  LAbortRemainingBody: string;
  LDrainBody: string;
  LReleaseBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LCancelBody := ExtractBetween(LIocp, 'procedure iocpcancelpendingops',
    'function iocpdispatchabortcompletion');
  LAbortDispatchBody := ExtractBetween(LIocp,
    'function iocpdispatchabortcompletion',
    'procedure iocpabortremainingpendingops');
  LAbortRemainingBody := ExtractBetween(LIocp,
    'procedure iocpabortremainingpendingops',
    'procedure iocpdraincancelledpendingops');
  LDrainBody := ExtractBetween(LIocp, 'procedure iocpdraincancelledpendingops',
    'procedure iocpreleasependingops');
  LReleaseBody := ExtractBetween(LIocp, 'procedure iocpreleasependingops',
    'function iocphasassociatedhandle');

  CheckContains(LCancelBody, 'cancelioex(lop^.handle, @lop^.overlapped);',
    'IOCP cancellation must request abort for each pending OVERLAPPED');
  CheckAbsent(LCancelBody, 'dispose(lop);',
    'IOCP cancellation must not free OVERLAPPED storage');
  CheckAbsent(LCancelBody,
    'lop^.callback(lop^.userdata, -int32(aerror), lop^.context);',
    'IOCP cancellation must not dispatch before completion settle');

  CheckContains(LDrainBody, 'while areactor.fpendingcount > 0 do',
    'IOCP close-abort drain must run until all pending completions settle');
  CheckContains(LDrainBody,
    'getqueuedcompletionstatus(aport, @lbytes, @lkey',
    'IOCP close-abort drain must observe completion port packets');
  CheckContains(LDrainBody, '@loverlapped, infinite)',
    'IOCP close-abort drain must wait for cancellation completion ownership');
  CheckContains(LDrainBody,
    'iocpdispatchabortcompletion(areactor, loverlapped, aerror)',
    'IOCP close-abort drain must dispatch only after receiving the completion packet');
  CheckBefore(LDrainBody,
    'getqueuedcompletionstatus(aport, @lbytes, @lkey',
    'iocpdispatchabortcompletion(areactor, loverlapped, aerror)',
    'IOCP close-abort drain must settle OS completion before callback/free');

  CheckContains(LAbortDispatchBody, 'lcallback := lop^.callback;',
    'IOCP abort dispatch must copy callback before detaching the op');
  CheckContains(LAbortDispatchBody, 'luserdata := lop^.userdata;',
    'IOCP abort dispatch must copy userdata before detaching the op');
  CheckContains(LAbortDispatchBody, 'lcontext := lop^.context;',
    'IOCP abort dispatch must copy context before detaching the op');
  CheckContains(LAbortDispatchBody, 'iocpunlinkop(areactor, lop);',
    'IOCP abort dispatch must detach the settled op before user callback re-entry');
  CheckContains(LAbortDispatchBody, 'setlasterror(aerror);',
    'IOCP abort dispatch must publish host abort error truth');
  CheckBefore(LAbortDispatchBody, 'iocpunlinkop(areactor, lop);',
    'lcallback(luserdata, -int32(aerror), lcontext);',
    'IOCP abort dispatch must detach before callback dispatch');
  CheckBefore(LAbortDispatchBody, 'setlasterror(aerror);',
    'lcallback(luserdata, -int32(aerror), lcontext);',
    'IOCP abort dispatch must publish abort error before callback dispatch');
  CheckContains(LAbortDispatchBody, 'try',
    'IOCP abort dispatch must guard callback dispatch cleanup');
  CheckContains(LAbortDispatchBody, 'finally',
    'IOCP abort dispatch must free the pending op if callback raises');
  CheckBefore(LAbortDispatchBody,
    'lcallback(luserdata, -int32(aerror), lcontext);',
    'finally',
    'IOCP abort dispatch must run cleanup after callback dispatch');
  CheckBefore(LAbortDispatchBody, 'finally', 'dispose(lop);',
    'IOCP abort dispatch must dispose the pending op from the cleanup block');

  CheckContains(LAbortRemainingBody, 'while areactor.fpendingcount > 0 do',
    'IOCP abort fallback must release every remaining pending owner');
  CheckContains(LAbortRemainingBody,
    'iocpdispatchabortcompletion(areactor, @lop^.overlapped, aerror)',
    'IOCP abort fallback must reuse the same detach/callback/free owner path');
  CheckContains(LDrainBody, 'iocpabortremainingpendingops(areactor, aerror);',
    'IOCP close-abort drain must not leak owners if completion draining fails');
  CheckBefore(LDrainBody, 'if (not lok) and (loverlapped = nil) then',
    'iocpabortremainingpendingops(areactor, aerror);',
    'IOCP close-abort drain must fallback when no completion packet can be observed');

  CheckBefore(LReleaseBody, 'iocpcancelpendingops(areactor, aerror);',
    'iocpdraincancelledpendingops(areactor, aport, aerror);',
    'IOCP release orchestration must cancel before completion drain');
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

procedure TestAsyncLoopCloseStopWakeOwnershipContract;
var
  LAsyncLoop: string;
  LCloseBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LCloseBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.close',
    'function tasyncloop.isvalid');

  CheckContains(LCloseBody, 'stop;',
    'async loop close must publish stopped state before releasing owner resources');
  CheckContains(LCloseBody, 'wake;',
    'async loop close must wake a blocked run loop before releasing wake resources');
  CheckBefore(LCloseBody, 'stop;', 'wake;',
    'async loop close must publish stop before waking waiters');
  CheckBefore(LCloseBody, 'wake;', 'fpoller.close;',
    'async loop close must wake waiters before closing completion resources');
  CheckBefore(LCloseBody, 'wake;', 'platform_poller_close(fwakepoller);',
    'async loop close must wake waiters before closing wake resources');
end;

procedure TestAsyncLoopPostClosedOwnerBoundaryContract;
var
  LAsyncLoop: string;
  LPostBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LPostBody := ExtractBetween(LAsyncLoop, 'procedure tasyncloop.post',
    'procedure tasyncloop.drainwake');

  CheckContains(LPostBody, 'if not fwakeready then',
    'async loop post must reject closed stale-owner submissions');
  CheckBefore(LPostBody, 'if not fwakeready then', 'platform_mutex_lock(fpendinglock);',
    'async loop post must not touch the pending mutex after close');
  CheckBefore(LPostBody, 'if not fwakeready then', 'setlength(fpendingqueue',
    'async loop post must not grow the pending queue after close');
  CheckBefore(LPostBody, 'if not fwakeready then', 'wake;',
    'async loop post must not signal closed wake resources');
end;

procedure TestAsyncLoopClosedTimeoutOwnerBoundaryContract;
var
  LAsyncLoop: string;
  LReadTimeoutBody: string;
  LWriteTimeoutBody: string;
  LRecvTimeoutBody: string;
  LSendTimeoutBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LReadTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncreadtimeout',
    'function tasyncloop.asyncwritetimeout');
  LWriteTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncwritetimeout',
    'function tasyncloop.asyncrecvtimeout');
  LRecvTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncrecvtimeout',
    'function tasyncloop.asyncsendtimeout');
  LSendTimeoutBody := ExtractBetween(LAsyncLoop,
    'function tasyncloop.asyncsendtimeout',
    'end.');

  CheckContains(LReadTimeoutBody, 'if not fwakeready then',
    'closed async read timeout must reject before creating timeout owners');
  CheckContains(LWriteTimeoutBody, 'if not fwakeready then',
    'closed async write timeout must reject before creating timeout owners');
  CheckContains(LRecvTimeoutBody, 'if not fwakeready then',
    'closed async recv timeout must reject before creating timeout owners');
  CheckContains(LSendTimeoutBody, 'if not fwakeready then',
    'closed async send timeout must reject before creating timeout owners');

  CheckBefore(LReadTimeoutBody, 'if not fwakeready then',
    'if adeadline.isinfinite then',
    'closed async read timeout must reject before delegating infinite deadlines');
  CheckBefore(LWriteTimeoutBody, 'if not fwakeready then',
    'if adeadline.isinfinite then',
    'closed async write timeout must reject before delegating infinite deadlines');
  CheckBefore(LRecvTimeoutBody, 'if not fwakeready then',
    'if adeadline.isinfinite then',
    'closed async recv timeout must reject before delegating infinite deadlines');
  CheckBefore(LSendTimeoutBody, 'if not fwakeready then',
    'if adeadline.isinfinite then',
    'closed async send timeout must reject before delegating infinite deadlines');

  CheckBefore(LReadTimeoutBody, 'if not fwakeready then',
    'lctx := timeoutctxcreate',
    'closed async read timeout must not allocate timeout context owners');
  CheckBefore(LWriteTimeoutBody, 'if not fwakeready then',
    'lctx := timeoutctxcreate',
    'closed async write timeout must not allocate timeout context owners');
  CheckBefore(LRecvTimeoutBody, 'if not fwakeready then',
    'lctx := timeoutctxcreate',
    'closed async recv timeout must not allocate timeout context owners');
  CheckBefore(LSendTimeoutBody, 'if not fwakeready then',
    'lctx := timeoutctxcreate',
    'closed async send timeout must not allocate timeout context owners');
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
  CheckBefore(LTimeoutIoBody, 'timeoutctxcanceltimerowner(lctx);',
    'lctx^.usercallback(auserdata, aresult, lctx^.usercontext);',
    'timeout IO callback must cancel the timer before forwarding I/O result');
  CheckContains(LTimeoutIoBody, 'timeoutctxrelease(lctx);',
    'timeout IO callback must release its owner reference on every exit path');
  CheckContains(LTimeoutTimerBody,
    'timeoutctxclaimcompletion(lctx, timeout_completion_timer)',
    'timeout timer callback must atomically claim the timeout result');
  CheckContains(LTimeoutTimerBody,
    'lctx^.usercallback(0, -etimedout_linux, lctx^.usercontext);',
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

  CheckContains(LFailBody, 'setlasterror(aerror);',
    'IOCP synchronous failure helper must publish host error truth');
  CheckBefore(LFailBody, 'setlasterror(aerror);',
    'acallback(auserdata, -int32(aerror), acontext);',
    'IOCP synchronous failure helper must publish host error before callback dispatch');
  CheckContains(LFailBody, 'acallback(auserdata, -int32(aerror), acontext);',
    'IOCP synchronous failure helper must deliver the callback inline');
  CheckContains(LFailBody, 'result := true;',
    'IOCP synchronous failure helper must report callback ownership transfer');
end;

procedure TestWindowsCompletionFfiAbiContract;
var
  LBase: string;
  LFfi: string;
  LIocp: string;
  LPendingOpBody: string;
begin
  LBase := LoadSourceText('src/nextpas.core.platform.windows.base.kernel32.inc');
  LFfi := LoadSourceText('src/nextpas.core.platform.windows.ffi.pas');
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LPendingOpBody := ExtractBetween(LIocp, 'tiocppendingop = record',
    'end;');

  CheckContains(LBase, 'pulong_ptr = ^ulong_ptr;',
    'Windows base must expose a typed completion-key out pointer');
  CheckContains(LBase, 'plpoverlapped = ^lpoverlapped;',
    'Windows base must expose a typed overlapped out pointer');
  CheckContains(LFfi,
    'function readfile(hfile: handle; lpbuffer: pointer; nnumberofbytestoread: dword; lpnumberofbytesread: lpdword; lpoverlapped: lpoverlapped): bool;',
    'ReadFile raw FFI must type the overlapped parameter');
  CheckContains(LFfi,
    'function writefile(hfile: handle; lpbuffer: pointer; nnumberofbytestowrite: dword; lpnumberofbyteswritten: lpdword; lpoverlapped: lpoverlapped): bool;',
    'WriteFile raw FFI must type the overlapped parameter');
  CheckContains(LFfi,
    'function getqueuedcompletionstatus(completionport: handle; lpnumberofbytestransferred: lpdword; lpcompletionkey: pulong_ptr; lpoverlapped: plpoverlapped; dwmilliseconds: dword): winbool;',
    'GetQueuedCompletionStatus raw FFI must type completion key and overlapped out pointers');
  CheckAbsent(LFfi,
    'getqueuedcompletionstatus(completionport: handle; lpnumberofbytestransferred: lpdword; lpcompletionkey: pointer; lpoverlapped: pointer;',
    'GetQueuedCompletionStatus must not expose untyped completion out parameters');

  CheckBefore(LPendingOpBody, 'overlapped: overlapped;',
    'kind: tiocpopkind;',
    'IOCP pending op must keep OVERLAPPED as the first field for ABI cast-back');
  CheckBefore(LPendingOpBody, 'overlapped: overlapped;',
    'handle: handle;',
    'IOCP pending op must keep OVERLAPPED before owned handle fields');
  CheckContains(LIocp, 'piocppendingop(aoverlapped)',
    'IOCP dispatch must make the cast-back invariant explicit');
end;

procedure TestIocpClosedSubmitOwnershipContract;
var
  LIocp: string;
  LSubmitBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LSubmitBody := ExtractBetween(LIocp, 'function iocpsubmitfileop',
    'function iocpdispatchcompletion');

  CheckContains(LSubmitBody, 'if areactor.fport = 0 then',
    'closed IOCP reactor must reject stale-owner file submissions');
  CheckContains(LSubmitBody, 'setlasterror(error_invalid_handle);',
    'closed IOCP reactor must publish invalid-handle failure truth');
  CheckContains(LSubmitBody, 'exit(false);',
    'closed IOCP reactor must reject ownership transfer without callback dispatch');
  CheckBefore(LSubmitBody, 'if areactor.fport = 0 then',
    'iocpensureassociatedhandle',
    'closed IOCP reactor must reject before handle association');
  CheckBefore(LSubmitBody, 'if areactor.fport = 0 then', 'iocpallocop',
    'closed IOCP reactor must reject before pending operation allocation');
  CheckBefore(LSubmitBody, 'if areactor.fport = 0 then',
    'iocpfail(acallback, acontext, 0, lerror)',
    'closed IOCP reactor must not reuse synchronous completion ownership transfer');
end;

procedure TestIocpSubmitFailureOwnershipContract;
var
  LIocp: string;
  LSubmitBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LSubmitBody := ExtractBetween(LIocp, 'function iocpsubmitfileop',
    'function iocpdispatchcompletion');

  CheckContains(LSubmitBody, 'luserdata := lop^.userdata;',
    'IOCP submit failure must preserve userdata before releasing the pending op');
  CheckContains(LSubmitBody, 'iocpfreeop(areactor, lop);',
    'IOCP submit failure must release the pending operation owner');
  CheckContains(LSubmitBody,
    'result := iocpfail(acallback, acontext, luserdata, lerror);',
    'IOCP submit failure must dispatch failure with preserved userdata');
  CheckBefore(LSubmitBody, 'lerror := getlasterror;',
    'if lerror = error_io_pending then',
    'IOCP submit failure must classify ERROR_IO_PENDING before cleanup');
  CheckBefore(LSubmitBody, 'if lerror = error_io_pending then',
    'luserdata := lop^.userdata;',
    'IOCP submit failure must not free queued ERROR_IO_PENDING operations');
  CheckBefore(LSubmitBody, 'luserdata := lop^.userdata;',
    'iocpfreeop(areactor, lop);',
    'IOCP submit failure must copy userdata before freeing the pending op');
  CheckBefore(LSubmitBody, 'iocpfreeop(areactor, lop);',
    'result := iocpfail(acallback, acontext, luserdata, lerror);',
    'IOCP submit failure must free the pending op before callback dispatch');
  CheckAbsent(LSubmitBody, 'iocpfail(acallback, acontext, lop^.userdata',
    'IOCP submit failure must not read userdata from a freed pending op');
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

procedure TestIocpDispatchSingleFireOwnershipContract;
var
  LIocp: string;
  LDispatchBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LDispatchBody := ExtractBetween(LIocp, 'function iocpdispatchcompletion',
    'class function tiocpreactor.create');

  CheckContains(LDispatchBody, 'lcallback := lop^.callback;',
    'IOCP dispatch must copy callback before detaching the pending op');
  CheckContains(LDispatchBody, 'luserdata := lop^.userdata;',
    'IOCP dispatch must copy userdata before detaching the pending op');
  CheckContains(LDispatchBody, 'lcontext := lop^.context;',
    'IOCP dispatch must copy context before detaching the pending op');
  CheckContains(LDispatchBody, 'iocpunlinkop(areactor, lop);',
    'IOCP dispatch must detach the completed op before user callback re-entry');
  CheckBefore(LDispatchBody, 'lcallback := lop^.callback;',
    'iocpunlinkop(areactor, lop);',
    'IOCP dispatch must copy callback ownership before detaching the op');
  CheckBefore(LDispatchBody, 'iocpunlinkop(areactor, lop);',
    'lcallback(luserdata, lresult, lcontext);',
    'IOCP dispatch must detach the op before callback dispatch');
  CheckContains(LDispatchBody, 'lcallback(luserdata, lresult, lcontext);',
    'IOCP dispatch must use local callback state after detaching');
  CheckAbsent(LDispatchBody, 'lop^.callback(lop^.userdata, lresult, lop^.context);',
    'IOCP dispatch must not dispatch from the pending owner record');
end;

procedure TestIocpAssociatedHandleOwnershipContract;
var
  LIocp: string;
  LEnsureBody: string;
begin
  LIocp := LoadSourceText('src/nextpas.core.io.reactor.iocp.pas');
  LEnsureBody := ExtractBetween(LIocp, 'function iocpensureassociatedhandle',
    'procedure iocpsetoffset');

  CheckContains(LIocp, 'piocpassociatedhandle',
    'IOCP reactor must track host handle association metadata');
  CheckContains(LIocp, 'iocpallocassociatedhandle',
    'IOCP association metadata must have an explicit owner allocation seam');
  CheckContains(LIocp, 'iocppushassociatedhandle',
    'IOCP association metadata must only be linked after host association succeeds');
  CheckContains(LEnsureBody, 'lnode := iocpallocassociatedhandle(ahandle);',
    'IOCP ensure must allocate association metadata before mutating host association state');
  CheckBefore(LEnsureBody, 'lnode := iocpallocassociatedhandle(ahandle);',
    'createiocompletionport(ahandle, handle(areactor.fport), 0,',
    'IOCP ensure must own releasable metadata before CreateIoCompletionPort');
  CheckContains(LEnsureBody, 'dispose(lnode);',
    'IOCP ensure must release preallocated metadata when host association fails');
  CheckBefore(LEnsureBody, 'createiocompletionport(ahandle, handle(areactor.fport), 0,',
    'dispose(lnode);',
    'IOCP ensure must release metadata on CreateIoCompletionPort failure');
  CheckBefore(LEnsureBody, 'createiocompletionport(ahandle, handle(areactor.fport), 0,',
    'iocppushassociatedhandle(areactor, lnode);',
    'IOCP ensure must link metadata only after CreateIoCompletionPort succeeds');
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

procedure TestWindowsForcedCompileAsyncFileSurfaceContract;
var
  LCompileGate: string;
  LIocpFileBody: string;
  LPollerFileBody: string;
  LPollerUnsupportedBody: string;
  LLoopFileBody: string;
  LLoopUnsupportedBody: string;
  LLoopFileTimeoutBody: string;
  LLoopUnsupportedTimeoutBody: string;
begin
  LCompileGate := LoadSourceText(
    'tests/nextpas.core.io.uring/test_poller_windows_compile_gate/test_poller_windows_compile_gate.lpr');
  LIocpFileBody := ExtractBetween(LCompileGate,
    'procedure touchiocpreactorfilesurface', 'procedure touchpollerfilesurface');
  LPollerFileBody := ExtractBetween(LCompileGate,
    'procedure touchpollerfilesurface', 'procedure touchpollerunsupportedsurface');
  LPollerUnsupportedBody := ExtractBetween(LCompileGate,
    'procedure touchpollerunsupportedsurface', 'procedure touchasyncloopfilesurface');
  LLoopFileBody := ExtractBetween(LCompileGate,
    'procedure touchasyncloopfilesurface', 'procedure touchasyncloopunsupportedsurface');
  LLoopUnsupportedBody := ExtractBetween(LCompileGate,
    'procedure touchasyncloopunsupportedsurface', 'procedure touchasyncloopfiletimeouts');
  LLoopFileTimeoutBody := ExtractBetween(LCompileGate,
    'procedure touchasyncloopfiletimeouts', 'procedure touchasyncloopunsupportedtimeouts');
  LLoopUnsupportedTimeoutBody := ExtractBetween(LCompileGate,
    'procedure touchasyncloopunsupportedtimeouts', 'procedure touchcompilegate');

  CheckContains(LCompileGate,
    'source-contract and forced-compile only; not windows runtime evidence',
    'Windows compile gate must declare its non-runtime truth layer');
  CheckContains(LCompileGate, 'procedure noopiocompletion',
    'Windows compile gate must force a real completion callback type');

  CheckContains(LIocpFileBody, 'liocp := tiocpreactor.create(8);',
    'Windows compile gate must directly touch IOCP reactor creation');
  CheckContains(LIocpFileBody, 'liocp.asyncread(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must directly touch IOCP file AsyncRead');
  CheckContains(LIocpFileBody, 'liocp.asyncwrite(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must directly touch IOCP file AsyncWrite');
  CheckContains(LIocpFileBody, 'liocp.flush;',
    'Windows compile gate must directly touch IOCP Flush');
  CheckContains(LIocpFileBody, 'liocp.poll;',
    'Windows compile gate must directly touch IOCP Poll');
  CheckContains(LIocpFileBody, 'liocp.pollone;',
    'Windows compile gate must directly touch IOCP PollOne');
  CheckContains(LIocpFileBody, 'liocp.stop;',
    'Windows compile gate must directly touch IOCP Stop');
  CheckContains(LIocpFileBody, 'liocp.close;',
    'Windows compile gate must directly touch IOCP Close');
  CheckAbsent(LIocpFileBody, 'asyncaccept',
    'Windows IOCP file surface gate must not mix accept unsupported truth');
  CheckAbsent(LIocpFileBody, 'asyncconnect',
    'Windows IOCP file surface gate must not mix connect unsupported truth');
  CheckAbsent(LIocpFileBody, 'asyncsend',
    'Windows IOCP file surface gate must not mix send unsupported truth');
  CheckAbsent(LIocpFileBody, 'asyncrecv',
    'Windows IOCP file surface gate must not mix recv unsupported truth');
  CheckAbsent(LIocpFileBody, 'asyncclose',
    'Windows IOCP file surface gate must not mix close unsupported truth');

  CheckContains(LPollerFileBody, 'lpoller.asyncread(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must touch poller file AsyncRead');
  CheckContains(LPollerFileBody, 'lpoller.asyncwrite(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must touch poller file AsyncWrite');
  CheckAbsent(LPollerFileBody, 'asyncaccept',
    'Windows file surface gate must not mix accept unsupported truth');
  CheckAbsent(LPollerFileBody, 'asyncconnect',
    'Windows file surface gate must not mix connect unsupported truth');
  CheckAbsent(LPollerFileBody, 'asyncsend',
    'Windows file surface gate must not mix send unsupported truth');
  CheckAbsent(LPollerFileBody, 'asyncrecv',
    'Windows file surface gate must not mix recv unsupported truth');
  CheckAbsent(LPollerFileBody, 'asyncclose',
    'Windows file surface gate must not mix close unsupported truth');

  CheckContains(LPollerUnsupportedBody, 'lpoller.asyncaccept',
    'Windows compile gate must separately touch poller unsupported accept boundary');
  CheckContains(LPollerUnsupportedBody, 'lpoller.asyncconnect',
    'Windows compile gate must separately touch poller unsupported connect boundary');
  CheckContains(LPollerUnsupportedBody, 'lpoller.asyncsend',
    'Windows compile gate must separately touch poller unsupported send boundary');
  CheckContains(LPollerUnsupportedBody, 'lpoller.asyncrecv',
    'Windows compile gate must separately touch poller unsupported recv boundary');
  CheckContains(LPollerUnsupportedBody, 'lpoller.asyncclose',
    'Windows compile gate must separately touch poller unsupported close boundary');

  CheckContains(LLoopFileBody, 'lloop.asyncread(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must touch async loop direct file AsyncRead');
  CheckContains(LLoopFileBody, 'lloop.asyncwrite(0, nil, 0, 0, @noopiocompletion, nil);',
    'Windows compile gate must touch async loop direct file AsyncWrite');
  CheckContains(LLoopFileBody, 'lloop.poll;',
    'Windows compile gate must touch async loop completion polling facade');
  CheckContains(LLoopFileBody, 'lloop.runonce;',
    'Windows compile gate must touch async loop single-iteration runner');
  CheckContains(LLoopFileBody, 'lloop.close;',
    'Windows compile gate must touch async loop close after file surface calls');
  CheckAbsent(LLoopFileBody, 'asyncaccept',
    'Windows async loop file surface gate must not mix accept unsupported truth');
  CheckAbsent(LLoopFileBody, 'asyncsend',
    'Windows async loop file surface gate must not mix send unsupported truth');
  CheckAbsent(LLoopFileBody, 'asyncrecv',
    'Windows async loop file surface gate must not mix recv unsupported truth');

  CheckContains(LLoopUnsupportedBody, 'lloop.asyncaccept',
    'Windows compile gate must separately touch async loop accept unsupported boundary');
  CheckContains(LLoopUnsupportedBody, 'lloop.asyncrecv',
    'Windows compile gate must separately touch async loop recv unsupported boundary');
  CheckContains(LLoopUnsupportedBody, 'lloop.asyncsend',
    'Windows compile gate must separately touch async loop send unsupported boundary');

  CheckContains(LLoopFileTimeoutBody, 'lloop.asyncreadtimeout',
    'Windows compile gate must touch async loop file read timeout');
  CheckContains(LLoopFileTimeoutBody, 'lloop.asyncwritetimeout',
    'Windows compile gate must touch async loop file write timeout');
  CheckContains(LLoopFileTimeoutBody, 'tdeadline.after(',
    'Windows file timeout gate must compile finite deadlines');
  CheckAbsent(LLoopFileTimeoutBody, 'tdeadline.infinite',
    'Windows file timeout gate must not bypass timeout wrappers');
  CheckAbsent(LLoopFileTimeoutBody, 'asyncrecvtimeout',
    'Windows file timeout gate must not mix recv unsupported truth');
  CheckAbsent(LLoopFileTimeoutBody, 'asyncsendtimeout',
    'Windows file timeout gate must not mix send unsupported truth');

  CheckContains(LLoopUnsupportedTimeoutBody, 'lloop.asyncrecvtimeout',
    'Windows compile gate must separately touch async loop recv timeout unsupported boundary');
  CheckContains(LLoopUnsupportedTimeoutBody, 'lloop.asyncsendtimeout',
    'Windows compile gate must separately touch async loop send timeout unsupported boundary');
  CheckContains(LLoopUnsupportedTimeoutBody, 'tdeadline.after(',
    'Windows unsupported timeout gate must compile finite deadlines');
  CheckAbsent(LLoopUnsupportedTimeoutBody, 'tdeadline.infinite',
    'Windows unsupported timeout gate must not bypass timeout wrappers');
end;

procedure TestAsyncLoopCompletionFacadeParityContract;
var
  LAsyncLoop, LConnectBody, LCloseBody: string;
begin
  LAsyncLoop := LoadSourceText('src/nextpas.core.async.loop.pas');
  LConnectBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.asyncconnect',
    'function tasyncloop.asyncrecv');
  LCloseBody := ExtractBetween(LAsyncLoop, 'function tasyncloop.asyncclose',
    'function tasyncloop.poll');

  CheckContains(LAsyncLoop, 'function asyncconnect(afd: ptrint',
    'async loop must expose the poller AsyncConnect completion facade');
  CheckContains(LAsyncLoop, 'function asyncclose(afd: ptrint',
    'async loop must expose the poller AsyncClose completion facade');
  CheckContains(LConnectBody,
    'result := fpoller.asyncconnect(afd, aaddr, aaddrlen, acallback, acontext);',
    'async loop AsyncConnect must preserve poller unsupported/runtime truth');
  CheckContains(LCloseBody,
    'result := fpoller.asyncclose(afd, acallback, acontext);',
    'async loop AsyncClose must preserve poller unsupported/runtime truth');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.poller.windows_contract');
  T.Run('poller Windows backend contract', @TestPollerWindowsBackendContract);
  T.Run('IOCP lifecycle contract', @TestIocpLifecycleContract);
  T.Run('IOCP run/stop/flush lifecycle contract',
    @TestIocpRunStopFlushLifecycleContract);
  T.Run('async loop run lifecycle contract',
    @TestAsyncLoopRunLifecycleContract);
  T.Run('async loop wake seam contract',
    @TestAsyncLoopWakeSeamContract);
  T.Run('IOCP close abort ownership contract',
    @TestIocpCloseAbortOwnershipContract);
  T.Run('IOCP close/run wake handoff contract',
    @TestIocpCloseRunWakeHandoffContract);
  T.Run('IOCP close abort completion drain ownership contract',
    @TestIocpCloseAbortCompletionDrainOwnershipContract);
  T.Run('async loop timeout close lifecycle contract',
    @TestAsyncLoopTimeoutCloseLifecycleContract);
  T.Run('async loop close stop/wake ownership contract',
    @TestAsyncLoopCloseStopWakeOwnershipContract);
  T.Run('async loop post closed owner-boundary contract',
    @TestAsyncLoopPostClosedOwnerBoundaryContract);
  T.Run('async loop closed timeout owner-boundary contract',
    @TestAsyncLoopClosedTimeoutOwnerBoundaryContract);
  T.Run('async loop timeout single-fire cleanup contract',
    @TestAsyncLoopTimeoutSingleFireCleanupContract);
  T.Run('IOCP synchronous failure ownership contract',
    @TestIocpSynchronousFailureOwnershipContract);
  T.Run('Windows completion FFI ABI contract',
    @TestWindowsCompletionFfiAbiContract);
  T.Run('IOCP closed submit ownership contract',
    @TestIocpClosedSubmitOwnershipContract);
  T.Run('IOCP submit failure ownership contract',
    @TestIocpSubmitFailureOwnershipContract);
  T.Run('IOCP unsupported async ownership contract',
    @TestIocpUnsupportedAsyncOwnershipContract);
  T.Run('IOCP pending operation ownership contract',
    @TestIocpPendingOperationOwnershipContract);
  T.Run('IOCP dispatch single-fire ownership contract',
    @TestIocpDispatchSingleFireOwnershipContract);
  T.Run('IOCP associated handle ownership contract',
    @TestIocpAssociatedHandleOwnershipContract);
  T.Run('Windows handle width contract', @TestPollerWindowsHandleWidthContract);
  T.Run('Windows forced compile async file surface contract',
    @TestWindowsForcedCompileAsyncFileSurfaceContract);
  T.Run('async loop completion facade parity contract',
    @TestAsyncLoopCompletionFacadeParityContract);
  T.Summary;
end.
