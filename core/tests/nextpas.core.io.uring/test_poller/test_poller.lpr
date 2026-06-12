program test_poller;

{$I nextpas.core.settings.inc}

uses
  Classes, SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.poller;

var
  T: TTestRunner;
  GCallbackCount: Int32;
  GLastResult: Int32;
  GLastUserData: UInt64;

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

function CountOccurrences(const ASource, AToken: string): SizeInt;
var
  LPos, LOffset: SizeInt;
begin
  Result := 0;
  LOffset := 1;
  repeat
    LPos := Pos(AToken, Copy(ASource, LOffset, Length(ASource)));
    if LPos = 0 then
      Break;
    Inc(Result);
    Inc(LOffset, LPos + Length(AToken) - 1);
  until False;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

procedure OnComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallbackCount);
  GLastResult := AResult;
  GLastUserData := AUserData;
end;

procedure TestBackendDetection;
var
  LBackend: TPollerBackend;
begin
  LBackend := PollerDetectBackend;
  Check((LBackend = pbIoUring) or (LBackend = pbEpoll),
    'Linux backend is usable io_uring or explicit epoll fallback');
end;

procedure TestBackendUsabilityContract;
var
  LPollerSource: string;
  LProbeBody: string;
  LCreateBody: string;
  LEpollBranch: string;
begin
  LPollerSource := LoadSourceText('src/nextpas.core.io.poller.pas');
  LProbeBody := ExtractBetween(LPollerSource, 'function tryiouringprobe',
    '{$endif}');
  LCreateBody := ExtractBetween(LPollerSource, 'class function tpoller.create',
    'procedure tpoller.close');
  LEpollBranch := ExtractBetween(LCreateBody, 'pbepoll:', '{$endif}');

  CheckEqual(Int64(1), Int64(CountOccurrences(LProbeBody, 'result := true;')),
    'io_uring probe must only report usable truth after a successful setup');
  Check(Pos('lfd >= 0', LProbeBody) > 0,
    'io_uring probe must tie usable truth to an opened setup fd');
  Check(Pos('result := false;', LProbeBody) > 0,
    'io_uring probe must fall back when setup cannot produce a usable fd');
  CheckContains(LCreateBody, 'if not result.furing.isvalid then',
    'poller create must validate the real io_uring queue after probe success');
  CheckContains(LCreateBody, 'result.fbackend := pbepoll;',
    'poller create must switch backend truth to epoll when io_uring create fails');
  CheckContains(LCreateBody, 'result.fepoll := tepollreactor.create(aqueuedepth);',
    'poller create must instantiate epoll fallback after io_uring create failure');
  CheckContains(LCreateBody, 'if not result.fepoll.isvalid then',
    'poller create must stop reporting epoll fallback when fallback create fails');
  CheckContains(LEpollBranch, 'if not result.fepoll.isvalid then',
    'poller create must validate direct epoll backend creation');
  CheckContains(LEpollBranch, 'result.fbackend := pbunsupported;',
    'poller create must stop reporting direct epoll when epoll create fails');
end;

procedure TestAsyncDocsBackendTruthContract;
var
  LDocs: string;
begin
  LDocs := LoadSourceText('docs/async/README.md');

  CheckContains(LDocs, 'io_uring is the linux completion backend',
    'async docs must name the Linux completion backend precisely');
  CheckContains(LDocs, '`pbepoll` is a readiness-backed fallback',
    'async docs must not present epoll as file-completion equivalent');
  CheckContains(LDocs, 'not a completion-equivalent replacement for file i/o',
    'async docs must state the epoll completion limitation');
  CheckContains(LDocs, 'if the real io_uring queue creation fails after probing',
    'async docs must state create-time fallback after probe success');
  CheckContains(LDocs, 'windows runtime ready',
    'async docs must keep Windows runtime readiness truth explicit');
  CheckAbsent(LDocs, 'or any error other than enosys',
    'async docs must not use stale io_uring probe truth');
  CheckAbsent(LDocs, 'application code is identical across supported backends',
    'async docs must not claim identical completion behavior across backends');
end;

procedure TestBackendModelSourceContract;
var
  LPollerSource: string;
  LReadBody: string;
  LWriteBody: string;
begin
  Check(PollerBackendModel(pbIoUring) = pbmCompletionQueue,
    'io_uring backend model is completion queue');
  Check(PollerBackendModel(pbIocp) = pbmCompletionQueue,
    'IOCP backend model is completion queue');
  Check(PollerBackendModel(pbEpoll) = pbmReadiness,
    'epoll backend model is readiness');
  Check(PollerBackendModel(pbUnsupported) = pbmUnsupported,
    'unsupported backend model is unsupported');

  LPollerSource := LoadSourceText('src/nextpas.core.io.poller.pas');

  CheckContains(LPollerSource, 'tpollerbackendmodel',
    'poller must publish readiness/completion backend model');
  CheckContains(LPollerSource, 'pbmcompletionqueue',
    'poller backend model must name completion queue semantics');
  CheckContains(LPollerSource, 'pbmreadiness',
    'poller backend model must name readiness semantics');
  CheckContains(LPollerSource, 'function pollerbackendmodel',
    'poller must expose backend model classifier');
  CheckContains(LPollerSource, 'pbiouring: result := pbmcompletionqueue',
    'io_uring backend must be classified as completion queue');
  CheckContains(LPollerSource, 'pbiocp: result := pbmcompletionqueue',
    'IOCP backend must be classified as completion queue');
  CheckContains(LPollerSource, 'pbepoll: result := pbmreadiness',
    'epoll backend must be classified as readiness');
  CheckAbsent(LPollerSource, 'pbepoll: result := pbmcompletionqueue',
    'epoll readiness fallback must not claim completion queue semantics');

  LReadBody := ExtractBetween(LPollerSource, 'function tpoller.asyncread',
    'function tpoller.asyncwrite');
  LWriteBody := ExtractBetween(LPollerSource, 'function tpoller.asyncwrite',
    'function tpoller.asyncaccept');
  CheckContains(LReadBody, 'if aoffset >= 0 then',
    'epoll readiness fallback must reject positioned file reads');
  CheckContains(LWriteBody, 'if aoffset >= 0 then',
    'epoll readiness fallback must reject positioned file writes');
  CheckContains(LReadBody, 'fepoll.asyncread',
    'epoll readiness fallback may still support stream-style reads');
  CheckContains(LWriteBody, 'fepoll.asyncwrite',
    'epoll readiness fallback may still support stream-style writes');
end;

procedure TestPositionedFileIoCapabilityContract;
var
  LPollerSource: string;
begin
  Check(PollerSupportsPositionedFileIO(pbIoUring),
    'io_uring supports positioned file I/O completion');
  Check(PollerSupportsPositionedFileIO(pbIocp),
    'IOCP supports positioned file I/O completion');
  Check(not PollerSupportsPositionedFileIO(pbEpoll),
    'epoll readiness fallback must not advertise positioned file I/O');
  Check(not PollerSupportsPositionedFileIO(pbUnsupported),
    'unsupported backend must not advertise positioned file I/O');

  LPollerSource := LoadSourceText('src/nextpas.core.io.poller.pas');
  CheckContains(LPollerSource, 'function pollersupportspositionedfileio',
    'poller must expose positioned file I/O capability truth');
  CheckContains(LPollerSource, 'pbiouring: result := true',
    'io_uring positioned file I/O capability must be true');
  CheckContains(LPollerSource, 'pbiocp: result := true',
    'IOCP positioned file I/O capability must be true');
  CheckContains(LPollerSource, 'pbepoll: result := false',
    'epoll readiness fallback positioned file I/O capability must be false');
end;

procedure TestCreateClose;
var
  LP: TPoller;
begin
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'poller valid');
  Check(LP.Backend = PollerDetectBackend, 'backend matches detection');
  LP.Close;
end;

procedure TestAsyncReadWrite;
var
  LP: TPoller;
  LFd: Int32;
  LWriteBuf: array[0..7] of Byte;
  LReadBuf: array[0..7] of Byte;
begin
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'valid');

  LFd := memfd_create('poller_rw', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd');
  if PollerBackendModel(LP.Backend) <> pbmCompletionQueue then
  begin
    Check(not LP.AsyncWrite(LFd, @LWriteBuf[0], 4, 0, @OnComplete, nil),
      'readiness backend rejects positioned file write');
    Check(not LP.AsyncRead(LFd, @LReadBuf[0], 4, 0, @OnComplete, nil),
      'readiness backend rejects positioned file read');
    FpClose(LFd);
    LP.Close;
    Exit;
  end;

  LWriteBuf[0] := $DE; LWriteBuf[1] := $AD;
  LWriteBuf[2] := $BE; LWriteBuf[3] := $EF;

  { Async write }
  GCallbackCount := 0;
  Check(LP.AsyncWrite(LFd, @LWriteBuf[0], 4, 0, @OnComplete, nil), 'write queued');
  LP.Flush;
  while GCallbackCount = 0 do LP.PollOne;
  Check(GLastResult = 4, 'wrote 4 bytes');

  { Async read }
  FillChar(LReadBuf, 8, 0);
  GCallbackCount := 0;
  Check(LP.AsyncRead(LFd, @LReadBuf[0], 4, 0, @OnComplete, nil), 'read queued');
  LP.Flush;
  while GCallbackCount = 0 do LP.PollOne;
  Check(GLastResult = 4, 'read 4 bytes');
  Check((LReadBuf[0] = $DE) and (LReadBuf[1] = $AD) and
        (LReadBuf[2] = $BE) and (LReadBuf[3] = $EF), 'data matches');

  FpClose(LFd);
  LP.Close;
end;

procedure TestMultipleAsync;
var
  LP: TPoller;
  LFd: Int32;
  LBufs: array[0..3] of array[0..3] of Byte;
  LI: Int32;
begin
  LP := TPoller.Create(32);
  Check(LP.IsValid, 'valid');

  LFd := memfd_create('poller_multi', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd');
  if PollerBackendModel(LP.Backend) <> pbmCompletionQueue then
  begin
    Check(not LP.AsyncWrite(LFd, @LBufs[0][0], 2, 0, @OnComplete, nil),
      'readiness backend rejects positioned batch file write');
    FpClose(LFd);
    LP.Close;
    Exit;
  end;

  { Queue 4 writes at different offsets }
  GCallbackCount := 0;
  for LI := 0 to 3 do
  begin
    LBufs[LI][0] := Byte(LI + 1);
    LBufs[LI][1] := Byte((LI + 1) * 10);
    Check(LP.AsyncWrite(LFd, @LBufs[LI][0], 2, Int64(LI * 2), @OnComplete, nil),
      'write ' + IntToStr(LI));
  end;
  LP.Flush;

  while GCallbackCount < 4 do LP.PollOne;
  CheckEqual(Int64(4), Int64(GCallbackCount), '4 write callbacks');

  { Read back and verify }
  GCallbackCount := 0;
  FillChar(LBufs, SizeOf(LBufs), 0);
  for LI := 0 to 3 do
    Check(LP.AsyncRead(LFd, @LBufs[LI][0], 2, Int64(LI * 2), @OnComplete, nil),
      'read ' + IntToStr(LI));
  LP.Flush;

  while GCallbackCount < 4 do LP.PollOne;
  CheckEqual(Int64(4), Int64(GCallbackCount), '4 read callbacks');

  for LI := 0 to 3 do
  begin
    Check(LBufs[LI][0] = Byte(LI + 1), 'buf[' + IntToStr(LI) + '][0]');
    Check(LBufs[LI][1] = Byte((LI + 1) * 10), 'buf[' + IntToStr(LI) + '][1]');
  end;

  FpClose(LFd);
  LP.Close;
end;

procedure TestPollBatch;
var
  LP: TPoller;
  LFd: Int32;
  LBuf: array[0..31] of Byte;
  LCount, LPolled: Int32;
begin
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'valid');

  LFd := memfd_create('poller_batch', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd');
  if PollerBackendModel(LP.Backend) <> pbmCompletionQueue then
  begin
    Check(not LP.AsyncWrite(LFd, @LBuf[0], 4, 0, @OnComplete, nil),
      'readiness backend rejects positioned poll batch file write');
    FpClose(LFd);
    LP.Close;
    Exit;
  end;

  { Queue 3 writes }
  GCallbackCount := 0;
  FillChar(LBuf, SizeOf(LBuf), $AA);
  LP.AsyncWrite(LFd, @LBuf[0], 4, 0, @OnComplete, nil);
  LP.AsyncWrite(LFd, @LBuf[4], 4, 4, @OnComplete, nil);
  LP.AsyncWrite(LFd, @LBuf[8], 4, 8, @OnComplete, nil);
  LP.Flush;

  { Use Poll (batch) — may need multiple iterations for completions to arrive }
  LCount := 0;
  while GCallbackCount < 3 do
  begin
    LPolled := LP.Poll;
    if LPolled = 0 then
      LP.PollOne; { fallback: PollOne may trigger submit-and-wait on io_uring }
    Inc(LCount);
    if LCount > 1000 then Break;
  end;

  CheckEqual(Int64(3), Int64(GCallbackCount), '3 via poll batch');

  FpClose(LFd);
  LP.Close;
end;

procedure TestContextPassing;
var
  LP: TPoller;
  LFd: Int32;
  LBuf: array[0..3] of Byte;
  LCtx: Int32;
begin
  LCtx := 0;
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'valid');

  LFd := memfd_create('poller_ctx', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd');
  if PollerBackendModel(LP.Backend) <> pbmCompletionQueue then
  begin
    Check(not LP.AsyncWrite(LFd, @LBuf[0], 4, 0,
      procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)
      begin
        PInt32(AContext)^ := 99;
      end, @LCtx), 'readiness backend rejects positioned context file write');
    FpClose(LFd);
    LP.Close;
    Exit;
  end;

  FillChar(LBuf, 4, $BB);
  LP.AsyncWrite(LFd, @LBuf[0], 4, 0,
    procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)
    begin
      PInt32(AContext)^ := 99;
    end, @LCtx);
  LP.Flush;
  while LCtx = 0 do LP.PollOne;

  CheckEqual(Int64(99), Int64(LCtx), 'context passed correctly');

  FpClose(LFd);
  LP.Close;
end;

procedure TestPipeReadWrite;
var
  LP: TPoller;
  LPipeFd: array[0..1] of Int32;
  LWriteBuf: array[0..7] of Byte;
  LReadBuf: array[0..7] of Byte;
begin
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'valid');

  Check(nextpas.core.platform.posix.ffi.pipe(@LPipeFd[0]) = 0, 'pipe created');

  LWriteBuf[0] := $CA; LWriteBuf[1] := $FE;
  LWriteBuf[2] := $BA; LWriteBuf[3] := $BE;

  { Write to pipe }
  GCallbackCount := 0;
  Check(LP.AsyncWrite(LPipeFd[1], @LWriteBuf[0], 4, -1, @OnComplete, nil), 'pipe write queued');
  LP.Flush;
  while GCallbackCount = 0 do LP.PollOne;
  Check(GLastResult = 4, 'pipe wrote 4');

  { Read from pipe }
  FillChar(LReadBuf, 8, 0);
  GCallbackCount := 0;
  Check(LP.AsyncRead(LPipeFd[0], @LReadBuf[0], 4, -1, @OnComplete, nil), 'pipe read queued');
  LP.Flush;
  while GCallbackCount = 0 do LP.PollOne;
  Check(GLastResult = 4, 'pipe read 4');
  Check((LReadBuf[0] = $CA) and (LReadBuf[1] = $FE) and
        (LReadBuf[2] = $BA) and (LReadBuf[3] = $BE), 'pipe data matches');

  FpClose(LPipeFd[0]);
  FpClose(LPipeFd[1]);
  LP.Close;
end;

procedure TestHasPending;
var
  LP: TPoller;
  LPipeFd: array[0..1] of Int32;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  LP := TPoller.Create(16);
  Check(LP.IsValid, 'valid');
  Check(not LP.HasPending, 'new poller has no pending operations');

  Check(nextpas.core.platform.posix.ffi.pipe(@LPipeFd[0]) = 0, 'pipe created');
  try
    GCallbackCount := 0;
    FillChar(LReadBuf, SizeOf(LReadBuf), 0);
    Check(LP.AsyncRead(LPipeFd[0], @LReadBuf[0], 4, -1, @OnComplete, nil),
      'pipe read queued');
    LP.Flush;
    Check(LP.HasPending, 'queued read is pending before pipe becomes readable');

    LWriteBuf[0] := $11;
    LWriteBuf[1] := $22;
    LWriteBuf[2] := $33;
    LWriteBuf[3] := $44;
    Check(FpWrite(LPipeFd[1], @LWriteBuf[0], SizeOf(LWriteBuf)) = SizeOf(LWriteBuf),
      'pipe write makes read ready');
    while GCallbackCount = 0 do
      LP.PollOne;

    CheckEqual(Int64(4), Int64(GLastResult), 'pending read completed');
    Check(not LP.HasPending, 'completed read clears pending state');
  finally
    FpClose(LPipeFd[0]);
    FpClose(LPipeFd[1]);
    LP.Close;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.io.poller');
  T.Run('Backend detection', @TestBackendDetection);
  T.Run('Backend usability contract', @TestBackendUsabilityContract);
  T.Run('Async docs backend truth contract', @TestAsyncDocsBackendTruthContract);
  T.Run('Backend model source contract', @TestBackendModelSourceContract);
  T.Run('Positioned file I/O capability contract',
    @TestPositionedFileIoCapabilityContract);
  T.Run('Create/Close', @TestCreateClose);
  T.Run('Async Read/Write (memfd)', @TestAsyncReadWrite);
  T.Run('Multiple async ops', @TestMultipleAsync);
  T.Run('Poll batch', @TestPollBatch);
  T.Run('Context passing', @TestContextPassing);
  T.Run('Pipe Read/Write', @TestPipeReadWrite);
  T.Run('HasPending', @TestHasPending);
  T.Summary;
end.
