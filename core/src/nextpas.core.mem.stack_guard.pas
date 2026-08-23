{
# nextpas.core.mem.stack_guard

## 摘要

栈溢出守卫 — Arena 分配时递归深度检查。

特性:
- threadvar 递归深度计数器
- 可配置最大递归深度
- 分配前检查，防止递归分配导致栈溢出

适用场景: Arena/池分配器的递归保护。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.stack_guard;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.error;

const
  {** 默认最大递归深度 }
  DEFAULT_MAX_ALLOC_DEPTH = 32;

type
  {** TStackGuard
   *
   *  栈溢出守卫。在 Arena 分配时检查递归深度，
   *  防止递归分配导致栈溢出。
   *
   *  使用 threadvar 记录每个线程的递归深度。
   *}
  TStackGuard = record
  public
    {** 检查当前递归深度是否超过限制。
     *  如果超过，返回 False。
     *  如果未超过，递增深度计数器并返回 True。 }
    class function Enter: Boolean; static;
    {** 退出分配，递减深度计数器。 }
    class procedure Leave; static;
    {** 当前递归深度。 }
    class function CurrentDepth: Integer; static;
    {** 设置最大递归深度。 }
    class procedure SetMaxDepth(ADepth: Integer); static;
    {** 获取最大递归深度。 }
    class function GetMaxDepth: Integer; static;
  end;

implementation

var
  {** 最大递归深度 (全局配置) }
  GMaxAllocDepth: Integer = DEFAULT_MAX_ALLOC_DEPTH;

threadvar
  {** 每线程递归深度 }
  GThreadAllocDepth: Integer;

class function TStackGuard.Enter: Boolean;
begin
  if GThreadAllocDepth >= GMaxAllocDepth then
    Exit(False);
  Inc(GThreadAllocDepth);
  Result := True;
end;

class procedure TStackGuard.Leave;
begin
  if GThreadAllocDepth > 0 then
    Dec(GThreadAllocDepth);
end;

class function TStackGuard.CurrentDepth: Integer;
begin
  Result := GThreadAllocDepth;
end;

class procedure TStackGuard.SetMaxDepth(ADepth: Integer);
begin
  if ADepth < 1 then
    ADepth := 1;
  GMaxAllocDepth := ADepth;
end;

class function TStackGuard.GetMaxDepth: Integer;
begin
  Result := GMaxAllocDepth;
end;

end.
