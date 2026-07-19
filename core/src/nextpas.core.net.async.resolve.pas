unit nextpas.core.net.async.resolve;
{**
 * @desc 异步 DNS 解析：集成事件循环的非阻塞 DNS 解析。
 *       AsyncResolve: 单 worker + AF_UNSPEC multi-A（兼容路径）。
 *       AsyncResolveEx: 并行 A/AAAA（RFC8305 Resolution Delay 子集）。
 *       注意：使用此模块的程序需要在 uses 中包含 cthreads。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.async.base, nextpas.core.async.loop;

const
  { RFC8305 default Resolution Delay (ms) before using first-family-only. }
  DNS_DEFAULT_RESOLUTION_DELAY_MS = 50;

type
  { DNS 解析结果 }
  TDnsResult = record
    Addresses: array of TNetAddress;
    Error: Int32;
    function Success: Boolean; inline;
    function FirstAddress: TNetAddress;
  end;

  { DNS 解析回调 }
  TDnsCallback = procedure(const AResult: TDnsResult; AContext: Pointer);
  TDnsCallbackRef = reference to procedure(const AResult: TDnsResult; AContext: Pointer);

  TDnsResolveOptions = record
    ResolutionDelayMs: UInt32; { default DNS_DEFAULT_RESOLUTION_DELAY_MS }
    PreferIPv6First: Boolean;  { merge order: prefer v6 then v4 if True }
  end;

function DefaultDnsResolveOptions: TDnsResolveOptions;

{ 异步 DNS 解析（单次 AF_UNSPEC getaddrinfo，兼容） }
function AsyncResolve(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; AContext: Pointer = nil): Boolean;

function AsyncResolveRef(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallbackRef; AContext: Pointer = nil): Boolean;

{ 并行 A + AAAA + Resolution Delay（RFC8305 §3 简化） }
function AsyncResolveEx(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallback;
  AContext: Pointer = nil): Boolean;

function AsyncResolveExRef(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallbackRef;
  AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.platform.socket,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread;

type

  PDnsContext = ^TDnsContext;
  TDnsContext = record
    Host: AnsiString;
    Loop: TAsyncLoop;
    Callback: TDnsCallback;
    CallbackRef: TDnsCallbackRef;
    Context: Pointer;
  end;

  PDnsPostContext = ^TDnsPostContext;
  TDnsPostContext = record
    Loop: TAsyncLoop;
    Callback: TDnsCallback;
    CallbackRef: TDnsCallbackRef;
    Context: Pointer;
    Result: TDnsResult;
  end;

  { Parallel family worker shares parent slot via AFamily tag. }
  PDnsFamilyWorker = ^TDnsFamilyWorker;
  TDnsFamilyWorker = record
    Parent: Pointer; { PDnsParallelCtx }
    Family: Int32;   { PLATFORM_AF_INET or PLATFORM_AF_INET6 }
  end;

  PDnsParallelCtx = ^TDnsParallelCtx;
  TDnsParallelCtx = record
    Host: AnsiString;
    Loop: TAsyncLoop;
    Callback: TDnsCallback;
    CallbackRef: TDnsCallbackRef;
    Context: Pointer;
    ResolutionDelayMs: UInt32;
    PreferIPv6First: Boolean;
    V4Raw: array[0..PLATFORM_RESOLVE_MAX - 1] of TPlatformResolvedAddr;
    V6Raw: array[0..PLATFORM_RESOLVE_MAX - 1] of TPlatformResolvedAddr;
    V4Count: Int32;
    V6Count: Int32;
    V4Err: Int32;
    V6Err: Int32;
    V4Done: Int32;
    V6Done: Int32;
  end;

function TDnsResult.Success: Boolean;
begin
  Result := (Error = 0) and (Length(Addresses) > 0);
end;

function TDnsResult.FirstAddress: TNetAddress;
begin
  if Length(Addresses) > 0 then
    Result := Addresses[0]
  else
    Result := Default(TNetAddress);
end;

function DefaultDnsResolveOptions: TDnsResolveOptions;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ResolutionDelayMs := DNS_DEFAULT_RESOLUTION_DELAY_MS;
  Result.PreferIPv6First := False;
end;

procedure DiscardDnsPostCtx(AContext: Pointer);
begin
  if AContext <> nil then
    Dispose(PDnsPostContext(AContext));
end;

procedure DnsPostCallback(AContext: Pointer);
var
  LPostCtx: PDnsPostContext;
begin
  LPostCtx := PDnsPostContext(AContext);
  try
    if Assigned(LPostCtx^.Callback) then
      LPostCtx^.Callback(LPostCtx^.Result, LPostCtx^.Context)
    else if Assigned(LPostCtx^.CallbackRef) then
      LPostCtx^.CallbackRef(LPostCtx^.Result, LPostCtx^.Context);
  finally
    Dispose(LPostCtx);
  end;
end;

function FormatIPv6Addr(AAddr: PByte): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
  LGroup: UInt16;
  LBuf: array[0..39] of Char;
  LPos: Integer;
begin
  LPos := 0;
  for I := 0 to 7 do
  begin
    LGroup := (UInt16(AAddr[I * 2]) shl 8) or UInt16(AAddr[I * 2 + 1]);
    if I > 0 then
    begin
      LBuf[LPos] := ':';
      Inc(LPos);
    end;
    LBuf[LPos] := HexChars[(LGroup shr 12) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[(LGroup shr 8) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[(LGroup shr 4) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[LGroup and $F]; Inc(LPos);
  end;
  SetString(Result, @LBuf[0], LPos);
end;

{ sin_addr.s_addr is network byte order; on LE print low byte first. }
function IPv4NetToString(ANet: UInt32): string;
begin
  Result := IntToStr(ANet and $FF) + '.' +
    IntToStr((ANet shr 8) and $FF) + '.' +
    IntToStr((ANet shr 16) and $FF) + '.' +
    IntToStr((ANet shr 24) and $FF);
end;

function IsIPv4Literal(const AHost: AnsiString): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if (Length(AHost) = 0) or (Pos(':', AHost) > 0) then
    Exit;
  for LI := 1 to Length(AHost) do
    if not (AHost[LI] in ['0'..'9', '.']) then
      Exit;
  Result := True;
end;

procedure AppendRawAddrs(var AResult: TDnsResult; ARaw: PPlatformResolvedAddr;
  ACount: Int32; AIsIPv6: Boolean);
var
  LI, LBase: Integer;
  LDst: Integer;
begin
  if ACount <= 0 then
    Exit;
  LBase := Length(AResult.Addresses);
  SetLength(AResult.Addresses, LBase + ACount);
  LDst := LBase;
  for LI := 0 to ACount - 1 do
  begin
    if AIsIPv6 then
    begin
      AResult.Addresses[LDst].IP := FormatIPv6Addr(@ARaw[LI].IPv6[0]);
      AResult.Addresses[LDst].IsIPv6 := True;
    end
    else
    begin
      AResult.Addresses[LDst].IP := IPv4NetToString(ARaw[LI].IPv4);
      AResult.Addresses[LDst].IsIPv6 := False;
    end;
    AResult.Addresses[LDst].Port := 0;
    Inc(LDst);
  end;
end;

procedure MergeSortedV4V6(var AResult: TDnsResult;
  ARaw: PPlatformResolvedAddr; ACount: Int32; APreferV6: Boolean);
var
  LI, LJdx, LTotal: Integer;
begin
  LTotal := 0;
  for LI := 0 to ACount - 1 do
    Inc(LTotal);
  SetLength(AResult.Addresses, LTotal);
  LJdx := 0;
  if not APreferV6 then
  begin
    for LI := 0 to ACount - 1 do
      if not ARaw[LI].IsIPv6 then
      begin
        AResult.Addresses[LJdx].IP := IPv4NetToString(ARaw[LI].IPv4);
        AResult.Addresses[LJdx].Port := 0;
        AResult.Addresses[LJdx].IsIPv6 := False;
        Inc(LJdx);
      end;
    for LI := 0 to ACount - 1 do
      if ARaw[LI].IsIPv6 then
      begin
        AResult.Addresses[LJdx].IP := FormatIPv6Addr(@ARaw[LI].IPv6[0]);
        AResult.Addresses[LJdx].Port := 0;
        AResult.Addresses[LJdx].IsIPv6 := True;
        Inc(LJdx);
      end;
  end
  else
  begin
    for LI := 0 to ACount - 1 do
      if ARaw[LI].IsIPv6 then
      begin
        AResult.Addresses[LJdx].IP := FormatIPv6Addr(@ARaw[LI].IPv6[0]);
        AResult.Addresses[LJdx].Port := 0;
        AResult.Addresses[LJdx].IsIPv6 := True;
        Inc(LJdx);
      end;
    for LI := 0 to ACount - 1 do
      if not ARaw[LI].IsIPv6 then
      begin
        AResult.Addresses[LJdx].IP := IPv4NetToString(ARaw[LI].IPv4);
        AResult.Addresses[LJdx].Port := 0;
        AResult.Addresses[LJdx].IsIPv6 := False;
        Inc(LJdx);
      end;
  end;
  SetLength(AResult.Addresses, LJdx);
end;

procedure PostDnsResult(const ALoop: TAsyncLoop; ACallback: TDnsCallback;
  ACallbackRef: TDnsCallbackRef; AContext: Pointer; const AResult: TDnsResult);
var
  LPostCtx: PDnsPostContext;
begin
  New(LPostCtx);
  LPostCtx^.Loop := ALoop;
  LPostCtx^.Callback := ACallback;
  LPostCtx^.CallbackRef := ACallbackRef;
  LPostCtx^.Context := AContext;
  LPostCtx^.Result := AResult;
  ALoop.PostEx(@DnsPostCallback, LPostCtx, @DiscardDnsPostCtx);
end;

function DnsResolveThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PDnsContext;
  LResult: TDnsResult;
  LRaw: array[0..PLATFORM_RESOLVE_MAX - 1] of TPlatformResolvedAddr;
  LCount: Int32;
  LRes: Int32;
begin
  Result := nil;
  LCtx := PDnsContext(AParam);
  try
    FillChar(LResult, SizeOf(LResult), 0);
    SetLength(LResult.Addresses, 0);

    { Fast path: IPv4 literal without DNS }
    if IsIPv4Literal(LCtx^.Host) then
    begin
      LResult.Error := 0;
      SetLength(LResult.Addresses, 1);
      LResult.Addresses[0].IP := string(LCtx^.Host);
      LResult.Addresses[0].Port := 0;
      LResult.Addresses[0].IsIPv6 := False;
      PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context,
        LResult);
      Exit;
    end;

    LRes := platform_socket_resolve_stream(PAnsiChar(LCtx^.Host), @LRaw[0],
      PLATFORM_RESOLVE_MAX, LCount);
    if (LRes = 0) and (LCount > 0) then
    begin
      LResult.Error := 0;
      MergeSortedV4V6(LResult, @LRaw[0], LCount, False);
    end
    else
    begin
      LResult.Error := LRes;
      if LResult.Error = 0 then
        LResult.Error := PLATFORM_ERR_INVALID;
      SetLength(LResult.Addresses, 0);
    end;

    PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context,
      LResult);
  finally
    Dispose(LCtx);
  end;
end;

function DnsFamilyWorkerThread(AParam: Pointer): Pointer; cdecl;
var
  LWorker: PDnsFamilyWorker;
  LParent: PDnsParallelCtx;
  LRes: Int32;
  LCount: Int32;
begin
  Result := nil;
  LWorker := PDnsFamilyWorker(AParam);
  LParent := PDnsParallelCtx(LWorker^.Parent);
  try
    if LWorker^.Family = PLATFORM_AF_INET then
    begin
      LRes := platform_socket_resolve_stream_family(PAnsiChar(LParent^.Host),
        PLATFORM_AF_INET, @LParent^.V4Raw[0], PLATFORM_RESOLVE_MAX, LCount);
      LParent^.V4Count := LCount;
      LParent^.V4Err := LRes;
      AtomicStore32(LParent^.V4Done, 1, moRelease);
    end
    else
    begin
      LRes := platform_socket_resolve_stream_family(PAnsiChar(LParent^.Host),
        PLATFORM_AF_INET6, @LParent^.V6Raw[0], PLATFORM_RESOLVE_MAX, LCount);
      LParent^.V6Count := LCount;
      LParent^.V6Err := LRes;
      AtomicStore32(LParent^.V6Done, 1, moRelease);
    end;
  finally
    Dispose(LWorker);
  end;
end;

function DnsParallelCoordinator(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PDnsParallelCtx;
  LResult: TDnsResult;
  LWorker4, LWorker6: PDnsFamilyWorker;
  LHandle4, LHandle6: TPlatformThreadHandle;
  LWaitedMs: UInt32;
  LFirstDone: Boolean;
  LBothDone: Boolean;
  LOk4, LOk6: Boolean;
  LSpawnOk: Boolean;
begin
  Result := nil;
  LCtx := PDnsParallelCtx(AParam);
  try
    FillChar(LResult, SizeOf(LResult), 0);
    SetLength(LResult.Addresses, 0);

    if IsIPv4Literal(LCtx^.Host) then
    begin
      LResult.Error := 0;
      SetLength(LResult.Addresses, 1);
      LResult.Addresses[0].IP := string(LCtx^.Host);
      LResult.Addresses[0].Port := 0;
      LResult.Addresses[0].IsIPv6 := False;
      PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context,
        LResult);
      Exit;
    end;

    LCtx^.V4Count := 0;
    LCtx^.V6Count := 0;
    LCtx^.V4Err := PLATFORM_ERR_INVALID;
    LCtx^.V6Err := PLATFORM_ERR_INVALID;
    AtomicStore32(LCtx^.V4Done, 0, moRelease);
    AtomicStore32(LCtx^.V6Done, 0, moRelease);

    New(LWorker4);
    LWorker4^.Parent := LCtx;
    LWorker4^.Family := PLATFORM_AF_INET;
    New(LWorker6);
    LWorker6^.Parent := LCtx;
    LWorker6^.Family := PLATFORM_AF_INET6;

    FillChar(LHandle4, SizeOf(LHandle4), 0);
    FillChar(LHandle6, SizeOf(LHandle6), 0);
    LSpawnOk := True;
    if platform_thread_create(LHandle4, @DnsFamilyWorkerThread, LWorker4) <> 0 then
    begin
      Dispose(LWorker4);
      LWorker4 := nil;
      AtomicStore32(LCtx^.V4Done, 1, moRelease);
      LCtx^.V4Err := PLATFORM_ERR_INVALID;
      LSpawnOk := False;
    end
    else
      platform_thread_detach(LHandle4);

    if platform_thread_create(LHandle6, @DnsFamilyWorkerThread, LWorker6) <> 0 then
    begin
      Dispose(LWorker6);
      LWorker6 := nil;
      AtomicStore32(LCtx^.V6Done, 1, moRelease);
      LCtx^.V6Err := PLATFORM_ERR_INVALID;
      LSpawnOk := False;
    end
    else
      platform_thread_detach(LHandle6);

    { Wait: both done, or first family + ResolutionDelay elapsed. }
    LWaitedMs := 0;
    LFirstDone := False;
    while True do
    begin
      LBothDone := (AtomicLoad32(LCtx^.V4Done, moAcquire) <> 0) and
        (AtomicLoad32(LCtx^.V6Done, moAcquire) <> 0);
      if LBothDone then
        Break;
      if not LFirstDone then
      begin
        if (AtomicLoad32(LCtx^.V4Done, moAcquire) <> 0) or
           (AtomicLoad32(LCtx^.V6Done, moAcquire) <> 0) then
        begin
          LFirstDone := True;
          LWaitedMs := 0;
        end;
      end
      else if LWaitedMs >= LCtx^.ResolutionDelayMs then
        Break; { partial OK; still join workers below }
      platform_thread_sleep_ms(1);
      if LFirstDone then
        Inc(LWaitedMs)
      else
        Inc(LWaitedMs); { pre-first wait also capped }
      if LWaitedMs > 60000 then
        Break;
    end;

    { Snapshot whatever families finished (RFC: may proceed with first family). }
    LOk4 := (AtomicLoad32(LCtx^.V4Done, moAcquire) <> 0) and
      (LCtx^.V4Err = 0) and (LCtx^.V4Count > 0);
    LOk6 := (AtomicLoad32(LCtx^.V6Done, moAcquire) <> 0) and
      (LCtx^.V6Err = 0) and (LCtx^.V6Count > 0);

    if LOk4 or LOk6 then
    begin
      LResult.Error := 0;
      if LCtx^.PreferIPv6First then
      begin
        if LOk6 then
          AppendRawAddrs(LResult, @LCtx^.V6Raw[0], LCtx^.V6Count, True);
        if LOk4 then
          AppendRawAddrs(LResult, @LCtx^.V4Raw[0], LCtx^.V4Count, False);
      end
      else
      begin
        if LOk4 then
          AppendRawAddrs(LResult, @LCtx^.V4Raw[0], LCtx^.V4Count, False);
        if LOk6 then
          AppendRawAddrs(LResult, @LCtx^.V6Raw[0], LCtx^.V6Count, True);
      end;
    end
    else
    begin
      { Prefer a finished family's error; else invalid. }
      if AtomicLoad32(LCtx^.V4Done, moAcquire) <> 0 then
        LResult.Error := LCtx^.V4Err
      else if AtomicLoad32(LCtx^.V6Done, moAcquire) <> 0 then
        LResult.Error := LCtx^.V6Err
      else
        LResult.Error := PLATFORM_ERR_INVALID;
      if LResult.Error = 0 then
        LResult.Error := PLATFORM_ERR_INVALID;
      SetLength(LResult.Addresses, 0);
    end;

    if not LSpawnOk and not LResult.Success then
      if LResult.Error = 0 then
        LResult.Error := PLATFORM_ERR_INVALID;

    PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context,
      LResult);

    { Join workers before free (workers may still write V* fields). }
    LWaitedMs := 0;
    while (AtomicLoad32(LCtx^.V4Done, moAcquire) = 0) or
          (AtomicLoad32(LCtx^.V6Done, moAcquire) = 0) do
    begin
      platform_thread_sleep_ms(1);
      Inc(LWaitedMs);
      if LWaitedMs > 60000 then
        Break;
    end;
  finally
    Dispose(LCtx);
  end;
end;

function StartResolveThread(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; ACallbackRef: TDnsCallbackRef;
  AContext: Pointer): Boolean;
var
  LCtx: PDnsContext;
  LHandle: TPlatformThreadHandle;
begin
  Result := False;
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async resolve: loop not valid');

  New(LCtx);
  LCtx^.Host := AHost;
  LCtx^.Loop := ALoop;
  LCtx^.Callback := ACallback;
  LCtx^.CallbackRef := ACallbackRef;
  LCtx^.Context := AContext;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @DnsResolveThread, LCtx) <> 0 then
  begin
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

function StartResolveExThread(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallback;
  ACallbackRef: TDnsCallbackRef; AContext: Pointer): Boolean;
var
  LCtx: PDnsParallelCtx;
  LHandle: TPlatformThreadHandle;
begin
  Result := False;
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async resolve: loop not valid');

  New(LCtx);
  { Do not FillChar — Host is a managed string. }
  LCtx^.Host := AHost;
  LCtx^.Loop := ALoop;
  LCtx^.Callback := ACallback;
  LCtx^.CallbackRef := ACallbackRef;
  LCtx^.Context := AContext;
  LCtx^.ResolutionDelayMs := AOptions.ResolutionDelayMs;
  LCtx^.PreferIPv6First := AOptions.PreferIPv6First;
  LCtx^.V4Count := 0;
  LCtx^.V6Count := 0;
  LCtx^.V4Err := 0;
  LCtx^.V6Err := 0;
  LCtx^.V4Done := 0;
  LCtx^.V6Done := 0;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @DnsParallelCoordinator, LCtx) <> 0 then
  begin
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

function AsyncResolve(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; AContext: Pointer): Boolean;
begin
  Result := StartResolveThread(ALoop, AHost, ACallback, nil, AContext);
end;

function AsyncResolveRef(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallbackRef; AContext: Pointer): Boolean;
begin
  Result := StartResolveThread(ALoop, AHost, nil, ACallback, AContext);
end;

function AsyncResolveEx(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallback;
  AContext: Pointer): Boolean;
begin
  Result := StartResolveExThread(ALoop, AHost, AOptions, ACallback, nil, AContext);
end;

function AsyncResolveExRef(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallbackRef;
  AContext: Pointer): Boolean;
begin
  Result := StartResolveExThread(ALoop, AHost, AOptions, nil, ACallback, AContext);
end;

end.
