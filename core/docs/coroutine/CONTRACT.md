# nextpas.core.coroutine 代码契约

**模块路径**：`core/src/nextpas.core.coroutine*.pas`（3 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| coroutine.base | TCoroutineID, TCoroutineState, TYieldKind, TCoroStep 记录 |
| coroutine.intf | ICoroutineManager 接口 |
| coroutine.pas | 门面 + 便利函数 |

### 1.2 核心接口

```pascal
ICoroutineManager = interface
  function Start(AProc: TCoroutineProc): TCoroutineID;
  procedure Stop(AID: TCoroutineID);
  procedure StopAll;
  procedure Update(ADeltaSeconds: Single);
  function IsActive(AID: TCoroutineID): Boolean;
  function ActiveCount: Integer;
end;
```

### 1.3 步骤构建

```pascal
function CoroAction(AAction: TCoroStepAction): TCoroStep;
function CoroWaitSeconds(ASeconds: Single): TCoroStep;
function CoroWaitFrames(AFrames: Integer): TCoroStep;
function CoroWaitUntil(ACondition: TCoroutineCondition; AData: Pointer = nil): TCoroStep;
function CoroEnd: TCoroStep;
```

### 1.4 协程状态

```
TCoroutineState = (csRunning, csWaiting, csCompleted, csStopped);
```

---

## 2. 不变量

- **[INV-1]** 协程在 Update 帧中推进，不跨线程
- **[INV-2]** CoroWaitSeconds 基于累计时间，不基于帧率
- **[INV-3]** CoroWaitUntil 每帧检查条件
- **[INV-4]** Stop 立即将状态设为 csStopped

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| 协程抛异常 | 捕获并停止该协程 |
| Stop 不存在的 ID | 静默忽略 |

---

## 4. 线程安全

❌ 单线程使用。ICoroutineManager 不跨线程。

---

## 5. 内存管理

- ICoroutineManager 拥有所有协程
- Stop/StopAll 释放协程资源
- StopAll 或 Destroy 时清理全部

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_coroutine | 基本协程操作 |
| **合计** | **1 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.1 | 时效修复：更新最后更新至 2026-08-31 v1.1 并对齐实现 | Claude |
