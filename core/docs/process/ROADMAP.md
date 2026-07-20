# process / fs / path / env — 开发地图（终局有界）

**范围**：L2 `nextpas.core.{process,fs,path,os.env}`  
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`  
**对标口径**：能力 + 边界语义 + 测试强度，**不是**符号名复制  
**状态日期**：2026-07-20（**M2-W4 Done**）  
**相关**：[`WIN.md`](./WIN.md)（Windows 一眼表） · [`PARITY-go-rust.md`](./PARITY-go-rust.md) · [`SCORECARD.md`](./SCORECARD.md) · 各模块 `CONTRACT.md`

---

## 1. 一句话结论

| 问题 | 答案 |
|------|------|
| Host Linux Essential 做完了吗？ | **做完了**（M0） |
| 还要不要 R35、R36… 无限小刀？ | **不要**。默认 **Host Maintenance** |
| 剩下的「海」在哪？ | **Windows L0（platform）+ 可选真 CI**，用 **M2 Wave** 交付，有出口 |
| 分数还要刷到 10.0 吗？ | **不要**为 0.1 分开新轮 |

---

## 2. 北极星（Definition of Done）

| 层 | 完成标准 | 状态 |
|----|----------|------|
| **E0 Host Essential** | Linux Essential 矩阵无 Missing（有意 ≠ Go 须写清）；框架合规；SCORECARD 可复现 | **DONE（R34）** |
| **E1 Host Hardening** | INV 稳定；无已知 P0；wine-runtime-smoke 绿；同方法 bench | **DONE** |
| **E2 Windows usable** | 核心路径 Win 可用或正式 Partial/Out-of-scope；无「代码写 Done、实则 stub」 | **DONE（M2-W1…W4；truth=wine-runtime-smoke）** |
| **E3 CI host-windows** | 真 Windows runner；truth ≠ 仅 wine | **OPEN（可选/基础设施）** |

### Host Maintenance 定义（冻结）

> Host Linux 上 Essential 无 Missing；Quality ≥ 9.5；Scale Essential ≥ 9.5；无 P0。  
> **默认不再开 Rxx 能力/证据小刀**，除非：回归 / 安全 / 用户**明确**要求新 Essential 能力。

---

## 3. 现状（M0 出口清单）

### 3.1 结构

| 模块 | L2 | 文档 | 代表测试规模 |
|------|----|------|----------------|
| process | `process*.pas` | CONTRACT / PARITY / SCORECARD / WIN / 本 ROADMAP | 128 + 21 + 27 + 17 + wine **11** |
| fs | `fs*.pas`（含 watch） | CONTRACT / README | 158 + ifile 22 + watch 13 + wine **3+3** |
| path | `path.pas` + `fs.path` | CONTRACT / README | 70 + wine **4** |
| env | `os.env.pas` | CONTRACT / README | 70 + wine **3** |

依赖：仅 `platform.{process,files,path,env,watch}` + core 时间/IO/错误；**禁止**裸 FPC RTL（INV）。

### 3.2 Essential（Host = Done）

- **process**：Command / Spawn-Wait / Capture / Merge / Status / Env / LookPath / Timeout / MaxOutput / WaitGraceful / ExtraFd / Credential / CancelToken / NewProcessGroup+KillTree（Unix）
- **fs**：读写全文 / Temp / MkdirAll-RemoveAll / Walk / Symlink / Stat / 锁 / Watch+AddTree+Remove / HardLink / Chtimes / Chown / ReadAt-WriteAt / …
- **path / env**：Join-Clean-Rel-Match-… / Get-Set-Expand-Clear / User*Dir

**有意 ≠ Go（不算缺口）**：`Remove` ENOENT 静默成功；PathDir 门面 vs `FsPathDir` 双轨。

### 3.3 评分与证据（快照）

- Quality **9.9** / Scale **9.8** / 综合 **9.9**
- Capture ~1.3× Go；Status ~1.15×（spawn 级，**非必达**）
- wine **最小生产集**（M2-W4）：process **11** / fs **3** / path **4** / env **3** / watch **3**（合计 **24**）；`bash core/tests/run_l2_wine_min_set.sh`
- fs 同方法 64KB×200 / 1MB×20 见 SCORECARD

### 3.4 分层债（分轨）

| 轨 | 主责 | 内容 | L2 动作 |
|----|------|------|---------|
| A Host | 本模块 | 已完成 | **关闭** |
| B Win L0 | **platform** | Job Object；watch S2 RDCW poll；spawn 扩展 | 接线 + 测 + 文档 |
| C CI | 仓库/CI | 真 Windows runner | 登记，非独占 |
| D 永不做 | — | 无限 Rxx；符号级 SysUtils KPI；强制 1.0× Go | **禁止** |

---

## 4. 里程碑地图

```
M0 Host Essential Complete     ← 当前（R16–R34）
        │
        ▼
M1 Freeze + Governance         ← 本图落地即完成
        │
        ├──────────────────┐
        ▼                  ▼
M2 Windows Usable ✅      M3 CI host-windows（可选）
   W1 Watch S2 ✅
   W2 Job / KillTree ✅
   W3 Spawn 矩阵 ✅
   W4 文档与 wine 收敛 ✅
        │
        ▼
Host + Win(wine)：仅 Maintenance（bug/安全/M3）
```

### M0 — Host Essential Complete — **DONE**

出口已满足（见 §3）。**禁止**为刷分再开 R35+。

历史锚点（不必再读完整 R 日志）：R16 矩阵 → R21–24 能力 → R25–32 watch → R27–28 性能/框架 → R31–34 证据与 IFile。

### M1 — Freeze + Governance — **本交付**

| 交付 | 说明 |
|------|------|
| 本文件 | 总图 |
| PARITY / README | 状态 **Host Maintenance**；链到本文件 |
| 变更闸门 | 见 §5 |

出口：地图合 main；无标签需求默认不接。

### M2 — Windows Usable（有限 Wave，**有出口**）

依赖 platform；**L0 未就绪时 L2 不硬造假实现**。

| Wave | 名称 | L0（platform） | L2 | 出口 |
|------|------|----------------|-----|------|
| **W1** | Watch S2 | **DONE** platform S2 RDCW poll (`29ce1f815`) | L2 wine 加厚 poll timeout + create soft | platform 事件路径 + L2 smoke |
| **W2** | Process tree | **DONE** Job Object spawn+kill | KillTree/NewProcessGroup Win | wine KillTree 绿 |
| **W3** | Spawn 扩展 | **DONE** 矩阵 + fail-closed | ExtraFd/Cred Win 明文 raise | wine 11 绿 |
| **W4** | 收敛 | — | **DONE** [`WIN.md`](./WIN.md) + `run_l2_wine_min_set.sh` + 各 CONTRACT Win 节 | 一眼懂；24 cases 绿 |

**M2 出口（W4）**：核心路径无 stub 冒充 Done；UNSUPPORTED 明文；最小生产集可一键复跑；E2 声明完成（truth 仍 wine）。  
**M2 不做**：真 Windows CI（M3）；Unix 信号 100% 同构；Host 再开性能刀。

编号：**用 W1–W4**，不用 R35/R36/…

### M3 — CI host-windows（可选）

有 runner 才做；SCORECARD 增加 `host-windows` 标签。无 runner → 挂起，不阻塞 M1/M2 声明。

---

## 5. 治理（止漂）

### 5.1 需求标签（必选一）

| 标签 | 含义 |
|------|------|
| `bug` | 回归 / 正确性 |
| `win-l0` | platform 实现 |
| `win-l2` | L2 接线与契约 |
| `ci` | 真 Windows CI |
| `docs` | 仅文档 |

**无标签 / 纯「再 polish 一下」→ 默认拒绝。**

### 5.2 决策流

```
需求 → 标签 → 对照本 ROADMAP
     → Host Maintenance 且非 bug/安全 → 拒绝或 backlog
     → Win → 优先 platform Wave，L2 只接线
     → 合 main：cherry-pick + push 确认 origin 祖先
```

### 5.3 合 main 纪律

- 模块开发在 worktree；**不**直接在 main 堆大改  
- 合入用 cherry-pick；合后 **确认 `origin/main` 含提交**（防 reset 冲掉）

---

## 6. platform 边界

| 能力 | platform | L2 |
|------|----------|-----|
| watch S1/S2 | **主责** | 消费 + CONTRACT + 测 |
| Job Object | **主责** | KillTree 接线 |
| files/path/env | 已齐 | 纯语义层 |

阻塞在 L0 时：**等 platform**，不在 L2 拆无限小 PR 假装进度。

---

## 7. 明确永不做

| 项 | 原因 |
|----|------|
| 无限 Rxx 证据微调 | 无终点 |
| 以 FPC SysUtils 符号兼容为 KPI | 架构：仅 `nextpas.core.system` 可 RTL |
| Status/Capture 必须 1.0× Go | 收益递减 |
| L0 债伪装成无编号小刀 | 用 M2 Wave |

---

## 8. 文档索引

| 文档 | 用途 |
|------|------|
| **本 ROADMAP** | 终局、里程碑、治理 |
| [WIN.md](./WIN.md) | **Windows 一眼表 + 最小生产集** |
| [PARITY-go-rust.md](./PARITY-go-rust.md) | Essential 矩阵 + 评分快照 |
| [SCORECARD.md](./SCORECARD.md) | 可复现数字；truth 标签 |
| [CONTRACT.md](./CONTRACT.md) | process 契约 |
| [../fs/CONTRACT.md](../fs/CONTRACT.md) | fs 契约 |
| [../path/CONTRACT.md](../path/CONTRACT.md) | path 契约 |
| [../env/CONTRACT.md](../env/CONTRACT.md) | env 契约 |

---

## 9. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-20 | 初版：M0 完成声明；M1 冻结；M2 W1–W4；禁止无限 Rxx |
| 2026-07-20 | **M2-W1**：platform S2 已合入；L2 wine watch 证据加厚；勾选 W1 |
| 2026-07-20 | **M2-W2**：Win Job Object NewProcessGroup + KillTree；wine process 9 |
| 2026-07-20 | **M2-W3**：Win ExtraFd/Credential fail-closed 矩阵；wine process 11 |
| 2026-07-20 | **M2-W4**：WIN.md + wine 最小生产集 24 + 文档对齐；**E2 Done**（wine truth） |
