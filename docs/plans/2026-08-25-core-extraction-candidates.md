# core 抽取候选盘点（来自 ~/projects 项目群）

日期：2026-08-25
性质：候选分析，供总控决策立项顺序；未含任何代码改动。
方法：以"多个项目重复实现同一通用能力"为筛选标准，逐项目扫描 uses/依赖清单。

## 候选清单（按证据强度排序）

| 候选 | 层级 | 证据来源 | 现状缺口 | 备注 |
|---|---|---|---|---|
| `cheader`（C 头文件→Pascal 单元翻译器） | tooling | `c2pas888` 手工转译 SQLite3 全过程；core 数十个手写 `*.ffi.pas`；`platform-ffi-import-workflow.md` | 完全空白 | 服务编译器自举叙事；纯 parser+emitter，L0-L1 依赖 |
| `tui.graphics`（sixel/kitty/iTerm2 内联图） | L3 | `term888/docs/TERMINAL_COMPAT.md`、borrow-wezterm-ghostty 文档 | tui 有 canvas 无图片上屏 | 与 image 解码扩展联动立项 |
| `image` 扩展（jpeg/gif/webp/bmp） | L2 | castle-engine 参照；tui.graphics 前置依赖 | 仅 PNG | 建议与 tui.graphics 同评审 |
| `audio.codec`（mp3/flac/ogg→PCM） | L2 | `go-musicfox` go.mod 解码依赖群、`music888`、`nes888` APU 输出 | audio 仅 pcm_wav 容器 | 复用 compress.lz4 的 native+ffi 双路径范式 |
| `compress.tar` + zstd 后端 | L2 | fpcupdeluxe downloader 装 FPC/Lazarus 全 tar 系；Docker/sing-box 生态 | 有 gzip/lz4/zlib 无 tar/zstd | tar 纯流式近零成本；zstd 照抄 lz4 双实现模式 |
| `diff`（Myers/patience + unified 编解码） | L1 | `tui.widget.diffview` 渲染端已存在；git 模块绑 libgit2 | 无公开算法模块 | 纯算法零依赖，最小切片 |
| `mail.imap`/`pop3` 收信客户端 | L3 | hotmails/outlook-pool 邮箱池业务结构性需求 | 发信侧齐全、收信仅 graph | 直连证据中等，置信度中 |
| `net.fetch`（断点续传+镜像+校验和下载器） | L3 | `fpcupdeluxe/source/downloader` 整目录 | http client 有、无高层下载编排 | 新识别；多镜像 failover+Range 续传+sha256 校验是可复用核心 |

## 已评估暂缓（避免重复讨论）

db.redis（归口 db lane 进行中）、scheduler/resilience/metrics/spreadsheet/markdown
等首批清单——总控此前表示暂不感兴趣，本表不再展开；webcore 的
circuit_breaker/metrics/job_queue 反哺 event(draft) 的路径仍有效。

## 建议

1. 下一个模块切片优先 `compress.tar`：成本最低、消费者明确（git.native 未来
   clone 落包、fpcupdeluxe 类工具链），且完全复用现有 io/compress owner。
2. `cheader` 单独立项前先做一次 c2pas888 findings.md 的系统审计，
   把手工踩过的坑清单转成解析器的测试用例集。
3. 任何立项走标准流程：registry 登记 → docs/<module>/ goal-tree →
   专属 worktree lane。

## 与 git.native 借鉴工作流的关系

`~/projects/libgit2` 参考借鉴模式（只读参考 + 格式对照 + 黄金互操作测试）
已验证有效，可直接套用到上述任何候选项的立项执行中。
