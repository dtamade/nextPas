# SESSION：JSONL 会话转录存储设计（W5 立项文档）

> **Status: active(W5)**。2026-08-25 总控立项。本文档是
> `nextpas.core.agent.session` 的设计权威；实现与本文冲突时先改本文。
> 接口 `IAgentTranscriptStore`（intf 词表，Append/Load/Delete/Fork 四方法，
> 2026-09-01 起 Fork 纳入接口；同时以独立能力接口 `IAgentTranscriptFork`
> 暴露，便于存量实现平滑过渡）；本文设计其 JSONL 落地实现与崩溃恢复语义。

## 1. 目标与非目标

**目标**：给 `IAgentTranscriptStore` 一个标准库级落地实现——JSONL
event-sourced 文件存储，具备：

- 崩溃恢复语义（torn tail 识别与丢弃、损坏行 fail-closed）
- 明确的 fsync 节奏选项（默认每追加落盘）
- 无损往返（TMessage 全词表含 ExtraJson 逐字节保真）
- Fork（会话分叉）：按 Load 恢复语义取干净快照物化到新线程

**非目标（v1）**：

- 不做 delta 级事件流（记录的是消息粒度，不是流式增量回放——那是 code888
  应用域的 event-sourcing 形态，体量与 fsync 节奏均超出 stdlib v1）
- 不做跨进程文件锁协同写（v1 单写者假设，见 §7）
- 不做压缩、加密、轮转（消费方可在 RootDir 层自行处理）
- 不做内存实现（消费方自建 in-memory store 成本极低；stdlib 只供持久形态）

## 2. 存储布局

```
<RootDir>/<ThreadId>.jsonl     ← 一线程一文件；行序即 transcript 序
```

- 一线程一文件使 Load=整读、Delete=删文件、跨线程零干扰；放弃单文件多线程
  方案（Load 需全库扫描、Delete 需重写、并发交错复杂）。
- 根目录在构造时 `MkdirAll` 确保（幂等）；失败让 fs 层异常穿透。

### ThreadId 校验（防路径穿越，SECURITY 铁律）

合法集：`[A-Za-z0-9._-]` 组成的非空串，且首字符不为 `'.'`（排除 `.` 与
`..`）、长度 ≤128。非法 → 抛 `EAgentMisuse`（不回显原值，避免污染日志）。
推荐消费方用 core.id 的 ulid/v7。

## 3. 行格式 schema v1

每行一个自包含 JSON object，UTF-8，单行内不得出现裸换行：

```json
{"v":1,"kind":"msg","msg":{...}}
```

`msg` 对象字段（全部可选除 role；缺省即词表零值）：

| 键 | 类型 | 词表落点 |
|----|------|---------|
| `id` | string | TMessage.Id |
| `role` | string | system/user/assistant/tool |
| `model` | string | TMessage.Model |
| `finish` | string | none/stop/length/tool_calls/content_filter |
| `usage` | object{in,out,cache_r,cache_w,reason} | 缺省五字段=CUsageUnknown（不伪造 0）|
| `parts` | array | 见下 |
| `extra` | **string** | ExtraJson 原文作为 JSON 字符串嵌入 |

part 对象字段：`kind`（text/thinking/tool_call/tool_result/image）+
按需 `text/call_id/name/args/result/is_error/image/sig/extra`。

**关键决策：四个 TJsonText 字段（ExtraJson×2、ArgumentsJson、ResultJson）
一律以 JSON 字符串形式嵌入，不做嵌套 RawJson 注入。** 理由：框架完整性
优先于手工可读性——builder.Str() 的转义保证行内永不出现裸换行，torn-tail
判定因此永远可靠；RawJson 直插则无法防御消费方塞入带换行的 pretty JSON。
往返仍逐字节无损（字符串原样取回）。翻案条件：出现需要直接 grep 存储文件
内部字段的运维诉求时，加规范化重打（parse→compact print）通道。

**版本策略：fail-closed。** 未知 `kind` 或不认识的 `v` → ETranscriptCorrupt
（滚动升级兼容性问题留给未来真实出现 v2 时再引入跳过策略；现在静默跳过
只会制造数据丢失错觉）。

## 4. 崩溃恢复语义（Load 规则）

按序读取 `<ThreadId>.jsonl`：

1. 文件不存在 → 空 transcript（nil 数组，不报错——"无历史"不是故障）。
2. 以 `\n` 分行；行尾 `\r` 剥离（Windows CRLF 兼容）。
3. **torn tail**：文件末字节不是 `\n` ⇒ 最后一段是中断写入，丢弃不计。
   （本实现的 Append 每次整行写入并自带行尾换行，故该判据完备。）
4. 完整行的空行：跳过（无害框架噪声）。
5. 完整行 JSON 解析失败或形状不符 → **fail-closed**：抛
   `ETranscriptCorrupt`（固定 aecProtocol），消息含 1-based 行号。
   磁盘故障/外部改写绝不允许被静默吞掉后伪装成"短了一点"的历史。

## 5. fsync 节奏

构造选项 `SyncEachAppend: Boolean = True`：

- **True（默认）**：每次 Append 打开 O_APPEND → 写整行 → `Sync` → 关闭。
  崩溃最多丢正在写的那一行（由 §4 torn-tail 规则兜底）。对话历史是有价值的
  生产数据，默认安全。
- **False**：写后依赖 OS 刷盘；高吞吐 loop 场景由消费方显式选择，
  崩溃窗口=自上次内核刷盘以来的尾部追加。
- Fork 经 `WriteAtomic`（临时文件+rename）保证内容原子可见；rename 后的
  目录级 fsync 属 fs 模块职责边界，本层不做重复保障（如实记录，不虚称）。

## 6. Fork 语义

`Fork(Src, Dst)`：对 Src 执行 §4 Load 规则取**干净快照**（torn tail 已剔
除），逐行重编为规范 JSONL，`WriteAtomic` 写入 Dst。

- Dst 已存在 → 抛 EAgentMisuse（fork 是分叉不是覆盖，防误删）。
- Src/Dst 同名 → 抛 EAgentMisuse。
- 快照时点语义：并发追加不在承诺范围内（见 §7）。

## 7. 并发模型

- **同一线程 id 单写者**（进程内或进程间均是）。O_APPEND 保证小行写入的
  原子落位，但不承诺多写者交错序——v1 如实声明不支持，不加锁（锁语义与
  超时策略是应用域问题）。
- 不同线程 id 各自独立文件，天然并发安全；同一 Store 实例可被多线程使用
  于不同 thread id（Append 路径无共享可变态）。
- 多读一写（Load 与 Append 并发）：读者看到的是文件某一致性前缀
  （完整行序列），最坏情况读到不含最新一行的快照——符合转录场景直觉。

## 8. 错误面

| 情形 | 异常 |
|------|------|
| ThreadId 非法 | `EAgentMisuse`（不回显原值） |
| Fork 目标已存在 / 自 fork | `EAgentMisuse` |
| 完整行解析失败 / 形状不符 / 未知 kind 或版本 | `ETranscriptCorrupt`（aecProtocol 固定码，消息含行号） |
| 底层 IO 失败 | fs 层异常**原样穿透**，不包装不降级（保留 fs 错误分类保真） |

`ETranscriptCorrupt = class(EAgentError)` 新增异常类不扩错误码枚举——
词表冻结纪律不变。

## 9. 公开 API（API.md §3 同步）

```pascal
function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore;
{ 门面同时转发类型 TJsonlTranscriptStore / ETranscriptCorrupt / IAgentTranscriptFork；
  Fork 为接口第四方法（亦以独立能力接口暴露，便于存量三方法实现通过 Supports 探测过渡）}
procedure Fork(const ASrcThreadId, ADstThreadId: string);  { IAgentTranscriptStore + IAgentTranscriptFork }
function TranscriptMessageToJson(const AMsg: TMessage): TJsonText;    { 存储编码 }
function TranscriptMessageFromJson(const AJson: TJsonText): TMessage; { 存储解码 }
```

## 10. 测试计划 → test_session gate

roundtrip 基础 / 全词表无损往返（thinking+signature+tool_call+tool_result
is_error+image+extra）/ 跨实例持久 / torn tail 丢弃 / 损坏行 fail-closed
含行号 / 未知 kind fail-closed / Delete 幂等 / 缺失线程空载 / ThreadId
校验全集 / Fork（剔除 torn tail、拒绝已存在目标、拒绝自 fork）/ 双同步
模式 / Unicode 内容 / usage unknown 不伪造 0。全部离线，产物落测试目录
build 下并 try/finally RemoveAll。
