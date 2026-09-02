# FLAC / MP3 / Vorbis 胜于蓝吸收设计（PR4 补完）

> **Status:** Draft · **Lane:** `codex/core-audio-flac` · **Base:** `a6e582d52`（PR9 完整态）
> **输入:** `~/projects/music888` 的 `music888.flacdec` / `music888.mp3dec` / `music888.vorbisdec`（c2pas888 纯 Pascal 已翻译体，位精确通过 `cmp`）
> **目标:** 不是平移，是 **青出于蓝** — 用 `nextpas.core` 原语重塑为 L2 零分配、可复用、可 bench 的 codec 域。

---

## 1. 背景与问题

- `nextpas.core.audio` PR1-PR9 已交付 `base/intf/codec.wav/aiff/meta/registry/resample/mix/dsp/device/graph/game/timeline`，13 门 180 用例全绿，`Probe≤4KB` + `registry` 可插拔已冻结。
- PR4 的 `flac/mp3` 在 `DESIGN.md §10` 标记为 `flac-pure`，实际在 `music888` 已有纯 Pascal 实现（`miniflac` 0BSD / `minimp3` / `stb_vorbis` 经 `c2pas888` 翻译，手写 `sse` 核，86-88% `gcc -O2` C 性能），但形态仍带 C 后遗症：`{$PACKRECORDS C}` 巨 record、`threadvar` 复用 `alloca`、`__c2p_*` 30+ `strlen/qsort` 回退、`external 'c'` 的 `memcpy` 声明。
- 直接 `cp` 能跑，但跑不出 5 维的胜于蓝：**性能**未用 `nextpas.core.simd` 运行时分派，**复用度**仍 `FsOpen(FilePath)` 而非 `IStream`，**稳定性**的 `threadvar` 在 `async/thread` 池下脆弱，**高级感**的 `TMINIFLAC*/TMp3dec*` 暴露给门面，**完整性**的 `OggFlac/OggVorbis` 与 `MergeTags` 未归一。

---

## 2. 五维差距审计

| 维度 | `music888` 现状 | `nextpas` 胜于蓝形态 |
|---|---|---|
| **性能** | 编译期 `{$ifdef C2P_SIMD}` 选 `sse` 核，`threadvar` 复用 `alloca` 已零每帧分配，但未接入 `nextpas.core.bench` 可复现基线 | `nextpas.core.simd.dispatch` 运行时 `SSE2→AVX2 / NEON`，`TMemoryArena` 实例级复用，`bench_flac/bench_mp3` 在 `bench` 框架下 `ns/op` 压过 86-88% 基线 |
| **高级感** | 巨 record + 30+ `__c2p_stdlib_*` + `external 'c'` | 对外仅 `TAudioBuffer(sfF32)` 与 `EAudioDecodeError(AtFrame)`，内部 `bytes.cursor/io.scanner` 替代位移，`System.Move/FillChar` 替代 `__c2p_memcpy`，`source-contract` 零 `vendor` 警告 |
| **复用度** | `IsFlacPath(const FilePath)` + `ProbeFlacDurationMs` 读文件 | `FlacProbe(const APrefix: TBytes): TAudioProbeResult` + `CreateFlacDecoder: IAudioDecoder`，输入 `IStream` 直通 `Graph/Timeline/Game`，`registry` 即插 |
| **稳定性** | `threadvar` 在 `TThread` 复用下错位（`music888` 已用 `vdec_imdct_buf2` 线程本地，但 `async` 池仍风险），截断流靠 `HEAPTRC` 事后发现 | 实例 `FArena: TMemoryArena` 1 次 `GetMem` 复用全生命周期，`TryDecodeWhole` 截断永不泄漏，`test_codec_fuzz` 1k 随机 + `cmp` 位精确双门禁 |
| **完整性** | `vorbis comment` 各写一套，`Ogg` 容器已在 `miniflac` 但未路由到 `prOggVorbis` | 统一走 `nextpas.core.audio.codec.meta` 的 `TryParseID3v2/VorbisComment/RIFFInfo/MergeTags`，`container: OGG vs NATIVE` 在 `registry` 透出 |

---

## 3. 设计原则

1. **Oracle 不为 Source**：`music888` 的 `build/test_*` 与 117 帧 `lame` 流为金丝雀，先让新 `codec.*` 在 `nextpas.core.test/bench` 下绿了再动内核。
2. **契约先行，门面极薄**：`IAudioDecoder(0001)` 已冻结，不新增 GUID；`nextpas.core.audio.pas` 仅 `inline` 转发。
3. **L2 纯 Pascal，零 `ffi/vendor`**：`external 'c'` 清零，`vendor/minimp3` 不入 `vendors/`，已翻译体自包含。
4. **实时零分配**：`DecodeWhole` 可分配，`FillRealtime` 零分配（`Graph/Timeline` 已做 `FScratch` 复用，新 `codec.*` 的流式 `Fill` 同律）。

---

## 4. 架构与文件映射

```
nextpas.core.audio.codec.flac.pas       ← music888.flacdec.pas  重塑（miniflac 语义）
nextpas.core.audio.codec.flac.sse.pas   ← music888.flacdec.sse.pas 保留，手写 SIMD 核
nextpas.core.audio.codec.mp3.pas        ← music888.mp3dec.pas   重塑（minimp3 语义）
nextpas.core.audio.codec.mp3.sse.pas    ← music888.mp3dec.sse.pas 保留
nextpas.core.audio.codec.vorbis.pas     ← music888.vorbisdec.pas 重塑（stb_vorbis）
nextpas.core.audio.codec.vorbis.sse.pas ← music888.vorbisdec.sse.pas 保留
```

- `base → intf → codec.* → 门面`，与 `codec.wav/aiff` 同 `uses` 链，禁止回指 `music888.*`。
- `TMINIFLAC*/TMp3dec*/TStbVorbis` 巨 record 降为 `TFlacDecoder = class(TInterfacedObject, IAudioDecoder)` 的私有字段，对外不可见。
- `Probe` 统一：`function XProbe(const APrefix: TBytes): TAudioProbeResult`（`≤4KB` 前缀，`prFlac/prMp3/prOggVorbis` 已在 `TAudioProbeResult` 预留）。

---

## 5. 关键重塑点（胜于蓝的实现）

**5.1 位流与容器**
- `TMiniflacBitreaderS` → `nextpas.core.bytes.cursor.TBytesCursor` + `nextpas.core.io.scanner`，`Native/Ogg` 容器分支保留 `MINIFLAC_CONTAINER_*` 语义，但输入改为 `IStream.Read` 增量，支持网络流与 `SeekTable` 跳转。

**5.2 内存**
- `threadvar vdec_imdct_buf2/vdec_res_pc`（`vorbisdec`）与 `mp3dec` 的 `TMp3decScratchT` → 实例 `FArena: TMemoryArena`（`nextpas.core.mem`），`GetMem` 1 次，`FArena.Reset` 复用，`async` 安全。

**5.3 SIMD**
- `music888.*.sse` 的 `SSE 4 车道` 核保留，但分派从 `{$ifdef cpux86_64}` 编译期改为 `nextpas.core.simd.dispatch` 运行时：`x86_64: SSE2→AVX2`，`aarch64: NEON`，标量回退与 `C2P_NO_SIMD` 逃生开关同 `music888` 保持逐位一致。

**5.4 C 运行时清理**
- 删除 30+ `__c2p_stdlib_strlen/strcpy/qsort/atoi` 与 `external 'c' name 'memcpy'`，直用 `System.StrLen/Move/FillChar/Trunc`；`FlacSar32/64` 提升为 `nextpas.core.base.utils` 候选（已在 `miniflac` 侧验证 floor 语义）。

**5.5 标签归一**
- `flac` 的 `VorbisComment` 与 `mp3` 的 `ID3v2` 不各写一套，统一调 `nextpas.core.audio.codec.meta.TryParse*` + `MergeTags`，`picture/seektable/cuesheet` 透传 `TAudioTags.Extra`。

---

## 6. 接口冻结（不新增 GUID）

```pascal
// 每个 codec 仅 2 个门面 inline
function FlacProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateFlacDecoder: IAudioDecoder; inline;
function Mp3Probe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateMp3Decoder: IAudioDecoder; inline;
function VorbisProbe(const APrefix: TBytes): TAudioProbeResult; inline;
function CreateVorbisDecoder: IAudioDecoder; inline;

// IAudioDecoder 已有
IAudioDecoder = interface['{F1A2B3C4-D5E6-7890-ABCD-A00000000001}']
  function Probe(const APrefix: TBytes): TAudioProbeResult;
  function TryDecodeWhole(const AStream: IStream; out ABuffer: TAudioBuffer): Boolean;
  function CreateSource(const AStream: IStream): IAudioSource; // 流式，分帧 Fill
end;
```

---

## 7. 测试与基准（复用 music888 资产）

| 来源 | 去向 | 门禁 |
|---|---|---|
| `music888/tests/test_flac_probe` | `core/tests/nextpas.core.audio/test_flac` | 8/16/24-bit、全声道、`-0..-8`、`picture/seektable` 位精确 |
| `music888/tests/test_mp3dec` 的 `cmp` 流 | `test_mp3` 的 `TryDecodeWhole` 回归 | 117 帧 `lame` CBR 与 C 逐位一致 |
| `music888/tests/test_vorbisdec` | `test_vorbis` | `HEAPTRC` + `stb_vorbis` 已有 `ogg` 容器 |
| `music888/build/test_codec_fuzz` | `test_codec_fuzz` 1k 随机 | 截断/错包永不泄漏 |
| 新增 | `core/benchmarks/nextpas.core.audio/bench_flac` & `bench_mp3` | `bench` 框架 `ns/op` + `MB/s`，`-O2`，对照 `music888` 86-88% 基线 |

`check_source_contract.sh` 追加 6 文件到 23→29 列表，`vendor` 检查对新文件同样生效。

---

## 8. 落地步骤（8 步，单 lane 闭环）

1. `scripts/worktree-add.sh codex/core-audio-flac`（已建，`a6e582d52` 为 base）
2. `git format-patch` 萃取 `music888` 头注释（保留 0BSD + 位精确矩阵可追溯）
3. `sed` 重命名单元 + 删除 `nextpas.core.fs` 等业务 `uses`
4. `bytes.cursor / simd.dispatch / mem.arena` 重塑（胜于蓝核心）
5. `nextpas.core.audio.pas` 门面 + `codec.registry` 注册
6. `check_source_contract.sh` 29 文件扩展
7. `make -C core/tests/nextpas.core.audio/test_flac clean test` 等 3 门 + `bench` 基线
8. 单 commit 原子落盘，`git diff --check && make hygiene` 双过

---

## 9. 风险与回滚

- **回滚面小**：仅 `codec.flac/mp3/vorbis` 6 文件 + 1 门禁 + 1 门面，`base/intf` 不动。
- **风险**：`aarch64` 的 `ppcros/a64` 寄存器错译（`music888.mp3dec` 已在 `{$optimization off}` 规避）— 本 lane 在 `bench` 中以 `C2P_NO_SIMD` 标量 oracle 双轨验证。
- **不做**：`libFLAC/libmpg123` 的 `ffi` 兜底不入本 PR，保持纯 Pascal 承诺；`Opus` 留待 `vorbis` 后另起 lane。

---

> 本设计以 `music888` 为金丝雀，以 `nextpas.core` 原语为刻刀，产出比 `music888` 更快、更薄、更可插拔的 L2 codec 域。
