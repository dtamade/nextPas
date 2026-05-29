unit nextpas.core.tls.bufferpool;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, SyncObjs;

type
  TSSLBufferPool = class
  private
    FPool: array of TBytes;
    FCount: Integer;
    FBufferSize: Integer;
    FMaxPooled: Integer;
    FLock: TCriticalSection;
  public
    constructor Create(ABufferSize: Integer = 16384; AMaxPooled: Integer = 32);
    destructor Destroy; override;
    function Acquire: TBytes;
    procedure Release(var ABuffer: TBytes);
    property BufferSize: Integer read FBufferSize;
  end;

var
  GlobalBufferPool: TSSLBufferPool;

implementation

constructor TSSLBufferPool.Create(ABufferSize: Integer; AMaxPooled: Integer);
begin
  inherited Create;
  FBufferSize := ABufferSize;
  FMaxPooled := AMaxPooled;
  FCount := 0;
  SetLength(FPool, AMaxPooled);
  FLock := TCriticalSection.Create;
end;

destructor TSSLBufferPool.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TSSLBufferPool.Acquire: TBytes;
begin
  FLock.Enter;
  try
    if FCount > 0 then
    begin
      Dec(FCount);
      Result := FPool[FCount];
      FPool[FCount] := nil;
    end
    else
    begin
      SetLength(Result, FBufferSize);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLBufferPool.Release(var ABuffer: TBytes);
begin
  if Length(ABuffer) <> FBufferSize then
  begin
    SetLength(ABuffer, 0);
    Exit;
  end;
  FLock.Enter;
  try
    if FCount < FMaxPooled then
    begin
      FPool[FCount] := ABuffer;
      Inc(FCount);
      ABuffer := nil;
    end
    else
      SetLength(ABuffer, 0);
  finally
    FLock.Leave;
  end;
end;

initialization
  GlobalBufferPool := TSSLBufferPool.Create;

finalization
  GlobalBufferPool.Free;

end.
