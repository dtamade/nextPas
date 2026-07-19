unit nextpas.core.net.async.resolve;
{**
 * @desc 异步 DNS 解析：集成事件循环的非阻塞 DNS 解析。
 *       使用独立线程执行 platform_socket_resolve_stream（multi-A / dual-stack）。
 *       注意：使用此模块的程序需要在 uses 中包含 cthreads。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.async.base, nextpas.core.async.loop;

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

{ 异步 DNS 解析 }
function AsyncResolve(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; AContext: Pointer = nil): Boolean;

function AsyncResolveRef(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallbackRef; AContext: Pointer = nil): Boolean;

implementation

uses
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

function DnsResolveThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PDnsContext;
  LResult: TDnsResult;
  LRaw: array[0..PLATFORM_RESOLVE_MAX - 1] of TPlatformResolvedAddr;
  LCount: Int32;
  LRes: Int32;
  LI, LJdx: Integer;
  LIsV4Lit: Boolean;
  LPostCtx: PDnsPostContext;
begin
  Result := nil;
  LCtx := PDnsContext(AParam);
  try
    FillChar(LResult, SizeOf(LResult), 0);
    SetLength(LResult.Addresses, 0);

    { Fast path: IPv4 literal without DNS }
    if (Length(LCtx^.Host) > 0) and (Pos(':', LCtx^.Host) = 0) then
    begin
      LIsV4Lit := True;
      for LI := 1 to Length(LCtx^.Host) do
        if not (LCtx^.Host[LI] in ['0'..'9', '.']) then
        begin
          LIsV4Lit := False;
          Break;
        end;
      if LIsV4Lit then
      begin
        LResult.Error := 0;
        SetLength(LResult.Addresses, 1);
        LResult.Addresses[0].IP := string(LCtx^.Host);
        LResult.Addresses[0].Port := 0;
        LResult.Addresses[0].IsIPv6 := False;
        New(LPostCtx);
        LPostCtx^.Loop := LCtx^.Loop;
        LPostCtx^.Callback := LCtx^.Callback;
        LPostCtx^.CallbackRef := LCtx^.CallbackRef;
        LPostCtx^.Context := LCtx^.Context;
        LPostCtx^.Result := LResult;
        LCtx^.Loop.PostEx(@DnsPostCallback, LPostCtx, @DiscardDnsPostCtx);
        Exit;
      end;
    end;

    LRes := platform_socket_resolve_stream(PAnsiChar(LCtx^.Host), @LRaw[0],
      PLATFORM_RESOLVE_MAX, LCount);
    if (LRes = 0) and (LCount > 0) then
    begin
      LResult.Error := 0;
      SetLength(LResult.Addresses, LCount);
      { Prefer IPv4 first then IPv6 for stable HE-lite order (legacy-compatible). }
      LI := 0;
      for LJdx := 0 to LCount - 1 do
        if not LRaw[LJdx].IsIPv6 then
        begin
          LResult.Addresses[LI].IP := IPv4NetToString(LRaw[LJdx].IPv4);
          LResult.Addresses[LI].Port := 0;
          LResult.Addresses[LI].IsIPv6 := False;
          Inc(LI);
        end;
      for LJdx := 0 to LCount - 1 do
        if LRaw[LJdx].IsIPv6 then
        begin
          LResult.Addresses[LI].IP := FormatIPv6Addr(@LRaw[LJdx].IPv6[0]);
          LResult.Addresses[LI].Port := 0;
          LResult.Addresses[LI].IsIPv6 := True;
          Inc(LI);
        end;
    end
    else
    begin
      LResult.Error := LRes;
      if LResult.Error = 0 then
        LResult.Error := PLATFORM_ERR_INVALID;
      SetLength(LResult.Addresses, 0);
    end;

    New(LPostCtx);
    LPostCtx^.Loop := LCtx^.Loop;
    LPostCtx^.Callback := LCtx^.Callback;
    LPostCtx^.CallbackRef := LCtx^.CallbackRef;
    LPostCtx^.Context := LCtx^.Context;
    LPostCtx^.Result := LResult;
    LCtx^.Loop.PostEx(@DnsPostCallback, LPostCtx, @DiscardDnsPostCtx);
  finally
    Dispose(LCtx);
  end;
end;

function AsyncResolve(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallback; AContext: Pointer): Boolean;
var
  LCtx: PDnsContext;
  LHandle: TPlatformThreadHandle;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async resolve: loop not valid');

  New(LCtx);
  LCtx^.Host := AHost;
  LCtx^.Loop := ALoop;
  LCtx^.Callback := ACallback;
  LCtx^.CallbackRef := nil;
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

function AsyncResolveRef(const ALoop: TAsyncLoop; const AHost: string;
  ACallback: TDnsCallbackRef; AContext: Pointer): Boolean;
var
  LCtx: PDnsContext;
  LHandle: TPlatformThreadHandle;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async resolve: loop not valid');

  New(LCtx);
  LCtx^.Host := AHost;
  LCtx^.Loop := ALoop;
  LCtx^.Callback := nil;
  LCtx^.CallbackRef := ACallback;
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

end.
