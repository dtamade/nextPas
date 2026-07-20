# process / fs / path / env — Windows 一眼表（M2+M3 出口）

**状态**：M2-W1…W4 **Done** · **M3 host-windows CI gate Done**（2026-07-20）  
**truth 分层**：

| 标签 | 含义 |
|------|------|
| `wine-runtime-smoke` | Win64 交叉 + Wine（本地/Linux CI） |
| `host-windows` | 真 Windows runner 上 native `make test`（GHA `windows-latest`） |

**总图**：[ROADMAP.md](./ROADMAP.md) · **证据**：[SCORECARD.md](./SCORECARD.md)

---

## 1. 一句话

| 模块 | Windows 结论 |
|------|----------------|
| **process** | Spawn/Wait/Capture/Status/Timeout/MaxOutput/Kill/**KillTree(Job)** 可用；**ExtraFd / Credential** 明文 fail-closed |
| **fs** | 读写/目录/OpenLocked 可用；**Chown** UNSUPPORTED；Watch **S2** poll（Wine 事件 soft） |
| **path** | Join/Clean/IsAbs/Volume/ToSlash/StripPrefix 可用 |
| **os.env** | Get/Set/Unset/Expand（含 `%VAR%`）可用 |

---

## 2. 最小生产集（硬清单）

### 2.1 wine（本地 / Linux）

```bash
bash core/tests/run_l2_wine_min_set.sh
```

| 套件 | 路径 | 期望 cases |
|------|------|------------|
| process | `…/test_process_wine` | **11** |
| fs | `…/test_fs_wine` | **3** |
| fs.watch | `…/test_fs_watch_wine` | **3** |
| path | `…/test_path_wine` | **4** |
| os.env | `…/test_os_env_wine` | **3** |
| **合计** | 5 目录 | **24** |

### 2.2 host-windows（真 Windows CI · M3）

```bash
# 在 Windows 主机 / GHA windows-latest（cwd 可为 core/）
bash core/scripts/l2-windows-ci-matrix.sh
```

同一 5 目录，目标为 native **`make clean test`**（非 `wine-runtime-smoke`）。  
CI 接线：`.github/workflows/core-ci.yml` → job `test-windows-runtime` → step  
`L2 process/fs/path/env Windows min-set (host-windows)`（**`if: always()`**，与 platform 矩阵失败解耦，同 Q34 async 模式）。

**通过标准**：五套件均绿。Watch create-event 仍允许 soft residual（与 wine 套件相同逻辑）。

**禁止**：把 wine 结果改写成 `host-windows`；把 min-set 说成「全量 L2 Windows 测试」。

---

## 3. 支持矩阵（L2 契约摘要）

### process

| 能力 | Linux | Windows | 失败形态 |
|------|-------|---------|----------|
| Spawn / Wait / Capture / Status | Done | Done | raise |
| Timeout / MaxOutput / CancelToken | Done | Done | 语义同 Host |
| NewProcessGroup / KillTree | setpgid + kill(-pg) | **Job Object** | raise |
| ExtraFd | Done | **UNSUPPORTED** | Spawn 前 `EProcessError` |
| Credential | Done | **UNSUPPORTED** | Spawn 前 `EProcessError` |
| Signal（非 Kill） | Partial | Partial（Kill=Terminate） | 文档 |

### fs

| 能力 | Linux | Windows | 失败形态 |
|------|-------|---------|----------|
| Read/Write/MkdirAll/Remove/… | Done | Done（min-set 子集） | raise |
| OpenLocked / Lock | flock | LockFileEx | busy→False / raise |
| ReadAt / WriteAt | Done | Done（L0） | raise |
| Chown | Done | **UNSUPPORTED** | 平台错误映射 |
| Watch Add/Poll | inotify | **RDCW S2** | soft on Wine |
| Watch AddTree 多目录 | Done | Partial | NOSPC / 文档 |

### path / env

| 能力 | Windows 备注 |
|------|----------------|
| path 分隔符 / Volume | `\` 与盘符；ToSlash 可移植 |
| env 大小写 | **不区分** |
| Expand | `$VAR` / `${VAR}` / `%VAR%` |
| User*Dir | `%USERPROFILE%` / `%LOCALAPPDATA%` / `%APPDATA%` |

详细 INV：各模块 `CONTRACT.md`。

---

## 4. 与里程碑

| 波次 | 交付 | 状态 |
|------|------|------|
| M2-W1…W4 | Watch / Job / fail-closed / 文档 | Done |
| **M3** | `l2-windows-ci-matrix` + core-ci 步骤 | **Done** |

---

## 5. 变更

| 日期 | 说明 |
|------|------|
| 2026-07-20 | M2-W4：一眼表 + wine 最小生产集（24） |
| 2026-07-20 | M3：host-windows 门禁脚本 + GHA 接线 |
| 2026-07-20 | M3-ci：L2 步与 platform 矩阵解耦（always + install-fpc success） |
