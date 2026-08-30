# nextpas.core.respack

L2 资源打包格式模块。把一棵文件树打包成单个带索引的二进制 blob（pack），支持
零拷贝随机读取，是前端资源嵌入程序/动态库场景的格式层。

**状态：S1-S5 已实现并有 gate 覆盖**
（`base`/`writer`/`reader`/`dirsource`/`embed`/门面；六个测试 gate 全绿、heaptrc
零泄漏；writer 含 golden 逐字节快照门禁，roundtrip 含 10k 条目 perf smoke；
embed 含 .inc 文本确定性 golden 门禁与 extract roundtrip 门禁；合计 **6 门**，vfs 侧 6 门，**12 门**闭环）。
嵌入工具链（S4）已落地：`nextpas.core.respack.embed` 单元 + `rp_pack` CLI；
http.static 对接（S5）已落地：`ServeVfs(AFs)` 让 embedded 后端直接服务 HTTP
（ETag 取条目 fnv32、条件请求/Range/MIME 与 fs 版同语义），端到端示例见
`core/examples/nextpas.core.http/http_static_vfs_demo/`。
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
nextpas.core.respack.dirsource.pas ← 目录枚举（输入）+ 解包落盘（输出），唯一引 fs 的 seam 单元
nextpas.core.respack.embed.pas     ← 嵌入工具链库：glob 过滤/prefix 映射/.inc 生成（S4）
```

依赖方向：`base ← reader/writer ← dirsource/embed ← 门面`。

### 依赖白名单

| 单元 | 允许依赖 | 说明 |
|------|----------|------|
| `base` | L0（`base`/`errors`） | 纯类型与常量 |
| `reader` | `base` | 无堆分配查找路径 |
| `writer` | `base` | 纯内存构造 |
| `dirsource` | `writer`/`reader` + `nextpas.core.fs` | **唯一的 L2→L2 IO seam**：目录枚举与 extract 落盘都收口在此，registry 记录 |
| `embed` | `writer`/`dirsource` + `nextpas.core.fs.glob` | 工具链库；仅允许 fs.glob（纯字符串匹配、无 IO），源契约门禁单列断言 |

`reader`/`writer`/`embed` 不依赖 fs/io：blob 输入输出一律 `(PByte, SizeUInt)` 或调用方提供的
目标缓冲，保持格式层可被任何宿主复用。

### 完整性双档

对标 asar（每文件 SHA-256 全量+分块）与 Tauri（CSP 哈希注入）后的分层决策：

| 档 | 算法 | 用途 | 成本 |
|----|------|------|------|
| 条目 hash | FNV-1a 32，内联实现于 `base` | HTTP ETag、去重候选键 | 近零 |
| digest 区（可选） | **不透明 32 字节**，算法由调用方注入（典型 SHA-256，header flags bit2-4 预留算法 ID，v1 仅 0=SHA-256） | 供应链完整性、发布审计 | 打包期一次 |

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

## 嵌入载体与嵌入工具链（S4 已落地）

writer 产出的 blob 如何进入程序，由构建侧选择：

| 载体 | 机制 | 适用 | 实现阶段 |
|------|------|------|----------|
| 独立 `.pack` 文件 | 随程序分发，运行时整体读入或 mmap | 大包、需热更新 | S1 起 |
| 生成 `.inc`/单元 typed const | `rp_pack inc` 把 blob 转成 Pascal 常量编入 | 中小包，跨平台零运行时工具要求 | **S4** |
| `{$R}` 资源链接 | fcl-res 跨平台链入，`TResourceStream` 取回 | 编译速度敏感 | 文档记录，按需实现 |

### 工具链构成

- **库（格式逻辑全部在此）**：`nextpas.core.respack.embed`
  - `ResPackEmbedBuild(SourceDir, TResPackEmbedOptions): TResPackBlob`
    —— 处理管线：相对路径 → StripPrefix 剥离（不匹配即剔除）→ glob
    include/exclude（对剥离后路径匹配；`*` 不跨 `/`、跨层级用 `**/`）→
    AddPrefix 拼接 → ValidPath 校验。过滤后 0 条目显式报错（空包几乎总是
    glob 写错），绝不静默产出。
  - `ResPackEmbedIncSource / ResPackEmbedIncUnitSource`：blob → Pascal 源文本
    （snippet 或完整单元形态）。确定性输出，由 test_respack_embed golden 门禁
    逐字节锁定。
  - 解包落盘 `ResPackExtractToDir(blob, dir)` 在 dirsource（唯一 IO seam 单元），
    对标 include_dir extract / asar unpack-dir 的调试迁移用途。
- **CLI 薄壳**：`core/tools/respack/rp_pack.lpr`（`make -C core/tools/respack build`）
  ```
  rp_pack build   --src DIR --out F.pack [--include GLOB]... [--exclude GLOB]...
                  [--strip-prefix P/] [--add-prefix P/] [--dedup] [--no-hash]
                  [--digest sha256]
  rp_pack inc     --src DIR (--const NAME | --unit NAME) --out F.pas [同上过滤项]
  rp_pack extract --pack F.pack --out DIR
  rp_pack list    --pack F.pack
  ```

### 载体实测数据（2026-08-26，本仓库 worktree 主机，fpc trunk -O2）

| 维度 | typed const 编入 | `.pack` 文件随程序分发 |
|------|------------------|------------------------|
| fpc 编译耗时（2MB 资产，200 文件） | ≈2.4 s | ≈0.29 s |
| fpc 编译耗时（4MB） | ≈4.4 s（≈1.1 s/MB 线性） | ≈0.30 s（恒定） |
| 启动"首资产可用"（1MB 包，200×5KB） | Open+Find ≈51 µs | ReadFile+Open+Find ≈3.3 ms |
| ServeVfs 每响应开销（handler 直调，4KB 条目，65 文件树） | embedded ≈7.0 µs/op（142 Kops/s）；206 区间同价 ≈7.1 µs；404 miss 无惩罚 ≈7.4 µs | os 真盘后端 ≈16.3 µs/op（61 Kops/s），嵌入路径快 **≈2.3×** |
| writer 内存峰值（INV-R10 上限实测） | — | 输入 512MB 构建成功；进程峰值 RSS ≈ 2×输入 + ~14MB（128MB→267MB、512MB→1038MB） |

结论：typed const 的编译时间随资产线性增长，经验阈值维持 **< 4MB 走 .inc**；
更大包走 `.pack`（启动一次性读入的毫秒级成本可忽略）。ServeVfs 下嵌入路径
免 stat/open 系统调用，区间读经 IStream 窗口定位与全量同价。复现实验：
`core/scripts/respack_bench_compile.sh [MB]`、基准
`core/benchmarks/nextpas.core.respack/bench_embed_startup`、
`bench_writer_memory` 与 `bench_servevfs`。

示例（开发态/发布态切换）：`core/examples/nextpas.core.vfs/demo_asset_embed/`；
端到端 HTTP 服务（respack → .inc → embedded → ServeVfs，自检 200/304/206/404，
另含 `--serve` 长驻与 `--dev` os 后端切换）：`core/examples/nextpas.core.http/http_static_vfs_demo/`
—— 同一 consumer 代码在 `CreateOsVfs('wwwroot')` 与
`CreateEmbeddedVfs(@DEMO_ASSETS[0], …)` 两后端上跑通。

## 测试计划（12 门闭环：respack 6 + vfs 6）

```bash
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_roundtrip
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_reader    # 含损坏输入拒绝 + indexOffset 恒 40 + LE 位移验证
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_writer    # 排序/去重/对齐/digest 4 对齐/golden
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_dirsource # 含 extract 落盘与 mtime 回归
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_embed     # S4：glob/prefix/inc golden/roundtrip
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contract   # uses 白名单 + facade 签名（12 门一致性）
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
| `for I := 0 to N - 1 do`（N: SizeUInt） | N=0 时上界回绕为 `$FFFFFFFF`，循环体以垃圾下标执行 → AV/总线错误 | 循环前守卫 `N > 0`，或改 `while I < N`；Hoare 分区类算法下标一律 Int64（S4 embed 的空 ExcludeGlobs 即踩此坑） |
| 取临时托管数组的指针存入 record | `E.Data := Pointer(BytesOf(s))` 中临时 TBytes 语句结束即释放，Data 成悬垂指针；症状随堆复用抖动（AV 或静默脏字节） | 内容缓冲锚定在存活局部变量上再取址 |
| 局部托管数组作逃逸指针的生命期锚点 | 函数返回后锚点数组释放，调用方持有的 Data 全体悬垂；gate 靠分配器运气通过，调用链上一旦插入分配即爆（S4 在 dirsource 修复为 bundle 返回锚点） | 逃逸结构必须自带内容所有权（record 携带缓冲字段），不依赖调用顺序默契 |

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
| BE 平台换序 | `RdU16LE/RdU32LE/RdU64LE` 位移编解码，与宿主字节序无关 | 直接使用 |

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
