unit nextpas.core.net.async.resolve;
{**
 * @desc 异步 DNS 解析：集成事件循环的非阻塞 DNS 解析。
 *       使用独立线程执行阻塞的地址解析，结果通过事件循环回调通知。
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

{ DNS 完成回调 - 在事件循环线程中执行 }
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

{ 格式化 IPv6 地址字节为字符串 }
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

{ DNS 解析线程 }
function DnsResolveThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PDnsContext;
  LResult: TDnsResult;
  LAddr: UInt32;
  LAddr6: array[0..15] of Byte;
  LRes: Int32;
  LPostCtx: PDnsPostContext;
begin
  Result := nil;
  LCtx := PDnsContext(AParam);
  try
    FillChar(LResult, SizeOf(LResult), 0);

    { 尝试 IPv4 解析 }
    LRes := platform_socket_resolve_ipv4(PAnsiChar(LCtx^.Host), LAddr);
    if LRes = 0 then
    begin
      SetLength(LResult.Addresses, 1);
      LResult.Error := 0;
      LResult.Addresses[0].IP := IntToStr(LAddr and $FF) + '.' +
        IntToStr((LAddr shr 8) and $FF) + '.' +
        IntToStr((LAddr shr 16) and $FF) + '.' +
        IntToStr((LAddr shr 24) and $FF);
      LResult.Addresses[0].Port := 0;
      LResult.Addresses[0].IsIPv6 := False;
    end
    else
    begin
      { IPv4 失败，尝试 IPv6 解析 }
      FillChar(LAddr6, SizeOf(LAddr6), 0);
      LRes := platform_socket_resolve_ipv6(PAnsiChar(LCtx^.Host), @LAddr6[0]);
      if LRes = 0 then
      begin
        SetLength(LResult.Addresses, 1);
        LResult.Error := 0;
        LResult.Addresses[0].IP := FormatIPv6Addr(@LAddr6[0]);
        LResult.Addresses[0].Port := 0;
        LResult.Addresses[0].IsIPv6 := True;
      end
      else
      begin
        LResult.Error := LRes;
        SetLength(LResult.Addresses, 0);
      end;
    end;

    New(LPostCtx);
    LPostCtx^.Loop := LCtx^.Loop;
    LPostCtx^.Callback := LCtx^.Callback;
    LPostCtx^.CallbackRef := LCtx^.CallbackRef;
    LPostCtx^.Context := LCtx^.Context;
    LPostCtx^.Result := LResult;
    LCtx^.Loop.Post(@DnsPostCallback, LPostCtx);

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
