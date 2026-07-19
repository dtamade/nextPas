unit nextpas.core.net.async.backpressure;
{**
 * @desc 异步背压控制：管理数据流的速率，防止缓冲区溢出。
 *       支持高/低水位标记、暂停/恢复读取；OnStateChange 经 loop.Post 通知。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.async.base, nextpas.core.async.loop;

type
  TBackpressureState = (
    bpsNormal,
    bpsPaused,
    bpsDraining
  );

  TBackpressureConfig = record
    HighWaterMark: UInt32;
    LowWaterMark: UInt32;
    class function Default: TBackpressureConfig; static;
  end;

  TBackpressureCallback = procedure(AState: TBackpressureState; AContext: Pointer);

  IBackpressureController = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-600000000001}']
    function Write(const AData; ASize: UInt32): UInt32;
    function Read(var AData; ASize: UInt32): UInt32;
    function BufferedSize: UInt32;
    function State: TBackpressureState;
    procedure Pause;
    procedure Resume;
    { State-change notify is Post'ed on the loop thread (not under lock). }
    procedure OnStateChange(ACallback: TBackpressureCallback; AContext: Pointer);
    procedure Close;
  end;

function CreateBackpressureController(const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController;
overload;

function CreateBackpressureController(const ALoop: TAsyncLoop): IBackpressureController;
overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync;

type
  PStateNotifyCtx = ^TStateNotifyCtx;
  TStateNotifyCtx = record
    Callback: TBackpressureCallback;
    State: TBackpressureState;
    Context: Pointer;
  end;

  TBackpressureController = class(TInterfacedObject, IBackpressureController)
  private
    FLoop: TAsyncLoop;
    FConfig: TBackpressureConfig;
    FState: TBackpressureState;
    FBuffer: array of Byte;
    FBufferPos: UInt32;
    FBufferSize: UInt32;
    FBufferCap: UInt32;
    FLock: TPlatformMutex;
    FClosed: Boolean;
    FOnStateChange: TBackpressureCallback;
    FOnStateChangeCtx: Pointer;

    { Returns True if state changed and a Post is required after unlock. }
    function CheckWaterMarks(out ANewState: TBackpressureState): Boolean;
    procedure GrowBuffer(ANewCap: UInt32);
    procedure PostStateChange(ACallback: TBackpressureCallback;
      AState: TBackpressureState; AContext: Pointer);
  public
    constructor Create(const ALoop: TAsyncLoop; const AConfig: TBackpressureConfig);
    destructor Destroy; override;

    function Write(const AData; ASize: UInt32): UInt32;
    function Read(var AData; ASize: UInt32): UInt32;
    function BufferedSize: UInt32;
    function State: TBackpressureState;
    procedure Pause;
    procedure Resume;
    procedure OnStateChange(ACallback: TBackpressureCallback; AContext: Pointer);
    procedure Close;
  end;

procedure StateNotifyCallback(AContext: Pointer);
var
  LCtx: PStateNotifyCtx;
begin
  LCtx := PStateNotifyCtx(AContext);
  try
    if Assigned(LCtx^.Callback) then
      LCtx^.Callback(LCtx^.State, LCtx^.Context);
  finally
    Dispose(LCtx);
  end;
end;

procedure StateNotifyDiscard(AContext: Pointer);
begin
  if AContext <> nil then
    Dispose(PStateNotifyCtx(AContext));
end;

class function TBackpressureConfig.Default: TBackpressureConfig;
begin
  Result.HighWaterMark := 64 * 1024;
  Result.LowWaterMark := 16 * 1024;
end;

constructor TBackpressureController.Create(const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig);
begin
  inherited Create;
  FLoop := ALoop;
  FConfig := AConfig;
  FState := bpsNormal;
  FBufferPos := 0;
  FBufferSize := 0;
  FBufferCap := AConfig.LowWaterMark;
  if FBufferCap = 0 then
    FBufferCap := 1;
  SetLength(FBuffer, FBufferCap);
  FClosed := False;
  FOnStateChange := nil;
  FOnStateChangeCtx := nil;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('backpressure: mutex init failed');
end;

destructor TBackpressureController.Destroy;
begin
  Close;
  platform_mutex_destroy(FLock);
  inherited;
end;

function TBackpressureController.CheckWaterMarks(out ANewState: TBackpressureState): Boolean;
var
  LOldState: TBackpressureState;
begin
  LOldState := FState;
  case FState of
    bpsNormal:
      begin
        if FBufferSize >= FConfig.HighWaterMark then
          FState := bpsPaused;
      end;
    bpsPaused:
      begin
        if FBufferSize <= FConfig.LowWaterMark then
          FState := bpsDraining;
      end;
    bpsDraining:
      begin
        if FBufferSize = 0 then
          FState := bpsNormal
        else if FBufferSize >= FConfig.HighWaterMark then
          FState := bpsPaused;
      end;
  end;
  ANewState := FState;
  Result := (FState <> LOldState) and Assigned(FOnStateChange);
end;

procedure TBackpressureController.PostStateChange(ACallback: TBackpressureCallback;
  AState: TBackpressureState; AContext: Pointer);
var
  LCtx: PStateNotifyCtx;
begin
  if not Assigned(ACallback) or (FLoop = nil) or (not FLoop.IsValid) then
    Exit;
  New(LCtx);
  LCtx^.Callback := ACallback;
  LCtx^.State := AState;
  LCtx^.Context := AContext;
  try
    FLoop.PostEx(@StateNotifyCallback, LCtx, @StateNotifyDiscard);
  except
    Dispose(LCtx);
    raise;
  end;
end;

procedure TBackpressureController.GrowBuffer(ANewCap: UInt32);
var
  LNewBuf: array of Byte;
  LReadPos, LHead, LTail: UInt32;
begin
  if ANewCap <= FBufferCap then Exit;
  if FBufferSize = 0 then
  begin
    SetLength(FBuffer, ANewCap);
    FBufferCap := ANewCap;
    FBufferPos := 0;
    Exit;
  end;
  SetLength(LNewBuf, ANewCap);
  LReadPos := FBufferPos - FBufferSize;
  if LReadPos >= FBufferCap then
    LReadPos := LReadPos + FBufferCap;
  if LReadPos + FBufferSize <= FBufferCap then
    Move(FBuffer[LReadPos], LNewBuf[0], FBufferSize)
  else
  begin
    LHead := FBufferCap - LReadPos;
    Move(FBuffer[LReadPos], LNewBuf[0], LHead);
    LTail := FBufferSize - LHead;
    Move(FBuffer[0], LNewBuf[LHead], LTail);
  end;
  FBuffer := LNewBuf;
  FBufferCap := ANewCap;
  FBufferPos := FBufferSize;
end;

function TBackpressureController.Write(const AData; ASize: UInt32): UInt32;
var
  LSrc: PByte;
  LRemaining: UInt32;
  LChunk: UInt32;
  LNotify: Boolean;
  LState: TBackpressureState;
  LCb: TBackpressureCallback;
  LCtx: Pointer;
begin
  if FClosed then Exit(0);
  if ASize = 0 then Exit(0);
  LNotify := False;
  LState := bpsNormal;
  LCb := nil;
  LCtx := nil;

  platform_mutex_lock(FLock);
  try
    if FState = bpsPaused then
      Exit(0);

    if FBufferSize + ASize > FBufferCap then
      GrowBuffer(FBufferSize + ASize);

    LSrc := PByte(@AData);
    LRemaining := ASize;
    while LRemaining > 0 do
    begin
      LChunk := LRemaining;
      if FBufferPos + LChunk > FBufferCap then
        LChunk := FBufferCap - FBufferPos;
      Move(LSrc^, FBuffer[FBufferPos], LChunk);
      Inc(LSrc, LChunk);
      Inc(FBufferPos, LChunk);
      Inc(FBufferSize, LChunk);
      Dec(LRemaining, LChunk);
      if FBufferPos >= FBufferCap then
        FBufferPos := 0;
    end;

    LNotify := CheckWaterMarks(LState);
    if LNotify then
    begin
      LCb := FOnStateChange;
      LCtx := FOnStateChangeCtx;
    end;
    Result := ASize;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LNotify then
    PostStateChange(LCb, LState, LCtx);
end;

function TBackpressureController.Read(var AData; ASize: UInt32): UInt32;
var
  LDst: PByte;
  LRemaining: UInt32;
  LChunk: UInt32;
  LReadPos: UInt32;
  LNotify: Boolean;
  LState: TBackpressureState;
  LCb: TBackpressureCallback;
  LCtx: Pointer;
begin
  if FClosed then Exit(0);
  if ASize = 0 then Exit(0);
  LNotify := False;
  LState := bpsNormal;
  LCb := nil;
  LCtx := nil;

  platform_mutex_lock(FLock);
  try
    if FBufferSize = 0 then Exit(0);

    LDst := PByte(@AData);
    LRemaining := ASize;
    if LRemaining > FBufferSize then
      LRemaining := FBufferSize;

    LReadPos := FBufferPos - FBufferSize;
    if LReadPos >= FBufferCap then
      LReadPos := LReadPos + FBufferCap;

    Result := LRemaining;
    while LRemaining > 0 do
    begin
      LChunk := LRemaining;
      if LReadPos + LChunk > FBufferCap then
        LChunk := FBufferCap - LReadPos;
      Move(FBuffer[LReadPos], LDst^, LChunk);
      Inc(LDst, LChunk);
      Inc(LReadPos, LChunk);
      Dec(FBufferSize, LChunk);
      Dec(LRemaining, LChunk);
      if LReadPos >= FBufferCap then
        LReadPos := 0;
    end;

    LNotify := CheckWaterMarks(LState);
    if LNotify then
    begin
      LCb := FOnStateChange;
      LCtx := FOnStateChangeCtx;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LNotify then
    PostStateChange(LCb, LState, LCtx);
end;

function TBackpressureController.BufferedSize: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FBufferSize;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TBackpressureController.State: TBackpressureState;
begin
  platform_mutex_lock(FLock);
  try
    Result := FState;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TBackpressureController.Pause;
var
  LNotify: Boolean;
  LOld: TBackpressureState;
  LCb: TBackpressureCallback;
  LCtx: Pointer;
begin
  LNotify := False;
  LCb := nil;
  LCtx := nil;
  platform_mutex_lock(FLock);
  try
    LOld := FState;
    FState := bpsPaused;
    LNotify := (FState <> LOld) and Assigned(FOnStateChange);
    if LNotify then
    begin
      LCb := FOnStateChange;
      LCtx := FOnStateChangeCtx;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LNotify then
    PostStateChange(LCb, bpsPaused, LCtx);
end;

procedure TBackpressureController.Resume;
var
  LNotify: Boolean;
  LState: TBackpressureState;
  LCb: TBackpressureCallback;
  LCtx: Pointer;
begin
  LNotify := False;
  LState := bpsNormal;
  LCb := nil;
  LCtx := nil;
  platform_mutex_lock(FLock);
  try
    if FState = bpsPaused then
      FState := bpsDraining;
    LNotify := CheckWaterMarks(LState);
    if LNotify then
    begin
      LCb := FOnStateChange;
      LCtx := FOnStateChangeCtx;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LNotify then
    PostStateChange(LCb, LState, LCtx);
end;

procedure TBackpressureController.OnStateChange(ACallback: TBackpressureCallback;
  AContext: Pointer);
begin
  platform_mutex_lock(FLock);
  try
    FOnStateChange := ACallback;
    FOnStateChangeCtx := AContext;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TBackpressureController.Close;
begin
  platform_mutex_lock(FLock);
  try
    FClosed := True;
    FBuffer := nil;
    FBufferSize := 0;
    FBufferCap := 0;
    FOnStateChange := nil;
    FOnStateChangeCtx := nil;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function CreateBackpressureController(const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController;
begin
  Result := TBackpressureController.Create(ALoop, AConfig);
end;

function CreateBackpressureController(const ALoop: TAsyncLoop): IBackpressureController;
begin
  Result := TBackpressureController.Create(ALoop, TBackpressureConfig.Default);
end;

end.
