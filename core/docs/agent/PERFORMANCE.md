# PERFORMANCE：热路径契约与资源预算

> 每条主张对应 TESTING.md 的 bench 项；landing 后数据落 BENCHMARKS.md。
> 无数据不叙事——本文件是机制侧契约，不是营销页。

## 1. 热路径复杂度契约

| 路径 | 复杂度 | 禁止 |
|------|--------|------|
| sse.Feed(bytes) | O(bytes) 单遍 | 回扫、逐字符字符串拼接 |
| Decoder.DecodeEvent | O(frame) | 每帧重建解析器/JSON DOM 全量重挂 |
| fold.FoldDelta | O(1) 摊销/delta（参数片段 StringBuilder 倍增缓冲）| per-delta SetLength、`s := s + x` |
| EncodeXxxRequest | O(payload) | 中间拷贝超过 2×payload |
| loop transcript 追加 | O(1) 摊销 | 每轮全量深拷贝历史（code888 已知债，明确不继承）|
| 工具查找 | O(n) n=注册工具数（n 小）| — （不上哈希表，避免过早优化）|
| AgentValidateWireHeaders(headers) | O(totalHeaderBytes) 单遍 | 4×Pos 扫描、每头二次分配 |

## 2. 缓冲与尺寸默认值

> 权威默认值总表在 `API.md §10`，本节仅为热路径视角的引用；数值与单位以 API 表为准，修改必同步三处（API §10 / SECURITY §3 / BENCHMARKS §2），F-L07（G6 2026-08-29 合规）。

| 项 | 默认 | 权威常量（单一真源 `nextpas.core.agent.base`） | 说明 |
|----|------|--------------------------------|------|
| transport 读 chunk | 32 KiB | `CReadChunkBytes`（transport 常量，引用 API 表） | IReader.Read 步长；首块前不预分配响应体 |
| SSE 行缓冲 | 阈值压实，单行上限 1 MiB | `CSSEMaxLineBytes` | 上限即 SECURITY DoS 线；零搬运阈值 4 KiB/半缓冲见 sse 单元 |
| ArgumentsJson 累积 | StringBuilder 初始 1024 B | `CAgentToolArgsInitialCap` | 工具参数片段典型 <2KiB |
| RawBodySnippet | 8 KiB 截断 | `CAgentMaxRawBodySnippetBytes`（`provider.common CMaxRawBodySnippetBytes` 为兼容 alias） | ERRORS §6 |
| wire 单头/总头 | 8 KiB / 64 KiB | `CAgentMaxWireHeaderValueBytes`/`CAgentMaxWireTotalHeaderBytes`（`provider.common` 为兼容 alias） | SECURITY §3，`AgentValidateWireHeaders` 单遍校验（典型 5 头 p50 <5µs，实测 ~203 ns（旧值 249 ns @0ab1ddc inline+SSE几何 -18%），`bench_wire_headers` 冻结） |

## 3. 字符串与编码策略

- wire 请求体组装：StringBuilder（text 语义，`{$H+}` UTF-8）单遍写出；
  不经 JSON DOM 再序列化（DOM 组装会引入 2-3× 分配）。结构化字段仍走
  core json 的**写出器**；只有 Extra 回注等未知结构才透传原始文本切片。
- 响应解码：按帧局部解析（decoder 内），禁止整流拼接成大字符串再 Parse
  ——这正是真增量与低分配的同一条路径。
- TJsonText 字段赋值是引用计数拷贝（COW），词表记录传递零深拷贝；
  需要独立可变副本时显式 UniqueString（消费方责任）。

## 4. 分配预算（bench 断言口径）

| 操作 | 预算 |
|------|------|
| 折叠 10k delta（含 50 工具槽）| 分配次数以 bench 框架的分配计数钩子为准（若框架未提供则降级为时长回归阈值，首版基线时定）；禁止 per-delta SetLength 回归 |
| Feed 16 MiB SSE 流 | 行缓冲外每 chunk 零额外常驻分配 |
| fake provider 10 轮纯文本 run | 总时长 µs~ms 级（抽象税基准），无 IO |
| wire 5 头校验 | p50 <5µs（实测 ~203 ns，冻结基线 ~203 ns / ~161 µs / ~198 MB/s，2026-08-29 更新，inline+SSE几何 -18%/-2.5%/+12%），bench_wire_headers 锚定；禁止回退为 4×Pos |

## 5. 与底座的性能协同

- http client keep-alive 复用：transport 不主动关连接，EOF 后归还池
  （连接生命周期归 client 池管）。
- async.cancellation 的 WaitForCancel 是唯一睡眠原语；retry 退避不引入
  第二种等待机制（保证取消打断语义单点实现）。
- bench 回归门禁 `bench_regression`（G6 2026-08-29）：W4 首次全量跑取 p50 为基线写入 `BENCHMARKS.md §2` 并冻结 `build/bench-agent-*.json`，之后任何 wave 收口以 `make bench-regression`（`performance-compare --threshold 10% --p50`）对比，劣化 **>10%** 必须在整改记录解释或回退，无叙事不落地（F-H23 闭环；HEAPTRC 盲区见 TESTING §4，benchmark 默认 `-gh` 豁免需显式 `BENCH_HEAPTRC=1` 另跑）。

## 6. 缓存友好不变量（W3 实施约束）

厂商 prompt cache 按请求前缀命中。agent 循环每轮全量重发历史，前缀稳定性直接
决定缓存命中率（成本差可达数量级），故 loop 构造每轮请求时必须遵守：

1. **历史消息序列字节稳定**：已完成轮次的消息内容/顺序/格式化永不重写
   （不重新缩进 JSON、不重排 part、不改 id）。
2. **system/tools 前置且恒定**：两者在请求对象中的位置与序列化形式跨轮不变。
3. **只追加**：每轮仅在尾部追加 assistant/tool 消息，禁止中间插入或压缩重排
   （自动 compaction 若将来引入，必须显式失效缓存预期并告知消费方）。
4. **cache_control 标记是元数据不是内容**（W10 起）：ccmAuto 在末条消息尾块
   附着的断点标记随轮移动，历史块的内容字节（text/id/signature 等）永不变化；
   tools/system 段标记位与序列化字节跨轮恒定（WIRE-MAPPINGS §2.6）。

该不变量是 W3 test_loop 的断言项之一（连续两轮请求的前缀字节相等）。

## 7. 附录：高级感与零分配 cookbook

> 本附录收敛高频坑位为可复制的惯用法；与 §1–§6 契约正交，仅补充「怎么做才不踩」。
> 三条均有真测锚点：改动后必跑 `bench_wire_headers` / `bench_fold` / `bench_loop_overhead` 对比 p50。

### 7.1 GraphemeNext 簇安全与 EAW 警示（`task888:721` / `nextpas.core.text.grapheme`）

`task888` 以簇为单位推进 TUI 渲染——`nextpas.core.text.grapheme.GraphemeNext(PByte, ALen)` 是 UAX #29 单一真源（`GraphemeClusterByteLen`），
覆盖 ZWJ / Regional Indicator / Extend / SpacingMark / keycap / VS16 变体；`Width` 按 EAW + 终端启发式（FE0F→2 列、keycap→2 列、RI 成对→2 列）计算。

**警示**：`nextpas.core.text.width` 已证明逐码点 `CodepointWidth` 累加会把 `👨‍👩‍👧` / `🇨🇳` / `1️⃣` 序列低报，导致右对齐压穿边界与省略号错位；
本模块同理——**截断/省略必须以 `GraphemeNext` 簇为原子**，禁止 `Copy(S,1,N)` 按字节/码点切：

```pascal
// 反例：半切 emoji 序列 → 非法 UTF-8 + EAW 列宽错位
LBad := Copy(S, 1, 6000);
// 正例：簇安全
LCut := AgentUtf8SafeCutLen(S, 6000); // 后向 UTF-8 边界
// 再向前对齐簇：以 GraphemeNext 前向遍历确认 LCut 落在簇边界，否则回退至上一簇起
LTrunc := AgentUtf8SafeTruncate(S, LCut); // 单一真源落地
```

`AgentUtf8SafeCutLen`（`textutil` 单一真源）只保 UTF-8 合法，不保簇完整；`GraphemeNext` 补齐簇边界。
两原语配对使用是 `PROMPT-BUDGET.md §5` 有界快照截断的落地点。

### 7.2 TAiStreamBox Lock+Done+id 失配丢弃 生命周期（`ARCHITECTURE.md §4`）

`code888` / `task888` 的 `TAiStreamBox`（UI 侧流式盒）以 `Lock + Done + id` 三件实现"归属线程唯一写权 + 迟到丢弃"：

| 字段 | 语义 |
|------|------|
| `Lock: TPlatformMutex` | 经 `nextpas.core.platform.sync` 单一真源保护 `Data/Done/id/FHead` 四字段；所有读写经 `platform_mutex_lock/unlock`，UI 线程与工作线程不跨线程释放资源（`ARCHITECTURE.md §4` 线程契约，零 `SyncObjs` 直连） |
| `Done: Boolean` | 流终止标志；`NextDelta=False` 时置位，`GetMessage/GetUsage` 仅在 `Done=True` 时有效（`LIFECYCLE.md §1` Active→Terminal 状态机） |
| `id: UInt64` | 流实例代际；每次 `Stream()` 自增，下游回调携带 `id`，`id` 失配即丢弃（迟到 `ToolDelta` / `TextDelta` 不回读已合成载荷）——与 `ARCHITECTURE.md §4`「取消后资源由拥有线程独占收尾」正交 |
| `FHead/FPending` | 环形游标：`Push` 尾追加，`TryPop` 取 `FPending[FHead]` 并 `Inc(FHead)`；`FHead>64` 且过半时逐项赋值前移并清零源位摊销 `O(1)`（托管类型禁用 `Move` 以保引用计数），消费完 `SetLength 0` 释压——替代 `O(n)` 逐项前移 |

```pascal
// 伪码：工作线程投递增量 → UI 线程消费（环形版）
procedure TAgentStreamBox.Push(const ADelta: TStreamDelta; AId: UInt64);
begin
  platform_mutex_lock(FLock);
  try
    if (AId <> FId) or FDone then Exit; // 失配/已终态丢弃
    SetLength(FPending, Length(FPending)+1); FPending[High(FPending)] := ADelta;
  finally platform_mutex_unlock(FLock); end;
end;
function TAgentStreamBox.TryPop(out ADelta: TStreamDelta): Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FHead < Length(FPending);
    if not Result then Exit;
    ADelta := FPending[FHead]; Inc(FHead);
    if (FHead>64) and (FHead>Length(FPending) div 2) then begin for I:=0 to LRemaining-1 do begin FPending[I]:=FPending[FHead+I]; FPending[FHead+I]:=Default(TStreamDelta); end; SetLength(FPending,LRemaining); FHead:=0; end;
  finally platform_mutex_unlock(FLock); end;
end;
```

本模块对应物：`loop` 的 `TAgentDeltaBuilder` + `fold.TAssistantBuild` 经 `FReg` 统一注册表保证槽位 `O(1)` 直映（`ARCHITECTURE.md §6` 记录数组只整体重建）；
`tools.RunToolBatch` 的写权仲裁（`WriteGuard`）是同一思想在工具域的落点——弃置线程的迟到结果永不回读已合成 `TToolResult`。

### 7.3 零分配惯用法：SetLength+Move 尾拷 / PByte 零 Copy / InsertSort n≤15

**a) `SetLength+Move` 尾拷替 `S+S` 的 `O(n²)`**

`MessageText` / `TAssistantBuild.PartialText` / `fold.Finish` 均以"先算总长 `LTotal` → 单次 `SetLength(Result, LTotal)` → `Move(Src[1], Dst[LPos], LLen)` 尾拷" 落地，
禁止 `Result := Result + Part.Text` 逐段拼接（每 `+` 一次分配+拷贝，`n` 段 `O(n²)` 搬运）：

```pascal
SetLength(Result, LTotal);
LPos := 1;
for I := 0 to High(Parts) do if Parts[I].Kind = pkText then
begin
  LLen := Length(Parts[I].Text);
  if LLen > 0 then begin Move(Parts[I].Text[1], Result[LPos], LLen); Inc(LPos, LLen); end;
end;
```

同款在 `base.MergeExtraJson` 的键表几何增长（`Cap 0→8→*2`）——`SetLength` 倍增摊还 `O(1)`，禁止 per-delta `SetLength(AArr, LOld+1)`。

**b) `PByte` 零 Copy**

`GraphemeNext(@S[1], Len)` / `GraphemeClusterByteLen(PByte, Len)` 均以 `PByte` + 长度视图入参，
不 `Copy` 子串；`AgentUtf8SafeCutLen` 内联 `Byte(S[LCut])` 直接读字节，零堆分配。
`sse.Feed(TByteSpan)` 同款：`Feeder.Feed(Buffer: TByteSpan)` 按字节域增量喂入，`BOM` 跨块与 `DoS` 上限在内。

**c) `InsertSort` 挡 `n≤15` 小表**

`AgentBuildSystemText` 去重线性扫描、`ValidateToolSpec` 键表查找、`LIFECYCLE.md §5` 的批内分组（`tcParallel` 贪心）均属 `n≤15` 小表——
显式选用 `InsertSort` / 线性扫描而非哈希/快排，避免常数开销与分配税；`n` 上规模再切 `QuickSort`（`nextpas.core.sort` 同款阈值）。

> 回归锚点：任何对 §7 惯用法的改动必跑 `make -C core/benchmarks/nextpas.core.agent/bench_fold run`
> 与 `bench_sse_feed` 对比 p50，劣化 `>10%` 按 `BENCHMARKS.md §4` 门禁解释或回退。
