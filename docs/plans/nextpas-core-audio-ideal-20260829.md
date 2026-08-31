# Plan: nextpas.core.audio 理想态彻底交付 — 播放器→游戏→工作室全能闭环

## Goal kind
code-change

## Acceptance criteria
1. **模块化与分层** — `core/src/nextpas.core.audio.*` 45 文件（见清单）在 `{$mode ObjFPC}{$H+}` 下通过；`audio.pas` 仅 `type` 别名 + `inline` 转发零逻辑；`TAudioEncodeOptions` 声明于 `IAudioDecoder(0001)` 之前；GUID 冻结 `0010 Source / 0011 RealtimeSource / 0020 Resampler / 0021 Converter / 0030 Processor / 0040 Device / 0041 Provider / 0042 Graph / 0043 Player / 0050 Game / 0060 Timeline / 0070 Studio / 0080 Playlist` 全在；L2 只依赖 `L0-L1`（`base/errors/platform/mem/log.intf → bytes/text/collections/sync/async`），禁止 `Windows/BaseUnix/Unix` 直调与 `ffi/vendor/miniaudio`，双编译器靠 `units/<target>/` stub 桥接
2. **Worktree 纪律** — 本任务全程在 `.worktrees/core-audio-studio` 分支 `codex/core-audio-studio` 执行；`main` 仅总控 landing；一 worktree 只负责一模块；跨模块改动需说明原因/范围/风险/验证；合并前 `worktree clean` + `focused verification` + `git diff --check` + `make hygiene` 全过；禁止 raw merge 长期 lane 到 main
3. **编解码器齐全** — `audio.codec.*` 13 文件交付：`codec.intf/wav/aiff/meta/registry` + `flac(.sse/.decoder)/mp3(.sse/.decoder)/vorbis(.sse/.decoder)` 5 解码器（WAV/AIFF/FLAC/MP3/Ogg Vorbis）+ `pcm(+pcm.simd)/pcm_wav`，`Probe≤4096` 经 `IByteCursor/NewByteCursor`，`IAudioDecoder(Probe/DecodeWhole(IStream)/DecodeBytes/OpenStreaming→IRealtimeAudioSource/Tags)` 全接口，`ALAC/WavPack/Opus/AAC/M4A/CAF` 本 Goal 仅 Probe 透传 `prUnknown` 不写假 Decoder
4. **其他子模块齐全** — `resample/sinc/mix/dsp.filters/dsp.dynamics/dsp.fft/device.intf/device.null/graph.intf/graph/player/game.intf/game/timeline.intf/timeline/simd` 20 文件，按 `base←intf←实现←门面` 四件套交付
5. **全能能力** — `playlist/queue/tags` (Gapless/Crossfade) + `spatial/bus/bank` (3D/HRTF/四总线/.npack) + `studio(.intf/.project/.sequencer/.pianoroll/.automation/.effects/.render)` (Project/BPM/Quantize/MidiNote/Hermite/Effects Rack/离线 Render) 8 文件，全部复用 `TAudioBuffer(sfF32)+Graph/Timeline` 货币，不另起音频核心
6. **性能与复用** — 热路径稳态零分配（`FOutCap FileLen*11/5` + `FScratch/ScratchMix` 复用）、`pcm.simd` 块核 `I32/S16 1 CALL/N`（Linux hand-assembler + Windows intrinsics inline）与 `mix/timeline 4-wide simd_loadu/mul/add/storeu` 直连 `simd.dispatch` 运行时 `SSE2→AVX2/NEON`，`PcmClampF32` 复用，基准 `nextpas.core.bench IBenchContext` 输出 `ns/op`
7. **稳定性与高级感** — `EAudioError(EIOError)→Decode/Encode/Device/Graph/Timeline` 分层，默认抛异常、`TryXxx` 仅分支时提供；`EnsureArena/FArena` 1 次 GetMem 复用、`InterlockedExchangeAdd64` 计数；`audio.intf` 冻结 `实时路径仅调 FillRealtime` 双平面纪律（FillRealtime 禁 GetMem/锁/IO/异常），`Timeline/Graph/Device` 快照化注释与 `README.md Draft v3` 一致；全量 20 门 `HEAPTRC OK`
8. **完整性与超越** — PR1 base → PR2 wav → PR3 aiff/meta/registry → PR4 flac/mp3/vorbis（ELEVATION 8 步青出于蓝）→ PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 game → PR9 timeline → PR10-16 全能，`taskset -c 3` 同 fixture `FNV-1a64` 对拍 `FLAC 1.13x / MP3 1.45x` 已达标，`scripts/sync-music888-audio.sh` 周检无漂移

## Verification plan
1. **16+4 门全绿** — `for g in test_base test_pcm_wav test_wav test_aiff test_meta test_registry test_resample test_mix test_dsp test_device test_graph test_game test_timeline test_flac test_mp3 test_vorbis test_playlist test_spatial test_studio test_automation; do make -C core/tests/nextpas.core.audio/$g clean test; done` 断言 `21+12+16+11+11+9+14+14+14+15+16+15+16+8+6+6+8+6+16+8` 全绿且 `HEAPTRC OK`，输出至 `{SCRATCH}/audio-tests.log`
2. **门禁+卫生** — `bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh`（37→45 文件 `no ffi/vendor` + 12 GUID + 纪律 PASSED）与 `make hygiene`（`scripts/build-hygiene-check.sh` 禁 `.o/.ppu/.a/.exe/link*.res`）及 `git diff --check`，输出至 `{SCRATCH}/contract-hygiene.log` + `grep -R FillRealtime core/src/nextpas.core.audio.intf.pas` + `grep -R IByteCursor core/src/nextpas.core.audio.codec.*.decoder.pas` 结构探查
3. **基准 ns/op** — `make -C core/benchmarks/nextpas.core.audio/bench_pcm_wav clean test && bench_flac clean test && bench_mp3 clean test && bench_mix clean test && bench_studio clean test` 均含 `ns/op/Median/P95/Throughput`，落盘 `{SCRATCH}/bench.log`（不可用则 `{SCRATCH}/bench-unavailable.log` 附环境证据）
4. **3 路对拍** — `taskset -c 3 bash core/benchmarks/nextpas.core.audio/bench_compare/run_3way.sh`（nextpas vs music888 vs C 同 fixture）→ `{SCRATCH}/bench-3way.log`
5. **Worktree 审计** — `git status --short --branch; git worktree list --porcelain; scripts/worktree-audit.sh` 确认仅本 worktree 有改动且 clean

## Non-goals
- `ffi/miniaudio/libmpg123` 兜底、外置 VST 宿主、跨平台真机声卡主观评测
- 编解码在 `ALAC/WavPack/Opus/AAC/M4A/CAF` 上的真实现（本 Goal 仅透传，另起 Goal）
- 无基准支撑的强制 AVX2 重写

## Assumed scope
`core/src/nextpas.core.audio.*`、`core/docs/audio/*`、`core/tests/nextpas.core.audio/*`、`core/benchmarks/nextpas.core.audio/*`、`scripts/build-hygiene-check.sh`、`units/<target>/` stub、`.worktrees/core-audio-studio`

## Implementation approach
沿 `base←intf←实现←门面` 与 L0-L3 分层、在 `codex/core-audio-studio` 单 lane 按 `PR1→PR9→PR10(playlist)→PR11(spatial/bus/bank)→PR12(studio骨架)→PR13(sequencer/pianoroll)→PR14(automation)→PR15(effects)→PR16(render)` 增量叠加：播放器复用 Graph、游戏复用 Timeline 总线、工作室复用 Timeline+Sequencer+Automation，三者在 FillRealtime 同源；`music888` 为 Oracle 金丝雀，以 `nextpas.core` 原语（bytes.cursor/mem.arena/simd.dispatch）重塑，不 verbatim 拷贝

## Task checklist
- [ ] 审计 16 门与 contract/hygiene 差距，出具短板清单
- [ ] 补齐门面转发与 L2 边界（清 ffi/vendor/Windows，补 stub）
- [ ] 热路径零分配收口（PCM/Probe/Mix/FillRealtime/DecodeWhole）+ 小范围标量用例
- [ ] 扩展 EAudioError/TryXxx/资源释放边界用例，HEAPTRC 零泄漏
- [ ] 跑通 20 门 + contract(45 文件) + hygiene + diff --check
- [ ] 跑通 5 基准 ns/op + taskset 3way 对拍，落盘 SCRATCH
- [ ] `bash scripts/sync-music888-audio.sh` 周检留痕
- [ ] 同步 README 与门禁注释，保持高级感一致

## Risks / Contradictions
- “追求完美”无上界，以本 Plan 6 项验收 + 5 步验证为唯一收敛判据，防蔓延
- FPC 3.3.1 -O3 错译：bench 固定 `-O3 -Xs`，源码层加固为准
- 多 AI 并行：严格 Worktree 纪律，`main` 仅 landing，禁止跨 worktree 污染
