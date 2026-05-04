# nextPas 第一阶段自举进度日志

- 关联计划：`docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
- 实施计划：
  `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
- 证据根目录：`.sisyphus/evidence/`

## 会话：2026-03-20

### 阶段 1：恢复并校验上下文

- **状态：** 完成
- **开始时间：** 2026-03-20 14:02 CST（恢复检查点）
- 已执行动作：
  - 检查当前工作区内容，确认仓库实际上除 `.sisyphus` 外几乎为空。
  - 读取恢复已规划实现和持久化规划所需的当前技能。
  - 从 `.sisyphus` 中恢复之前的计划和草稿。
  - 识别出任务 1-3 才是正确的第一批执行任务，因为后续任务都被它们阻塞。
- 创建/修改文件：
  - 第一阶段自举工作的在途计划记录

### 阶段 2：编写第一波次基线文档

- **状态：** 完成
- **开始时间：** 2026-03-20 14:02 CST
- 已执行动作：
  - 准备好用于跟踪本批次的会话记忆文件。
  - 阅读 FPC 源码树顶层 README，确认要保留的生态边界。
  - 阅读 FPC RTL 与测试套件说明，锁定运行时兼容性与验证预期。
  - 阅读历史 `compiler` 驱动入口及外部 `compiler`/RTL 测试样本，锚定后续兼容性措辞。
  - 编写 `docs/adr/0001-fpc-reference-baseline.md`、
    `docs/architecture/overview.md` 和
    `docs/architecture/compatibility-matrix.md`。
  - 运行任务 1-3 的验收命令与 QA 场景命令，并把证据写入
    `.sisyphus/evidence/`。
  - 在任务 1 的负向 grep 命中字面量 `dual-platform` 后，修正了一处措辞冲突。
- 创建/修改文件：
  - `docs/plans/` 与 `docs/plans/support/` 下的正式计划记录
  - `docs/adr/0001-fpc-reference-baseline.md`（新建）
  - `docs/architecture/overview.md`（新建）
  - `docs/architecture/compatibility-matrix.md`（新建）
  - `.sisyphus/evidence/task-1-freeze-fpc-baseline.txt`（新建）
  - `.sisyphus/evidence/task-1-freeze-fpc-baseline-error.txt`（新建）
  - `.sisyphus/evidence/task-2-architecture-blueprint.txt`（新建）
  - `.sisyphus/evidence/task-2-architecture-blueprint-error.txt`（新建）
  - `.sisyphus/evidence/task-3-compatibility-matrix.txt`（新建）
  - `.sisyphus/evidence/task-3-compatibility-matrix-error.txt`（新建）

### 阶段 3：发布可执行级实施计划

- **状态：** 完成
- **开始时间：** 2026-03-20 15:13 CST
- 已执行动作：
  - 编写 `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`，
    作为任务 4-12 的可执行交接文档。
  - 更新 `docs/plans/README.md`，使当前生效的计划集合同时包含自举
    主计划和实施计划。
  - 更新自举主计划，使其引用新的实施计划并保持当前状态同步。
  - 确认下一批可执行任务仍然是任务 4-5。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（新建）
  - `docs/plans/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`
    （更新）

### 阶段 4：发布剩余的第一波次结构文档

- **状态：** 完成
- **开始时间：** 2026-03-20 17:56 CST
- 已执行动作：
  - 编写 `docs/architecture/directory-structure-specification.md`，把保留的顶层边界和现代
    编译器子模块布局正式化。
  - 编写 `docs/architecture/bootstrap-roadmap.md`，定义 `stage0`、`stage1`
    和 `stage2`，并补齐显式的 promotion gate 与回退条件。
  - 运行 任务 4 和 任务 5 的验证命令，并把证据写入 `.sisyphus/evidence/`。
  - 更新自举主计划和实施计划，使下一批就绪状态前移到任务 6-8。
- 创建/修改文件：
  - `docs/architecture/directory-structure-specification.md`（新建）
  - `docs/architecture/bootstrap-roadmap.md`（新建）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `.sisyphus/evidence/task-4-directory-blueprint.txt`（新建）
  - `.sisyphus/evidence/task-4-directory-blueprint-error.txt`（新建）
  - `.sisyphus/evidence/task-5-bootstrap-roadmap.txt`（新建）
  - `.sisyphus/evidence/task-5-bootstrap-roadmap-error.txt`（新建）

### 阶段 5：搭建仓库与验证路径

- **状态：** 就绪
- 已执行动作：
  - 任务 6-8 现已作为批次 B 进入可执行状态。
- 创建/修改文件：
  - 暂无

### 阶段 6：统一文档与计划语言为中文

- **状态：** 完成
- **开始时间：** 2026-03-20 22:15 CST
- 已执行动作：
  - 继续完成 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
    的剩余中文化，把任务画像、并行信息、参考资料、验收标准、QA 场景、最终验证波次
    和提交策略统一为中文表述。
  - 收口 `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
    中残留的英文标签，把目标、架构背景、技术栈、文件与执行步骤等结构块统一成中文。
  - 复核 `docs/plans/README.md`、调研记录、ADR 与架构文档，确保
    `docs/` 下的规划文档命名与正文风格保持正式、统一。
  - 刻意保留执行锚点与 grep 接口：`Linux x86_64`、
    `ABI compatibility is deferred`、`No new syntax`、`Source syntax`、
    `Core semantics`、`promotion gate`、`stage0`、`stage1`、`stage2`，
    以及目录/模块名 `compiler`、`rtl`、`packages`、`tests`、`tools`、
    `build`、`frontend`、`syntax`、`sema`、`ir`、`backend`、`targets`、
    `driver`、`diagnostics`。
  - 运行目标文件存在性检查、关键锚点 grep 核验，以及
    `docs/plans`、`docs/architecture`、`docs/adr` 文件清单核对。
- 创建/修改文件：
  - `docs/plans/README.md`（复核）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（复核）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
  - `docs/adr/0001-fpc-reference-baseline.md`（复核）
  - `docs/architecture/overview.md`（复核）
  - `docs/architecture/compatibility-matrix.md`（复核）
  - `docs/architecture/directory-structure-specification.md`（复核）
  - `docs/architecture/bootstrap-roadmap.md`（复核）

### 阶段 7：继续收口剩余英文规划术语

- **状态：** 完成
- **开始时间：** 2026-03-20 22:31 CST
- 已执行动作：
  - 继续收口 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
    中少量残留的叙述性英文，把“target 规格”“仅限 Linux x86_64”等表述统一成中文。
  - 继续清理 `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
    中残留的叙述性英文，包括执行提示、批次命名、检查点、提交信息和最终验证波次等表述。
  - 收口 `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`
    中的“文档优先”“验证优先”“第一波次”等规划术语。
  - 更新本进度日志中的“批次”“就绪”“当前计划集合”“自托管”“验证 grep”
    等历史叙述，使回放文本与当前中文风格一致。
  - 再次扫描 `docs/plans` 与 `docs/plans/support`，确认结构性英文标签已基本清除，
    仅保留命令、路径、测试组名、模块名和关键 grep 锚点。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 8：继续收口 ADR 与架构文档的叙述性英文

- **状态：** 完成
- **开始时间：** 2026-03-20 22:43 CST
- 已执行动作：
  - 继续清理 `docs/architecture/bootstrap-roadmap.md` 中残留的英文叙述，把
    自托管、前端、目标平台模型、驱动入口、`harness` 等上下文表达
    收口为更正式的中文，同时保留 `stage0`、`stage1`、`stage2` 和
    `promotion gate` 等执行锚点。
  - 更新 `docs/architecture/directory-structure-specification.md`、`docs/architecture/overview.md`
    与 `docs/architecture/compatibility-matrix.md`，把编译器树、包分层、目标平台规格、
    测试分类和非目标说明中的叙述性英文继续降到最少。
  - 更新 `docs/adr/0001-fpc-reference-baseline.md`，把驱动入口、`harness`、
    包管理器、完整包覆盖面、全生态工具链对等等表述切换为中文，同时保留 `Source syntax`、`Core semantics`、
    `No new syntax` 和 `ABI compatibility is deferred`。
  - 重新执行结构性英文扫描、关键锚点保留检查，以及面向 ADR/架构文档的常见英文术语扫描，
    确认当前保留的英文主要限于文件路径、命令、模块名和刻意保留的技术锚点。
- 创建/修改文件：
  - `docs/architecture/bootstrap-roadmap.md`（更新）
  - `docs/architecture/directory-structure-specification.md`（更新）
  - `docs/architecture/overview.md`（更新）
  - `docs/architecture/compatibility-matrix.md`（更新）
  - `docs/adr/0001-fpc-reference-baseline.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 9：继续收口计划与进度文档的叙述性英文

- **状态：** 完成
- **开始时间：** 2026-03-20 22:56 CST
- 已执行动作：
  - 继续清理 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
    与 `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
    中残留的说明性英文，把“自举”“命令行驱动入口”“目标平台配置”“包管理器”等正文表述
    进一步统一为中文。
  - 更新 `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`
    与本进度日志，把调研回放、阶段记录、测试结果和重启问题中的叙述性英文继续收口。
  - 再次执行 `docs/plans` 与 `docs/plans/support` 的定向扫描，确认当前残留的英文主要来自
    文件名、路径、命令、grep 关键字、提交示例和刻意保留的技术锚点。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 10：同步计划核验语句与当前中文文档

- **状态：** 完成
- **开始时间：** 2026-03-20 23:10 CST
- 已执行动作：
  - 继续清理 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
    与 `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
    中残留的说明性英文，把命令行驱动入口、样例、目标平台配置、
    发行布局等表述进一步统一为中文。
  - 修正主计划与实施计划中的部分验收说明和 grep 场景，使其与当前已经中文化的
    ADR/架构文档保持一致，例如把旧的兼容层标签、包管理器和自托管等说明词，
    替换为当前实际使用的中文表述或约束语句。
  - 重新执行计划结构扫描、剩余叙述性英文扫描，以及关键锚点保留检查，确认
    这轮修订没有破坏执行锚点和命令接口。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 11：继续收口 support 文档的回放式英文

- **状态：** 完成
- **开始时间：** 2026-03-20 23:27 CST
- 已执行动作：
  - 继续清理调研记录与进度日志中的回放式英文，把“测试套件”“自托管负向 grep”
    等说明统一成中文表达，尽量减少仅为追踪历史改动而残留的英文词。
  - 保留文件路径、命令、grep 模式和关键锚点不变，只调整叙述性说明与测试结果文字，
    使 `docs/plans/support` 下的记录更接近正式中文文档风格。
- 创建/修改文件：
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 12：补齐缺失的运行时与发行设计文档

- **状态：** 完成
- **开始时间：** 2026-03-20 23:45 CST
- 已执行动作：
  - 新建 `docs/architecture/rtl-specification.md`，把第一阶段 RTL 的现代化边界、
    `rtl/core/` 与 `rtl/crt/` 的分工、验证路径、阶段关系和非目标正式写清。
  - 新建 `docs/architecture/crt-specification.md`，把控制台导向行为从泛化 RTL 文案中
    独立出来，并明确它与 `tests/crt/`、`tests/harness/` 和 smoke 路径的关系。
  - 新建 `docs/architecture/distribution-layout-specification.md`，把未来发行布局明确为
    `bin/`、`lib/`、`units/<target>/` 和 `share/`，并补充它与 `stage0`、
    `build/verify_local.sh` 和 Linux CI 的约束关系。
  - 同步 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md` 中任务 11 的
    RTL 验收关键词，把旧的 `modern` grep 锚点改为与当前中文文档一致的
    `现代化`。
  - 更新调研记录中的“当前已完成文档”清单，使 support 文档与最新架构集合保持一致。
  - 保持“当前只做计划/设计”的边界，本轮没有创建 `rtl/`、`build/`、`tests/`
    下的实现骨架。
- 创建/修改文件：
  - `docs/architecture/rtl-specification.md`（新建）
  - `docs/architecture/crt-specification.md`（新建）
  - `docs/architecture/distribution-layout-specification.md`（新建）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 13：继续补齐实现前置的验证、驱动与目标规格设计

- **状态：** 完成
- **开始时间：** 2026-03-21 00:08 CST
- 已执行动作：
  - 新建 `docs/architecture/test-harness-specification.md`，把 `tests/run_all_tests.sh`、
    `tests/harness/`、`tests/snapshots/` 的职责拆分、分组名、`smoke` 视角、
    `unknown-group` 失败语义，以及与本地验证和 CI 的关系正式写清。
  - 新建 `docs/architecture/stage0-driver-specification.md`，把
    `nextpas build <source> --target linux-x86_64` 作为第一阶段唯一公开成功路径，
    并明确 `unsupported-command`、`stage0` 阶段边界和非目标。
  - 新建 `docs/architecture/target-platform-specification.md`，把
    `build/targets/linux-x86_64.toml` 的职责、唯一受支持目标、`unsupported target`
    拒绝行为，以及与发行布局的关系固定下来。
  - 更新主计划，把三份新文档纳入当前架构交付物与完成定义，并把它们接入
    任务 7、任务 9 和任务 10 的参考资料。
  - 统一主计划与实施计划中的 `harness` 测试组名，收口为
    `compiler-pass` / `compiler-fail` / `diagnostics` / `rtl` / `crt` / `regression`，
    避免组名与 CLI 输出不一致。
  - 更新调研记录中的“当前已完成文档”列表，使 support 文档继续与架构集合同步。
- 创建/修改文件：
  - `docs/architecture/test-harness-specification.md`（新建）
  - `docs/architecture/stage0-driver-specification.md`（新建）
  - `docs/architecture/target-platform-specification.md`（新建）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 14：统一架构文档的正式命名体系

- **状态：** 完成
- **开始时间：** 2026-03-21 09:02 CST
- 已执行动作：
  - 把规范类架构文档统一收口到更正式的 `*-specification.md` 命名：
    `directory-structure-specification.md`、`rtl-specification.md`、
    `crt-specification.md`、`distribution-layout-specification.md`、
    `test-harness-specification.md`、`stage0-driver-specification.md`、
    `target-platform-specification.md`。
  - 同步更新主计划、实施计划、调研记录、进度日志和架构文档内部的所有路径引用，
    避免出现旧文件名与新文件名并存的中间态。
  - 把规范类文档标题与任务 11 的说明性措辞，统一到“规范/目录结构规范”表述，
    同时保留 `overview`、`matrix` 和 `roadmap`
    这类已经足够清晰的标准文档类型。
- 创建/修改文件：
  - `docs/architecture/directory-structure-specification.md`（由旧文件更名）
  - `docs/architecture/rtl-specification.md`（由旧文件更名）
  - `docs/architecture/crt-specification.md`（由旧文件更名）
  - `docs/architecture/distribution-layout-specification.md`（由旧文件更名）
  - `docs/architecture/test-harness-specification.md`（由旧文件更名）
  - `docs/architecture/stage0-driver-specification.md`（由旧文件更名）
  - `docs/architecture/target-platform-specification.md`（由旧文件更名）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 15：补充架构目录命名说明并收口正文旧称

- **状态：** 完成
- **开始时间：** 2026-03-21 00:27 CST
- 已执行动作：
  - 新建 `docs/architecture/README.md`，明确说明 `overview`、`matrix`、
    `roadmap` 与 `*-specification.md` 的正式用法、中文正式名称和阅读入口。
  - 收口主计划、实施计划与架构正文中残留的旧称，统一为“概览/规范/路线图/
    边界说明”等正式表述，避免继续混用不够稳定的历史叫法。
  - 修正进度日志中的旧文件名检查命令，并补充命名规则检查与旧命名残留扫描，
    确认 `docs/` 下的正式命名体系已经闭环。
- 创建/修改文件：
  - `docs/architecture/README.md`（新建）
  - `docs/architecture/overview.md`（更新）
  - `docs/architecture/bootstrap-roadmap.md`（更新）
  - `docs/architecture/compatibility-matrix.md`（更新）
  - `docs/architecture/directory-structure-specification.md`（更新）
  - `docs/architecture/rtl-specification.md`（更新）
  - `docs/architecture/crt-specification.md`（更新）
  - `docs/architecture/distribution-layout-specification.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 16：建立 phase1 文档基线并收口状态口径

- **状态：** 完成
- **开始时间：** 2026-03-21 00:40 CST
- 已执行动作：
  - 新建 `docs/architecture/documentation-baseline-specification.md`，把
    `docs/adr/`、`docs/architecture/`、`docs/plans/`、
    `docs/plans/support/` 与 `.sisyphus/evidence/` 的分层职责、阅读顺序和裁决顺序
    正式写清。
  - 更新 `docs/architecture/README.md` 与 `docs/plans/README.md`，把新的文档基线入口
    接入目录导航，并明确活动计划与历史记录的区别。
  - 更新自举主计划，去掉“唯一事实来源”的过度表述，改为计划层入口，并把当前活动批次
    收口到“批次 B，任务 6-8，当前起始任务 6”。
  - 更新实施计划顶部目标，把“执行任务 4-12”修正为“执行任务 6-12”，同时明确
    稳定边界继续以 ADR 与架构规范为准。
  - 同步更新调研记录中的“当前已完成文档”清单，避免恢复上下文时遗漏新的文档基线规范。
- 创建/修改文件：
  - `docs/architecture/documentation-baseline-specification.md`（新建）
  - `docs/architecture/README.md`（更新）
  - `docs/plans/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）

### 阶段 17：完成 task 6 仓库骨架与顶层 ownership README

- **状态：** 完成
- **开始时间：** 2026-03-21 14:35 CST
- 已执行动作：
  - 创建 `compiler/`、`rtl/`、`packages/`、`tests/`、`tools/`、`build/` 顶层目录，
    并补齐 `compiler/frontend/`、`compiler/syntax/`、`compiler/sema/`、
    `compiler/ir/`、`compiler/backend/`、`compiler/targets/`、
    `compiler/driver/`、`compiler/diagnostics/`、`rtl/core/` 和 `rtl/crt/`
    这些第一阶段要求的最小骨架目录。
  - 为 `compiler/`、`rtl/`、`packages/`、`tests/`、`tools/` 和 `build/`
    编写顶层 `README.md`，把职责、phase1 护栏、相邻边界和显式非目标收口到目录入口。
  - 更新 phase1 主计划与实施计划，把 task 6 标记为已完成，并把当前起始任务推进到 task 7。
- 创建/修改文件：
  - `compiler/README.md`（新建）
  - `rtl/README.md`（新建）
  - `packages/README.md`（新建）
  - `tests/README.md`（新建）
  - `tools/README.md`（新建）
  - `build/README.md`（新建）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-6-repo-skeleton.txt`
  - `.sisyphus/evidence/task-6-repo-skeleton-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 7：搭建验证 `harness` 骨架

### 阶段 18：完成 task 7 `harness` 控制面与 Pascal 骨架

- **状态：** 完成
- **开始时间：** 2026-03-21 15:08 CST
- 已执行动作：
  - 新建 `tests/run_all_tests.sh`，冻结 `--list-groups`、`--filter <group>`、
    `--filter smoke` 和 `unknown-group` 的最小公开控制面。
  - 新建 `tests/harness/README.md`，把分组名、退出码、smoke 语义和当前骨架阶段的
    非目标写清。
  - 新建 `tests/harness/runner.pas` 与 `tests/harness/snapshot_support.pas`，
    为 Pascal 执行层与快照支持层保留明确落点。
  - 更新 `tests/README.md`，把 `tests/run_all_tests.sh` 与 `tests/harness/`
    的当前存在状态写回顶层测试目录入口。
  - 更新 phase1 主计划与实施计划，把 task 7 标记为完成，并把当前起始任务推进到 task 8。
- 创建/修改文件：
  - `tests/run_all_tests.sh`（新建）
  - `tests/harness/README.md`（新建）
  - `tests/harness/runner.pas`（新建）
  - `tests/harness/snapshot_support.pas`（新建）
  - `tests/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-7-harness.txt`
  - `.sisyphus/evidence/task-7-harness-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 8：补齐兼容性测试桶与 smoke 样例集

### 阶段 19：完成 task 8 smoke 样例与测试桶播种

- **状态：** 完成
- **开始时间：** 2026-03-21 15:35 CST
- 已执行动作：
  - 新建 `tests/compiler/pass/`、`tests/compiler/fail/`、`tests/diagnostics/parser/`、
    `tests/rtl/`、`tests/crt/`、`tests/regression/` 和 `tests/snapshots/`，
    为六类已声明测试桶补齐首批 smoke 样例与快照资产。
  - 更新 `tests/run_all_tests.sh`，为合法分组输出稳定的 `expectation`、`status`
    和 `result` 字段，并让 `compiler-fail` 以“预期失败被正确分类”的语义报告
    `result=pass`。
  - 更新 `tests/README.md` 与 `tests/harness/README.md`，把 task 8 完成后的目录现状、
    smoke 结果语义和 `compiler-fail` 分类规则写回目录入口。
  - 更新 phase1 主计划与实施计划，把 task 8 标记为完成，并把当前起始任务推进到 task 9。
- 创建/修改文件：
  - `tests/run_all_tests.sh`（更新）
  - `tests/README.md`（更新）
  - `tests/harness/README.md`（更新）
  - `tests/compiler/pass/hello_pass.pas`（新建）
  - `tests/compiler/fail/missing_semicolon_fail.pas`（新建）
  - `tests/diagnostics/parser/unclosed_block.pas`（新建）
  - `tests/rtl/sysutils_smoke.pas`（新建）
  - `tests/crt/console_smoke.pas`（新建）
  - `tests/regression/reference_regression.pas`（新建）
  - `tests/snapshots/compiler-fail-missing_semicolon.stderr.txt`（新建）
  - `tests/snapshots/diagnostics-parser-unclosed_block.stderr.txt`（新建）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-8-smoke.txt`
  - `.sisyphus/evidence/task-8-smoke-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 9：实现 `stage0` `nextpas` 命令行驱动入口

### 阶段 20：完成 task 9 `stage0` 驱动入口

- **状态：** 完成
- **开始时间：** 2026-03-21 16:38 CST
- 已执行动作：
  - 新建 `tools/stage0/nextpas.pas`，实现只支持
    `nextpas build <source> --target linux-x86_64` 的最小 `stage0` 命令行入口。
  - 新建 `tools/stage0/README.md`，把用法、退出码、输出字段和 `unsupported-command`
    失败语义写清。
  - 新建 `examples/smoke/hello.pas` 作为当前规范 smoke 输入。
  - 更新 `tools/README.md`，把 `stage0/` 的当前存在状态和标准 smoke 输入写回目录入口。
  - 修正驱动实现里的两处早期问题：显式通过 `PATH` 解析 `fpc`，并让未知命令优先返回
    `unsupported-command`，而不是被参数校验短路。
  - 更新 phase1 主计划与实施计划，把 task 9 标记为完成，并把当前起始任务推进到 task 10。
- 创建/修改文件：
  - `tools/stage0/nextpas.pas`（新建）
  - `tools/stage0/README.md`（新建）
  - `examples/smoke/hello.pas`（新建）
  - `tools/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-9-stage0-driver.txt`
  - `.sisyphus/evidence/task-9-stage0-driver-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 10：外置 Linux x86_64 目标平台与工具链配置

### 阶段 21：完成 task 10 目标规格外置

- **状态：** 完成
- **开始时间：** 2026-03-21 16:57 CST
- 已执行动作：
  - 新建 `build/targets/linux-x86_64.toml`，把当前唯一受支持目标、宿主编译器和发行布局
    相关假设写成显式目标事实。
  - 新建 `tools/stage0/target_config.pas`，实现最小配置读取逻辑，让 `stage0` driver
    根据外置目标规格加载配置，而不是继续把目标规则硬编码在主文件里。
  - 更新 `tools/stage0/nextpas.pas`，移除写死的目标判断与编译器常量，改为从配置单元
    读取目标、编译器和配置路径，并把 `target-config` 写入 build 结果字段。
  - 更新 `tools/stage0/README.md` 与 `build/README.md`，把目标规格已外置的当前状态写回
    目录入口。
  - 更新 phase1 主计划与实施计划，把 task 10 标记为完成，并把当前起始任务推进到 task 11。
- 创建/修改文件：
  - `build/targets/linux-x86_64.toml`（新建）
  - `tools/stage0/target_config.pas`（新建）
  - `tools/stage0/nextpas.pas`（更新）
  - `tools/stage0/README.md`（更新）
  - `build/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-10-target-config.txt`
  - `.sisyphus/evidence/task-10-target-config-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 11：定义现代 RTL/CRT 规范与骨架

### 阶段 22：完成 task 11 RTL/CRT 骨架对齐

- **状态：** 完成
- **开始时间：** 2026-03-21 17:20 CST
- 已执行动作：
  - 复核 `docs/architecture/rtl-specification.md` 与
    `docs/architecture/crt-specification.md`，确认 task 11 需要补的是仓库骨架，
    不是重写规范正文。
  - 新建 `rtl/core/README.md`、`rtl/core/system/README.md` 与 `rtl/crt/README.md`，
    把 `rtl/core/`、`rtl/core/system/` 与 `rtl/crt/` 的责任边界落到仓库实体。
  - 新建 `rtl/core/system/system_placeholder.pas` 与
    `rtl/crt/crt_placeholder.pas`，为未来 `System` 与 CRT 公开表面预留最小 Pascal 位置。
  - 更新 `rtl/README.md`，把顶层 `rtl/` 入口与新子目录的职责关系写清。
  - 更新 phase1 主计划、实施计划与根目录 tracking 文件，把 task 11 标记为完成，并把当前起始任务推进到 task 12。
- 创建/修改文件：
  - `rtl/core/README.md`（新建）
  - `rtl/core/system/README.md`（新建）
  - `rtl/core/system/system_placeholder.pas`（新建）
  - `rtl/crt/README.md`（新建）
  - `rtl/crt/crt_placeholder.pas`（新建）
  - `rtl/README.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`
    （更新）
  - `task_plan.md`（更新）
  - `findings.md`（更新）
  - `progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-11-rtl-crt-contracts.txt`
  - `.sisyphus/evidence/task-11-rtl-crt-contracts-error.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - task 12：增加 Linux CI 与本地验证入口

### 阶段 23：收口 `harness` 的 snapshot baseline locator 投影

- **状态：** 完成
- **开始时间：** 2026-03-23 23:01 CST
- 已执行动作：
  - 更新 `tests/harness/snapshot_support.pas`，把单个 fixture 的 snapshot readiness 判断收进快照支持层，避免 runner 自己重新发明 baseline 状态语义。
  - 更新 `tests/harness/runner.pas`，让 `compiler-fail` 与 `diagnostics` 在现有 `snapshot-root`、`snapshot-count`、`snapshot-status` 之外，再逐 fixture 打印 `snapshot-entry=<key> fixture=<path> status=<...> path=<snapshot> diff=<diff>`。
  - 更新 `tests/harness/README.md`、`tests/README.md`、`docs/architecture/test-harness-specification.md` 与 `docs/architecture/diagnostics-specification.md`，把当前已经落地的 snapshot identity / locator 投影写回文档，而不是继续停留在只有 readiness 的描述。
- 创建/修改文件：
  - `tests/harness/snapshot_support.pas`（更新）
  - `tests/harness/runner.pas`（更新）
  - `tests/harness/README.md`（更新）
  - `tests/README.md`（更新）
  - `docs/architecture/test-harness-specification.md`（更新）
  - `docs/architecture/diagnostics-specification.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/task-7-harness-snapshot-projection.txt`
  - `.sisyphus/evidence/task-12-local-verify.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - 让 `diagnostics` 组从“比较 baseline 资产是否就绪”继续推进到“比较真实生成的 canonical diagnostics snapshot”

### 阶段 24：完成 task 12 收口并执行 phase1 最终验证波次

- **状态：** 完成
- **开始时间：** 2026-03-24 01:08 CST
- 已执行动作：
  - 复核 task 12 的真实仓库状态，确认 `.github/workflows/ci.yml`、`build/verify_local.sh` 与 `docs/architecture/distribution-layout-specification.md` 已存在，但主计划和实施计划仍停在“当前起始任务为 task 12”的旧状态。
  - fresh 运行 task 12 的本地验证与 Linux-only 负向检查，刷新 `task-12-local-verify.txt` 与 `task-12-local-verify-error.txt`。
  - 执行 phase1 最终验证波次 F1-F4，生成计划一致性、质量/构建复核、手工 QA 回放与范围忠实度四份证据。
  - 更新主计划、实施计划与当前会话 tracking 文件，把 phase1 状态从“task 12 就绪”推进到“等待用户明确回复 `okay`”。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
  - `task_plan.md`（更新）
  - `findings.md`（更新）
  - `progress.md`（更新）
  - `.sisyphus/evidence/task-12-local-verify.txt`（更新）
  - `.sisyphus/evidence/task-12-local-verify-error.txt`（更新）
  - `.sisyphus/evidence/f1-plan-compliance.txt`（新建）
  - `.sisyphus/evidence/f2-quality-review.txt`（新建）
  - `.sisyphus/evidence/f3-manual-qa.txt`（新建）
  - `.sisyphus/evidence/f4-scope-fidelity.txt`（新建）
- 证据路径：
  - `.sisyphus/evidence/task-12-local-verify.txt`
  - `.sisyphus/evidence/task-12-local-verify-error.txt`
  - `.sisyphus/evidence/f1-plan-compliance.txt`
  - `.sisyphus/evidence/f2-quality-review.txt`
  - `.sisyphus/evidence/f3-manual-qa.txt`
  - `.sisyphus/evidence/f4-scope-fidelity.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - 等待用户明确回复 `okay`；若收到反馈，则按反馈修复并重跑对应验证

### 阶段 25：phase1 获得用户接受并正式关账

- **状态：** 完成
- **开始时间：** 2026-03-24 01:20 CST
- 已执行动作：
  - 将用户的“好的，继续，你自主规划”解释为对 phase1 收口结果的明确接受。
  - 更新主计划，把 phase1 顶部状态改为完成，并把 F1-F4 标记为已检查。
  - 更新实施计划，把当前状态从“等待 `okay`”推进为“phase1 已完成，后续工作转入新主线”。
- 创建/修改文件：
  - `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`（更新）
  - `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`（更新）
  - `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`（更新）
- 证据路径：
  - `.sisyphus/evidence/f1-plan-compliance.txt`
  - `.sisyphus/evidence/f2-quality-review.txt`
  - `.sisyphus/evidence/f3-manual-qa.txt`
  - `.sisyphus/evidence/f4-scope-fidelity.txt`
- 阻塞项：
  - 无
- 下一项就绪任务：
  - 进入新的批次主线，优先选择最贴近真实代码和统一结果契约的实现方向

## 测试结果

| 测试                                | 输入                                                                                                                                                                                                                                                                                                                                                      | 预期                                                                                     | 实际                                    | 状态           |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | --------------------------------------- | -------------- | ---- |
| 会话恢复                            | `git status --short`                                                                                                                                                                                                                                                                                                                                      | 展示仓库状态                                                                             | 失败，因为当前工作区不是 Git 仓库       | 预期的环境限制 |
| 任务 1 验收                         | `test -f ... && grep ...`                                                                                                                                                                                                                                                                                                                                 | ADR 基线存在，并包含冻结的 FPC 路径、Linux x86_64 以及 `No new syntax`                   | 通过                                    | 通过           |
| 任务 2 验收                         | `test -f ... && grep ...`                                                                                                                                                                                                                                                                                                                                 | 架构总览存在，并包含所有顶层边界和显式非目标                                             | 通过                                    | 通过           |
| 任务 3 验收                         | `test -f ... && grep ...`                                                                                                                                                                                                                                                                                                                                 | 兼容性矩阵存在，并把 ABI 标记为延后                                                      | 通过                                    | 通过           |
| 任务 1-3 QA 场景                    | 自举主计划中的场景命令                                                                                                                                                                                                                                                                                                                                    | 生成证据文件，且负向检查保持干净                                                         | 在修正一次任务 1 措辞后通过             | 通过           |
| 计划集合更新                        | `test -f docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md` 加 `rg implementation-plan docs/plans docs/plans/support`                                                                                                                                                                                                                           | 新实施计划存在，且已在活动计划文档中被链接                                               | 通过                                    | 通过           |
| 任务 4 验证                         | `test -f docs/architecture/directory-structure-specification.md` 加顶层边界与 `compiler` 子模块 grep                                                                                                                                                                                                                                                      | 目录结构规范存在并命名了所有必须区域                                                     | 通过                                    | 通过           |
| 任务 5 验证                         | `test -f docs/architecture/bootstrap-roadmap.md` 加 `stage0`/`stage1`/`stage2` grep 与自托管负向 grep                                                                                                                                                                                                                                                     | 自举路线图存在，并且没有把自托管写进第一阶段完成条件                                     | 通过                                    | 通过           |
| 文档中文化目标文件检查              | `for path in ...; do test -f \"$path\"; done`                                                                                                                                                                                                                                                                                                             | 所有计划、架构与 ADR 目标文件都存在                                                      | 通过                                    | 通过           |
| 关键锚点保留检查                    | `rg -n 'Linux x86_64\|ABI compatibility is deferred\|No new syntax\|Source syntax\|Core semantics\|promotion gate\|stage0\|stage1\|stage2' docs/adr docs/architecture docs/plans`                                                                                                                                                                         | 中文化后仍保留所有关键执行锚点                                                           | 通过                                    | 通过           |
| docs 文件清单核对                   | `find docs/plans docs/architecture docs/adr -maxdepth 3 -type f                                                                                                                                                                                                                                                                                           | sort`                                                                                    | 计划、架构与 ADR 文件集合完整且路径稳定 | 通过           | 通过 |
| 剩余英文规划术语扫描                | 针对当前主计划与实施计划执行结构性英文标签扫描                                                                                                                                                                                                                                                                                                            | 结构性英文标签已清理，仅保留技术锚点与必要英文标识                                       | 通过                                    | 通过           |
| 架构/ADR 叙述性英文扫描             | `rg -n 'self-host\|front-end\|package universe\|compiler tree\|package manager\|Whole-ecosystem tooling parity\|Full package surface' docs/adr docs/architecture`                                                                                                                                                                                         | 常见叙述性英文词已清理，仅保留关键锚点、路径和模块名                                     | 通过                                    | 通过           |
| 计划核验语句对齐扫描                | 针对主计划与实施计划扫描旧兼容层标签、自托管与包管理器等说明词                                                                                                                                                                                                                                                                                            | 计划中的说明性核验语句已与当前中文文档基本对齐，保留的英文仅限命令、路径、锚点与提交示例 | 通过                                    | 通过           |
| 缺失架构设计文档存在性检查          | `test -f docs/architecture/rtl-specification.md && test -f docs/architecture/crt-specification.md && test -f docs/architecture/distribution-layout-specification.md`                                                                                                                                                                                      | 三份缺失设计文档都已补齐                                                                 | 通过                                    | 通过           |
| RTL/CRT/发行布局关键锚点检查        | `grep -n "现代化" docs/architecture/rtl-specification.md`、`grep -n "控制台" docs/architecture/crt-specification.md`、`grep -n "bin/\|units/<target>/\|share/" docs/architecture/distribution-layout-specification.md`                                                                                                                                    | 新文档包含当前计划所需的关键中文锚点与发行路径约束                                       | 通过                                    | 通过           |
| 过度承诺负向检查                    | `! grep -n "第一阶段完整 RTL 移植\|第一阶段完整 CRT 替换" docs/architecture/rtl-specification.md docs/architecture/crt-specification.md`                                                                                                                                                                                                                  | 运行时设计文档不会把第一阶段写成整体替换承诺                                             | 通过                                    | 通过           |
| 主计划任务 11 验收锚点同步          | `grep -n 'grep -n "现代化" docs/architecture/rtl-specification.md' docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`                                                                                                                                                                                                                                | 主计划中的 RTL 验收关键词与当前中文文档一致                                              | 通过                                    | 通过           |
| 新增前置设计文档存在性检查          | `test -f docs/architecture/test-harness-specification.md && test -f docs/architecture/stage0-driver-specification.md && test -f docs/architecture/target-platform-specification.md`                                                                                                                                                                       | 三份实现前置设计文档都已补齐                                                             | 通过                                    | 通过           |
| `harness`/驱动/目标规格关键锚点检查 | `grep -n "unknown-group\|--list-groups\|compiler-pass" docs/architecture/test-harness-specification.md`、`grep -n "unsupported-command\|nextpas build <source> --target linux-x86_64" docs/architecture/stage0-driver-specification.md`、`grep -n "unsupported target\|linux-x86_64\|units/<target>/" docs/architecture/target-platform-specification.md` | 新文档覆盖了后续任务 7/9/10 需要依赖的公开行为与拒绝语义                                 | 通过                                    | 通过           |
| 测试组名一致性检查                  | `! rg -n "compile-pass\|compile-fail" docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`                                                                                                                                                                                                 | 主计划与实施计划不再混用旧的测试组名                                                     | 通过                                    | 通过           |
| 架构目录命名说明检查                | `test -f docs/architecture/README.md && rg -n "命名规则\|overview\|matrix\|roadmap\|specification" docs/architecture/README.md`                                                                                                                                                                                                                           | 架构目录存在正式命名说明，并明确标准类型与中文标题的对应关系                             | 通过                                    | 通过           |
| 旧文件名残留检查                    | `! rg -n "directory-blueprint\.md\|rtl-contract\.md\|crt-contract\.md\|distribution-layout\.md\|harness-contract\.md\|stage0-driver-contract\.md\|target-spec-contract\.md" docs`                                                                                                                                                                         | `docs/` 下不再残留旧文件名引用                                                           | 通过                                    | 通过           |
| 文档基线规范存在性检查              | `test -f docs/architecture/documentation-baseline-specification.md && rg -n "文档冲突时按这个顺序裁决\|docs/plans/support/\|.sisyphus/evidence/" docs/architecture/documentation-baseline-specification.md`                                                                                                                                               | phase1 文档分层、裁决顺序和证据角色已被正式写清                                          | 通过                                    | 通过           |
| 计划状态口径同步检查                | `rg -n "执行任务 6-12" docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md && ! rg -n "执行任务 4-12" docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md && rg -n "当前活动批次为批次 B" docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`                                                                                         | 主计划和实施计划不再对当前就绪范围给出互相冲突的口径                                     | 通过                                    | 通过           |

## 错误日志

| 时间戳           | 错误                                                      | 尝试次数 | 解决方式                                      |
| ---------------- | --------------------------------------------------------- | -------- | --------------------------------------------- |
| 2026-03-20 14:02 | `git status` 返回 “not a git repository”                  | 1        | 改为基于 `.sisyphus` 恢复，并直接检查文件系统 |
| 2026-03-20 14:10 | 任务 1 的负向 grep 命中了受限范围条目里的 `dual-platform` | 1        | 重写该条目，并重复执行场景直到通过            |

## 5 个重启问题

| 问题             | 回答                                                                                                                                                                                                                                            |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 我现在在哪？     | 已补齐 11 份核心与专题架构文档，并把 phase1 文档基线、`harness`、`stage0` 驱动和目标规格的实现前置边界补成正式设计                                                                                                                              |
| 我要去哪里？     | 按这些设计文档继续推进任务 7、任务 9、任务 10 和后续本地验证/CI 收口，把文档边界落到仓库骨架与命令路径上                                                                                                                                        |
| 目标是什么？     | 建立 nextPas 第一阶段基线，使后续实现拥有明确约束                                                                                                                                                                                               |
| 我学到了什么？   | 如果不把文档分层和裁决顺序单独冻结下来，README、主计划、实施计划与历史记录会很快出现状态口径漂移；而当前工作区仍不是 Git 仓库，因此提交信息只能继续作为指导                                                                                     |
| 我已经做了什么？ | 恢复并延续了先前上下文，完成了任务 1-5 的基线文档与验证，统一了 `docs/` 下计划/架构/ADR 的中文正式表述，补齐了 RTL、CRT、发行布局、`harness`、`stage0` 驱动与目标平台三类实现前置规范文档，并新增了 phase1 文档基线规范来收口文档层级与状态口径 |
