unit nextpas.core.http.impl.h1.prepend;
{**
 * @desc H1 read-prepend TCP stream (shared by client CONNECT leftover and
 *       server hijack pending bytes). Extracted from impl.h1.
 *
 *       B8 第二片：实现 ITcpStreamRuntime（TryRead 前缀优先 + 委托 socket），
 *       使 hijack 出的带残留字节流可直接交给事件驱动 WS 会话
 *       （TNetWsFrameSession 要求 Supports(AConn, ITcpStreamRuntime)）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline;

type
  TReadPrependTcpStream = class(TInterfacedObject, IReader, IWriter, ITcpStream,
    ITcpStreamRuntime, ITcpSocketRuntime)
  private
    FInner: ITcpStream;
    FPrefix: string;
    FPrefixPos: SizeInt;
  public
    constructor Create(const AInner: ITcpStream; const APrefix: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    { ITcpStreamRuntime }
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
  end;


implementation

{ TReadPrependTcpStream }

constructor TReadPrependTcpStream.Create(const AInner: ITcpStream; const APrefix: string);
begin
  inherited Create;
  FInner := AInner;
  FPrefix := APrefix;
  FPrefixPos := 1;
end;

function TReadPrependTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LPtr: PByte;
  LCopy: SizeUInt;
begin
  Result := 0;
  if ACount = 0 then
    Exit(0);

  LPtr := @ABuf;
  if (FPrefixPos > 0) and (FPrefixPos <= Length(FPrefix)) then
  begin
    LCopy := SizeUInt(Length(FPrefix) - FPrefixPos + 1);
    if LCopy > ACount then
      LCopy := ACount;
    Move(FPrefix[FPrefixPos], LPtr^, LCopy);
    Inc(FPrefixPos, SizeInt(LCopy));
    Inc(Result, LCopy);
    Inc(LPtr, LCopy);
    if FPrefixPos > Length(FPrefix) then
      FPrefix := '';
  end;

  if Result < ACount then
    Inc(Result, FInner.Read(LPtr^, ACount - Result));
end;

function TReadPrependTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

procedure TReadPrependTcpStream.Close;
begin
  FInner.Close;
end;

function TReadPrependTcpStream.LocalAddr: TNetAddress;
begin
  Result := FInner.LocalAddr;
end;

function TReadPrependTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FInner.RemoteAddr;
end;

procedure TReadPrependTcpStream.Shutdown;
begin
  FInner.Shutdown;
end;

procedure TReadPrependTcpStream.SetNoDelay(const AValue: Boolean);
begin
  FInner.SetNoDelay(AValue);
end;

procedure TReadPrependTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  FInner.SetKeepAlive(AValue);
end;

procedure TReadPrependTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FInner.SetReadDeadline(ADeadline);
end;

procedure TReadPrependTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FInner.SetWriteDeadline(ADeadline);
end;

procedure TReadPrependTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
  FInner.SetCancelToken(AToken);
end;

function TReadPrependTcpStream.NativeSocketHandle: PtrUInt;
var
  LSocket: ITcpSocketRuntime;
begin
  Supports(FInner, ITcpSocketRuntime, LSocket);
  if LSocket <> nil then
    Result := LSocket.NativeSocketHandle
  else
    Result := 0;
end;

procedure TReadPrependTcpStream.SetBlocking(const ABlocking: Boolean);
var
  LSocket: ITcpSocketRuntime;
begin
  Supports(FInner, ITcpSocketRuntime, LSocket);
  if LSocket <> nil then
    LSocket.SetBlocking(ABlocking);
end;

function TReadPrependTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LPtr: PByte;
  LCopy: SizeUInt;
  LInner: ITcpStreamRuntime;
  LInnerRes: TTcpStreamIOResult;
begin
  ARead := 0;
  LPtr := @ABuf;
  if (FPrefixPos > 0) and (FPrefixPos <= Length(FPrefix)) then
  begin
    LCopy := SizeUInt(Length(FPrefix) - FPrefixPos + 1);
    if LCopy > ACount then
      LCopy := ACount;
    Move(FPrefix[FPrefixPos], LPtr^, LCopy);
    Inc(FPrefixPos, SizeInt(LCopy));
    Inc(ARead, LCopy);
    Inc(LPtr, LCopy);
    if FPrefixPos > Length(FPrefix) then
      FPrefix := '';
    if ARead >= ACount then
      Exit(tsiorOk);
  end;
  Supports(FInner, ITcpStreamRuntime, LInner);
  if LInner = nil then
    Exit(tsiorClosed);
  LInnerRes := LInner.TryRead(LPtr^, ACount - ARead, LCopy);
  if LInnerRes = tsiorOk then
    Inc(ARead, LCopy)
  else
  begin
    { 前缀已交付（ARead > 0）时，内层无更多可读不算失败：返回 Ok，
      让上层消费已读前缀；否则原样返回内层结果。 }
    if ARead = 0 then
      Exit(LInnerRes);
  end;
  Result := tsiorOk;
end;

function TReadPrependTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LInner: ITcpStreamRuntime;
begin
  Supports(FInner, ITcpStreamRuntime, LInner);
  if LInner = nil then
  begin
    AWritten := 0;
    Exit(tsiorClosed);
  end;
  Result := LInner.TryWrite(ABuf, ACount, AWritten);
end;

end.
