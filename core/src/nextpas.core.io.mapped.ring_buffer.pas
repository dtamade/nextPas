{$CODEPAGE UTF8}
unit nextpas.core.io.mapped.ring_buffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils, nextpas.core.mem.memory_map;

type
  {**
   * TMappedRingBufferMode
   *
   * @desc 映射环形缓冲区的访问模式
   *}
  TMappedRingBufferMode = (
    mrbProducer,    // 生产者模式（只写）
    mrbConsumer,    // 消费者模式（只读）
    mrbBidirectional // 双向模式（读写）
  );

  {**
   * TMappedRingBuffer
   *
   * @desc 基于内存映射的高性能跨进程环形缓冲区
   *       支持无锁的生产者/消费者模式
   *}
  TMappedRingBuffer = class
  private
    FMemoryMap: TMemoryMap;
    FSharedMemory: TSharedMemory;
    FIsShared: Boolean;
    FMode: TMappedRingBufferMode;
    FCapacity: UInt64;
    FElementSize: UInt32;
    FIsCreator: Boolean;

    // 内存布局指针
    FHeader: Pointer;
    // 双向布局：不再保留单一 SeqArray 指针
    FDataBuffer: Pointer;     // 本端“发送”方向数据区基址（Creator=AB，Opener=BA）
    FDataBufferIn: Pointer;   // 本端“接收”方向数据区基址（Creator=BA，Opener=AB）

    function SendSeqBase: PByte; inline;
    function ReceiveSeqBase: PByte; inline;
    function SendProducerSeqPtr: PInt64; inline;
    function SendConsumerSeqPtr: PInt64; inline;
    function SendCachedConsumerSeqPtr: PInt64; inline;
    function ReceiveProducerSeqPtr: PInt64; inline;
    function ReceiveConsumerSeqPtr: PInt64; inline;
    function ReceiveCachedProducerSeqPtr: PInt64; inline;
    procedure BindDataBuffers;
    procedure ResetSendDirection;
    procedure ResetReceiveDirection;
    function GetWriteIndex: UInt64; inline;
    function GetReadIndex: UInt64; inline;
    procedure SetWriteIndex(const Value: UInt64); inline;
    procedure SetReadIndex(const Value: UInt64); inline;
    function GetAvailableSpace: UInt64;
    function GetUsedSpace: UInt64;
    function CalculateRequiredSize(aCapacity: UInt64; aElementSize: UInt32): UInt64;
    procedure InitializeHeader(aCapacity: UInt64; aElementSize: UInt32);
    function ValidateHeader: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    {**
     * CreateFile
     *
     * @desc 创建基于文件的环形缓冲区
     * @param aFileName 文件路径
     * @param aCapacity 容量（元素个数）
     * @param aElementSize 单个元素大小（字节）
     * @param aMode 访问模式
     * @return 是否成功
     *}
    function CreateFile(const aFileName: string; aCapacity: UInt64;
      aElementSize: UInt32; aMode: TMappedRingBufferMode = mrbBidirectional): Boolean;

    {**
     * OpenFile
     *
     * @desc 打开已存在的文件环形缓冲区
     * @param aFileName 文件路径
     * @param aMode 访问模式
     * @return 是否成功
     *}
    function OpenFile(const aFileName: string;
      aMode: TMappedRingBufferMode = mrbBidirectional): Boolean;

    {**
     * CreateShared
     *
     * @desc 创建跨进程共享环形缓冲区
     * @param aName 共享内存名称
     * @param aCapacity 容量（元素个数）
     * @param aElementSize 单个元素大小（字节）
     * @param aMode 访问模式
     * @return 是否成功
     *}
    function CreateShared(const aName: string; aCapacity: UInt64;
      aElementSize: UInt32; aMode: TMappedRingBufferMode = mrbBidirectional): Boolean;

    {**
     * OpenShared
     *
     * @desc 打开已存在的共享环形缓冲区
     * @param aName 共享内存名称
     * @param aMode 访问模式
     * @return 是否成功
     *}
    function OpenShared(const aName: string;
      aMode: TMappedRingBufferMode = mrbBidirectional): Boolean;

    {**
     * Close
     *
     * @desc 关闭环形缓冲区
     *}
    procedure Close;

    {**
     * Push
     *
     * @desc 向缓冲区写入一个元素（生产者操作）
     * @param aData 数据指针
     * @return 是否成功（缓冲区满时返回 False）
     *}
    function Push(const aData: Pointer): Boolean;

    {**
     * Pop
     *
     * @desc 从缓冲区读取一个元素（消费者操作）
     * @param aData 数据指针（输出）
     * @return 是否成功（缓冲区空时返回 False）
     *}
    function Pop(aData: Pointer): Boolean;

    {**
     * Peek
     *
     * @desc 查看下一个元素但不移除
     * @param aData 数据指针（输出）
     * @return 是否成功
     *}
    function Peek(aData: Pointer): Boolean;

    {**
     * PushBatch
     *
     * @desc 批量写入元素
     * @param aData 数据数组指针
     * @param aCount 元素个数
     * @return 实际写入的元素个数
     *}
    function PushBatch(const aData: Pointer; aCount: UInt64): UInt64;

    {**
     * PopBatch
     *
     * @desc 批量读取元素
     * @param aData 数据数组指针（输出）
     * @param aCount 期望读取的元素个数
     * @return 实际读取的元素个数
     *}
    function PopBatch(aData: Pointer; aCount: UInt64): UInt64;

    {**
     * Clear
     *
     * @desc 清空缓冲区（重置读写指针）
     *}
    procedure Clear;

    {**
     * IsEmpty
     *
     * @desc 检查缓冲区是否为空
     *}
    function IsEmpty: Boolean; inline;

    {**
     * IsFull
     *
     * @desc 检查缓冲区是否已满
     *}
    function IsFull: Boolean; inline;

    {**
     * IsValid
     *
     * @desc 检查缓冲区是否有效
     *}
    function IsValid: Boolean; inline;

    // 属性
    property Capacity: UInt64 read FCapacity;
    property ElementSize: UInt32 read FElementSize;
    property AvailableSpace: UInt64 read GetAvailableSpace;
    property UsedSpace: UInt64 read GetUsedSpace;
    property Mode: TMappedRingBufferMode read FMode;
    property IsCreator: Boolean read FIsCreator;
  end;

implementation

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.atomic;

// Helper: next power of two for UInt64
function NextPow2U64(x: UInt64): UInt64; inline;
begin
  if x <= 1 then Exit(1);
  Dec(x);
  x := x or (x shr 1);
  x := x or (x shr 2);
  x := x or (x shr 4);
  x := x or (x shr 8);
  x := x or (x shr 16);
  x := x or (x shr 32);
  Inc(x);
  Result := x;
end;

function IsMappedRingBufferBackingSizeValid(const AStat: TPlatformFileStat;
  ARequiredSize: UInt64): Boolean; inline;
begin
  if AStat.Size < 0 then
    Exit(False);
  Result := UInt64(AStat.Size) >= ARequiredSize;
end;


const
  // 缓存行大小，避免伪共享
  CACHE_LINE_SIZE = 64;

type
  // 环形缓冲区头部结构（v2：支持双向两套ring）
  PMappedRingBufferHeader = ^TMappedRingBufferHeader;
  TMappedRingBufferHeader = packed record
    Magic: UInt32;           // 魔数，用于验证
    Version: UInt32;         // 版本号
    Capacity: UInt64;        // 容量（元素个数），强制为2的幂（两套ring共用此容量）
    Mask: UInt64;            // 快速取模掩码 = Capacity - 1
    ElementSize: UInt32;     // 单个元素大小
    Reserved1: UInt32;       // 保留字段
    // Ring AB（A->B）计数器（独立cacheline）
    ProducerSeq_AB: Int64;
    ConsumerSeq_AB: Int64;
    CachedConsumerSeq_AB: Int64;
    CachedProducerSeq_AB: Int64;
    AB_Padding: array[0..(CACHE_LINE_SIZE div SizeOf(Int64))*2-5] of Int64; // pad到两行，减少伪共享
    // Ring BA（B->A）计数器（独立cacheline）
    ProducerSeq_BA: Int64;
    ConsumerSeq_BA: Int64;
    CachedConsumerSeq_BA: Int64;
    CachedProducerSeq_BA: Int64;
    BA_Padding: array[0..(CACHE_LINE_SIZE div SizeOf(Int64))*2-5] of Int64;
    // 各区域偏移（相对基址）
    OffSeq_AB: UInt64;
    OffData_AB: UInt64;
    OffSeq_BA: UInt64;
    OffData_BA: UInt64;
  end;

const
  MAPPED_RINGBUFFER_MAGIC = $4D524246; // 'MRBF'
  MAPPED_RINGBUFFER_VERSION = 2;
  // 头部大小由头结构大小决定
  HEADER_SIZE = SizeOf(TMappedRingBufferHeader);

{ TMappedRingBuffer }

constructor TMappedRingBuffer.Create;
begin
  inherited Create;
  FMemoryMap := nil;
  FSharedMemory := nil;
  FIsShared := False;
  FMode := mrbBidirectional;
  FCapacity := 0;
  FElementSize := 0;
  FIsCreator := False;
  FHeader := nil;
  FDataBuffer := nil;
end;

destructor TMappedRingBuffer.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMappedRingBuffer.CalculateRequiredSize(aCapacity: UInt64; aElementSize: UInt32): UInt64;
begin
  // 头部 + 数据缓冲区（对齐到缓存行）
  // 强制容量为2的幂
  if (aCapacity and (aCapacity - 1)) <> 0 then
    aCapacity := NextPow2U64(aCapacity);
  // 头 + 两套序号数组 + 两套数据区（双向）
  Result := HEADER_SIZE
          + (aCapacity * SizeOf(Int64)) + (aCapacity * aElementSize) // AB
          + (aCapacity * SizeOf(Int64)) + (aCapacity * aElementSize); // BA
  // 对齐到缓存行
  Result := ((Result + CACHE_LINE_SIZE - 1) div CACHE_LINE_SIZE) * CACHE_LINE_SIZE;
end;

procedure TMappedRingBuffer.InitializeHeader(aCapacity: UInt64; aElementSize: UInt32);
var
  LHeader: PMappedRingBufferHeader;
  LIndex: UInt64;
  LSeqPtr: PInt64;
begin
  LHeader := PMappedRingBufferHeader(FHeader);
  // 规范化容量为2的幂
  if (aCapacity and (aCapacity - 1)) <> 0 then
    aCapacity := NextPow2U64(aCapacity);
  LHeader^.Magic := MAPPED_RINGBUFFER_MAGIC;
  LHeader^.Version := MAPPED_RINGBUFFER_VERSION;
  LHeader^.Capacity := aCapacity;
  LHeader^.Mask := aCapacity - 1;
  LHeader^.ElementSize := aElementSize;
  // 同步设置对象字段
  FCapacity := aCapacity;
  FElementSize := aElementSize;
  // 初始化序号计数器（双向）
  atomic_store_64(LHeader^.ProducerSeq_AB, 0, mo_relaxed);
  atomic_store_64(LHeader^.ConsumerSeq_AB, 0, mo_relaxed);
  atomic_store_64(LHeader^.CachedConsumerSeq_AB, 0, mo_relaxed);
  atomic_store_64(LHeader^.CachedProducerSeq_AB, 0, mo_relaxed);
  atomic_store_64(LHeader^.ProducerSeq_BA, 0, mo_relaxed);
  atomic_store_64(LHeader^.ConsumerSeq_BA, 0, mo_relaxed);
  atomic_store_64(LHeader^.CachedConsumerSeq_BA, 0, mo_relaxed);
  atomic_store_64(LHeader^.CachedProducerSeq_BA, 0, mo_relaxed);
  // 计算并写入双向偏移（基于规范化后的容量）
  LHeader^.OffSeq_AB := HEADER_SIZE;
  LHeader^.OffData_AB := LHeader^.OffSeq_AB + aCapacity * SizeOf(Int64);
  LHeader^.OffSeq_BA := LHeader^.OffData_AB + aCapacity * aElementSize;
  LHeader^.OffData_BA := LHeader^.OffSeq_BA + aCapacity * SizeOf(Int64);
  // 初始化两套序列数组：空槽期望值 = 索引值
  for LIndex := 0 to aCapacity - 1 do
  begin
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_AB + LIndex * SizeOf(Int64));
    atomic_store_64(LSeqPtr^, LIndex, mo_relaxed);
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_BA + LIndex * SizeOf(Int64));
    atomic_store_64(LSeqPtr^, LIndex, mo_relaxed);
  end;
end;

function TMappedRingBuffer.ValidateHeader: Boolean;
var
  LHeader: PMappedRingBufferHeader;
begin
  Result := False;
  if FHeader = nil then Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  if (LHeader^.Magic <> MAPPED_RINGBUFFER_MAGIC) or
     (LHeader^.Version <> MAPPED_RINGBUFFER_VERSION) then
    Exit;

  FCapacity := LHeader^.Capacity;
  FElementSize := LHeader^.ElementSize;
  Result := True;
end;

function TMappedRingBuffer.SendSeqBase: PByte;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffSeq_AB
  else
    Result := PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffSeq_BA;
end;

function TMappedRingBuffer.ReceiveSeqBase: PByte;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffSeq_BA
  else
    Result := PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffSeq_AB;
end;

function TMappedRingBuffer.SendProducerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.ProducerSeq_AB
  else
    Result := @PMappedRingBufferHeader(FHeader)^.ProducerSeq_BA;
end;

function TMappedRingBuffer.SendConsumerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.ConsumerSeq_AB
  else
    Result := @PMappedRingBufferHeader(FHeader)^.ConsumerSeq_BA;
end;

function TMappedRingBuffer.SendCachedConsumerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.CachedConsumerSeq_AB
  else
    Result := @PMappedRingBufferHeader(FHeader)^.CachedConsumerSeq_BA;
end;

function TMappedRingBuffer.ReceiveProducerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.ProducerSeq_BA
  else
    Result := @PMappedRingBufferHeader(FHeader)^.ProducerSeq_AB;
end;

function TMappedRingBuffer.ReceiveConsumerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.ConsumerSeq_BA
  else
    Result := @PMappedRingBufferHeader(FHeader)^.ConsumerSeq_AB;
end;

function TMappedRingBuffer.ReceiveCachedProducerSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit(nil);
  if FIsCreator then
    Result := @PMappedRingBufferHeader(FHeader)^.CachedProducerSeq_BA
  else
    Result := @PMappedRingBufferHeader(FHeader)^.CachedProducerSeq_AB;
end;

procedure TMappedRingBuffer.BindDataBuffers;
var
  LHeader: PMappedRingBufferHeader;
begin
  if FHeader = nil then
  begin
    FDataBuffer := nil;
    FDataBufferIn := nil;
    Exit;
  end;

  LHeader := PMappedRingBufferHeader(FHeader);
  if FIsCreator then
  begin
    FDataBuffer := Pointer(PByte(FHeader) + LHeader^.OffData_AB);
    FDataBufferIn := Pointer(PByte(FHeader) + LHeader^.OffData_BA);
  end
  else
  begin
    FDataBuffer := Pointer(PByte(FHeader) + LHeader^.OffData_BA);
    FDataBufferIn := Pointer(PByte(FHeader) + LHeader^.OffData_AB);
  end;
end;

procedure TMappedRingBuffer.ResetSendDirection;
var
  LHeader: PMappedRingBufferHeader;
  LIndex: UInt64;
  LSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  atomic_store_64(SendProducerSeqPtr^, 0, mo_relaxed);
  atomic_store_64(SendConsumerSeqPtr^, 0, mo_relaxed);
  atomic_store_64(SendCachedConsumerSeqPtr^, 0, mo_relaxed);

  if FIsCreator then
    atomic_store_64(LHeader^.CachedProducerSeq_AB, 0, mo_relaxed)
  else
    atomic_store_64(LHeader^.CachedProducerSeq_BA, 0, mo_relaxed);

  for LIndex := 0 to FCapacity - 1 do
  begin
    LSeqPtr := PInt64(SendSeqBase + SizeUInt(LIndex) * SizeOf(Int64));
    atomic_store_64(LSeqPtr^, LIndex, mo_relaxed);
  end;
end;

procedure TMappedRingBuffer.ResetReceiveDirection;
var
  LHeader: PMappedRingBufferHeader;
  LIndex: UInt64;
  LSeqPtr: PInt64;
begin
  if FHeader = nil then
    Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  atomic_store_64(ReceiveProducerSeqPtr^, 0, mo_relaxed);
  atomic_store_64(ReceiveConsumerSeqPtr^, 0, mo_relaxed);
  atomic_store_64(ReceiveCachedProducerSeqPtr^, 0, mo_relaxed);

  if FIsCreator then
    atomic_store_64(LHeader^.CachedConsumerSeq_BA, 0, mo_relaxed)
  else
    atomic_store_64(LHeader^.CachedConsumerSeq_AB, 0, mo_relaxed);

  for LIndex := 0 to FCapacity - 1 do
  begin
    LSeqPtr := PInt64(ReceiveSeqBase + SizeUInt(LIndex) * SizeOf(Int64));
    atomic_store_64(LSeqPtr^, LIndex, mo_relaxed);
  end;
end;

function TMappedRingBuffer.GetWriteIndex: UInt64;
begin
  if FHeader = nil then Exit(0);

  case FMode of
    mrbConsumer:
      Result := atomic_load_64(ReceiveProducerSeqPtr^, mo_relaxed);
  else
    Result := atomic_load_64(SendProducerSeqPtr^, mo_relaxed);
  end;
end;

function TMappedRingBuffer.GetReadIndex: UInt64;
begin
  if FHeader = nil then Exit(0);

  case FMode of
    mrbConsumer:
      Result := atomic_load_64(ReceiveConsumerSeqPtr^, mo_relaxed);
  else
    Result := atomic_load_64(SendConsumerSeqPtr^, mo_relaxed);
  end;
end;

procedure TMappedRingBuffer.SetWriteIndex(const Value: UInt64);
begin
  case FMode of
    mrbConsumer:
      atomic_store_64(ReceiveProducerSeqPtr^, Value, mo_relaxed);
  else
    atomic_store_64(SendProducerSeqPtr^, Value, mo_relaxed);
  end;
end;

procedure TMappedRingBuffer.SetReadIndex(const Value: UInt64);
begin
  case FMode of
    mrbConsumer:
      atomic_store_64(ReceiveConsumerSeqPtr^, Value, mo_relaxed);
  else
    atomic_store_64(SendConsumerSeqPtr^, Value, mo_relaxed);
  end;
end;

function TMappedRingBuffer.GetAvailableSpace: UInt64;
var
  LWriteIdx, LReadIdx: UInt64;
begin
  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;

  if LWriteIdx < LReadIdx then
    Exit(0);
  if (LWriteIdx - LReadIdx) >= FCapacity then
    Exit(0);
  Result := FCapacity - (LWriteIdx - LReadIdx);
end;

function TMappedRingBuffer.GetUsedSpace: UInt64;
var
  LWriteIdx, LReadIdx: UInt64;
begin
  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;
  if LWriteIdx < LReadIdx then
    Result := 0
  else
    Result := LWriteIdx - LReadIdx;
end;

{$PUSH}
{$WARN 6018 OFF} // 局部屏蔽：不可达代码（多处 Exit 快路径）
function TMappedRingBuffer.CreateFile(const aFileName: string; aCapacity: UInt64;
  aElementSize: UInt32; aMode: TMappedRingBufferMode): Boolean;
var
  LRequiredSize: UInt64;
  LAccess: TMemoryMapAccess;
  LFileHandle: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LExpectedSize: UInt64;
begin
  Result := False;
  Close;

  if (aCapacity = 0) or (aElementSize = 0) then Exit;

  LRequiredSize := CalculateRequiredSize(aCapacity, aElementSize);

  // 环形缓冲区的控制字段需要双向读写；访问模式只限制公开 API，不降低映射权限。
  LAccess := mmaReadWrite;

  FMemoryMap := TMemoryMap.Create;
  try
    // 尝试打开现有文件
    if platform_file_stat(PAnsiChar(aFileName), LStat) = 0 then
    begin
      if not IsMappedRingBufferBackingSizeValid(LStat, HEADER_SIZE) then
        Exit;
      if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;
      FIsCreator := False;
    end
    else
    begin
      // 创建新文件并设置大小
      if platform_file_open(PAnsiChar(aFileName), fomReadWrite, fcmCreateAlways, LFileHandle) <> 0 then
        Exit;
      platform_file_truncate(LFileHandle, LRequiredSize);
      platform_file_close(LFileHandle);

      if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;
      FIsCreator := True;
    end;

    FIsShared := False;
    FMode := aMode;
    FHeader := FMemoryMap.BaseAddress;

    if FIsCreator then
    begin
      InitializeHeader(aCapacity, aElementSize);
    end
    else
    begin
      if not ValidateHeader then Exit;
      LExpectedSize := CalculateRequiredSize(FCapacity, FElementSize);
      if (platform_file_stat(PAnsiChar(aFileName), LStat) <> 0) or
         (not IsMappedRingBufferBackingSizeValid(LStat, LExpectedSize)) then
        Exit;
    end;

    BindDataBuffers;
    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;
{$POP}

{$PUSH}
{$WARN 6018 OFF}
function TMappedRingBuffer.OpenFile(const aFileName: string;
  aMode: TMappedRingBufferMode): Boolean;
var
  LAccess: TMemoryMapAccess;
  LStat: TPlatformFileStat;
  LExpectedSize: UInt64;
begin
  Result := False;
  Close;

  if platform_file_stat(PAnsiChar(aFileName), LStat) <> 0 then Exit;
  if not IsMappedRingBufferBackingSizeValid(LStat, HEADER_SIZE) then Exit;

  LAccess := mmaReadWrite;

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;

    FIsShared := False;
    FMode := aMode;
    FIsCreator := False;
    FHeader := FMemoryMap.BaseAddress;
    // 先校验头，再计算偏移
    if not ValidateHeader then Exit;
    LExpectedSize := CalculateRequiredSize(FCapacity, FElementSize);
    if not IsMappedRingBufferBackingSizeValid(LStat, LExpectedSize) then
      Exit;
    BindDataBuffers;

    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;
{$POP}

{$PUSH}
{$WARN 6018 OFF}
function TMappedRingBuffer.CreateShared(const aName: string; aCapacity: UInt64;
  aElementSize: UInt32; aMode: TMappedRingBufferMode): Boolean;
var
  LRequiredSize: UInt64;
  LAccess: TMemoryMapAccess;
begin
  Result := False;
  Close;

  if (aCapacity = 0) or (aElementSize = 0) then Exit;

  LRequiredSize := CalculateRequiredSize(aCapacity, aElementSize);

  LAccess := mmaReadWrite;

  FSharedMemory := TSharedMemory.Create;
  try
    if FSharedMemory.CreateShared(aName, LRequiredSize, LAccess) then
    begin
      FIsCreator := FSharedMemory.IsCreator;
    end
    else
    begin
      // 尝试打开已存在的
      if not FSharedMemory.OpenShared(aName, LAccess) then Exit;
      FIsCreator := False;
    end;

    FIsShared := True;
    FMode := aMode;
    FHeader := FSharedMemory.BaseAddress;

    if FIsCreator then
    begin
      InitializeHeader(aCapacity, aElementSize);
    end
    else
    begin
      if not ValidateHeader then Exit;
    end;

    // 必须在 InitializeHeader/ValidateHeader 之后设置，因为 offset 字段需要先初始化
    BindDataBuffers;

    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;
{$POP}

{$PUSH}
{$WARN 6018 OFF}
function TMappedRingBuffer.OpenShared(const aName: string;
  aMode: TMappedRingBufferMode): Boolean;
var
  LAccess: TMemoryMapAccess;
begin
  Result := False;
  Close;

  LAccess := mmaReadWrite;

  FSharedMemory := TSharedMemory.Create;
  try
    if not FSharedMemory.OpenShared(aName, LAccess) then Exit;

    FIsShared := True;
    FMode := aMode;
    FIsCreator := False;
    FHeader := FSharedMemory.BaseAddress;
    // 先校验头，再计算偏移
    if not ValidateHeader then Exit;
    BindDataBuffers;

    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;
{$POP}

procedure TMappedRingBuffer.Close;
begin
  FHeader := nil;
  FDataBuffer := nil;
  FCapacity := 0;
  FElementSize := 0;
  FIsCreator := False;

  if Assigned(FMemoryMap) then
  begin
    FMemoryMap.Free;
    FMemoryMap := nil;
  end;

  if Assigned(FSharedMemory) then
  begin
    FSharedMemory.Free;
    FSharedMemory := nil;
  end;

  FIsShared := False;
end;

{$PUSH}
{$WARN 6058 OFF} // 局部屏蔽：inline 未内联提示
function TMappedRingBuffer.Push(const aData: Pointer): Boolean;
var
  LProdSeq, LConsSeq, LCachedCons: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbConsumer) then Exit;

  LProdSeq := atomic_load_64(SendProducerSeqPtr^, mo_relaxed);
  LIndex := UInt64(LProdSeq) and (FCapacity - 1);
  LSeqPtr := PInt64(SendSeqBase + SizeUInt(LIndex) * SizeOf(Int64));

  // 槽位可用性检查：期望等于 LProdSeq
  LExpectedSeq := LProdSeq;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    // 检查是否满：Prod - CachedCons >= Capacity
    LCachedCons := atomic_load_64(SendCachedConsumerSeqPtr^, mo_relaxed);
    if (LProdSeq - LCachedCons) >= Int64(FCapacity) then
    begin
      LConsSeq := atomic_load_64(SendConsumerSeqPtr^, mo_acquire);
      atomic_store_64(SendCachedConsumerSeqPtr^, LConsSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) >= Int64(FCapacity) then Exit(False);
    end
    else
      Exit(False);
  end;

  // 写入数据
  LDataPtr := Pointer(PByte(FDataBuffer) + (LIndex * UInt64(FElementSize)));
  Move(aData^, LDataPtr^, FElementSize);

  // 发布槽位：sequence = LProdSeq + 1（release）
  atomic_store_64(LSeqPtr^, LProdSeq + 1, mo_release);
  // 推进生产者序号（relaxed）
  atomic_store_64(SendProducerSeqPtr^, LProdSeq + 1, mo_relaxed);

  Result := True;
end;

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.Pop(aData: Pointer): Boolean;
var
  LConsSeq, LProdSeq, LCachedProd: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbProducer) then Exit;

  LConsSeq := atomic_load_64(ReceiveConsumerSeqPtr^, mo_relaxed);
  LIndex := UInt64(LConsSeq) and (FCapacity - 1);
  LSeqPtr := PInt64(ReceiveSeqBase + SizeUInt(LIndex) * SizeOf(Int64));

  // 槽位可读性检查：期望等于 LConsSeq + 1
  LExpectedSeq := LConsSeq + 1;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    // 检查是否空：CachedProd - Cons <= 0
    LCachedProd := atomic_load_64(ReceiveCachedProducerSeqPtr^, mo_relaxed);
    if (LCachedProd - LConsSeq) <= 0 then
    begin
      LProdSeq := atomic_load_64(ReceiveProducerSeqPtr^, mo_acquire);
      atomic_store_64(ReceiveCachedProducerSeqPtr^, LProdSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) <= 0 then Exit(False);
    end
    else
      Exit(False);
  end;

  // 读取数据
  LDataPtr := Pointer(PByte(FDataBufferIn) + (LIndex * UInt64(FElementSize)));
  Move(LDataPtr^, aData^, FElementSize);

  // 释放槽位：sequence = LConsSeq + Capacity（release）
  atomic_store_64(LSeqPtr^, LConsSeq + Int64(FCapacity), mo_release);
  // 推进消费者序号
  atomic_store_64(ReceiveConsumerSeqPtr^, LConsSeq + 1, mo_relaxed);

  Result := True;
end;
{$POP}
{$POP}

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.Peek(aData: Pointer): Boolean;
var
  LConsSeq, LProdSeq, LCachedProd: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbProducer) then Exit;

  LConsSeq := atomic_load_64(ReceiveConsumerSeqPtr^, mo_relaxed);
  LIndex := UInt64(LConsSeq) and (FCapacity - 1);
  LSeqPtr := PInt64(ReceiveSeqBase + SizeUInt(LIndex) * SizeOf(Int64));

  LExpectedSeq := LConsSeq + 1;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    LCachedProd := atomic_load_64(ReceiveCachedProducerSeqPtr^, mo_relaxed);
    if (LCachedProd - LConsSeq) <= 0 then
    begin
      LProdSeq := atomic_load_64(ReceiveProducerSeqPtr^, mo_acquire);
      atomic_store_64(ReceiveCachedProducerSeqPtr^, LProdSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) <= 0 then Exit(False);
    end
    else
      Exit(False);
  end;

  LDataPtr := Pointer(PByte(FDataBufferIn) + (LIndex * UInt64(FElementSize)));
  Move(LDataPtr^, aData^, FElementSize);

  Result := True;
end;
{$POP}

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.PushBatch(const aData: Pointer; aCount: UInt64): UInt64;
var
  LIndex: UInt64;
  LSrcPtr: Pointer;
begin
  Result := 0;
  if not IsValid or (FMode = mrbConsumer) or (aCount = 0) then Exit;

  for LIndex := 0 to aCount - 1 do
  begin
    LSrcPtr := Pointer(PByte(aData) + SizeUInt(LIndex) * FElementSize);
    if not Push(LSrcPtr) then
      Break;
    Inc(Result);
  end;
end;

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.PopBatch(aData: Pointer; aCount: UInt64): UInt64;
var
  LIndex: UInt64;
  LDstPtr: Pointer;
begin
  Result := 0;
  if not IsValid or (FMode = mrbProducer) or (aCount = 0) then Exit;

  for LIndex := 0 to aCount - 1 do
  begin
    LDstPtr := Pointer(PByte(aData) + SizeUInt(LIndex) * FElementSize);
    if not Pop(LDstPtr) then
      Break;
    Inc(Result);
  end;
end;
{$POP}

procedure TMappedRingBuffer.Clear;
begin
  if not IsValid then Exit;

  case FMode of
    mrbProducer:
      ResetSendDirection;
    mrbConsumer:
      ResetReceiveDirection;
  else
    begin
      ResetSendDirection;
      ResetReceiveDirection;
    end;
  end;
end;

function TMappedRingBuffer.IsEmpty: Boolean;
begin
  Result := not IsValid or (GetUsedSpace = 0);
end;

function TMappedRingBuffer.IsFull: Boolean;
begin
  Result := IsValid and (GetAvailableSpace = 0);
end;

function TMappedRingBuffer.IsValid: Boolean;
begin
  Result := (FHeader <> nil) and (FDataBuffer <> nil) and
            (FCapacity > 0) and (FElementSize > 0) and
            ((FMemoryMap <> nil) or (FSharedMemory <> nil));
end;

end.
