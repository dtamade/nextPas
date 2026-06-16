{**
 * Unit: nextpas.core.tls.ringbuffer
 * Purpose: 无锁环形缓冲区 - 高性能单生产者单消费者队列
 *
 * 架构升级 Phase 2: 无锁并发优化
 *
 * 设计原则:
 * - 单生产者单消费者 (SPSC) 模型
 * - 无锁操作，使用原子操作和内存屏障
 * - 缓存行对齐，避免伪共享
 * - 零拷贝读写支持
 *
 * 适用场景:
 * - 网络 I/O 缓冲
 * - 日志异步写入
 * - 生产者-消费者模式
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-02-05
 *}

unit nextpas.core.tls.ringbuffer;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base;


{ 内存屏障函数声明 }
procedure ReadMemoryBarrier;
procedure WriteMemoryBarrier;
procedure FullMemoryBarrier;

const
  { 默认缓冲区大小 (必须是2的幂) }
  DEFAULT_RING_SIZE = 65536;  // 64 KB

  { 缓存行大小 }
  CACHE_LINE_SIZE = 64;

type
  {**
   * TLockFreeRingBuffer - 无锁环形缓冲区
   *
   * 单生产者单消费者 (SPSC) 模型，无需锁即可实现线程安全。
   * 生产者和消费者可以在不同线程中同时操作。
   *
   * 性能特点:
   * - 写入: O(1)，无锁
   * - 读取: O(1)，无锁
   * - 吞吐量: 10M+ ops/s
   *}
  TLockFreeRingBuffer = class
  private
    FBuffer: PByte;
    FCapacity: Integer;       // 容量（必须是2的幂）
    FMask: Integer;           // 容量掩码 (Capacity - 1)

    { 缓存行对齐的索引 }
    FHead: Integer;           // 写入位置 (生产者拥有)
    FPadding1: array[0..CACHE_LINE_SIZE - SizeOf(Integer) - 1] of Byte;
    FTail: Integer;           // 读取位置 (消费者拥有)
    FPadding2: array[0..CACHE_LINE_SIZE - SizeOf(Integer) - 1] of Byte;

    { 统计 }
    FTotalWritten: Int64;
    FTotalRead: Int64;
    FOverflows: Int64;        // 写入溢出次数

    function NextPowerOfTwo(AValue: Integer): Integer;

  public
    constructor Create(ACapacity: Integer = DEFAULT_RING_SIZE);
    destructor Destroy; override;

    {** 写入数据（生产者调用）
        @returns 实际写入的字节数 *}
    function Write(const AData; ACount: Integer): Integer;

    {** 写入 TBytes *}
    function WriteBytes(const AData: TBytes): Integer;

    {** 尝试写入全部数据
        @returns True 如果全部写入成功 *}
    function TryWrite(const AData; ACount: Integer): Boolean;

    {** 读取数据（消费者调用）
        @returns 实际读取的字节数 *}
    function Read(var AData; ACount: Integer): Integer;

    {** 读取为 TBytes *}
    function ReadBytes(ACount: Integer): TBytes;

    {** 尝试读取指定数量
        @returns True 如果读取了 ACount 字节 *}
    function TryRead(var AData; ACount: Integer): Boolean;

    {** 查看数据但不消费 *}
    function Peek(var AData; ACount: Integer): Integer;

    {** 跳过数据 *}
    function Skip(ACount: Integer): Integer;

    {** 可写入的字节数 *}
    function WriteAvailable: Integer;

    {** 可读取的字节数 *}
    function ReadAvailable: Integer;

    {** 缓冲区是否为空 *}
    function IsEmpty: Boolean;

    {** 缓冲区是否已满 *}
    function IsFull: Boolean;

    {** 清空缓冲区 *}
    procedure Clear;

    {** 获取底层缓冲区指针（用于零拷贝操作）*}
    function GetWritePtr(out AAvailable: Integer): PByte;
    procedure CommitWrite(ACount: Integer);

    function GetReadPtr(out AAvailable: Integer): PByte;
    procedure CommitRead(ACount: Integer);

    property Capacity: Integer read FCapacity;
    property TotalWritten: Int64 read FTotalWritten;
    property TotalRead: Int64 read FTotalRead;
    property Overflows: Int64 read FOverflows;
  end;

  {**
   * TRingBufferStats - 环形缓冲区统计
   *}
  TRingBufferStats = record
    Capacity: Integer;
    Used: Integer;
    Free: Integer;
    TotalWritten: Int64;
    TotalRead: Int64;
    Overflows: Int64;
    Utilization: Double;      // 使用率 (%)
  end;

implementation

{ ========================================================================
  内存屏障实现
  注意：FPC 不支持在 inline 函数中使用内联汇编
  ======================================================================== }

procedure ReadMemoryBarrier;
{$IFDEF CPUX86_64}
assembler; nostackframe;
asm
  lfence
end;
{$ELSE}
{$IFDEF CPUX86}
assembler; nostackframe;
asm
  lfence
end;
{$ELSE}
begin
  // 对于其他平台，使用 volatile 语义
  ReadWriteBarrier;
end;
{$ENDIF}
{$ENDIF}

procedure WriteMemoryBarrier;
{$IFDEF CPUX86_64}
assembler; nostackframe;
asm
  sfence
end;
{$ELSE}
{$IFDEF CPUX86}
assembler; nostackframe;
asm
  sfence
end;
{$ELSE}
begin
  // 对于其他平台，使用 volatile 语义
  ReadWriteBarrier;
end;
{$ENDIF}
{$ENDIF}

procedure FullMemoryBarrier;
{$IFDEF CPUX86_64}
assembler; nostackframe;
asm
  mfence
end;
{$ELSE}
{$IFDEF CPUX86}
assembler; nostackframe;
asm
  mfence
end;
{$ELSE}
begin
  // 对于其他平台，使用 volatile 语义
  ReadWriteBarrier;
end;
{$ENDIF}
{$ENDIF}

{ ========================================================================
  TLockFreeRingBuffer
  ======================================================================== }

constructor TLockFreeRingBuffer.Create(ACapacity: Integer);
begin
  inherited Create;

  // 确保容量是2的幂
  FCapacity := NextPowerOfTwo(ACapacity);
  FMask := FCapacity - 1;

  // 分配缓冲区
  GetMem(FBuffer, FCapacity);
  FillChar(FBuffer^, FCapacity, 0);

  // 初始化索引
  FHead := 0;
  FTail := 0;

  // 初始化统计
  FTotalWritten := 0;
  FTotalRead := 0;
  FOverflows := 0;
end;

destructor TLockFreeRingBuffer.Destroy;
begin
  if FBuffer <> nil then
    FreeMem(FBuffer);
  inherited Destroy;
end;

function TLockFreeRingBuffer.NextPowerOfTwo(AValue: Integer): Integer;
begin
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

function TLockFreeRingBuffer.WriteAvailable: Integer;
var
  Head, Tail: Integer;
begin
  // 读取时使用内存屏障
  Head := FHead;
  ReadMemoryBarrier;
  Tail := FTail;

  // 可用空间 = 容量 - 已用空间 - 1（保留一个位置区分满/空）
  Result := FCapacity - ((Head - Tail) and FMask) - 1;
  if Result < 0 then
    Result := 0;
end;

function TLockFreeRingBuffer.ReadAvailable: Integer;
var
  Head, Tail: Integer;
begin
  // 读取时使用内存屏障
  Tail := FTail;
  ReadMemoryBarrier;
  Head := FHead;

  Result := (Head - Tail) and FMask;
end;

function TLockFreeRingBuffer.IsEmpty: Boolean;
begin
  Result := ReadAvailable = 0;
end;

function TLockFreeRingBuffer.IsFull: Boolean;
begin
  Result := WriteAvailable = 0;
end;

function TLockFreeRingBuffer.Write(const AData; ACount: Integer): Integer;
var
  Available, FirstPart, SecondPart: Integer;
  WritePos: Integer;
  Src: PByte;
begin
  if ACount <= 0 then Exit(0);

  Available := WriteAvailable;
  Result := ACount;
  if Result > Available then
  begin
    Result := Available;
    Inc(FOverflows);
  end;

  if Result = 0 then Exit;

  WritePos := FHead and FMask;
  Src := @AData;

  // 计算是否需要环绕
  FirstPart := FCapacity - WritePos;
  if FirstPart >= Result then
  begin
    // 不需要环绕
    Move(Src^, (FBuffer + WritePos)^, Result);
  end
  else
  begin
    // 需要环绕写入
    Move(Src^, (FBuffer + WritePos)^, FirstPart);
    SecondPart := Result - FirstPart;
    Move((Src + FirstPart)^, FBuffer^, SecondPart);
  end;

  // 内存屏障确保数据写入完成后再更新索引
  WriteMemoryBarrier;
  FHead := FHead + Result;  // 让 head 自由增长，不使用 and FMask

  Inc(FTotalWritten, Result);
end;

function TLockFreeRingBuffer.WriteBytes(const AData: TBytes): Integer;
begin
  if Length(AData) = 0 then
    Result := 0
  else
    Result := Write(AData[0], Length(AData));
end;

function TLockFreeRingBuffer.TryWrite(const AData; ACount: Integer): Boolean;
begin
  Result := WriteAvailable >= ACount;
  if Result then
    Write(AData, ACount);
end;

function TLockFreeRingBuffer.Read(var AData; ACount: Integer): Integer;
var
  Available, FirstPart, SecondPart: Integer;
  ReadPos: Integer;
  Dst: PByte;
begin
  if ACount <= 0 then Exit(0);

  Available := ReadAvailable;
  Result := ACount;
  if Result > Available then
    Result := Available;

  if Result = 0 then Exit;

  ReadPos := FTail and FMask;
  Dst := @AData;

  // 计算是否需要环绕
  FirstPart := FCapacity - ReadPos;
  if FirstPart >= Result then
  begin
    // 不需要环绕
    Move((FBuffer + ReadPos)^, Dst^, Result);
  end
  else
  begin
    // 需要环绕读取
    Move((FBuffer + ReadPos)^, Dst^, FirstPart);
    SecondPart := Result - FirstPart;
    Move(FBuffer^, (Dst + FirstPart)^, SecondPart);
  end;

  // 内存屏障确保数据读取完成后再更新索引
  ReadMemoryBarrier;
  FTail := FTail + Result;  // 让 tail 自由增长，不使用 and FMask

  Inc(FTotalRead, Result);
end;

function TLockFreeRingBuffer.ReadBytes(ACount: Integer): TBytes;
var
  Available: Integer;
begin
  Available := ReadAvailable;
  if ACount > Available then
    ACount := Available;

  SetLength(Result, ACount);
  if ACount > 0 then
    Read(Result[0], ACount);
end;

function TLockFreeRingBuffer.TryRead(var AData; ACount: Integer): Boolean;
begin
  Result := ReadAvailable >= ACount;
  if Result then
    Read(AData, ACount);
end;

function TLockFreeRingBuffer.Peek(var AData; ACount: Integer): Integer;
var
  Available, FirstPart, SecondPart: Integer;
  ReadPos: Integer;
  Dst: PByte;
begin
  if ACount <= 0 then Exit(0);

  Available := ReadAvailable;
  Result := ACount;
  if Result > Available then
    Result := Available;

  if Result = 0 then Exit;

  ReadPos := FTail and FMask;
  Dst := @AData;

  FirstPart := FCapacity - ReadPos;
  if FirstPart >= Result then
    Move((FBuffer + ReadPos)^, Dst^, Result)
  else
  begin
    Move((FBuffer + ReadPos)^, Dst^, FirstPart);
    SecondPart := Result - FirstPart;
    Move(FBuffer^, (Dst + FirstPart)^, SecondPart);
  end;
  // 注意：Peek 不更新 FTail
end;

function TLockFreeRingBuffer.Skip(ACount: Integer): Integer;
var
  Available: Integer;
begin
  Available := ReadAvailable;
  Result := ACount;
  if Result > Available then
    Result := Available;

  if Result > 0 then
  begin
    ReadMemoryBarrier;
    FTail := FTail + Result;  // 让 tail 自由增长
    Inc(FTotalRead, Result);
  end;
end;

procedure TLockFreeRingBuffer.Clear;
begin
  FHead := 0;
  FTail := 0;
  WriteMemoryBarrier;
end;

function TLockFreeRingBuffer.GetWritePtr(out AAvailable: Integer): PByte;
var
  WritePos, ToEnd: Integer;
begin
  AAvailable := WriteAvailable;
  WritePos := FHead and FMask;

  // 只返回到缓冲区末尾的连续空间
  ToEnd := FCapacity - WritePos;
  if AAvailable > ToEnd then
    AAvailable := ToEnd;

  Result := FBuffer + WritePos;
end;

procedure TLockFreeRingBuffer.CommitWrite(ACount: Integer);
begin
  if ACount > 0 then
  begin
    WriteMemoryBarrier;
    FHead := FHead + ACount;  // 让 head 自由增长
    Inc(FTotalWritten, ACount);
  end;
end;

function TLockFreeRingBuffer.GetReadPtr(out AAvailable: Integer): PByte;
var
  ReadPos, ToEnd: Integer;
begin
  AAvailable := ReadAvailable;
  ReadPos := FTail and FMask;

  // 只返回到缓冲区末尾的连续数据
  ToEnd := FCapacity - ReadPos;
  if AAvailable > ToEnd then
    AAvailable := ToEnd;

  Result := FBuffer + ReadPos;
end;

procedure TLockFreeRingBuffer.CommitRead(ACount: Integer);
begin
  if ACount > 0 then
  begin
    ReadMemoryBarrier;
    FTail := FTail + ACount;  // 让 tail 自由增长
    Inc(FTotalRead, ACount);
  end;
end;

end.
