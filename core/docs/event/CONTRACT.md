# nextpas.core.event 代码契约

**模块路径**：`core/src/nextpas.core.event*.pas`（3 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| event.base | TSubscriptionEntry, TQueuedEvent, TEventData 记录类型 |
| event.intf | IEventBus 接口定义 |
| event.pas | TEventBus 实现 |

### 1.2 核心接口

```pascal
IEventBus = interface
  function Subscribe(const AEvent: string; AHandler: TEventHandler): TSubscriptionId;
  procedure Unsubscribe(AId: TSubscriptionId);
  procedure Emit(const AEvent: string; const AData: TEventData);
  procedure EmitAsync(const AEvent: string; const AData: TEventData);
  procedure Drain;
end;
```

### 1.3 核心类型

```pascal
TEventData = record
  Sender: TObject;
  Data: Pointer;
end;

TSubscriptionEntry = record
  Id: TSubscriptionId;
  Event: string;
  Handler: TEventHandler;
end;
```

---

## 2. 不变量

- 订阅 ID 全局唯一，单调递增
- `Emit` 同步调用所有 handler
- `EmitAsync` 将事件入队，`Drain` 时调用
- `Unsubscribe` 后不再收到事件

---

## 3. 错误处理

- Handler 抛异常不影响其他 handler 调用
- `Unsubscribe` 不存在的 ID 无操作

---

## 4. 线程安全

- `Subscribe`/`Unsubscribe` 使用锁保护
- `Emit` 在调用方线程同步执行
- `EmitAsync` 入队操作线程安全

---

## 5. 内存管理

- `Unsubscribe` 释放订阅条目
- TEventBus 销毁时释放所有订阅

---

## 6. 测试覆盖

- `test_event`: 12 测试，覆盖 Subscribe/Unsubscribe/Emit/EmitAsync/Drain
