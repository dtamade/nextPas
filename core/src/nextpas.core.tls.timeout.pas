unit nextpas.core.tls.timeout;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes;

type
  TTimeoutStream = class(TStream)
  private
    FInner: TStream;
    FReadTimeout: Integer;
    FWriteTimeout: Integer;
    FConnectTimeout: Integer;
  public
    constructor Create(AInner: TStream; AReadTimeoutMs: Integer = 30000;
      AWriteTimeoutMs: Integer = 30000);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property ReadTimeout: Integer read FReadTimeout write FReadTimeout;
    property WriteTimeout: Integer read FWriteTimeout write FWriteTimeout;
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    property InnerStream: TStream read FInner;
  end;

implementation

uses
  {$IFDEF UNIX}BaseUnix, Unix,{$ENDIF}
  Sockets;

constructor TTimeoutStream.Create(AInner: TStream; AReadTimeoutMs: Integer;
  AWriteTimeoutMs: Integer);
begin
  inherited Create;
  FInner := AInner;
  FReadTimeout := AReadTimeoutMs;
  FWriteTimeout := AWriteTimeoutMs;
  FConnectTimeout := 10000;
end;

function TTimeoutStream.Read(var Buffer; Count: Longint): Longint;
{$IFDEF UNIX}
var
  LFD: Integer;
  LSet: TFDSet;
  LTimeout: TTimeVal;
  LRet: Integer;
begin
  if FInner is THandleStream then
  begin
    LFD := THandleStream(FInner).Handle;
    fpFD_ZERO(LSet);
    fpFD_SET(LFD, LSet);
    LTimeout.tv_sec := FReadTimeout div 1000;
    LTimeout.tv_usec := (FReadTimeout mod 1000) * 1000;
    LRet := fpSelect(LFD + 1, @LSet, nil, nil, @LTimeout);
    if LRet <= 0 then
      Exit(0);
  end;
  Result := FInner.Read(Buffer, Count);
end;
{$ELSE}
begin
  Result := FInner.Read(Buffer, Count);
end;
{$ENDIF}

function TTimeoutStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FInner.Write(Buffer, Count);
end;

function TTimeoutStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FInner.Seek(Offset, Origin);
end;

end.
