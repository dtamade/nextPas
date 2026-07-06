{**
 * np_parallel_scheduler.pas — Parallel Build Scheduler (Stub)
 *
 * 并行编译调度接口。当前为 stub 实现，待 AL4 完善。
 *}

unit np_parallel_scheduler;

{$mode objfpc}{$H+}

interface

type
  TParallelScheduler = class
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TParallelScheduler.Create;
begin
  inherited Create;
end;

destructor TParallelScheduler.Destroy;
begin
  inherited Destroy;
end;

end.
