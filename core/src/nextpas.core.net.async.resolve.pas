unit nextpas.core.net.async.resolve;
{**
 * @desc 异步 DNS 解析：集成事件循环的非阻塞 DNS 解析。
 *       AsyncResolve: 单 worker + AF_UNSPEC multi-A（兼容路径）。
 *       AsyncResolveEx: 并行 A/AAAA + Resolution Delay，一次回调。
 *       AsyncResolveStream: 并行 A/AAAA，按家族增量回调（DNS-race 用）。
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
    { 双栈选址：True=先 A 再退第一条；False=先 AAAA 再退第一条。 }
    function PreferredAddress(APreferIPv4: Boolean = True): TNetAddress;
  end;

  { DNS 解析回调 }
  TDnsCallback = procedure(const AResult: TDnsResult; AContext: Pointer);
  TDnsCallbackRef = reference to procedure(const AResult: TDnsResult; AContext: Pointer);

  TDnsResolveOptions = record
    ResolutionDelayMs: UInt32; { default DNS_DEFAULT_RESOLUTION_DELAY_MS }
    PreferIPv6First: Boolean;  { merge order: prefer v6 then v4 if True }
  end;

  { 增量 DNS 事件：每家族最多一次 batch；最后一次 AllDone=True }
  TDnsStreamEvent = record
    Addresses: array of TNetAddress;
    IsIPv6: Boolean;
    Error: Int32;
    AllDone: Boolean;
  end;
  TDnsStreamCallback = procedure(const AEvent: TDnsStreamEvent; AContext: Pointer);

function DefaultDnsResolveOptions: TDnsResolveOptions;

function AsyncResolve(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; AContext: Pointer = nil): Boolean;

function AsyncResolveRef(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallbackRef; AContext: Pointer = nil): Boolean;

function AsyncResolveEx(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallback;
  AContext: Pointer = nil): Boolean;

function AsyncResolveExRef(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallbackRef;
  AContext: Pointer = nil): Boolean;

{ 并行 A/AAAA；Resolution Delay 后门控首投递，第二家族再投递。DNS-race 用。 }
function AsyncResolveStream(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsStreamCallback;
  AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.net.resolve,
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

  PDnsStreamPostContext = ^TDnsStreamPostContext;
  TDnsStreamPostContext = record
    Loop: TAsyncLoop;
    Callback: TDnsStreamCallback;
    Context: Pointer;
    Event: TDnsStreamEvent;
  end;

  PDnsFamilyWorker = ^TDnsFamilyWorker;
  TDnsFamilyWorker = record
    Parent: Pointer;
    Family: Int32;
  end;

  PDnsParallelCtx = ^TDnsParallelCtx;
  TDnsParallelCtx = record
    Host: AnsiString;
    Loop: TAsyncLoop;
    Callback: TDnsCallback;
    CallbackRef: TDnsCallbackRef;
    StreamCallback: TDnsStreamCallback;
    Context: Pointer;
    ResolutionDelayMs: UInt32;
    PreferIPv6First: Boolean;
    Streaming: Boolean;
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

function TDnsResult.PreferredAddress(APreferIPv4: Boolean): TNetAddress;
var
  LI: Integer;
begin
  Result := Default(TNetAddress);
  if APreferIPv4 then
  begin
    for LI := 0 to High(Addresses) do
      if not Addresses[LI].IsIPv6 then
        Exit(Addresses[LI]);
  end
  else
  begin
    for LI := 0 to High(Addresses) do
      if Addresses[LI].IsIPv6 then
        Exit(Addresses[LI]);
  end;
  if Length(Addresses) > 0 then
    Result := Addresses[0];
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

procedure DiscardDnsStreamPostCtx(AContext: Pointer);
var
  LPostCtx: PDnsStreamPostContext;
begin
  if AContext = nil then
    Exit;
  LPostCtx := PDnsStreamPostContext(AContext);
  SetLength(LPostCtx^.Event.Addresses, 0);
  Dispose(LPostCtx);
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

procedure DnsStreamPostCallback(AContext: Pointer);
var
  LPostCtx: PDnsStreamPostContext;
begin
  LPostCtx := PDnsStreamPostContext(AContext);
  try
    if Assigned(LPostCtx^.Callback) then
      LPostCtx^.Callback(LPostCtx^.Event, LPostCtx^.Context);
  finally
    SetLength(LPostCtx^.Event.Addresses, 0);
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

function IPv4NetToString(ANet: UInt32): string;
begin
  Result := IntToStr(ANet and $FF) + '.' +
    IntToStr((ANet shr 8) and $FF) + '.' +
    IntToStr((ANet shr 16) and $FF) + '.' +
    IntToStr((ANet shr 24) and $FF);
end;

function TryFillIpLiteral(const AHost: AnsiString; var AResult: TDnsResult): Boolean;
var
  H: string;
begin
  Result := False;
  H := StripHostBrackets(string(AHost));
  if not HostIsIpLiteral(H) then
    Exit;
  AResult.Error := 0;
  SetLength(AResult.Addresses, 1);
  if IsIPv6Literal(H) then
    AResult.Addresses[0] := TNetAddress.IPv6(H, 0)
  else
    AResult.Addresses[0] := TNetAddress.IPv4(H, 0);
  Result := True;
end;

procedure AppendRawAddrs(var AResult: TDnsResult; ARaw: PPlatformResolvedAddr;
  ACount: Int32; AIsIPv6: Boolean);
var
  LI, LBase, LDst: Integer;
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
  LI, LJdx: Integer;
begin
  SetLength(AResult.Addresses, ACount);
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

procedure PostDnsStreamEvent(const ALoop: TAsyncLoop; ACallback: TDnsStreamCallback;
  AContext: Pointer; const AEvent: TDnsStreamEvent);
var
  LPostCtx: PDnsStreamPostContext;
begin
  New(LPostCtx);
  LPostCtx^.Loop := ALoop;
  LPostCtx^.Callback := ACallback;
  LPostCtx^.Context := AContext;
  LPostCtx^.Event := AEvent;
  ALoop.PostEx(@DnsStreamPostCallback, LPostCtx, @DiscardDnsStreamPostCtx);
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
    LResult := Default(TDnsResult);
    SetLength(LResult.Addresses, 0);
    if TryFillIpLiteral(LCtx^.Host, LResult) then
    begin
      PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context, LResult);
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
    PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context, LResult);
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
      atomic_store(LParent^.V4Done, 1, mo_release);
    end
    else
    begin
      LRes := platform_socket_resolve_stream_family(PAnsiChar(LParent^.Host),
        PLATFORM_AF_INET6, @LParent^.V6Raw[0], PLATFORM_RESOLVE_MAX, LCount);
      LParent^.V6Count := LCount;
      LParent^.V6Err := LRes;
      atomic_store(LParent^.V6Done, 1, mo_release);
    end;
  finally
    Dispose(LWorker);
  end;
end;

procedure WaitFamilyGate(LCtx: PDnsParallelCtx);
var
  LWaitedMs: UInt32;
  LFirstDone: Boolean;
  LBothDone: Boolean;
begin
  LWaitedMs := 0;
  LFirstDone := False;
  while True do
  begin
    LBothDone := (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) and
      (atomic_load(LCtx^.V6Done, mo_acquire) <> 0);
    if LBothDone then
      Break;
    if not LFirstDone then
    begin
      if (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) or
         (atomic_load(LCtx^.V6Done, mo_acquire) <> 0) then
      begin
        LFirstDone := True;
        LWaitedMs := 0;
      end;
    end
    else if LWaitedMs >= LCtx^.ResolutionDelayMs then
      Break;
    platform_thread_sleep_ms(1);
    Inc(LWaitedMs);
    if LWaitedMs > 60000 then
      Break;
  end;
end;

procedure JoinFamilyWorkers(LCtx: PDnsParallelCtx);
var
  LWaitedMs: UInt32;
begin
  LWaitedMs := 0;
  while (atomic_load(LCtx^.V4Done, mo_acquire) = 0) or
        (atomic_load(LCtx^.V6Done, mo_acquire) = 0) do
  begin
    platform_thread_sleep_ms(1);
    Inc(LWaitedMs);
    if LWaitedMs > 60000 then
      Break;
  end;
end;

function SpawnFamilyWorkers(LCtx: PDnsParallelCtx): Boolean;
var
  LWorker4, LWorker6: PDnsFamilyWorker;
  LHandle4, LHandle6: TPlatformThreadHandle;
begin
  Result := True;
  LCtx^.V4Count := 0;
  LCtx^.V6Count := 0;
  LCtx^.V4Err := PLATFORM_ERR_INVALID;
  LCtx^.V6Err := PLATFORM_ERR_INVALID;
  atomic_store(LCtx^.V4Done, 0, mo_release);
  atomic_store(LCtx^.V6Done, 0, mo_release);
  New(LWorker4);
  LWorker4^.Parent := LCtx;
  LWorker4^.Family := PLATFORM_AF_INET;
  New(LWorker6);
  LWorker6^.Parent := LCtx;
  LWorker6^.Family := PLATFORM_AF_INET6;
  FillChar(LHandle4, SizeOf(LHandle4), 0);
  FillChar(LHandle6, SizeOf(LHandle6), 0);
  if platform_thread_create(LHandle4, @DnsFamilyWorkerThread, LWorker4) <> 0 then
  begin
    Dispose(LWorker4);
    atomic_store(LCtx^.V4Done, 1, mo_release);
    LCtx^.V4Err := PLATFORM_ERR_INVALID;
    Result := False;
  end
  else
    platform_thread_detach(LHandle4);
  if platform_thread_create(LHandle6, @DnsFamilyWorkerThread, LWorker6) <> 0 then
  begin
    Dispose(LWorker6);
    atomic_store(LCtx^.V6Done, 1, mo_release);
    LCtx^.V6Err := PLATFORM_ERR_INVALID;
    Result := False;
  end
  else
    platform_thread_detach(LHandle6);
end;

function BuildFamilyEvent(LCtx: PDnsParallelCtx; AIsIPv6: Boolean): TDnsStreamEvent;
var
  LOk: Boolean;
  LCount, LI: Integer;
begin
  Result := Default(TDnsStreamEvent);
  Result.IsIPv6 := AIsIPv6;
  Result.AllDone := False;
  SetLength(Result.Addresses, 0);
  if AIsIPv6 then
  begin
    LOk := (atomic_load(LCtx^.V6Done, mo_acquire) <> 0) and
      (LCtx^.V6Err = 0) and (LCtx^.V6Count > 0);
    Result.Error := LCtx^.V6Err;
    if LOk then
    begin
      Result.Error := 0;
      LCount := LCtx^.V6Count;
      SetLength(Result.Addresses, LCount);
      for LI := 0 to LCount - 1 do
      begin
        Result.Addresses[LI].IP := FormatIPv6Addr(@LCtx^.V6Raw[LI].IPv6[0]);
        Result.Addresses[LI].Port := 0;
        Result.Addresses[LI].IsIPv6 := True;
      end;
    end
    else if Result.Error = 0 then
      Result.Error := PLATFORM_ERR_INVALID;
  end
  else
  begin
    LOk := (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) and
      (LCtx^.V4Err = 0) and (LCtx^.V4Count > 0);
    Result.Error := LCtx^.V4Err;
    if LOk then
    begin
      Result.Error := 0;
      LCount := LCtx^.V4Count;
      SetLength(Result.Addresses, LCount);
      for LI := 0 to LCount - 1 do
      begin
        Result.Addresses[LI].IP := IPv4NetToString(LCtx^.V4Raw[LI].IPv4);
        Result.Addresses[LI].Port := 0;
        Result.Addresses[LI].IsIPv6 := False;
      end;
    end
    else if Result.Error = 0 then
      Result.Error := PLATFORM_ERR_INVALID;
  end;
end;

function DnsParallelCoordinator(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PDnsParallelCtx;
  LResult: TDnsResult;
  LOk4, LOk6, LSpawnOk, LBothDone: Boolean;
  LEvent: TDnsStreamEvent;
  LPostedV4, LPostedV6: Boolean;
  LWaitedMs: UInt32;
begin
  Result := nil;
  LCtx := PDnsParallelCtx(AParam);
  try
    LResult := Default(TDnsResult);
    SetLength(LResult.Addresses, 0);

    if TryFillIpLiteral(LCtx^.Host, LResult) then
    begin
      if LCtx^.Streaming then
      begin
        LEvent := Default(TDnsStreamEvent);
        LEvent.Error := 0;
        LEvent.IsIPv6 := LResult.Addresses[0].IsIPv6;
        LEvent.AllDone := True;
        LEvent.Addresses := LResult.Addresses;
        PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
      end
      else
      begin
        PostDnsResult(LCtx^.Loop, LCtx^.Callback, LCtx^.CallbackRef, LCtx^.Context,
          LResult);
      end;
      Exit;
    end;

    LSpawnOk := SpawnFamilyWorkers(LCtx);
    WaitFamilyGate(LCtx);

    LOk4 := (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) and
      (LCtx^.V4Err = 0) and (LCtx^.V4Count > 0);
    LOk6 := (atomic_load(LCtx^.V6Done, mo_acquire) <> 0) and
      (LCtx^.V6Err = 0) and (LCtx^.V6Count > 0);
    LBothDone := (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) and
      (atomic_load(LCtx^.V6Done, mo_acquire) <> 0);

    if LCtx^.Streaming then
    begin
      LPostedV4 := False;
      LPostedV6 := False;

      if LCtx^.PreferIPv6First then
      begin
        if atomic_load(LCtx^.V6Done, mo_acquire) <> 0 then
        begin
          LEvent := BuildFamilyEvent(LCtx, True);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV6 := True;
        end;
        if atomic_load(LCtx^.V4Done, mo_acquire) <> 0 then
        begin
          LEvent := BuildFamilyEvent(LCtx, False);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV4 := True;
        end;
      end
      else
      begin
        if atomic_load(LCtx^.V4Done, mo_acquire) <> 0 then
        begin
          LEvent := BuildFamilyEvent(LCtx, False);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV4 := True;
        end;
        if atomic_load(LCtx^.V6Done, mo_acquire) <> 0 then
        begin
          LEvent := BuildFamilyEvent(LCtx, True);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV6 := True;
        end;
      end;

      if not LBothDone then
      begin
        LWaitedMs := 0;
        while (atomic_load(LCtx^.V4Done, mo_acquire) = 0) or
              (atomic_load(LCtx^.V6Done, mo_acquire) = 0) do
        begin
          platform_thread_sleep_ms(1);
          Inc(LWaitedMs);
          if LWaitedMs > 60000 then
            Break;
        end;
        if (not LPostedV4) and (atomic_load(LCtx^.V4Done, mo_acquire) <> 0) then
        begin
          LEvent := BuildFamilyEvent(LCtx, False);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV4 := True;
        end;
        if (not LPostedV6) and (atomic_load(LCtx^.V6Done, mo_acquire) <> 0) then
        begin
          LEvent := BuildFamilyEvent(LCtx, True);
          LEvent.AllDone := False;
          if Length(LEvent.Addresses) > 0 then
            PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
          LPostedV6 := True;
        end;
      end;

      LEvent := Default(TDnsStreamEvent);
      LEvent.AllDone := True;
      SetLength(LEvent.Addresses, 0);
      if LPostedV4 or LPostedV6 then
        LEvent.Error := 0
      else
      begin
        if LCtx^.V4Err <> 0 then
          LEvent.Error := LCtx^.V4Err
        else if LCtx^.V6Err <> 0 then
          LEvent.Error := LCtx^.V6Err
        else
          LEvent.Error := PLATFORM_ERR_INVALID;
        if LEvent.Error = 0 then
          LEvent.Error := PLATFORM_ERR_INVALID;
      end;
      PostDnsStreamEvent(LCtx^.Loop, LCtx^.StreamCallback, LCtx^.Context, LEvent);
    end
    else
    begin
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
        if atomic_load(LCtx^.V4Done, mo_acquire) <> 0 then
          LResult.Error := LCtx^.V4Err
        else if atomic_load(LCtx^.V6Done, mo_acquire) <> 0 then
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
    end;

    JoinFamilyWorkers(LCtx);
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

function StartResolveParallel(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallback;
  ACallbackRef: TDnsCallbackRef; AStreamCallback: TDnsStreamCallback;
  AStreaming: Boolean; AContext: Pointer): Boolean;
var
  LCtx: PDnsParallelCtx;
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
  LCtx^.StreamCallback := AStreamCallback;
  LCtx^.Context := AContext;
  LCtx^.ResolutionDelayMs := AOptions.ResolutionDelayMs;
  LCtx^.PreferIPv6First := AOptions.PreferIPv6First;
  LCtx^.Streaming := AStreaming;
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
  Result := StartResolveParallel(ALoop, AHost, AOptions, ACallback, nil, nil, False, AContext);
end;

function AsyncResolveExRef(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsCallbackRef;
  AContext: Pointer): Boolean;
begin
  Result := StartResolveParallel(ALoop, AHost, AOptions, nil, ACallback, nil, False, AContext);
end;

function AsyncResolveStream(const ALoop: TAsyncLoop; const AHost: string;
  const AOptions: TDnsResolveOptions; ACallback: TDnsStreamCallback;
  AContext: Pointer): Boolean;
begin
  if not Assigned(ACallback) then
    Exit(False);
  Result := StartResolveParallel(ALoop, AHost, AOptions, nil, nil, ACallback, True, AContext);
end;

end.
