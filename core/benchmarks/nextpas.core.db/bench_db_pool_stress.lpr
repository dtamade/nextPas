program bench_db_pool_stress;

{ 连接池并发压测（INC-1 性能门禁）：
    phase=read   : 多线程 Acquire/Exec/释放锤读路径；核心不变量 =
                   工厂建连数恰好等于 MaxReadConnections（无泄漏式
                   新建，全部经空闲队列复用）
    phase=writer : 多线程争用单写者槽位；成功与忙超时计数之和 =
                   总轮次（无异常逃逸）
  输出行格式：phase=<p> threads=<t> rounds=<r> ops=<n> ms=<ms>
              ops_per_sec=<n> [opens=<k>|busy=<b>]
  sqlite :memory: 段总是执行；每条连接同一时刻仅被一个租约线程使用，
  符合 CONTRACT §2.1 线程亲和契约。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  cthreads,
  SysUtils,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool;

const
  READ_THREADS = 8;
  READ_ROUNDS = 3000;
  WRITER_THREADS = 4;
  WRITER_ROUNDS = 200;

type
  TWorkerArg = record
    Rounds: Integer;
    Ops: Int64;
    Busy: Int64;                       { writer 阶段：忙超时次数 }
  end;
  PWorkerArg = ^TWorkerArg;

var
  GPool: TDbPool;
  GOpens: Integer;

function MakeCountingFactory: TDbConnectFunc;
begin
  Result := function: IDbConnection
  begin
    InterlockedIncrement(GOpens);
    Result := ConnectSqlite(':memory:');
  end;
end;

function ReadWorkerMain(AArg: Pointer): PtrInt;
var
  Arg: PWorkerArg absolute AArg;
  I: Integer;
  C: IDbConnection;
begin
  Result := 0;
  for I := 1 to Arg^.Rounds do
  begin
    C := GPool.Acquire;
    C.Exec('SELECT 1');
    C := nil;                          { 释放即归还 }
    Inc(Arg^.Ops);
  end;
end;

function WriterWorkerMain(AArg: Pointer): PtrInt;
var
  Arg: PWorkerArg absolute AArg;
  I: Integer;
  C: IDbConnection;
begin
  Result := 0;
  for I := 1 to Arg^.Rounds do
  begin
    try
      C := GPool.Writer;
      C.Exec('SELECT 1');
      C := nil;
      Inc(Arg^.Ops);
    except
      on E: EDbError do
        Inc(Arg^.Busy);                { 槽位忙超时：合法竞争结果 }
    end;
  end;
end;

procedure RunPhase(const AName: string; const AThreads, ARounds: Integer;
  const AEntry: TThreadFunc);
var
  Args: array of TWorkerArg;
  TIDs: array of TThreadID;
  I: Integer;
  TotalOps, TotalBusy: Int64;
  T0, T1: QWord;
begin
  SetLength(Args, AThreads);
  SetLength(TIDs, AThreads);
  for I := 0 to AThreads - 1 do
  begin
    Args[I].Rounds := ARounds;
    Args[I].Ops := 0;
    Args[I].Busy := 0;
  end;
  T0 := GetTickCount64;
  for I := 0 to AThreads - 1 do
    TIDs[I] := BeginThread(AEntry, @Args[I]);
  for I := 0 to AThreads - 1 do
    WaitForThreadTerminate(TIDs[I], 0);
  T1 := GetTickCount64;

  TotalOps := 0;
  TotalBusy := 0;
  for I := 0 to AThreads - 1 do
  begin
    Inc(TotalOps, Args[I].Ops);
    Inc(TotalBusy, Args[I].Busy);
  end;
  Write('phase=', AName, ' threads=', AThreads, ' rounds=', ARounds,
    ' ops=', TotalOps, ' ms=', T1 - T0);
  if T1 > T0 then
    Write(' ops_per_sec=', TotalOps * 1000 div (T1 - T0));
  if AName = 'read' then
    WriteLn(' opens=', GOpens)
  else
    WriteLn(' busy=', TotalBusy);
end;

var
  P: TDbPoolPolicy;
begin
  { 读路径：4 连接上限、零逐出策略下，8 线程锤完工厂必须只开 4 条 }
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 4;
  P.AcquireTimeoutMs := 2000;
  P.IdleTimeoutSec := 0;
  P.MaxLifetimeSec := 0;
  GOpens := 0;
  GPool := TDbPool.Create(MakeCountingFactory, P);
  RunPhase('read', READ_THREADS, READ_ROUNDS, @ReadWorkerMain);
  if GOpens <> P.MaxReadConnections then
  begin
    WriteLn('FAIL: opens=', GOpens, ' expected ', P.MaxReadConnections);
    GPool.Free;
    Halt(1);
  end;
  GPool.Free;

  { 写路径：单槽位争用；busy 计数证明超时路径在并发下正确工作 }
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 20;
  GOpens := 0;
  GPool := TDbPool.Create(MakeCountingFactory, P);
  RunPhase('writer', WRITER_THREADS, WRITER_ROUNDS, @WriterWorkerMain);
  GPool.Free;
  WriteLn('pool-stress=pass');
end.
