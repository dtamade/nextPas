{**
 * @desc 基准测试对象池
 *
 * 提供 TBenchContext 对象池，减少高频基准测试的分配开销。
 * 零分配路径：预分配对象，复用而不是重新创建。
 *}
unit nextpas.core.bench.pool;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.bench.runner;

type
  {** TBenchContext 对象池 }
  TBenchContextPool = class
  private
    FPool: array of TBenchContext;
    FPoolSize: Integer;
    FAvailable: Integer;
    FLock: TRTLCriticalSection;

  public
    constructor Create(APoolSize: Integer = 16);
    destructor Destroy; override;

    {** 获取一个可用的 TBenchContext }
    function Acquire: TBenchContext;

    {** 归还 TBenchContext 到池中 }
    procedure Release(AContext: TBenchContext);

    {** 获取池中可用对象数量 }
    property Available: Integer read FAvailable;

    {** 获取池大小 }
    property PoolSize: Integer read FPoolSize;
  end;

{** 全局对象池实例 }
var
  GBenchContextPool: TBenchContextPool;

{** 初始化全局对象池 }
procedure InitGlobalPool(APoolSize: Integer = 16);

{** 释放全局对象池 }
procedure FinalizeGlobalPool;

implementation

constructor TBenchContextPool.Create(APoolSize: Integer);
var
  I: Integer;
begin
  inherited Create;
  FPoolSize := APoolSize;
  FAvailable := APoolSize;
  SetLength(FPool, APoolSize);

  { 预分配所有对象 }
  for I := 0 to APoolSize - 1 do
    FPool[I] := TBenchContext.Create;

  InitCriticalSection(FLock);
end;

destructor TBenchContextPool.Destroy;
var
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    for I := 0 to FPoolSize - 1 do
      FreeAndNil(FPool[I]);
  finally
    LeaveCriticalSection(FLock);
  end;

  DoneCriticalSection(FLock);
  inherited;
end;

function TBenchContextPool.Acquire: TBenchContext;
begin
  Result := nil;

  EnterCriticalSection(FLock);
  try
    if FAvailable > 0 then
    begin
      Dec(FAvailable);
      Result := FPool[FAvailable];
      FPool[FAvailable] := nil;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;

  { 如果池已空，创建新对象 }
  if Result = nil then
    Result := TBenchContext.Create;
end;

procedure TBenchContextPool.Release(AContext: TBenchContext);
begin
  if AContext = nil then
    Exit;

  { 重置上下文状态 }
  AContext.Reset;

  EnterCriticalSection(FLock);
  try
    if FAvailable < FPoolSize then
    begin
      FPool[FAvailable] := AContext;
      Inc(FAvailable);
    end
    else
    begin
      { 池已满，释放对象 }
      AContext.Free;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure InitGlobalPool(APoolSize: Integer);
begin
  if GBenchContextPool = nil then
    GBenchContextPool := TBenchContextPool.Create(APoolSize);
end;

procedure FinalizeGlobalPool;
begin
  FreeAndNil(GBenchContextPool);
end;

initialization
  { 默认不初始化全局池，由用户显式调用 InitGlobalPool }

finalization
  FinalizeGlobalPool;

end.
