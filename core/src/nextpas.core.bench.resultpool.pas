{**
 * @desc 基准结果缓冲区池
 *
 * TBenchResultPool 预分配 TBenchResult 缓冲区，工作线程借用而非分配，
 * 避免高频基准场景的 GetMem/FreeMem 开销。
 *
 * 设计要点:
 * - 预分配固定大小池，工作线程通过原子索引无锁借用
 * - 池销毁时统一释放所有缓冲区
 * - 池满时回退到直接分配
 *
 * @see TBenchRun (线程安全执行器)
 *}
unit nextpas.core.bench.resultpool;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.atomic,
  nextpas.core.bench.base,
  nextpas.core.bench.run;

const
  {** 默认池大小 }
  BENCH_RESULT_POOL_DEFAULT_SIZE = 1024;

type
  {** 基准结果缓冲区池 }
  TBenchResultPool = class
  private
    FBuffers: array of PBenchRunResult;
    FCapacity: Int32;
    FNextIdx: Int32;        { 原子借用索引 }
  public
    constructor Create(ACapacity: Int32 = BENCH_RESULT_POOL_DEFAULT_SIZE);
    destructor Destroy; override;

    {** 从池中借用一个缓冲区（无锁原子操作）
     *  @returns 缓冲区指针，池满时回退到直接分配 }
    function Borrow: PBenchRunResult;

    {** 当前已借用的缓冲区数 }
    function BorrowedCount: Int32;

    {** 池容量 }
    function Capacity: Int32;
  end;

implementation

{ --------------------------------------------------------------------- }
{  TBenchResultPool }
{ --------------------------------------------------------------------- }

constructor TBenchResultPool.Create(ACapacity: Int32);
var
  I: Int32;
begin
  inherited Create;
  if ACapacity <= 0 then
    ACapacity := BENCH_RESULT_POOL_DEFAULT_SIZE;
  FCapacity := ACapacity;
  FNextIdx := 0;

  { 预分配缓冲区数组 }
  SetLength(FBuffers, FCapacity);

  { 预分配所有缓冲区 }
  for I := 0 to FCapacity - 1 do
    FBuffers[I] := AllocBenchResult(Default(TBenchResult));
end;

destructor TBenchResultPool.Destroy;
var
  I: Int32;
begin
  { 释放所有预分配的缓冲区 }
  for I := 0 to FCapacity - 1 do
    FreeBenchResult(FBuffers[I]);

  SetLength(FBuffers, 0);
  inherited;
end;

function TBenchResultPool.Borrow: PBenchRunResult;
var
  LIdx: Int32;
begin
  LIdx := AtomicFetchAdd32(FNextIdx, 1, moAcqRel);
  if LIdx >= FCapacity then
  begin
    { 池已满，回退到直接分配 }
    Result := AllocBenchResult(Default(TBenchResult));
    Exit;
  end;
  Result := FBuffers[LIdx];
  { 缓冲区已在构造时初始化，直接返回 }
end;

function TBenchResultPool.BorrowedCount: Int32;
begin
  Result := AtomicLoad32(FNextIdx, moRelaxed);
end;

function TBenchResultPool.Capacity: Int32;
begin
  Result := FCapacity;
end;

end.
