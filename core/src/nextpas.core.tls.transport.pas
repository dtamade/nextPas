unit nextpas.core.tls.transport;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base, nextpas.core.platform.socket;


type
  TSSLTransportResult = (
    trOK,
    trWantRead,
    trWantWrite,
    trClosed,
    trError
  );

  ISSLTransport = interface
    ['{A7E3F1D2-8B4C-4E5A-9F6D-1C2B3A4E5F60}']
    function Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
    function Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
    function Flush: TSSLTransportResult;
  end;

  ISSLBIOPair = interface
    ['{B8F4A2E3-9C5D-4F6B-A0E7-2D3C4B5A6071}']
    function GetReadBIO: ISSLTransport;
    function GetWriteBIO: ISSLTransport;
    function PendingRead: Integer;
    function PendingWrite: Integer;
  end;

  TSSLMemoryTransport = class(TInterfacedObject, ISSLTransport)
  private
    FBuffer: TBytes;
    FReadPos: Integer;
    FWritePos: Integer;
  public
    constructor Create(ACapacity: Integer = 16384);
    function Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
    function Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
    function Flush: TSSLTransportResult;
    function Pending: Integer;
    procedure Inject(const AData: TBytes);
    function Extract(AMaxBytes: Integer): TBytes;
  end;

  TSSLSocketTransport = class(TInterfacedObject, ISSLTransport)
  private
    FSocket: TPlatformSocket;
    FNonBlocking: Boolean;
  public
    constructor Create(const ASocket: TPlatformSocket; ANonBlocking: Boolean = False);
    function Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
    function Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
    function Flush: TSSLTransportResult;
  end;

implementation

uses nextpas.core.system.classes; constructor TSSLMemoryTransport.Create(ACapacity: Integer);
begin
  inherited Create;
  SetLength(FBuffer, ACapacity);
  FReadPos := 0;
  FWritePos := 0;
end;

function TSSLMemoryTransport.Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
var
  LAvail: Integer;
begin
  LAvail := FWritePos - FReadPos;
  if LAvail <= 0 then
  begin
    ABytesRead := 0;
    Exit(trWantRead);
  end;
  if ACount > LAvail then
    ACount := LAvail;
  Move(FBuffer[FReadPos], ABuffer, ACount);
  Inc(FReadPos, ACount);
  if FReadPos = FWritePos then
  begin
    FReadPos := 0;
    FWritePos := 0;
  end;
  ABytesRead := ACount;
  Result := trOK;
end;

function TSSLMemoryTransport.Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
var
  LSpace: Integer;
begin
  LSpace := Length(FBuffer) - FWritePos;
  if LSpace <= 0 then
  begin
    ABytesWritten := 0;
    Exit(trWantWrite);
  end;
  if ACount > LSpace then
    ACount := LSpace;
  Move(ABuffer, FBuffer[FWritePos], ACount);
  Inc(FWritePos, ACount);
  ABytesWritten := ACount;
  Result := trOK;
end;

function TSSLMemoryTransport.Flush: TSSLTransportResult;
begin
  Result := trOK;
end;

function TSSLMemoryTransport.Pending: Integer;
begin
  Result := FWritePos - FReadPos;
end;

procedure TSSLMemoryTransport.Inject(const AData: TBytes);
var
  LLen: Integer;
begin
  LLen := Length(AData);
  if FWritePos + LLen > Length(FBuffer) then
    SetLength(FBuffer, FWritePos + LLen);
  Move(AData[0], FBuffer[FWritePos], LLen);
  Inc(FWritePos, LLen);
end;

function TSSLMemoryTransport.Extract(AMaxBytes: Integer): TBytes;
var
  LAvail: Integer;
begin
  LAvail := FWritePos - FReadPos;
  if AMaxBytes > LAvail then
    AMaxBytes := LAvail;
  SetLength(Result, AMaxBytes);
  if AMaxBytes > 0 then
  begin
    Move(FBuffer[FReadPos], Result[0], AMaxBytes);
    Inc(FReadPos, AMaxBytes);
    if FReadPos = FWritePos then
    begin
      FReadPos := 0;
      FWritePos := 0;
    end;
  end;
end;

constructor TSSLSocketTransport.Create(const ASocket: TPlatformSocket; ANonBlocking: Boolean);
begin
  inherited Create;
  FSocket := ASocket;
  FNonBlocking := ANonBlocking;
  if ANonBlocking then
    platform_socket_set_nonblocking(FSocket, True);
end;

function TSSLSocketTransport.Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
var
  LErr: Int32;
  LRecvd: Int32;
begin
  LErr := platform_socket_recv(FSocket, @ABuffer, ACount, 0, LRecvd);
  if LErr <> 0 then
  begin
    if FNonBlocking and platform_socket_error_would_block(LErr) then
    begin
      ABytesRead := 0;
      Exit(trWantRead);
    end;
    ABytesRead := 0;
    Exit(trError);
  end;
  if LRecvd = 0 then
  begin
    ABytesRead := 0;
    Exit(trClosed);
  end;
  ABytesRead := LRecvd;
  Result := trOK;
end;

function TSSLSocketTransport.Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
var
  LErr: Int32;
  LSent: Int32;
begin
  LErr := platform_socket_send(FSocket, @ABuffer, ACount, 0, LSent);
  if LErr <> 0 then
  begin
    if FNonBlocking and platform_socket_error_would_block(LErr) then
    begin
      ABytesWritten := 0;
      Exit(trWantWrite);
    end;
    ABytesWritten := 0;
    Exit(trError);
  end;
  ABytesWritten := LSent;
  Result := trOK;
end;

function TSSLSocketTransport.Flush: TSSLTransportResult;
begin
  Result := trOK;
end;

end.
