unit nextpas.core.tls.transport;

{$mode objfpc}{$H+}{$J-}

interface


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
    FHandle: THandle;
    FNonBlocking: Boolean;
  public
    constructor Create(AHandle: THandle; ANonBlocking: Boolean = False);
    function Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
    function Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
    function Flush: TSSLTransportResult;
  end;

implementation

uses BaseUnix, Sockets, WinSock2, Classes;

constructor TSSLMemoryTransport.Create(ACapacity: Integer);
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

constructor TSSLSocketTransport.Create(AHandle: THandle; ANonBlocking: Boolean);
begin
  inherited Create;
  FHandle := AHandle;
  FNonBlocking := ANonBlocking;
end;

function TSSLSocketTransport.Read(var ABuffer; ACount: Integer; out ABytesRead: Integer): TSSLTransportResult;
var
  LRet: Integer;
  {$IFDEF UNIX}
  LErrno: Integer;
  {$ENDIF}
begin
  {$IFDEF UNIX}
  if FNonBlocking then
    LRet := fpRecv(FHandle, @ABuffer, ACount, MSG_DONTWAIT)
  else
    LRet := fpRecv(FHandle, @ABuffer, ACount, 0);
  if LRet < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
    begin
      ABytesRead := 0;
      Exit(trWantRead);
    end;
    ABytesRead := 0;
    Exit(trError);
  end;
  {$ELSE}
  LRet := recv(FHandle, ABuffer, ACount, 0);
  if LRet = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
    begin
      ABytesRead := 0;
      Exit(trWantRead);
    end;
    ABytesRead := 0;
    Exit(trError);
  end;
  {$ENDIF}
  if LRet = 0 then
  begin
    ABytesRead := 0;
    Exit(trClosed);
  end;
  ABytesRead := LRet;
  Result := trOK;
end;

function TSSLSocketTransport.Write(const ABuffer; ACount: Integer; out ABytesWritten: Integer): TSSLTransportResult;
var
  LRet: Integer;
  {$IFDEF UNIX}
  LErrno: Integer;
  {$ENDIF}
begin
  {$IFDEF UNIX}
  if FNonBlocking then
    LRet := fpSend(FHandle, @ABuffer, ACount, MSG_DONTWAIT or MSG_NOSIGNAL)
  else
    LRet := fpSend(FHandle, @ABuffer, ACount, MSG_NOSIGNAL);
  if LRet < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
    begin
      ABytesWritten := 0;
      Exit(trWantWrite);
    end;
    ABytesWritten := 0;
    Exit(trError);
  end;
  {$ELSE}
  LRet := send(FHandle, ABuffer, ACount, 0);
  if LRet = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
    begin
      ABytesWritten := 0;
      Exit(trWantWrite);
    end;
    ABytesWritten := 0;
    Exit(trError);
  end;
  {$ENDIF}
  ABytesWritten := LRet;
  Result := trOK;
end;

function TSSLSocketTransport.Flush: TSSLTransportResult;
begin
  Result := trOK;
end;

end.
