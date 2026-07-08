{**
 * @desc 基准测试通用辅助函数
 *
 * 提供 TBenchEntry 快速构建、通用 bench 函数、
 * TBenchStatsAnalyzer 工厂函数等测试辅助工具。
 *}
unit nextpas.core.bench.test_helpers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

{ --------------------------------------------------------------------- }
{  通用 bench 函数 }
{ --------------------------------------------------------------------- }

{** 空操作基准 — 用于测试框架本身 }
procedure NoOpBench(const ACtx: IBenchContext);

{** 忙等基准 — 轻量计算用于测试执行逻辑 }
procedure BusyBench(const ACtx: IBenchContext);

{** 分配内存基准 — 用于测试内存跟踪 }
procedure AllocBench(const ACtx: IBenchContext);

{ --------------------------------------------------------------------- }
{  TBenchEntry 构建辅助 }
{ --------------------------------------------------------------------- }

{** 创建简单 TBenchEntry（无参数、无循环） }
function MakeBenchEntry(const AName: string; AFunc: TBenchFunc): TBenchEntry;

{** 创建带条件的 TBenchEntry }
function MakeConditionalEntry(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): TBenchEntry;

{ --------------------------------------------------------------------- }
{  TBenchStatsAnalyzer 工厂 }
{ --------------------------------------------------------------------- }

{** 创建 TBenchStatsAnalyzer 实例（调用方负责 Free） }
function NewStatsAnalyzer: TBenchStatsAnalyzer;

{ --------------------------------------------------------------------- }
{  测试数据生成 }
{ --------------------------------------------------------------------- }

{** 生成 [0, ARange) 范围的随机浮点数组 }
function MakeRandomData(ACount: Integer; ARange: Double = 100.0): TDoubleArray;

{** 生成固定序列 [1, 2, ..., N] }
function MakeSequence(ACount: Integer): TDoubleArray;

implementation

uses
  nextpas.core.bench.run;

{ --------------------------------------------------------------------- }
{  通用 bench 函数 }
{ --------------------------------------------------------------------- }

procedure NoOpBench(const ACtx: IBenchContext);
begin
  { 空操作 }
end;

procedure BusyBench(const ACtx: IBenchContext);
var
  I, S: Integer;
begin
  S := 0;
  for I := 1 to 1000 do
    S := S + I;
  ACtx.SetBytes(S);
end;

procedure AllocBench(const ACtx: IBenchContext);
var
  LBuf: array of Byte;
begin
  SetLength(LBuf, 1024);
  LBuf[0] := 1;
  ACtx.SetBytes(Length(LBuf));
end;

{ --------------------------------------------------------------------- }
{  TBenchEntry 构建辅助 }
{ --------------------------------------------------------------------- }

function MakeBenchEntry(const AName: string; AFunc: TBenchFunc): TBenchEntry;
begin
  Result := Default(TBenchEntry);
  Result.Name := AName;
  Result.Func := AFunc;
  Result.ParamFunc := nil;
  Result.ParamValue := 0;
  Result.IsLoop := False;
  Result.LoopFunc := nil;
  Result.LoopContextFunc := nil;
  Result.Setup := nil;
  Result.Teardown := nil;
  Result.Condition := True;
  Result.EnableParallel := False;
  Result.ParallelThreads := 0;
  Result.TimeoutMs := 0;
  Result.CollectRawSamples := False;
  Result.SimpleFunc := nil;
end;

function MakeConditionalEntry(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): TBenchEntry;
begin
  Result := MakeBenchEntry(AName, AFunc);
  Result.Condition := ACondition;
end;

{ --------------------------------------------------------------------- }
{  TBenchStatsAnalyzer 工厂 }
{ --------------------------------------------------------------------- }

function NewStatsAnalyzer: TBenchStatsAnalyzer;
begin
  Result := TBenchStatsAnalyzer.Create;
end;

{ --------------------------------------------------------------------- }
{  测试数据生成 }
{ --------------------------------------------------------------------- }

function MakeRandomData(ACount: Integer; ARange: Double): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := Random * ARange;
end;

function MakeSequence(ACount: Integer): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := I + 1;
end;

end.
