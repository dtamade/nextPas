# nextpas.core.sse 代码契约

**模块路径**：`core/src/nextpas.core.sse*.pas`（3 个源文件）
**层级**：L2（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| sse.base | TSseEvent 记录类型，SSE 常量 |
| sse.parser | TSseParser 解析器 |
| sse.pas | 门面 re-export |

### 1.2 核心类型

```pascal
TSseEvent = record
  Event: string;
  Data: string;
  Id: string;
  Retry: Integer;
end;

TSseParser = record
  // 增量解析器状态
end;
```

### 1.3 核心函数

```pascal
procedure SseParserInit(var AParser: TSseParser);
function SseParserFeed(var AParser: TSseParser; const AChunk: string): TSseEventArray;
function SseEventToStr(const AEvent: TSseEvent): string;
```

---

## 2. 不变量

- SSE 行以 `\n\n` 分隔事件
- `data:` 字段可多行，以 `\n` 连接
- 空行触发事件分发

---

## 3. 错误处理

- 格式错误跳过当前事件，继续解析
- 不抛异常

---

## 4. 线程安全

- TSseParser 是值类型，调用方自行同步

---

## 5. 内存管理

- 返回的数组和字符串由调用方负责释放

---

## 6. 测试覆盖

- `test_sse`: 8 测试，覆盖 Init/Feed/EventToStr/MultiLine/Retry
