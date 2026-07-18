unit nextpas.core.net.async.backpressure;
{**
 * @desc 异步背压控制：管理数据流的速率，防止缓冲区溢出。
 *       支持高/低水位标记、暂停/恢复读取。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 背压状态 }
  TBackpressureState = (
    bpsNormal,      // 正常状态
    bpsPaused,      // 已暂停（达到高水位）
    bpsDraining     // 排空中（低于低水位，恢复读取）
  );

  { 背压配置 }
  TBackpressureConfig = record
    HighWaterMark: UInt32;  // 高水位标记（暂停读取）
    LowWaterMark: UInt32;   // 低水位标记（恢复读取）
    class function Default: TBackpressureConfig; static;
  end;

  { 背压回调 }
  TBackpressureCallback = procedure(AState: TBackpressureState; AContext: Pointer);

  { 背压控制器接口 }
  IBackpressureController = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-600000000001}']
    { 写入数据（返回实际写入的字节数） }
    function Write(const AData; ASize: UInt32): UInt32;

    { 读取数据（返回实际读取的字节数） }
    function Read(var AData; ASize: UInt32): UInt32;

    { 获取当前缓冲区大小 }
    function BufferedSize: UInt32;

    { 获取状态 }
    function State: TBackpressureState;

    { 手动暂停/恢复 }
    procedure Pause;
    procedure Resume;

    { 关闭 }
    procedure Close;
  end;

{ 创建背压控制器 }
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

    procedure CheckWaterMarks;
    procedure GrowBuffer(ANewCap: UInt32);
  public
    constructor Create(const ALoop: TAsyncLoop; const AConfig: TBackpressureConfig);
    destructor Destroy; override;

    { IBackpressureController }
    function Write(const AData; ASize: UInt32): UInt32;
    function Read(var AData; ASize: UInt32): UInt32;
    function BufferedSize: UInt32;
    function State: TBackpressureState;
    procedure Pause;
    procedure Resume;
    procedure Close;
  end;

{ TBackpressureConfig }

class function TBackpressureConfig.Default: TBackpressureConfig;
begin
  Result.HighWaterMark := 64 * 1024;  // 64KB
  Result.LowWaterMark := 16 * 1024;   // 16KB
end;

{ TBackpressureController }

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

procedure TBackpressureController.CheckWaterMarks;
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
  if (FState <> LOldState) and Assigned(FOnStateChange) then
    FOnStateChange(FState, FOnStateChangeCtx);
end;

procedure TBackpressureController.GrowBuffer(ANewCap: UInt32);
var
  LNewBuf: array of Byte;
  LReadPos, LHead, LTail: UInt32;
begin
  if ANewCap <= FBufferCap then Exit;
  if FBufferSize = 0 then
  begin
    { 空缓冲区，直接扩容 }
    SetLength(FBuffer, ANewCap);
    FBufferCap := ANewCap;
    FBufferPos := 0;
    Exit;
  end;
  { 环形缓冲区可能 wrap，需要拆包到线性布局 }
  SetLength(LNewBuf, ANewCap);
  LReadPos := FBufferPos - FBufferSize;
  if LReadPos >= FBufferCap then
    LReadPos := LReadPos + FBufferCap;
  if LReadPos + FBufferSize <= FBufferCap then
  begin
    { 数据未 wrap，单次拷贝 }
    Move(FBuffer[LReadPos], LNewBuf[0], FBufferSize);
  end
  else
  begin
    { 数据已 wrap，两段拷贝 }
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
begin
  if FClosed then Exit(0);
  if ASize = 0 then Exit(0);

  platform_mutex_lock(FLock);
  try
    { 如果已暂停，不接受更多数据 }
    if FState = bpsPaused then
      Exit(0);

    { 确保缓冲区足够大 }
    if FBufferSize + ASize > FBufferCap then
      GrowBuffer(FBufferSize + ASize);

    { 写入数据 }
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

    CheckWaterMarks;
    Result := ASize;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TBackpressureController.Read(var AData; ASize: UInt32): UInt32;
var
  LDst: PByte;
  LRemaining: UInt32;
  LChunk: UInt32;
  LReadPos: UInt32;
begin
  if FClosed then Exit(0);
  if ASize = 0 then Exit(0);

  platform_mutex_lock(FLock);
  try
    if FBufferSize = 0 then Exit(0);

    { 读取数据 }
    LDst := PByte(@AData);
    LRemaining := ASize;
    if LRemaining > FBufferSize then
      LRemaining := FBufferSize;

    { 计算读取位置 }
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

    CheckWaterMarks;
  finally
    platform_mutex_unlock(FLock);
  end;
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
begin
  platform_mutex_lock(FLock);
  try
    FState := bpsPaused;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TBackpressureController.Resume;
begin
  platform_mutex_lock(FLock);
  try
    if FState = bpsPaused then
      FState := bpsDraining;
    CheckWaterMarks;
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
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ 工厂函数 }

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
