unit nextpas.core.http.impl.h1.outbound;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf;

type
  IH1OutboundBuffer = interface(IWriter)
    ['{6F1D6F1D-4D7C-4E31-9100-510000000001}']
    function PendingBytes: SizeUInt;
    function IsEmpty: Boolean;
    function DrainAllTo(const AWriter: IWriter): SizeUInt;
    function TryDrainTo(const ARuntime: ITcpStreamRuntime;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    procedure Reset;
  end;

function NewH1OutboundBuffer: IH1OutboundBuffer;

implementation

uses
  nextpas.core.errors;

type
  TH1OutboundBuffer = class(TInterfacedObject, IWriter, IH1OutboundBuffer)
  private
    FBuf: array of Byte;
    FReadPos: SizeUInt;
    FWritePos: SizeUInt;
    procedure Compact;
    procedure EnsureCapacity(const AExtra: SizeUInt);
    procedure Advance(const ACount: SizeUInt); inline;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function PendingBytes: SizeUInt; inline;
    function IsEmpty: Boolean; inline;
    function DrainAllTo(const AWriter: IWriter): SizeUInt;
    function TryDrainTo(const ARuntime: ITcpStreamRuntime;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    procedure Reset;
  end;

procedure RaiseDrainFailure;
begin
  raise EIOError.Create('h1 outbound buffer: write failed (zero progress)');
end;

procedure RaiseDrainOverreport;
begin
  raise EIOError.Create('h1 outbound buffer: write over-reported progress');
end;

function TH1OutboundBuffer.PendingBytes: SizeUInt; inline;
begin
  Result := FWritePos - FReadPos;
end;

function TH1OutboundBuffer.IsEmpty: Boolean; inline;
begin
  Result := PendingBytes = 0;
end;

procedure TH1OutboundBuffer.Compact;
var
  LPending: SizeUInt;
begin
  LPending := PendingBytes;
  if LPending > 0 then
    Move(FBuf[FReadPos], FBuf[0], LPending);
  FReadPos := 0;
  FWritePos := LPending;
end;

procedure TH1OutboundBuffer.EnsureCapacity(const AExtra: SizeUInt);
var
  LPending: SizeUInt;
  LNeed: SizeUInt;
  LCap: SizeUInt;
begin
  LPending := PendingBytes;
  LNeed := LPending + AExtra;
  LCap := SizeUInt(Length(FBuf));
  if LNeed <= (LCap - FWritePos) then
    Exit;
  if (FReadPos > 0) and (LNeed <= LCap) then
  begin
    Compact;
    Exit;
  end;
  if LCap = 0 then
    LCap := 64;
  while LCap < LNeed do
    LCap := LCap * 2;
  SetLength(FBuf, LCap);
  if FReadPos > 0 then
    Compact;
end;

procedure TH1OutboundBuffer.Advance(const ACount: SizeUInt); inline;
begin
  Inc(FReadPos, ACount);
  if FReadPos >= FWritePos then
    Reset
  else if FReadPos >= (SizeUInt(Length(FBuf)) div 2) then
    Compact;
end;

function TH1OutboundBuffer.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  EnsureCapacity(ACount);
  Move(ABuf, FBuf[FWritePos], ACount);
  Inc(FWritePos, ACount);
  Result := ACount;
end;

function TH1OutboundBuffer.DrainAllTo(const AWriter: IWriter): SizeUInt;
var
  LWritten: SizeUInt;
begin
  Result := 0;
  while PendingBytes > 0 do
  begin
    LWritten := AWriter.Write(FBuf[FReadPos], PendingBytes);
    if LWritten = 0 then
      RaiseDrainFailure;
    if LWritten > PendingBytes then
      RaiseDrainOverreport;
    Advance(LWritten);
    Inc(Result, LWritten);
  end;
end;

function TH1OutboundBuffer.TryDrainTo(const ARuntime: ITcpStreamRuntime;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := 0;
  if PendingBytes = 0 then
    Exit(tsiorOk);
  Result := ARuntime.TryWrite(FBuf[FReadPos], PendingBytes, AWritten);
  if Result = tsiorOk then
  begin
    if AWritten = 0 then
      RaiseDrainFailure;
    if AWritten > PendingBytes then
      RaiseDrainOverreport;
    Advance(AWritten);
  end;
end;

procedure TH1OutboundBuffer.Reset;
begin
  FReadPos := 0;
  FWritePos := 0;
end;

function NewH1OutboundBuffer: IH1OutboundBuffer;
begin
  Result := TH1OutboundBuffer.Create;
end;

end.
