{$CODEPAGE UTF8}
unit nextpas.core.mem.stack_scope_helpers;

{$I nextpas.core.settings.inc}


interface

uses
  SysUtils,
  nextpas.core.mem.stack_pool;

// RAII 风格的 StackPool 作用域守卫：创建即保存状态，销毁即恢复状态
// 用法：
//   var Guard: TStackScopeGuard;
//   Guard := TStackScopeGuard.Enter(S);
//   try
//     ... S.Alloc(...)
//   finally
//     Guard.Leave; // 或者依靠作用域结束自动调用析构（record + managed field 不需要，显式更清晰）
//   end;

type
  TStackScopeGuard = record
  private
    FPool: TStackPool;
    FState: SizeUInt;
  public
    class function Enter(aPool: TStackPool): TStackScopeGuard; static;
    procedure Leave; inline;
  end;

implementation

class function TStackScopeGuard.Enter(aPool: TStackPool): TStackScopeGuard;
begin
  Result.FPool := aPool;
  if aPool <> nil then
    Result.FState := aPool.SaveState
  else
    Result.FState := 0;
end;

procedure TStackScopeGuard.Leave;
begin
  if FPool <> nil then
    FPool.RestoreState(FState);
end;

end.
