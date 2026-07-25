{**
 * @desc 基准测试通用辅助函数
 *
 * 提供 TBenchEntry 快速构建和通用 bench 函数。
 *}
unit nextpas.core.bench.test_helpers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf;

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

implementation

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
  Result.CollectRawSamples := False;
  Result.SimpleFunc := nil;
end;

end.
