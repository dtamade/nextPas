{$CODEPAGE UTF8}
unit nextpas.core.mem.mapped_ring_buffer;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, nextpas.core.mem.memory_map;

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
  Classes, nextpas.core.atomic;

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

function TMappedRingBuffer.GetWriteIndex: UInt64;
begin
  if FHeader = nil then Exit(0);
  // 仅用于旧语义的估算：返回当前方向的序号
  if FIsCreator then
    Result := atomic_load_64(PMappedRingBufferHeader(FHeader)^.ProducerSeq_AB, mo_relaxed)
  else
    Result := atomic_load_64(PMappedRingBufferHeader(FHeader)^.ProducerSeq_BA, mo_relaxed);
end;

function TMappedRingBuffer.GetReadIndex: UInt64;
begin
  if FHeader = nil then Exit(0);
  if FIsCreator then
    Result := atomic_load_64(PMappedRingBufferHeader(FHeader)^.ConsumerSeq_AB, mo_relaxed)
  else
    Result := atomic_load_64(PMappedRingBufferHeader(FHeader)^.ConsumerSeq_BA, mo_relaxed);
end;

procedure TMappedRingBuffer.SetWriteIndex(const Value: UInt64);
begin
  if FIsCreator then
    atomic_store_64(PMappedRingBufferHeader(FHeader)^.ProducerSeq_AB, Value, mo_relaxed)
  else
    atomic_store_64(PMappedRingBufferHeader(FHeader)^.ProducerSeq_BA, Value, mo_relaxed);
end;

procedure TMappedRingBuffer.SetReadIndex(const Value: UInt64);
begin
  if FIsCreator then
    atomic_store_64(PMappedRingBufferHeader(FHeader)^.ConsumerSeq_AB, Value, mo_relaxed)
  else
    atomic_store_64(PMappedRingBufferHeader(FHeader)^.ConsumerSeq_BA, Value, mo_relaxed);
end;

function TMappedRingBuffer.GetAvailableSpace: UInt64;
var
  LWriteIdx, LReadIdx: UInt64;
begin
  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;
  if LWriteIdx >= LReadIdx then
    Result := FCapacity - (LWriteIdx - LReadIdx)
  else
    Result := LReadIdx - LWriteIdx;
  if Result > 0 then Dec(Result); // 留一个空槽以区分满/空
end;

function TMappedRingBuffer.GetUsedSpace: UInt64;
begin
  Result := FCapacity - GetAvailableSpace;
end;

{$PUSH}
{$WARN 6018 OFF} // 局部屏蔽：不可达代码（多处 Exit 快路径）
function TMappedRingBuffer.CreateFile(const aFileName: string; aCapacity: UInt64;
  aElementSize: UInt32; aMode: TMappedRingBufferMode): Boolean;
var
  LRequiredSize: UInt64;
  LAccess: TMemoryMapAccess;
begin
  Result := False;
  Close;

  if (aCapacity = 0) or (aElementSize = 0) then Exit;

  LRequiredSize := CalculateRequiredSize(aCapacity, aElementSize);

  // 根据模式确定访问权限
  case aMode of
    mrbProducer: LAccess := mmaWrite;
    mrbConsumer: LAccess := mmaRead;
    mrbBidirectional: LAccess := mmaReadWrite;
  else
    LAccess := mmaReadWrite;
  end;

  FMemoryMap := TMemoryMap.Create;
  try
    // 尝试打开现有文件
    if FileExists(aFileName) then
    begin
      if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;
      FIsCreator := False;
    end
    else
    begin
      // 创建新文件
      with TFileStream.Create(aFileName, fmCreate) do
      try
        Size := LRequiredSize;
      finally
        Free;
      end;

      if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;
      FIsCreator := True;
    end;

    FIsShared := False;
    FMode := aMode;
    FHeader := FMemoryMap.BaseAddress;
    // 单向默认绑定 AB 方向数据区
    FDataBuffer := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_AB);
    FDataBufferIn := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_BA);

    if FIsCreator then
    begin
      InitializeHeader(aCapacity, aElementSize);
    end
    else
    begin
      if not ValidateHeader then Exit;
    end;

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
begin
  Result := False;
  Close;

  if not FileExists(aFileName) then Exit;

  case aMode of
    mrbProducer: LAccess := mmaWrite;
    mrbConsumer: LAccess := mmaRead;
    mrbBidirectional: LAccess := mmaReadWrite;
  else
    LAccess := mmaReadWrite;
  end;

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.OpenFile(aFileName, LAccess) then Exit;

    FIsShared := False;
    FMode := aMode;
    FIsCreator := False;
    FHeader := FMemoryMap.BaseAddress;
    // 先校验头，再计算偏移
    if not ValidateHeader then Exit;
    FDataBuffer := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_AB);
    FDataBufferIn := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_BA);

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

  case aMode of
    mrbProducer: LAccess := mmaWrite;
    mrbConsumer: LAccess := mmaRead;
    mrbBidirectional: LAccess := mmaReadWrite;
  else
    LAccess := mmaReadWrite;
  end;

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
    FDataBuffer := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_AB);
    FDataBufferIn := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_BA);

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

  case aMode of
    mrbProducer: LAccess := mmaWrite;
    mrbConsumer: LAccess := mmaRead;
    mrbBidirectional: LAccess := mmaReadWrite;
  else
    LAccess := mmaReadWrite;
  end;

  FSharedMemory := TSharedMemory.Create;
  try
    if not FSharedMemory.OpenShared(aName, LAccess) then Exit;

    FIsShared := True;
    FMode := aMode;
    FIsCreator := False;
    FHeader := FSharedMemory.BaseAddress;
    // 先校验头，再计算偏移
    if not ValidateHeader then Exit;
    FDataBuffer := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_AB);
    FDataBufferIn := Pointer(PByte(FHeader) + PMappedRingBufferHeader(FHeader)^.OffData_BA);

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
  LHeader: PMappedRingBufferHeader;
  LProdSeq, LConsSeq, LCachedCons: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbConsumer) then Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  // 发送方向选择：Creator端使用AB，Open端使用BA
  if FIsCreator then
    LProdSeq := atomic_load_64(LHeader^.ProducerSeq_AB, mo_relaxed)
  else
    LProdSeq := atomic_load_64(LHeader^.ProducerSeq_BA, mo_relaxed);
  LIndex := UInt64(LProdSeq) and LHeader^.Mask;
  if FIsCreator then
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_AB + LIndex * SizeOf(Int64))
  else
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_BA + LIndex * SizeOf(Int64));

  // 槽位可用性检查：期望等于 LProdSeq
  LExpectedSeq := LProdSeq;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    // 检查是否满：Prod - CachedCons >= Capacity
    if FIsCreator then
      LCachedCons := atomic_load_64(LHeader^.CachedConsumerSeq_AB, mo_relaxed)
    else
      LCachedCons := atomic_load_64(LHeader^.CachedConsumerSeq_BA, mo_relaxed);
    if (LProdSeq - LCachedCons) >= Int64(LHeader^.Capacity) then
    begin
      if FIsCreator then
        LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_AB, mo_acquire)
      else
        LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_BA, mo_acquire);
      if FIsCreator then
        atomic_store_64(LHeader^.CachedConsumerSeq_AB, LConsSeq, mo_relaxed)
      else
        atomic_store_64(LHeader^.CachedConsumerSeq_BA, LConsSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) >= Int64(LHeader^.Capacity) then Exit(False);
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
  if FIsCreator then
    atomic_store_64(LHeader^.ProducerSeq_AB, LProdSeq + 1, mo_relaxed)
  else
    atomic_store_64(LHeader^.ProducerSeq_BA, LProdSeq + 1, mo_relaxed);

  Result := True;
end;

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.Pop(aData: Pointer): Boolean;
var
  LHeader: PMappedRingBufferHeader;
  LConsSeq, LProdSeq, LCachedProd: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbProducer) then Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  // 接收方向选择：Creator端读取AB，Open端读取BA
  if FIsCreator then
    LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_AB, mo_relaxed)
  else
    LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_BA, mo_relaxed);
  LIndex := UInt64(LConsSeq) and LHeader^.Mask;
  if FIsCreator then
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_AB + LIndex * SizeOf(Int64))
  else
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_BA + LIndex * SizeOf(Int64));

  // 槽位可读性检查：期望等于 LConsSeq + 1
  LExpectedSeq := LConsSeq + 1;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    // 检查是否空：CachedProd - Cons <= 0
    if FIsCreator then
      LCachedProd := atomic_load_64(LHeader^.CachedProducerSeq_AB, mo_relaxed)
    else
      LCachedProd := atomic_load_64(LHeader^.CachedProducerSeq_BA, mo_relaxed);
    if (LCachedProd - LConsSeq) <= 0 then
    begin
      if FIsCreator then
        LProdSeq := atomic_load_64(LHeader^.ProducerSeq_AB, mo_acquire)
      else
        LProdSeq := atomic_load_64(LHeader^.ProducerSeq_BA, mo_acquire);
      if FIsCreator then
        atomic_store_64(LHeader^.CachedProducerSeq_AB, LProdSeq, mo_relaxed)
      else
        atomic_store_64(LHeader^.CachedProducerSeq_BA, LProdSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) <= 0 then Exit(False);
    end
    else
      Exit(False);
  end;

  // 读取数据
  LDataPtr := Pointer(PByte(FDataBuffer) + (LIndex * UInt64(FElementSize)));
  Move(LDataPtr^, aData^, FElementSize);

  // 释放槽位：sequence = LConsSeq + Capacity（release）
  atomic_store_64(LSeqPtr^, LConsSeq + Int64(LHeader^.Capacity), mo_release);
  // 推进消费者序号
  if FIsCreator then
    atomic_store_64(LHeader^.ConsumerSeq_AB, LConsSeq + 1, mo_relaxed)
  else
    atomic_store_64(LHeader^.ConsumerSeq_BA, LConsSeq + 1, mo_relaxed);

  Result := True;
end;
{$POP}
{$POP}

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.Peek(aData: Pointer): Boolean;
var
  LHeader: PMappedRingBufferHeader;
  LConsSeq, LProdSeq, LCachedProd: Int64;
  LIndex: UInt64;
  LExpectedSeq: Int64;
  LSeqPtr: PInt64;
  LDataPtr: Pointer;
begin
  Result := False;
  if not IsValid or (FMode = mrbProducer) then Exit;

  LHeader := PMappedRingBufferHeader(FHeader);
  if FIsCreator then
    LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_AB, mo_relaxed)
  else
    LConsSeq := atomic_load_64(LHeader^.ConsumerSeq_BA, mo_relaxed);
  LIndex := UInt64(LConsSeq) and LHeader^.Mask;
  if FIsCreator then
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_AB + LIndex * SizeOf(Int64))
  else
    LSeqPtr := PInt64(PByte(FHeader) + LHeader^.OffSeq_BA + LIndex * SizeOf(Int64));

  LExpectedSeq := LConsSeq + 1;
  if atomic_load_64(LSeqPtr^, mo_acquire) <> LExpectedSeq then
  begin
    if FIsCreator then
      LCachedProd := atomic_load_64(LHeader^.CachedProducerSeq_AB, mo_relaxed)
    else
      LCachedProd := atomic_load_64(LHeader^.CachedProducerSeq_BA, mo_relaxed);
    if (LCachedProd - LConsSeq) <= 0 then
    begin
      if FIsCreator then
        LProdSeq := atomic_load_64(LHeader^.ProducerSeq_AB, mo_acquire)
      else
        LProdSeq := atomic_load_64(LHeader^.ProducerSeq_BA, mo_acquire);
      if FIsCreator then
        atomic_store_64(LHeader^.CachedProducerSeq_AB, LProdSeq, mo_relaxed)
      else
        atomic_store_64(LHeader^.CachedProducerSeq_BA, LProdSeq, mo_relaxed);
      if (LProdSeq - LConsSeq) <= 0 then Exit(False);
    end
    else
      Exit(False);
  end;

  LDataPtr := Pointer(PByte(FDataBuffer) + (LIndex * UInt64(FElementSize)));
  Move(LDataPtr^, aData^, FElementSize);

  Result := True;
end;
{$POP}

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.PushBatch(const aData: Pointer; aCount: UInt64): UInt64;
var
  LWriteIdx, LReadIdx, LAvailSpace, LBatchSize: UInt64;
  LIndex: UInt64;
  LSrcPtr, LDstPtr: Pointer;
begin
  Result := 0;
  if not IsValid or (FMode = mrbConsumer) or (aCount = 0) then Exit;

  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;

  // 计算可用空间
  if LWriteIdx >= LReadIdx then
    LAvailSpace := FCapacity - (LWriteIdx - LReadIdx) - 1
  else
    LAvailSpace := LReadIdx - LWriteIdx - 1;

  if aCount < LAvailSpace then LBatchSize := aCount else LBatchSize := LAvailSpace;
  if LBatchSize = 0 then Exit;

  // 批量复制数据
  for LIndex := 0 to LBatchSize - 1 do
  begin
    LSrcPtr := Pointer(PByte(aData) + LIndex * FElementSize);
    LDstPtr := Pointer(PByte(FDataBuffer) + ((LWriteIdx + LIndex) mod FCapacity) * FElementSize);
    Move(LSrcPtr^, LDstPtr^, FElementSize);
  end;

  // 原子更新写入索引
  SetWriteIndex((LWriteIdx + LBatchSize) mod FCapacity);

  Result := LBatchSize;
end;

{$PUSH}
{$WARN 6058 OFF}
function TMappedRingBuffer.PopBatch(aData: Pointer; aCount: UInt64): UInt64;
var
  LWriteIdx, LReadIdx, LBatchSize: UInt64;
  LIndex: UInt64;
  LSrcPtr, LDstPtr: Pointer;
begin
  Result := 0;
  if not IsValid or (FMode = mrbProducer) or (aCount = 0) then Exit;

  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;

  // 计算已用空间并确定批量大小
  if LWriteIdx >= LReadIdx then
  begin
    if aCount < (LWriteIdx - LReadIdx) then
      LBatchSize := aCount
    else
      LBatchSize := LWriteIdx - LReadIdx;
  end
  else
  begin
    if aCount < (FCapacity - (LReadIdx - LWriteIdx)) then
      LBatchSize := aCount
    else
      LBatchSize := FCapacity - (LReadIdx - LWriteIdx);
  end;
  if LBatchSize = 0 then Exit;

  // 批量复制数据
  for LIndex := 0 to LBatchSize - 1 do
  begin
    LSrcPtr := Pointer(PByte(FDataBuffer) + ((LReadIdx + LIndex) mod FCapacity) * FElementSize);
    LDstPtr := Pointer(PByte(aData) + LIndex * FElementSize);
    Move(LSrcPtr^, LDstPtr^, FElementSize);
  end;

  // 原子更新读取索引
  SetReadIndex((LReadIdx + LBatchSize) mod FCapacity);

  Result := LBatchSize;
end;
{$POP}

procedure TMappedRingBuffer.Clear;
begin
  if not IsValid then Exit;
  SetWriteIndex(0);
  SetReadIndex(0);
end;

function TMappedRingBuffer.IsEmpty: Boolean;
begin
  Result := not IsValid or (GetWriteIndex = GetReadIndex);
end;

function TMappedRingBuffer.IsFull: Boolean;
var
  LWriteIdx, LReadIdx: UInt64;
begin
  Result := False;
  if not IsValid then Exit;

  LWriteIdx := GetWriteIndex;
  LReadIdx := GetReadIndex;
  Result := ((LWriteIdx + 1) mod FCapacity) = LReadIdx;
end;

function TMappedRingBuffer.IsValid: Boolean;
begin
  Result := (FHeader <> nil) and (FDataBuffer <> nil) and
            (FCapacity > 0) and (FElementSize > 0) and
            ((FMemoryMap <> nil) or (FSharedMemory <> nil));
end;

end.
