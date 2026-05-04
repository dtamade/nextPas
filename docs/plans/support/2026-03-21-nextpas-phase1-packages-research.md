# nextPas 第一阶段 packages 调研记录

- 关联计划：`docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`
- 目的：记录上游 `packages/` 包族勘察结果，以及 phase1 packages 推进计划的分组选型依据

## 已确认的需求

- `packages` 工作必须继续服从 Linux x86_64、FreePascal `stage0`、文档优先和验证优先约束。
- 这轮文档的目标不是再定义稳定边界，而是为 `packages` 推进计划补足上游勘察依据。
- 计划需要解释为什么某些包族可以进入 P1/P2/P3，为什么另一些包族继续明确延后。

## 已确认的技术决策

- `packages` 的下一份正式文档应是计划，而不是第二份稳定规范。
- phase1 先按包族推进，而不是按完整包名清单推进。
- 在 P1/P2 之前，不把 `tests/packages/` 作为前置条件，先复用现有 `harness`、smoke、
  `compiler-pass`、`rtl`、`regression` 和 `diagnostics` 结构。

## 上游勘察结论

- `/home/dtamade/freepascal/fpcsrc/packages` 顶层包树极宽，混合了 `fcl-*`、`rtl-*`、
  数据库、网络、GUI、多媒体、平台专用 units、外部库绑定和生态工具扩展。
- `/home/dtamade/freepascal/fpcsrc/packages/build/Makefile` 暴露出大规模多目标构建矩阵，
  说明 nextPas 如果不先锁住 Linux x86_64，就无法诚实推进 packages 兼容。
- `/home/dtamade/freepascal/fpcsrc/packages/rtl-generics/readme.txt` 表明该包族来自外部维护源的镜像，
  这意味着它虽然接近语言/运行时层，但仍需要明确版本和行为边界。
- `/home/dtamade/freepascal/fpcsrc/packages/fcl-net/README.txt` 明确它以 pure Pascal 方式实现
  网络、主机名和 DNS 相关能力，同时读取 `/etc/resolv.conf`、hosts/services/networks 等系统文件。
  这说明它虽然不一定强依赖 C 库，但环境耦合和验证复杂度依然高于 P1。
- `fcl-json` 在当前树里没有明显的顶层 README 命中，说明不同包族的说明完整度并不一致，
  这进一步支持“先按包族规划，再逐步细化包级设计”的写法。

## 对包族波次的解释

- P1 适合放语言/运行时相邻、低外部依赖、易于在 Linux x86_64 上写最小 smoke 的基础包族，
  例如 `rtl-generics`、`rtl-objpas`、`fcl-base`、`fcl-process`、`fcl-hash`、`regexpr`。
- P2 适合放能增强验证能力、样例表达力和迁移辅助性的文本/数据/测试支持包族，
  例如 `fcl-json`、`fcl-md`、`paszlib`、`fcl-fpcunit`、`fcl-passrc`、`fcl-syntax`。
- P3 适合放虽有明显价值、但环境条件、协议语义、外部服务或数据库耦合更高的包族，
  例如 `fcl-net`、`fcl-web`、`fcl-db`、`sqlite`、`postgres`、`mysql`、`odbc`。

## 明确延后的包族

- GUI、窗口系统和多媒体绑定：`gtk*`、`fpgtk`、`x11`、`opengl`、`opengles`、
  `sdl`、`cairo`、`gstreamer`、`openal`
- 强外部库绑定：`libcurl`、`openssl`、`libxml`、`libpng`、`fftw`、`libusb`
- 平台专用 units：`os2units`、`qlunits`、`winceunits`、`winunits-*`、`univint`
- 生态工具链扩展：`fppkg`、`ide`、`vcl-compat`

这些包族不是“不做”，而是当前不适合先于 core baseline 和低依赖包族进入 phase1 gate。

## 风险与护栏

- 不因为上游存在 pure Pascal 实现，就自动把网络或服务类包降级成低风险包。
- 不把某个包族的“常见”误当成“适合 phase1 首批推进”。
- 不让 `packages` 推进反向扩大目标平台、发行布局或 `stage0` 承诺。
- 不把 support 调研记录写成新的稳定规范；正式边界仍以 `docs/architecture/` 为准。

## 参考资料

- FPC packages 顶层目录：
  `/home/dtamade/freepascal/fpcsrc/packages`
- FPC packages 构建矩阵：
  `/home/dtamade/freepascal/fpcsrc/packages/build/Makefile`
- `rtl-generics` 说明：
  `/home/dtamade/freepascal/fpcsrc/packages/rtl-generics/readme.txt`
- `fcl-net` 说明：
  `/home/dtamade/freepascal/fpcsrc/packages/fcl-net/README.txt`
- phase1 packages 推进计划：
  `docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`
- phase1 packages 稳定边界：
  `docs/architecture/packages-specification.md`
