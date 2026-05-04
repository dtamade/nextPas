# nextPas 文档基线规范

用这份规范定义 nextPas 第一阶段文档体系的分层、裁决顺序和阅读入口。它的目标不是
增加新的文书负担，而是避免 README、计划、调研记录和进度日志各自维护一套互相打架的
状态口径。

## 先把五类文档分清楚

第一阶段的文档与证据资产必须按下面的角色理解：

| 位置                  | 角色       | 负责什么                                     | 不负责什么                   |
| --------------------- | ---------- | -------------------------------------------- | ---------------------------- |
| `docs/adr/`           | 已接受决策 | 冻结长期范围、平台、自举与兼容性基线         | 不负责拆解执行顺序           |
| `docs/architecture/`  | 稳定规范   | 定义系统边界、职责、公开行为、约束和非目标   | 不负责记录逐次会话历史       |
| `docs/plans/`         | 活动计划   | 定义当前范围下的执行顺序、验收标准和任务依赖 | 不负责改写已接受的稳定边界   |
| `docs/plans/support/` | 历史记录   | 保留调研结论、会话检查点、回放信息和审计痕迹 | 不负责反向覆盖稳定规范       |
| `.sisyphus/evidence/` | 原始证据   | 保留命令输出、失败样本和验证留证             | 不负责单独定义产品或架构意图 |

这份拆分的重点，是让“谁来定义边界”和“谁来记录执行历史”保持可区分。

## 文档冲突时按这个顺序裁决

当不同文档出现口径冲突时，按以下顺序解释：

1. `docs/adr/`
2. `docs/architecture/`
3. `docs/plans/`
4. `docs/plans/support/`
5. `.sisyphus/evidence/`

这里的顺序并不意味着后面的内容不重要，而是表示它们承担的是不同职责：

- ADR 决定第一阶段是否支持 Linux x86_64、是否以 FreePascal 为 `stage0`。
- 架构规范决定 `harness`、`stage0` 驱动、目标规格和发行布局的稳定边界。
- 活动计划决定当前要先做哪一批任务，以及验收怎么跑。
- `support/` 记录“当时发生了什么”，但不能回写成新的正式边界。
- 证据说明“命令实际跑出了什么”，但不能单独替代规范文本。

因此，第一阶段不应再把任意单个计划文件写成“全仓唯一事实来源”。

## 用这个顺序阅读当前主线文档

如果你要恢复 nextPas 当前上下文，按下面的顺序进入：

1. `docs/adr/0001-fpc-reference-baseline.md`，先锁定平台、自举和兼容性基线。
2. `docs/architecture/README.md`，了解架构目录和专题入口。
3. `docs/architecture/overview.md`、`docs/architecture/compatibility-matrix.md`、
   `docs/architecture/master-roadmap.md`、`docs/architecture/bootstrap-roadmap.md`，
   先读总览、兼容范围、全局主线与自举推进。
4. 按需进入各份 `*-specification.md`，查看专题边界。
5. `docs/plans/README.md`，确认活动计划和历史记录各放在哪里。
6. `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`，确认当前 rolling window
   的批次顺序。
7. `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md` 与
   `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`，回看已完成 phase1 的
   历史执行面。
8. 最后再读 `docs/plans/support/` 与 `.sisyphus/evidence/`，回放历史与验证输出。

这个顺序的目的，是先确定稳定意图，再进入当前执行面，最后才看历史轨迹。

## 更新规则要保持同步

为了避免同一范围的文档继续分叉，第一阶段遵守以下更新规则：

- 同一范围继续推进时，优先更新现有文档，而不是平行新建第二份主文档。
- 只有当范围发生实质变化时，才新建新的 `...-plan.md`。
- 新增稳定设计时，必须同时更新 `docs/architecture/README.md` 的目录入口。
- 计划状态变化时，`bootstrap-plan.md` 和 `implementation-plan.md` 的就绪状态要同步收口。
- `docs/plans/support/` 只追加新的历史检查点，不回写旧阶段来假装它们原本就包含新结论。
- `.sisyphus/evidence/` 继续保留原始输出，不把证据文件当作稳定说明文档引用。

## 这份规范要挡住的反模式

- 不把某一份计划文档写成覆盖 ADR、架构规范和历史记录的“唯一真相来源”。
- 不让 `support/` 下的会话记录反向决定稳定架构边界。
- 不在入口文档里只列出部分专题规范，导致读者误以为其余规范不存在。
- 不继续保留过时的状态口径，例如明明任务 1-5 已完成，却还写成“执行任务 4-12”。

第一阶段要得到的是一套可恢复、可裁决、可继续扩展的文档基线，而不是一组互相引用、
但没有明确层级的 Markdown 文件。
