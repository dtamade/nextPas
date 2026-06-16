unit nextpas.core.io.reactor;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.atomic, nextpas.core.platform.posix.base, nextpas.core.platform.linux.base, nextpas.core.platform.linux.modern, nextpas.core.io.uring;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TIoReactorEntry = record
    Callback: TIoCompletion;
    Context: Pointer;
    NextFree: Int32;
    Active: Boolean;
  end;

  TIoReactor = record
  private
    FRing: TIoUring;
    FEntries: array of TIoReactorEntry;
    FEntryCount: UInt32;
    FEntryCap: UInt32;
    FPendingCount: UInt32;
    FFreeHead: Int32;
    FRunning: Int32;
    function AllocEntry(ACallback: TIoCompletion; AContext: Pointer): UInt64;
    procedure FreeEntry(AId: UInt64);
    procedure ReleasePendingEntries(AResult: Int32);
    procedure DispatchCqe(ACqe: PIoUringCqe);
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
    function HasPending: Boolean;
  end;

implementation


const
  INITIAL_ENTRIES = 256;

type
  TIoReactorPendingRelease = record
    Callback: TIoCompletion;
    Context: Pointer;
    UserData: UInt64;
  end;

class function TIoReactor.Create(AQueueDepth: UInt32): TIoReactor;
begin
  Result := Default(TIoReactor);
  Result.FRing := TIoUring.Create(AQueueDepth);
  if not Result.FRing.IsValid then Exit;
  Result.FEntryCap := INITIAL_ENTRIES;
  SetLength(Result.FEntries, INITIAL_ENTRIES);
  Result.FEntryCount := 0;
  Result.FPendingCount := 0;
  Result.FFreeHead := -1;
  AtomicStore32(Result.FRunning, 0, moRelease);
end;

procedure TIoReactor.Close;
begin
  AtomicStore32(FRunning, 0, moRelease);
  try
    ReleasePendingEntries(-ESysECANCELED);
  finally
    FRing.Close;
    SetLength(FEntries, 0);
    FEntryCount := 0;
    FEntryCap := 0;
    FPendingCount := 0;
    FFreeHead := -1;
  end;
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
  FEntries[LIdx].Active := True;
  Inc(FPendingCount);
  Result := LIdx;
end;

procedure TIoReactor.FreeEntry(AId: UInt64);
begin
  if AId >= FEntryCount then Exit;
  if not FEntries[AId].Active then
    Exit;
  if FPendingCount > 0 then
    Dec(FPendingCount);
  FEntries[AId].Callback := nil;
  FEntries[AId].Context := nil;
  FEntries[AId].Active := False;
  FEntries[AId].NextFree := FFreeHead;
  FFreeHead := Int32(AId);
end;

procedure TIoReactor.ReleasePendingEntries(AResult: Int32);
var
  LI: UInt32;
  LReleaseCount: UInt32;
  LReleases: array of TIoReactorPendingRelease;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  if FPendingCount = 0 then
    Exit;
  SetLength(LReleases, FEntryCount);
  LReleaseCount := 0;
  for LI := 0 to FEntryCount - 1 do
  begin
    if not FEntries[LI].Active then
      Continue;
    if Assigned(FEntries[LI].Callback) then
    begin
      LReleases[LReleaseCount].Callback := FEntries[LI].Callback;
      LReleases[LReleaseCount].Context := FEntries[LI].Context;
      LReleases[LReleaseCount].UserData := UInt64(LI);
      Inc(LReleaseCount);
    end;
    FEntries[LI].Callback := nil;
    FEntries[LI].Context := nil;
    FEntries[LI].Active := False;
    FEntries[LI].NextFree := -1;
  end;
  FEntryCount := 0;
  FPendingCount := 0;
  FFreeHead := -1;
  if LReleaseCount = 0 then
    Exit;
  LHasException := False;
  LExceptionMessage := '';
  FRing.Close;
  for LI := 0 to LReleaseCount - 1 do
  begin
    try
      LReleases[LI].Callback(LReleases[LI].UserData, AResult,
        LReleases[LI].Context);
    except
      on E: Exception do
      begin
        if not LHasException then
        begin
          LHasException := True;
          LExceptionMessage := E.Message;
        end;
      end;
    end;
  end;
  if LHasException then
    raise Exception.Create(LExceptionMessage);
end;

procedure TIoReactor.DispatchCqe(ACqe: PIoUringCqe);
var
  LId: UInt64;
  LResult: Int32;
  LCallback: TIoCompletion;
  LContext: Pointer;
begin
  LId := IoUringCqeGetData(ACqe);
  LResult := ACqe^.res;
  LCallback := nil;
  LContext := nil;
  if (LId < FEntryCount) and FEntries[LId].Active then
  begin
    LCallback := FEntries[LId].Callback;
    LContext := FEntries[LId].Context;
    FreeEntry(LId);
  end;
  FRing.CqeSeen(ACqe);
  if Assigned(LCallback) then
    LCallback(LId, LResult, LContext);
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
  if not IsValid then
    Exit(0);
  Result := FRing.Submit;
end;

function TIoReactor.HasPending: Boolean;
begin
  Result := FPendingCount > 0;
end;

function TIoReactor.PollOne: Boolean;
var
  LCqe: PIoUringCqe;
begin
  if not FRing.PeekCqe(LCqe) then
  begin
    Result := False;
    Exit;
  end;
  DispatchCqe(LCqe);
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
const
  EINTR = 4;
  EAGAIN = 11;
begin
  if not IsValid then
    Exit;
  AtomicStore32(FRunning, 1, moRelease);
  while AtomicLoad32(FRunning, moAcquire) <> 0 do
  begin
    LRet := FRing.SubmitAndWait(1);
    if LRet < 0 then
    begin
      if (LRet = -EINTR) or (LRet = -EAGAIN) then Continue;
      Break;
    end;
    while (AtomicLoad32(FRunning, moAcquire) <> 0) and FRing.PeekCqe(LCqe) do
      DispatchCqe(LCqe);
  end;
end;

procedure TIoReactor.Stop;
begin
  AtomicStore32(FRunning, 0, moRelease);
end;

end.
