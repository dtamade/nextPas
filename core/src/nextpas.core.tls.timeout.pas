unit nextpas.core.tls.timeout;

{$mode objfpc}{$H+}{$J-}

interface

uses
   nextpas.core.system.classes,
  nextpas.core.io.base,
  nextpas.core.io.intf;

type
  TTimeoutStream = class(TInterfacedObject, IStream)
  private
    FInner: IStream;
    FReadTimeout: Integer;
    FWriteTimeout: Integer;
    FConnectTimeout: Integer;
    procedure ApplyReadTimeout;
    procedure ApplyWriteTimeout;
  public
    constructor Create(AInner: IStream; AReadTimeoutMs: Integer = 30000;
      AWriteTimeoutMs: Integer = 30000); overload;
    constructor Create(AInner: TStream; AReadTimeoutMs: Integer = 30000;
      AWriteTimeoutMs: Integer = 30000); overload;
    function Read(var Buffer; Count: Longint): Longint; overload;
    function Write(const Buffer; Count: Longint): Longint; overload;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt; overload;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; overload;
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64; overload;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);

    property ReadTimeout: Integer read FReadTimeout write FReadTimeout;
    property WriteTimeout: Integer read FWriteTimeout write FWriteTimeout;
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    property InnerStream: IStream read FInner;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.stream_adapter,
  nextpas.core.net.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

constructor TTimeoutStream.Create(AInner: IStream; AReadTimeoutMs: Integer;
  AWriteTimeoutMs: Integer);
begin
  inherited Create;
  FInner := AInner;
  FReadTimeout := AReadTimeoutMs;
  FWriteTimeout := AWriteTimeoutMs;
  FConnectTimeout := 10000;
end;

constructor TTimeoutStream.Create(AInner: TStream; AReadTimeoutMs: Integer;
  AWriteTimeoutMs: Integer);
begin
  Create(WrapTStream(AInner, False), AReadTimeoutMs, AWriteTimeoutMs);
end;

procedure TTimeoutStream.ApplyReadTimeout;
var
  LTcp: ITcpStream;
begin
  if (FInner <> nil) and Supports(FInner, ITcpStream, LTcp) then
  begin
    if FReadTimeout < 0 then
      LTcp.SetReadDeadline(TDeadline.Infinite)
    else
      LTcp.SetReadDeadline(
        TDeadline.After(TDuration.FromMilliseconds(FReadTimeout))
      );
  end;
end;

procedure TTimeoutStream.ApplyWriteTimeout;
var
  LTcp: ITcpStream;
begin
  if (FInner <> nil) and Supports(FInner, ITcpStream, LTcp) then
  begin
    if FWriteTimeout < 0 then
      LTcp.SetWriteDeadline(TDeadline.Infinite)
    else
      LTcp.SetWriteDeadline(
        TDeadline.After(TDuration.FromMilliseconds(FWriteTimeout))
      );
  end;
end;

function TTimeoutStream.Read(var Buffer; Count: Longint): Longint;
begin
  if Count <= 0 then
    Exit(0);
  Result := Longint(Read(Buffer, SizeUInt(Count)));
end;

function TTimeoutStream.Write(const Buffer; Count: Longint): Longint;
begin
  if Count <= 0 then
    Exit(0);
  Result := Longint(Write(Buffer, SizeUInt(Count)));
end;

function TTimeoutStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FInner = nil) or (ACount = 0) then
    Exit(0);
  ApplyReadTimeout;
  try
    Result := FInner.Read(ABuf, ACount);
  except
    on E: ENetworkError do
      if Pos('deadline exceeded', LowerCase(E.Message)) > 0 then
        Exit(0)
      else
        raise;
  end;
end;

function TTimeoutStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FInner = nil) or (ACount = 0) then
    Exit(0);
  ApplyWriteTimeout;
  try
    Result := FInner.Write(ABuf, ACount);
  except
    on E: ENetworkError do
      if Pos('deadline exceeded', LowerCase(E.Message)) > 0 then
        Exit(0)
      else
        raise;
  end;
end;

function TTimeoutStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Seek(AOffset, AOrigin);
end;

procedure TTimeoutStream.Close;
begin
  if FInner <> nil then
    FInner.Close;
end;

function TTimeoutStream.GetSize: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Size;
end;

function TTimeoutStream.GetPosition: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Position;
end;

procedure TTimeoutStream.SetPosition(const AValue: Int64);
begin
  if FInner <> nil then
    FInner.Position := AValue;
end;

end.
