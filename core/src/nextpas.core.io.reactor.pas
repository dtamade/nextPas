unit nextpas.core.io.reactor;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TIoReactorEntry = record
    Callback: TIoCompletion;
    Context: Pointer;
    NextFree: Int32;
  end;

  TIoReactor = record
  private
    FRing: TIoUring;
    FEntries: array of TIoReactorEntry;
    FEntryCount: UInt32;
    FEntryCap: UInt32;
    FFreeHead: Int32;
    FRunning: Int32;
    function AllocEntry(ACallback: TIoCompletion; AContext: Pointer): UInt64;
    procedure FreeEntry(AId: UInt64);
  public
    class function Create(AQueueDepth: UInt32 = 64): TIoReactor; static;
    procedure Close;
    function IsValid: Boolean; inline;

    // Submit async operations
    function AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: Int32; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncNop(ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    // Event loop
    function Poll: Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
  end;

implementation

const
  INITIAL_ENTRIES = 256;

class function TIoReactor.Create(AQueueDepth: UInt32): TIoReactor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FRing := TIoUring.Create(AQueueDepth);
  if not Result.FRing.IsValid then Exit;
  Result.FEntryCap := INITIAL_ENTRIES;
  SetLength(Result.FEntries, INITIAL_ENTRIES);
  Result.FEntryCount := 0;
  Result.FFreeHead := -1;
  AtomicStore32(Result.FRunning, 0, moRelaxed);
end;

procedure TIoReactor.Close;
begin
  FRing.Close;
  SetLength(FEntries, 0);
  FEntryCount := 0;
end;

function TIoReactor.IsValid: Boolean;
begin
  Result := FRing.IsValid;
end;

function TIoReactor.AllocEntry(ACallback: TIoCompletion; AContext: Pointer): UInt64;
var
  LIdx: UInt32;
begin
  if FFreeHead >= 0 then
  begin
    LIdx := UInt32(FFreeHead);
    FFreeHead := FEntries[LIdx].NextFree;
  end
  else
  begin
    if FEntryCount >= FEntryCap then
    begin
      FEntryCap := FEntryCap * 2;
      SetLength(FEntries, FEntryCap);
    end;
    LIdx := FEntryCount;
    Inc(FEntryCount);
  end;
  FEntries[LIdx].Callback := ACallback;
  FEntries[LIdx].Context := AContext;
  FEntries[LIdx].NextFree := -1;
  Result := LIdx;
end;

procedure TIoReactor.FreeEntry(AId: UInt64);
begin
  if AId >= FEntryCount then Exit;
  FEntries[AId].Callback := nil;
  FEntries[AId].Context := nil;
  FEntries[AId].NextFree := FFreeHead;
  FFreeHead := Int32(AId);
end;

function TIoReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepRead(LSqe, AFd, ABuf, ALen, AOffset);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepWrite(LSqe, AFd, ABuf, ALen, AOffset);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepAccept(LSqe, AFd, AAddr, AAddrLen, AFlags);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncConnect(AFd: Int32; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepConnect(LSqe, AFd, AAddr, AAddrLen);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepSend(LSqe, AFd, ABuf, ALen, AFlags);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepRecv(LSqe, AFd, ABuf, ALen, AFlags);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncClose(AFd: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepClose(LSqe, AFd);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.AsyncNop(ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LSqe: PIoUringSqe;
  LId: UInt64;
begin
  LSqe := FRing.GetSqe;
  if LSqe = nil then begin Result := False; Exit; end;
  LId := AllocEntry(ACallback, AContext);
  IoUringPrepNop(LSqe);
  IoUringSqeSetData(LSqe, LId);
  Result := True;
end;

function TIoReactor.Flush: Int32;
begin
  Result := FRing.Submit;
end;

function TIoReactor.PollOne: Boolean;
var
  LCqe: PIoUringCqe;
  LId: UInt64;
begin
  if not FRing.PeekCqe(LCqe) then
  begin
    Result := False;
    Exit;
  end;
  LId := IoUringCqeGetData(LCqe);
  try
    if (LId < FEntryCount) and Assigned(FEntries[LId].Callback) then
      FEntries[LId].Callback(LId, LCqe^.res, FEntries[LId].Context);
  finally
    FRing.CqeSeen(LCqe);
    if LId < FEntryCount then
      FreeEntry(LId);
  end;
  Result := True;
end;

function TIoReactor.Poll: Int32;
var
  LCount: Int32;
begin
  LCount := 0;
  while PollOne do
    Inc(LCount);
  Result := LCount;
end;

procedure TIoReactor.Run;
var
  LRet: Int32;
  LCqe: PIoUringCqe;
  LId: UInt64;
const
  EINTR = 4;
  EAGAIN = 11;
begin
  AtomicStore32(FRunning, 1, moRelaxed);
  while AtomicLoad32(FRunning, moRelaxed) <> 0 do
  begin
    LRet := FRing.SubmitAndWait(1);
    if LRet < 0 then
    begin
      if (LRet = -EINTR) or (LRet = -EAGAIN) then Continue;
      Break;
    end;
    while (AtomicLoad32(FRunning, moRelaxed) <> 0) and FRing.PeekCqe(LCqe) do
    begin
      LId := IoUringCqeGetData(LCqe);
      try
        if (LId < FEntryCount) and Assigned(FEntries[LId].Callback) then
          FEntries[LId].Callback(LId, LCqe^.res, FEntries[LId].Context);
      finally
        FRing.CqeSeen(LCqe);
        if LId < FEntryCount then
          FreeEntry(LId);
      end;
    end;
  end;
end;

procedure TIoReactor.Stop;
begin
  AtomicStore32(FRunning, 0, moRelaxed);
end;

end.
