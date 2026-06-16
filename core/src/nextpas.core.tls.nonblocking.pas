unit nextpas.core.tls.nonblocking;

{$mode objfpc}{$H+}{$J-}

interface

uses
   Classes,
  nextpas.core.io.base,
  nextpas.core.io.intf;

type
  TSSLIOResult = (
    ioSuccess,
    ioWantRead,
    ioWantWrite,
    ioError,
    ioClosed
  );

  TNonBlockingStream = class(TInterfacedObject, IStream)
  protected
    FInner: IStream;
    FLastIOResult: TSSLIOResult;
  public
    constructor Create(AInner: IStream); overload;
    constructor Create(AInner: TStream); overload;
    function Read(var Buffer; Count: Longint): Longint; overload;
    function Write(const Buffer; Count: Longint): Longint; overload;

    function Read(var ABuf; const ACount: SizeUInt): SizeUInt; overload; virtual;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; overload; virtual;
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64; overload;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);

    property LastIOResult: TSSLIOResult read FLastIOResult;
    property InnerStream: IStream read FInner;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

  TSocketNonBlockingAdapter = class(TNonBlockingStream)
  private
    FHandle: THandle;
  public
    constructor Create(AHandle: THandle);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; override;
  end;

implementation

uses
  {$IFDEF UNIX}BaseUnix, Unix, Sockets,{$ENDIF}
  {$IFDEF WINDOWS}WinSock2,{$ENDIF}
  nextpas.core.errors,
  nextpas.core.io.stream_adapter,
  nextpas.core.net.intf;

constructor TNonBlockingStream.Create(AInner: IStream);
var
  LRuntime: ITcpSocketRuntime;
begin
  inherited Create;
  FInner := AInner;
  FLastIOResult := ioSuccess;
  if (FInner <> nil) and Supports(FInner, ITcpSocketRuntime, LRuntime) then
    LRuntime.SetBlocking(False);
end;

constructor TNonBlockingStream.Create(AInner: TStream);
begin
  Create(WrapTStream(AInner, False));
end;

function TNonBlockingStream.Read(var Buffer; Count: Longint): Longint;
begin
  if Count <= 0 then
    Exit(0);
  Result := Longint(Read(Buffer, SizeUInt(Count)));
end;

function TNonBlockingStream.Write(const Buffer; Count: Longint): Longint;
begin
  if Count <= 0 then
    Exit(0);
  Result := Longint(Write(Buffer, SizeUInt(Count)));
end;

function TNonBlockingStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRuntime: ITcpStreamRuntime;
begin
  if (FInner = nil) or (ACount = 0) then
  begin
    FLastIOResult := ioClosed;
    Exit(0);
  end;

  if Supports(FInner, ITcpStreamRuntime, LRuntime) then
  begin
    case LRuntime.TryRead(ABuf, ACount, Result) of
      tsiorOk:
        if Result > 0 then
          FLastIOResult := ioSuccess
        else
          FLastIOResult := ioClosed;
      tsiorWouldBlock:
        begin
          FLastIOResult := ioWantRead;
          Result := 0;
        end;
      tsiorClosed:
        begin
          FLastIOResult := ioClosed;
          Result := 0;
        end;
    end;
    Exit;
  end;

  Result := FInner.Read(ABuf, ACount);
  if Result > 0 then
    FLastIOResult := ioSuccess
  else
    FLastIOResult := ioClosed;
end;

function TNonBlockingStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRuntime: ITcpStreamRuntime;
begin
  if (FInner = nil) or (ACount = 0) then
  begin
    FLastIOResult := ioClosed;
    Exit(0);
  end;

  if Supports(FInner, ITcpStreamRuntime, LRuntime) then
  begin
    case LRuntime.TryWrite(ABuf, ACount, Result) of
      tsiorOk:
        if Result > 0 then
          FLastIOResult := ioSuccess
        else
          FLastIOResult := ioClosed;
      tsiorWouldBlock:
        begin
          FLastIOResult := ioWantWrite;
          Result := 0;
        end;
      tsiorClosed:
        begin
          FLastIOResult := ioClosed;
          Result := 0;
        end;
    end;
    Exit;
  end;

  Result := FInner.Write(ABuf, ACount);
  if Result > 0 then
    FLastIOResult := ioSuccess
  else
    FLastIOResult := ioError;
end;

function TNonBlockingStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Seek(AOffset, AOrigin);
end;

procedure TNonBlockingStream.Close;
begin
  if FInner <> nil then
    FInner.Close;
end;

function TNonBlockingStream.GetSize: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Size;
end;

function TNonBlockingStream.GetPosition: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Position;
end;

procedure TNonBlockingStream.SetPosition(const AValue: Int64);
begin
  if FInner <> nil then
    FInner.Position := AValue;
end;

constructor TSocketNonBlockingAdapter.Create(AHandle: THandle);
begin
  inherited Create(IStream(nil));
  FHandle := AHandle;
end;

function TSocketNonBlockingAdapter.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
{$IFDEF UNIX}
var
  LErrno: Integer;
  LResult: Int32;
{$ENDIF}
begin
  Result := 0;
  if ACount = 0 then
    Exit;

  {$IFDEF UNIX}
  LResult := fpRecv(FHandle, @ABuf, ACount, MSG_DONTWAIT);
  if LResult < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
      FLastIOResult := ioWantRead
    else
      FLastIOResult := ioError;
    Exit;
  end;
  Result := SizeUInt(LResult);
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ELSE}
  Result := recv(FHandle, ABuf, Integer(ACount), 0);
  if Integer(Result) = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
      FLastIOResult := ioWantRead
    else
      FLastIOResult := ioError;
    Result := 0;
    Exit;
  end;
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ENDIF}
end;

function TSocketNonBlockingAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
{$IFDEF UNIX}
var
  LErrno: Integer;
  LResult: Int32;
{$ENDIF}
begin
  Result := 0;
  if ACount = 0 then
    Exit;

  {$IFDEF UNIX}
  LResult := fpSend(FHandle, @ABuf, ACount, MSG_DONTWAIT or MSG_NOSIGNAL);
  if LResult < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
      FLastIOResult := ioWantWrite
    else
      FLastIOResult := ioError;
    Exit;
  end;
  Result := SizeUInt(LResult);
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ELSE}
  Result := send(FHandle, ABuf, Integer(ACount), 0);
  if Integer(Result) = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
      FLastIOResult := ioWantWrite
    else
      FLastIOResult := ioError;
    Result := 0;
    Exit;
  end;
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ENDIF}
end;

end.
