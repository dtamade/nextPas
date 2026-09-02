# libgit2 绑定再生成管线与 C 绑定坑清单

本文档记录 `nextpas.core.git.libgit2.bindings` 的再生成方法，以及从
c2pas888 项目 `findings.md`（475 条）中提炼的、与 C 头文件绑定直接
相关的坑与对策。改了 libgit2 版本或 c2pas888 之后按此重跑。

## 再生成管线（linux-x86_64-lp64）

前置：c2pas888 已构建（`~/projects/c2pas888/bin/c2pas888`），
libgit2 源码在 `~/projects/libgit2`。

1. **shim 目录**（必须）：libgit2 自带的 `include/git2/stdint.h` 是
   MSVC 兼容层，POSIX 下整文件包在 `#ifdef _MSC_VER` 里；但翻译器的
   内建类型表与系统 `<stdint.h>` 同时参与时会在 sema 层产生
   `intmax_t/uintmax_t` 冲突重声明。用优先搜索目录放一个自供
   typedef 的 shim（**故意不含 intmax_t/uintmax_t**，留给内建）：

   ```c
   /* shim_git2/stdint.h */
   #ifndef C2P_STDINT_SHIM_H
   #define C2P_STDINT_SHIM_H
   typedef signed char int8_t;
   typedef unsigned char uint8_t;
   typedef signed short int16_t;
   typedef unsigned short uint16_t;
   typedef signed int int32_t;
   typedef unsigned int uint32_t;
   typedef signed long int64_t;    /* lp64 */
   typedef unsigned long uint64_t;
   typedef long intptr_t;
   typedef unsigned long uintptr_t;
   #endif
   ```

2. **翻译**（伞头一次成单元；产物 ~8200 行、876 个 API 函数、零诊断）：

   ```
   c2pas888 --header-unit --target linux-x86_64-lp64 \
     -u nextpas.core.git.libgit2.bindings -l git2 \
     -I shim_git2 -I . -I ~/projects/libgit2/include unit_git2d.h
   ```

   `unit_git2d.h` 仅一行 `#include "git2.h"`。

2b. **按功能域分片**（800 行/单元红线，匠心修复后）：单文件 8240 行违背
    `single-unit ≤800` 与域内聚原则。按 libgit2 功能域拆为 10 子单元，
    每单元 <800 行，门面 `nextpas.core.git.libgit2.bindings` 纯 re-export：

    - `bindings.types`：C 标量别名（TGitOidT 等）
    - `bindings.structs`：全量记录/句柄/回调（TGitOid/ TGitCommit 等）
    - `bindings.consts`：GIT_* 宏常量
    - `bindings.c`：C 标准库 external（memcpy/strtod 等， shim 走 external 'c'）
    - `bindings.oid`：oid/oidarray/indexer/odb 基础
    - `bindings.odb`：odb 流与对象
    - `bindings.refs`：refs/refdb
    - `bindings.commit`：commit/tree/blob/object
    - `bindings.repo`：repository/annotated_commit
    - `bindings.diff`：tree/diff/patch
    - `bindings.extra`：filter/attr/blame/checkout/config/remote/revwalk 等
    - 门面 `bindings` <150 行，`uses` 聚合 + 少量 type alias（零拷贝 Move inline 复用 bytes.ops 单源）

    再生成后按此清单分片，`grep -c "^function\|^procedure"` 校验 876 函数仍全量，
    `wc -l` 校验每文件 <800。

3. **整形**：unit 名改回点分形式；头部换成 `{** @desc ... *}` 注释 +
   `{$I nextpas.core.settings.inc}`；保留 `{$PACKRECORDS C}`。
   产物不得引入 uses SysUtils（当前为零依赖纯类型+external）。
   分片后每个子单元仅 `uses bindings.types/structs` + `base.utils`，保持 L2 依赖向下。

4. **黄金对照**：`gcc -I ~/projects/libgit2/include abi_probe.c` 打印
   关键 struct 的 sizeof/offsetof 作黄金数字，硬编码进
   `core/tests/nextpas.core.git/test_git_bindings/`。gate 同时以
   `-k-l:libgit2.so.1.9` 链接运行库做符号存在性与运行时版本实证。

## c2pas888 本次修复

- `src/pas2/lower/c2p_pas2_lower_core_typebuild.inc` 两处：C 原型中
  不完整数组参数（`T x[]`）在 CSIR 里是负尺寸数组，此前 lower 硬拒
  （"array size must be positive"），导致 commit/clone/repository/
  merge/rebase 等 11 个域全部不可译。现已按 C 标准衰减语义映射为
  `Pointer`（与既有弹性成员 `[0..0]` 政策并列）。修复后 git2.h 伞头
  一次通过。触发该修复的定位方法：对伞头产物二分 include 列表，
  S031 首触点为 `git_commitarray_dispose(git_commitarray *array)`
  （其参数结构体含 `git_commit *const *commits` 字段）。

## C 绑定坑清单（findings 精选）

| 坑 | 来源锚点 | 对本产物的对策 |
|---|---|---|
| FPC 大小写不敏感：局部名 `pParse` 与类型 `PParse` 折叠冲突 | findings.md 2026-08-12 条目 | 产物参数名由 c2pas888 `MakeUniquePasRoutineName` 去重；新增消费方代码避免与 T/P 前缀类型同名 |
| FPC variant record typed const 数据段错乱 | findings.md 2026-08-16 条目 | 本绑定只含声明无初始化数据；消费方不要手写带 variant case 全字段初始化的 const |
| 跨单元类型身份分裂（公共 header 壳 vs 内部完整体） | findings.md 2026-08-20 条目 | bindings 单元是不透明壳的唯一 owner；消费方一律经 `PGitRepository` 等指针别名引用，不得自行展开内部结构 |
| GCC visibility attribute 不保留（P010 warning ×880） | 本次翻译 diag | 无害豁免：ELF 符号可见性不影响 cdecl 外部声明 |
| bitfield 符号性 / flexible array 政策 | findings.md 2026-06-08 Phase 4/5 系列 | libgit2 公共头无 bitfield；弹性数组成员已按 `[0..0]` 单槽政策落地 |

## 与手写 ffi/binding/backend 的关系（双轨互补，不退役）

初版文档曾建议"消费者迁移后退役手写单元"——该结论**有误，已撤回**。
复核事实：

- `git.libgit2.binding` 的函数声明没有 external，implementation 走
  `nextpas.core.platform.dl` 的 dlopen/dlsym 运行时加载（与
  db.pg 同理：宿主常只有版本化 soname、无 dev symlink）；
- 手写三件套（ffi 类型层 + binding 加载层 + backend OO 层）被
  `test_git` 门 20 个测试真实覆盖（dlopen 真库跑 commit/diff/blame/
  revwalk/config 全链路），是活跃生产代码。

因此两套体系是**互补的加载策略**，职责边界已写入 CONTRACT.md §1.1.2：
运行时加载系是默认消费路径；静态声明系（本产物）服务完整 ABI 面
场景。词汇已收敛：权威 20-byte `native.base.TGitOid` 单源，运行时 `git_oid` variant 叠加（`AsNative` 零拷贝，`SizeOf=20`，`PACKRECORDS C` 双编译器等价 stub 经 `settings.inc`，`Assert` 保证，`inline` 零拷贝 overlay）/静态 `TGitOid` 已单源化为 20-byte `libgit2.base.git_oid` 别名（33-byte `TGitOid33` 及其 `GitOidCopy20To33/33To20` 桥接已于 Phase7 (2026-09-02) 彻底移除，`grep -R TGitOid33` 零命中，SHA256 泛型候选改经 `bytes.ops` `Len` 参化 `TByteSpan`，`bindings.structs:682` 无 `TGitOid33`）+ 20-byte `git_oid/TGitOid20` 同体，Ops 同经 `bytes.ops` 单源（详见 CONTRACT §1.1.2 收敛路线），各自 gate 仍独立但须经单源 Ops。
手写 ffi 中的 PChar/cint 词汇已随 Phase 7 收敛（`scripts/git-contract-check.sh` C5 归一 gate，双轨零残留），
本产物范围仅保留 `PACKRECORDS C`（FPC/nextPas 双编译器等价 stub 经 `settings.inc`） + `Assert(SizeOf=20)` + `inline` 零拷贝桥接（`SpanEqual` 3×QWord/`SpanCopy` 单Move，`bytes.ops` 单源，`try..finally` 资源不丢）。
