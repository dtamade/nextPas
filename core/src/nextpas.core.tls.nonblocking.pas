unit nextpas.core.tls.nonblocking;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes;

type
  TSSLIOResult = (
    ioSuccess,
    ioWantRead,
    ioWantWrite,
    ioError,
    ioClosed
  );

  TNonBlockingStream = class(TStream)
  private
    FInner: TStream;
    FLastIOResult: TSSLIOResult;
  public
    constructor Create(AInner: TStream);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property LastIOResult: TSSLIOResult read FLastIOResult;
    property InnerStream: TStream read FInner;
  end;

  TSocketNonBlockingAdapter = class(TNonBlockingStream)
  private
    FHandle: THandle;
  public
    constructor Create(AHandle: THandle);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

implementation

uses
  {$IFDEF UNIX}BaseUnix, Unix, Sockets,{$ENDIF}
  {$IFDEF WINDOWS}WinSock2,{$ENDIF}
  nextpas.core.tls.errors;

constructor TNonBlockingStream.Create(AInner: TStream);
begin
  inherited Create;
  FInner := AInner;
  FLastIOResult := ioSuccess;
end;

function TNonBlockingStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FInner.Read(Buffer, Count);
  if Result > 0 then
    FLastIOResult := ioSuccess
  else if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioError;
end;

function TNonBlockingStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FInner.Write(Buffer, Count);
  if Result > 0 then
    FLastIOResult := ioSuccess
  else
    FLastIOResult := ioError;
end;

function TNonBlockingStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FInner.Seek(Offset, Origin);
end;

constructor TSocketNonBlockingAdapter.Create(AHandle: THandle);
begin
  inherited Create(nil);
  FHandle := AHandle;
end;

function TSocketNonBlockingAdapter.Read(var Buffer; Count: Longint): Longint;
{$IFDEF UNIX}
var
  LErrno: Integer;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Result := fpRecv(FHandle, @Buffer, Count, MSG_DONTWAIT);
  if Result < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
    begin
      FLastIOResult := ioWantRead;
      Result := 0;
    end
    else
      FLastIOResult := ioError;
  end
  else if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ELSE}
  Result := recv(FHandle, Buffer, Count, 0);
  if Result = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
    begin
      FLastIOResult := ioWantRead;
      Result := 0;
    end
    else
      FLastIOResult := ioError;
  end
  else if Result = 0 then
    FLastIOResult := ioClosed
  else
    FLastIOResult := ioSuccess;
  {$ENDIF}
end;

function TSocketNonBlockingAdapter.Write(const Buffer; Count: Longint): Longint;
{$IFDEF UNIX}
var
  LErrno: Integer;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Result := fpSend(FHandle, @Buffer, Count, MSG_DONTWAIT or MSG_NOSIGNAL);
  if Result < 0 then
  begin
    LErrno := fpGetErrno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
    begin
      FLastIOResult := ioWantWrite;
      Result := 0;
    end
    else
      FLastIOResult := ioError;
  end
  else
    FLastIOResult := ioSuccess;
  {$ELSE}
  Result := send(FHandle, Buffer, Count, 0);
  if Result = SOCKET_ERROR then
  begin
    if WSAGetLastError = WSAEWOULDBLOCK then
    begin
      FLastIOResult := ioWantWrite;
      Result := 0;
    end
    else
      FLastIOResult := ioError;
  end
  else
    FLastIOResult := ioSuccess;
  {$ENDIF}
end;

end.
