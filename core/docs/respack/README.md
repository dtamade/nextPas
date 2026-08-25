# nextpas.core.respack

L2 资源打包格式模块。把一棵文件树打包成单个带索引的二进制 blob（pack），支持
零拷贝随机读取，是前端资源嵌入程序/动态库场景的格式层。

**状态：S1 格式层 + S2 解析/打包/目录收集已实现并有 gate 覆盖**
（`base`/`writer`/`reader`/`dirsource`/门面，五个测试 gate 全绿、heaptrc 零泄漏）。
`vfs.embedded` 接入（S3）、嵌入工具链（S4）、http.static 对接（S5）未开始。
计划见 [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../../docs/plans/2026-08-25-respack-vfs-modules-plan.md)。

## 模块定位

- **拥有**：pack 二进制格式 v1 的唯一定义（线格式见 [FORMAT.md](FORMAT.md)）、
  打包器（writer）、解析器（reader）。
- **不拥有**：文件树的抽象视图（归 `nextpas.core.vfs`）、真实文件系统访问
  （归 `nextpas.core.fs`）、嵌入载体决策（构建工具层）。
- **对标**：游戏引擎 `.pak`、Electron `asar`、Qt Resource System 的格式部分。

### 为什么和 vfs 分开

| | respack | vfs |
|---|---|---|
| 回答的问题 | 字节怎么排、怎么校验、怎么找 | 树怎么抽象、后端怎么换 |
| 依赖 | 仅 L0（base/errors） | L0-L1（含 io 流词汇） |
| 单独可用性 | 编译器构建工具、安装器可直接用 | 必须有后端才有内容 |

respack 刻意做成纯格式模块：编译器自身的资源打包、离线工具都能用它，
不需要拖进 vfs 抽象。

## 目标使用形态（未实现，设计签名）

```pascal
uses nextpas.core.respack;

// 读：blob 可以来自 const 数组、堆缓冲、mmap 文件 —— 一律 (指针, 长度)
var
  RP: TResPack;
begin
  RP := ResPackOpen(@EmbeddedAssetBlob[0], Length(EmbeddedAssetBlob));
  try
    if RP.Find('index.html', Entry) then
      // Entry.DataOffset / Entry.Size 直接指向 blob 内切片，零拷贝
      CopyOut(Blob[Entry.DataOffset], Entry.Size);
  finally
    RP.Close;
  end;
end;

// 写：条目列表进，单个 blob 出
var Pack := ResPackBuild(Entries);   // 排序、去重、对齐、写索引
```

## 架构

```
nextpas.core.respack.pas           ← 门面：re-export + Open/Build inline 转发
nextpas.core.respack.base.pas      ← TResPackHeader/TResPackEntry record、常量、错误
nextpas.core.respack.reader.pas    ← 校验 + 索引二分查找（只读，无分配热路径）
nextpas.core.respack.writer.pas    ← 条目列表 → blob（排序/去重/对齐/索引生成）
nextpas.core.respack.dirsource.pas ← 从 nextpas.core.fs 目录枚举条目（唯一引 fs 的单元）
```

依赖方向：`base ← reader/writer ← dirsource ← 门面`。

### 依赖白名单

| 单元 | 允许依赖 | 说明 |
|------|----------|------|
| `base` | L0（`base`/`errors`） | 纯类型与常量 |
| `reader` | `base` | 无堆分配查找路径 |
| `writer` | `base` | 纯内存构造 |
| `dirsource` | `writer` + `nextpas.core.fs` | **唯一的 L2→L2 seam**，与 fs→path seam 同性质，registry 记录 |

`reader`/`writer` 不依赖 fs/bytes/io：输入输出一律 `(PByte, SizeUInt)` 或调用方提供的
目标缓冲，保持格式层可被任何宿主复用。

### 完整性双档

对标 asar（每文件 SHA-256 全量+分块）与 Tauri（CSP 哈希注入）后的分层决策：

| 档 | 算法 | 用途 | 成本 |
|----|------|------|------|
| 条目 hash | FNV-1a 32，内联实现于 `base` | HTTP ETag、去重候选键 | 近零 |
| digest 区（可选） | **不透明 32 字节**，算法由调用方注入（典型 SHA-256） | 供应链完整性、发布审计 | 打包期一次 |

digest 算法不进格式的理由：SHA-256 属 L2 hash/crypto 域，而本模块仅依赖 L0——
writer 经注入的摘要函数生产摘要，校验助手放消费侧 hash 模块。分块哈希
（asar blockSize/blocks 对等物）推迟至有部分校验真实需求。

### 内容去重与压缩槽位

- **内容去重**：writer 可选开关；fnv32 候选 + 字节级回验后才复用槽位（同 asar 策略，
  杜绝碰撞错误共享）。适合 node_modules 式重复内容的依赖树打包
- **codecId 槽位**：条目级编码标识，v1 只定义 `0=store`。压缩不进 v1 是有意决策：
  Tauri brotli 读时解压需分配、破坏零拷贝；HTTP 内容编码归 http.static。
  未来 zstd/brotli 经 compress 模块 seam 走登记表立项

逐项对标证据见 [PARITY-go-rust.md](PARITY-go-rust.md)。

## 嵌入载体

writer 产出的 blob 如何进入程序，由构建侧选择：

| 载体 | 机制 | 适用 | 实现阶段 |
|------|------|------|----------|
| 独立 `.pack` 文件 | 随程序分发，运行时整体读入或 mmap | 大包、需热更新 | S1 起 |
| 生成 `.inc` typed const | 工具把 blob 转成 Pascal 常量数组编入 | 中小包（经验值 < 4MB），跨平台零工具链要求 | S4 |
| `{$R}` 资源链接 | fcl-res 跨平台链入，`TResourceStream` 取回 | 编译速度敏感 | 文档记录，按需实现 |

`.inc` 生成器放在工具侧（S4），不在本模块运行时单元里。

## 测试计划

```bash
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_roundtrip
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_reader    # 含损坏输入拒绝
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_writer    # 排序/去重/对齐/golden
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_dirsource
```

- round-trip：目录样例 → build → open → 逐字节比对全部条目
- reader：FORMAT.md 校验清单每条规则至少一个拒绝用例（magic/version/越界/未知
  codecId/路径不规范/截断/digest 边界）
- writer：乱序输入自动排序、重复路径报错、对齐断言、golden 字节快照、
  去重开启时碰撞回验与共享槽位断言、digest 区内容与注入函数一致
- 全部 gate 要求 heaptrc 零泄漏

## 设计决策记录

| 决策 | 理由 |
|------|------|
| 纯格式模块，仅依赖 L0 | 工具链/安装器可复用；格式层不该背 IO 抽象 |
| reader 输入是 `(指针,长度)` 而非接口 | 同一 API 覆盖 const 数组/堆/mmap 三种来源，零适配 |
| FNV-1a 内联而非依赖 checksum | 六行算法不值得建 seam；与仓库算法选型一致 |
| digest 区存不透明摘要、算法注入 | SHA-256 属 hash 域；格式零加密依赖（对标 asar integrity 的依赖倒置版） |
| 目录隐式表达，不存目录条目 | 省空间；List 由路径前缀推导 |
| modTime 秒级精度 | 主要消费者是 HTTP If-Modified-Since，本身就是秒粒度 |
| dirsource 是唯一 fs 引用点 | 把 L2→L2 依赖压缩到一个可审计单元 |
| 路径语法全盘采纳 Go ValidPath | 业界事实标准，含 `.` 根特例与反斜杠规则 |
| 压缩只留 codecId 槽位 | Tauri brotli 读时分配破坏零拷贝；HTTP 编码归 http.static |

### 实现期发现的 FPC trunk 注意事项（S1/S2 实测，后续模块同样适用）

| 陷阱 | 症状 | 规避 |
|------|------|------|
| 常量标识符实参 + inline 函数的 u64 参数 | 常量传播把函数体按 32 位折叠（`shr 32` 后 high:=low），写出 `0x0000002800000028` 类错值 | u64 写入一律显式 `UInt64(常量)`；见 writer 内注释 |
| `Pos('', S)` 返回值 | FPC 返回 0（Delphi 语义为 1），`Pos(Prefix,S)=1` 式前缀判断对空前缀全错 | 前缀判断用显式 `StartsWith` 助手，空前缀恒真 |
| `for I := 0 to N - 1 do`（N: SizeUInt） | N=0 时上界回绕为 `$FFFFFFFF`，循环体以垃圾下标执行 → AV/总线错误 | 循环前守卫 `N > 0`，或改 `while I < N`；Hoare 分区类算法下标一律 Int64 |

## FPC RTL 隔离与反哺

项目规范：`nextpas.core.*` 不直接依赖 FPC RTL；缺口通过反哺 nextpas.core 解决。

### 本模块 uses 白名单（source-contract 锁定）

| 允许 | 禁止 |
|------|------|
| `nextpas.core.settings.inc` | `SysUtils`、`Classes` |
| `nextpas.core.base` | `Windows`、`BaseUnix`、`Unix` 及一切 OS 单元 |
| `nextpas.core.errors` / `exception`（经根模块桥接） | 任何其他 FPC RTL 单元 |

- 异常类型继承 `nextpas.core.exception.Exception`。异常词汇的桥接点收敛在 exception
  根模块（FPC 下桥接、nextPas 编译器下原生实现）；仓库对 FPC RTL 直引的整体豁免面
  见 fs CONTRACT INV-7（仅 system 根门面等治理特例），本模块不在豁免面内——
  本模块的 `EResPack*` 异常只认 exception 根
- source-contract 测试逐单元断言 uses 清单，违例即红。**复用既有门禁机制**
  `core/tests/fpc_rtl_uses_scan.inc`（test_fs 已在用），不自造扫描器

### 反哺触发点（当前已知）

| 缺口 | 反哺去向 | 状态 |
|------|----------|------|
| 大 blob 内存映射读取 | platform/mem（文件映射 owner） | v1 不做 mmap；有需求时反哺立项，不在本模块内私调 OS API |
| BE 平台换序 | `platform.endian` inquiry（已有） | 直接使用 |

## 与既有模块的关系

| 模块 | 边界 |
|------|------|
| `nextpas.core.zip`（已存在，store 写端） | **定位互补不重叠**：zip 是"外部工具可读的交换容器"（unzip/python/Go 可直接解）；respack 是"程序附着的运行时容器"（16 字节对齐、const 数组嵌入、header-first 递进校验、零拷贝切片）。两者共享同一套规范路径纪律（zip 单元已拒绝 zip-slip 形态，与本模块 ValidPath 语法同源） |
| `nextpas.core.compress` | v1 无接触；未来压缩编解码经 codecId 登记表 + compress seam 立项 |
| `checksum.fnv32` | 算法选型一致但内联实现（六行不值得建 seam），见设计决策记录 |

## 可抽取存量盘点（2026-08-25 实查）

- `core/src/nextpas.core.bench.report.*.inc` 是 `{$I}` **代码拆分**先例，不是数据嵌入；
  本模块 S4 的 `.inc` 数据载体生成器是新能力，不与之混淆
- compiler/toolchain 的 `ResourceToolProfileId` 是目标平台资源工具（windres 类）的
  工具链档案，与资产嵌入无关，不抽取
- compiler/tools 中不存在虚拟 FS 或打包存量代码可抽取

## 关联文档

- [CONTRACT.md](CONTRACT.md) — 代码契约：不变量、错误表、线程安全、性能契约
- [FORMAT.md](FORMAT.md) — 线格式 v1 权威定义（字节布局、校验规则、扩展策略）
- [PARITY-go-rust.md](PARITY-go-rust.md) — asar/Tauri/rust-embed/include_dir/Go embed 对标矩阵与来源
- [`core/docs/vfs/README.md`](../vfs/README.md) — 消费本格式的树视图模块
- [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../../docs/plans/2026-08-25-respack-vfs-modules-plan.md) — 实施计划
