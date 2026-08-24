# nextpas.core.respack

L2 资源打包格式模块。把一棵文件树打包成单个带索引的二进制 blob（pack），支持
零拷贝随机读取，是前端资源嵌入程序/动态库场景的格式层。

**状态：设计阶段（S0）。本模块尚未实现；本目录即权威设计文档。**
实现进度见 [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../docs/plans/2026-08-25-respack-vfs-modules-plan.md)。

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

### 内容哈希

每条目可选携带 FNV-1a 32 位哈希（flag 位控制有效性），供 HTTP ETag、增量比对使用。
算法约十行，**内联实现于 `base`，不依赖 `checksum` 模块**——避免为六行代码建立
L2→L2 依赖；若未来 checksum 升到 L1 再收敛。选择 FNV-1a 与仓库现有
`checksum.fnv32` 保持一致。

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
- reader：magic/version/越界/路径不规范/截断 每类损坏一个拒绝用例
- writer：乱序输入自动排序、重复路径报错、对齐断言、golden 字节快照
- 全部 gate 要求 heaptrc 零泄漏

## 设计决策记录

| 决策 | 理由 |
|------|------|
| 纯格式模块，仅依赖 L0 | 工具链/安装器可复用；格式层不该背 IO 抽象 |
| reader 输入是 `(指针,长度)` 而非接口 | 同一 API 覆盖 const 数组/堆/mmap 三种来源，零适配 |
| FNV-1a 内联而非依赖 checksum | 六行算法不值得建 seam；与仓库算法选型一致 |
| 目录隐式表达，不存目录条目 | 省空间；List 由路径前缀推导 |
| modTime 秒级精度 | 主要消费者是 HTTP If-Modified-Since，本身就是秒粒度 |
| dirsource 是唯一 fs 引用点 | 把 L2→L2 依赖压缩到一个可审计单元 |

## 关联文档

- [FORMAT.md](FORMAT.md) — 线格式 v1 权威定义（字节布局、校验规则、扩展策略）
- [`core/docs/vfs/README.md`](../vfs/README.md) — 消费本格式的树视图模块
- [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../docs/plans/2026-08-25-respack-vfs-modules-plan.md) — 实施计划
