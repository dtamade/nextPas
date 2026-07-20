unit nextpas.core.tls.socket_stream;

{$mode ObjFPC}{$H+}

{ Socket-backed IStream that does not close the native handle.
  Owner of the fd remains the TLS connection / dialer. }

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.platform.socket;

function SocketHandleAsIStream(AHandle: THandle): IStream;

implementation

type
  TFdIStream = class(TInterfacedObject, IStream)
  private
    FHandle: THandle;
    FPos: Int64;
    function AsPlatformSocket: TPlatformSocket; inline;
  public
    constructor Create(AHandle: THandle);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

function SocketHandleAsIStream(AHandle: THandle): IStream;
begin
  Result := TFdIStream.Create(AHandle);
end;

constructor TFdIStream.Create(AHandle: THandle);
begin
  inherited Create;
  FHandle := AHandle;
  FPos := 0;
end;

function TFdIStream.AsPlatformSocket: TPlatformSocket;
begin
  {$IFDEF WINDOWS}
  Result.Value := PtrUInt(FHandle);
  {$ELSE}
  Result.Value := Int32(FHandle);
  {$ENDIF}
end;

function TFdIStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSock: TPlatformSocket;
  LRecvd: Int32;
  LErr: Int32;
begin
  Result := 0;
  if ACount = 0 then
    Exit;
  LSock := AsPlatformSocket;
  LErr := platform_socket_recv(LSock, @ABuf, Int32(ACount), 0, LRecvd);
  if LErr <> 0 then
    Exit(0);
  Result := SizeUInt(LRecvd);
  Inc(FPos, Result);
end;

function TFdIStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSock: TPlatformSocket;
  LSent: Int32;
  LErr: Int32;
begin
  Result := 0;
  if ACount = 0 then
    Exit;
  LSock := AsPlatformSocket;
  LErr := platform_socket_send(LSock, @ABuf, Int32(ACount), PLATFORM_MSG_NOSIGNAL, LSent);
  if LErr <> 0 then
    Exit(0);
  Result := SizeUInt(LSent);
  Inc(FPos, Result);
end;

function TFdIStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  case AOrigin of
    soBeginning: FPos := AOffset;
    soCurrent: FPos := FPos + AOffset;
    soEnd: FPos := AOffset;
  end;
  Result := FPos;
end;

procedure TFdIStream.Close;
begin
  { Connection owns the socket. }
end;

function TFdIStream.GetSize: Int64;
begin
  Result := -1;
end;

function TFdIStream.GetPosition: Int64;
begin
  Result := FPos;
end;

procedure TFdIStream.SetPosition(const AValue: Int64);
begin
  FPos := AValue;
end;

end.
