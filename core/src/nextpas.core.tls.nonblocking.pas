unit nextpas.core.tls.nonblocking;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.base.utils;

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
  nextpas.core.errors,
  nextpas.core.io.stream_adapter,
  nextpas.core.net.intf,
  nextpas.core.platform.socket;

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

function HandleToPlatformSocket(AHandle: THandle): TPlatformSocket; inline;
begin
  {$IFDEF WINDOWS}
  Result.Value := PtrUInt(AHandle);
  {$ELSE}
  Result.Value := Int32(AHandle);
  {$ENDIF}
end;

function TSocketNonBlockingAdapter.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSock: TPlatformSocket;
  LRecvd: Int32;
  LErr: Int32;
begin
  Result := 0;
  if ACount = 0 then
    Exit;

  LSock := HandleToPlatformSocket(FHandle);
  LErr := platform_socket_recv(LSock, @ABuf, Int32(ACount), 0, LRecvd);
  if LErr <> 0 then
  begin
    if platform_socket_error_would_block(LErr) or
       platform_socket_error_interrupted(LErr) then
      FLastIOResult := ioWantRead
    else
      FLastIOResult := ioError;
    Exit;
  end;
  Result := SizeUInt(LRecvd);
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
end;

function TSocketNonBlockingAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSock: TPlatformSocket;
  LSent: Int32;
  LErr: Int32;
begin
  Result := 0;
  if ACount = 0 then
    Exit;

  LSock := HandleToPlatformSocket(FHandle);
  LErr := platform_socket_send(LSock, @ABuf, Int32(ACount), PLATFORM_MSG_NOSIGNAL, LSent);
  if LErr <> 0 then
  begin
    if platform_socket_error_would_block(LErr) or
       platform_socket_error_interrupted(LErr) then
      FLastIOResult := ioWantWrite
    else
      FLastIOResult := ioError;
    Exit;
  end;
  Result := SizeUInt(LSent);
  if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
end;

end.
