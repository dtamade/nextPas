# nextpas.core.event

进程内事件总线——发布/订阅 + 优先级 + 延迟队列。

## 概述

轻量级事件系统，支持即时发布（同步）和延迟发布（队列化）。
处理器按优先级排序执行，支持方法指针和普通过程两种回调形式。

## 层级

L3（框架）

## 快速开始

```pascal
uses
  nextpas.core.event;

type
  TMyHandler = class
    procedure OnDamage(const AName: string; const AData: TEventData);
  end;

procedure TMyHandler.OnDamage(const AName: string; const AData: TEventData);
begin
  WriteLn('Damage: ', AData.IntVal);
end;

var
  LBus: IEventBus;
  LHandler: TMyHandler;
begin
  LBus := CreateEventBus;
  LHandler := TMyHandler.Create;

  LBus.Subscribe('damage', @LHandler.OnDamage, 10);
  LBus.EmitInt('damage', 50);  // 立即触发

  LBus.PostInt('heal', 20);    // 加入队列
  LBus.Flush;                  // 处理队列

  LHandler.Free;
end;
```

## API

### 工厂

| 函数 | 说明 |
|------|------|
| `CreateEventBus` | 创建 IEventBus 实例 |

### IEventBus

| 方法 | 说明 |
|------|------|
| `Subscribe(Name, Handler, Priority)` | 订阅（方法指针） |
| `SubscribeProc(Name, Handler, Priority)` | 订阅（普通过程） |
| `Unsubscribe(ID)` | 取消订阅 |
| `UnsubscribeAll(Name)` | 取消指定事件的所有订阅 |
| `Emit(Name)` | 即时发布（无数据） |
| `EmitInt(Name, Value)` | 即时发布（整数数据） |
| `EmitFloat(Name, Value)` | 即时发布（浮点数据） |
| `EmitPtr(Name, Value)` | 即时发布（指针数据） |
| `Post(Name)` | 延迟发布 |
| `PostInt(Name, Value)` | 延迟发布（整数） |
| `Flush` | 处理所有延迟事件 |
| `ClearQueue` | 清空队列 |
| `GetSubscriptionCount` | 活跃订阅数 |
| `GetQueuedCount` | 队列中事件数 |

### 数据构建器

| 函数 | 说明 |
|------|------|
| `EventDataNone` | 无数据 |
| `EventDataInt(Value)` | 整数数据 |
| `EventDataFloat(Value)` | 浮点数据 |
| `EventDataPtr(Value)` | 指针数据 |

## 设计决策

- **字符串事件名**：灵活、可调试、无需预注册
- **优先级排序**：数值越大越先执行
- **延迟队列**：Post + Flush 模式适合帧边界处理
- **双回调形式**：方法指针 + 普通过程，覆盖所有使用场景
- **固定容量**：256 订阅 + 64 队列，无动态分配

## 限制

- 最大 256 个订阅（`EVENT_MAX_SUBSCRIPTIONS`）
- 最大 64 个队列事件（`EVENT_MAX_QUEUED`）
- 事件数据仅支持 int/float/pointer（不支持复合类型）
