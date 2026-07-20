# process / fs / path / env — Windows 一眼表（M2 出口）

**状态**：M2-W1…W4 **Done**（2026-07-20）  
**truth**：下列证据为 `wine-runtime-smoke`（Win64 交叉编译 + Wine），**≠** 真 Windows host（那是 M3）。  
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

## 2. wine 最小生产集（硬清单）

一键复跑：

```bash
# 仓库根
bash core/tests/run_l2_wine_min_set.sh
```

| 套件 | 路径 | 期望 cases | 覆盖意图 |
|------|------|------------|----------|
| process | `core/tests/nextpas.core.process/test_process_wine` | **11** | echo/Capture/LookPath/timeout/MaxOutput/Status/Kill/**KillTree**/ExtraFd×/Cred× |
| fs | `…/fs/test_fs_wine` | **3** | Write-Read-Remove / MkdirAll / OpenLocked |
| fs.watch | `…/fs/test_fs_watch_wine` | **3** | create-close / poll timeout / create-event **or soft** |
| path | `…/path/test_path_wine` | **4** | Join-Clean / IsAbs-Volume / ToSlash / StripPrefix |
| os.env | `…/os.env/test_os_env_wine` | **3** | GetEnv / Set-Unset-Expand / Expand brace |
| **合计** | 5 目录 | **24** | 生产路径 smoke；非全量 Host 矩阵 |

**通过标准（M2 出口）**：五套件均绿、0 leak（heaptrc）。Watch create-event 允许 soft residual（打印说明，不 fail）。

**禁止**：把本表写成 `host-windows` production ready。

---

## 3. 支持矩阵（L2 契约摘要）

### process

| 能力 | Linux | Windows | 失败形态 |
|------|-------|---------|----------|
| Spawn / Wait / Capture / Status | Done | Done（wine） | raise |
| Timeout / MaxOutput / CancelToken | Done | Done | 语义同 Host |
| NewProcessGroup / KillTree | setpgid + kill(-pg) | **Job Object** | raise |
| ExtraFd | Done | **UNSUPPORTED** | Spawn 前 `EProcessError` |
| Credential | Done | **UNSUPPORTED** | Spawn 前 `EProcessError` |
| Signal（非 Kill） | Partial | Partial（Kill=Terminate） | 文档 |

### fs

| 能力 | Linux | Windows | 失败形态 |
|------|-------|---------|----------|
| Read/Write/MkdirAll/Remove/… | Done | Done（wine 子集） | raise |
| OpenLocked / Lock | flock | LockFileEx | busy→False / raise |
| ReadAt / WriteAt | Done | Done（L0 pread/pwrite） | raise |
| Chown | Done | **UNSUPPORTED** | 平台错误映射 |
| Watch Add/Poll | inotify | **RDCW S2** | soft on Wine |
| Watch AddTree 多目录 | Done | **Partial**（L0 目录槽有限；见 platform） | NOSPC / 文档 |

### path / env

| 能力 | Windows 备注 |
|------|----------------|
| path 分隔符 / Volume | `\` 与盘符；ToSlash 可移植 |
| env 大小写 | **不区分**（`EnvironmentVariableNamesCaseSensitive=false`） |
| Expand | 支持 `$VAR` / `${VAR}` / `%VAR%` |
| User*Dir | `%USERPROFILE%` / `%LOCALAPPDATA%` / `%APPDATA%` |

详细 INV：各模块 `CONTRACT.md`。

---

## 4. 与里程碑

| 波次 | 交付 | 状态 |
|------|------|------|
| M2-W1 | Watch S2 + L2 wine | Done |
| M2-W2 | Job Object + KillTree | Done |
| M2-W3 | ExtraFd/Cred 矩阵 fail-closed | Done |
| **M2-W4** | 本页 + 最小生产集脚本 + 文档对齐 | **Done** |
| M3 | 真 `host-windows` CI | 可选 / 开放 |

---

## 5. 变更

| 日期 | 说明 |
|------|------|
| 2026-07-20 | M2-W4：一眼表 + wine 最小生产集（24 cases / 5 suites） |
