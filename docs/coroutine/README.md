# nextpas.core.coroutine

无栈协程系统——基于状态表驱动的轻量级协作式多任务。

## 概述

提供零分配热路径的协程管理，适用于游戏逻辑、动画序列、延迟操作等场景。
协程通过步骤序列（Action → Wait → Action → ...）定义行为，每帧调用 `Update` 推进。

## 层级

L1（基础设施）

## 快速开始

```pascal
uses
  nextpas.core.coroutine;

var
  LMgr: ICoroutineManager;
  LSteps: array[0..3] of TCoroStep;
begin
  LMgr := CreateCoroutineManager;

  LSteps[0] := CoroAction(@DoSomething);
  LSteps[1] := CoroWaitSeconds(1.0);
  LSteps[2] := CoroAction(@DoNext);
  LSteps[3] := CoroEnd;

  LMgr.StartSequence(@LSteps[0], 4);

  // 游戏循环中
  while True do
    LMgr.Update(1.0 / 60.0);
end;
```

## API

### 工厂

| 函数 | 说明 |
|------|------|
| `CreateCoroutineManager` | 创建 ICoroutineManager 实例 |

### ICoroutineManager

| 方法 | 说明 |
|------|------|
| `Start(Proc, UserData, Tag)` | 启动过程式协程 |
| `StartSequence(Steps, Count, UserData, Tag)` | 启动步骤序列 |
| `Stop(ID)` | 停止指定协程 |
| `StopByTag(Tag)` | 停止所有带指定 Tag 的协程 |
| `StopAll` | 停止所有协程 |
| `YieldFrames(ID, N)` | 挂起 N 帧 |
| `YieldSeconds(ID, T)` | 挂起 T 秒 |
| `YieldUntil(ID, Condition)` | 挂起直到条件为真 |
| `YieldCoroutine(ID, WaitFor)` | 挂起直到另一个协程完成 |
| `Update(DeltaTime)` | 每帧调用，推进所有活跃协程 |
| `GetState(ID)` | 查询协程状态 |
| `GetActiveCount` | 当前活跃协程数 |

### 步骤构建器

| 函数 | 说明 |
|------|------|
| `CoroAction(Proc)` | 执行动作步骤 |
| `CoroWaitSeconds(T)` | 等待秒数 |
| `CoroWaitFrames(N)` | 等待帧数 |
| `CoroWaitUntil(Condition)` | 等待条件 |
| `CoroEnd` | 序列结束标记 |

## 设计决策

- **无栈**：不使用 fiber/setjmp，零平台依赖
- **状态表驱动**：每个协程是步骤数组 + 当前索引
- **固定容量**：预分配 256 槽位，无动态内存分配
- **值语义步骤**：TCoroStep 是 record，可栈上分配

## 限制

- 最大 256 个并发协程（编译时常量 `COROUTINE_MAX_ACTIVE`）
- 步骤序列必须在协程生命周期内保持有效（调用方持有）
