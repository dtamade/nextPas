# nextPas 架构原则与质量门槛规范

这份规范定义 nextPas 的长期架构原则、质量门槛和推进纪律。它回答的不是“下一轮具体改哪几个
文件”，而是“每一轮实现、设计和文档怎样持续朝 FreePascal 领域一流现代 Pascal
开发环境靠拢”。

如果某个局部计划、专题规范或实现批次和本规范冲突，先按本规范重新审视方向，再回到对应
ADR、专题规范和活动计划里落地。它不替代 `master-roadmap.md`、`compiler-roadmap.md`
或 `bootstrap-roadmap.md`，而是约束这些路线图如何做取舍。

## 长期目标必须能落到工程门槛

nextPas 的长期目标不是“有一个能跑的 Pascal 编译器”，而是一整套现代 Pascal
开发环境：

- 兼容 FreePascal 生态中应当保留的语言、RTL 和开发体验边界
- 拥有清晰的 compiler kernel、toolchain control plane、workspace truth、package workflow、
  language service、GUI framework 和 IDE 演进路线
- 能让命令行、测试、编辑器、包管理、发行布局和未来 IDE 共享同一套事实对象
- 在正确性、性能、可维护性和用户体验上持续优于“脚本拼接 + 历史副作用”的旧路径

因此，任何新能力都不能只以“这次看起来能输出结果”为完成标准。完成标准必须同时回答：

- 这条能力的 owner 是谁
- 它消费和产出的 truth object 是什么
- 它怎样被 `build/verify_local.sh` 或同等级别的 fresh gate 冻结
- 它怎样避免和已有 compiler / workspace / package / toolchain truth 分叉
- 它的当前非目标是什么，哪些能力仍然不能宣称已经完成

## 正确性先于表面进度

nextPas 接受小步推进，但不接受把未验证的行为包装成已完成能力。

每个实现切片至少要满足这些要求：

- 先定位真实 failure boundary，再决定设计切片
- 优先修正 owner、identity、lifetime、result envelope 和 diagnostics，而不是只补输出文本
- promotion gate 必须覆盖当前最容易漂移的 contract 字段
- 文档必须把当前实现边界写诚实，不能把 deferred 能力写成 ready
- 已经 fresh 通过的 gate 不因为新功能而被弱化

如果局部改动能让一个 smoke 变绿，但会让 truth object 变得更分散，应该停下来重新设计。

## Shared truth 先于命令扩张

命令表面可以增长，但每条命令都必须薄。`stage0`、test harness、developer tooling、
package workflow、language service 和 future IDE 不应该各自重新发现 workspace、target、
package、toolchain 或 artifact truth。

推荐方向是：

- command entrypoint 负责 parse intent、选择 workspace / target、调用 shared core、投影结果
- compiler/session 层拥有 source、unit graph、semantic model、backend plan 和 diagnostics truth
- workspace/package/toolchain/runtime truth 必须先成为 typed object，再投影成 line output 和
  `command-envelope=<json>.result`
- 新命令只能扩展现有 truth 的 projection，不能并行维护第二套事实

任何“先在命令里临时拼一遍路径，后面再抽出来”的做法都需要明确还债计划，并尽量避免进入
长期 contract。

## Thin entrypoint + shared core 是默认形态

nextPas 的公开工具面会越来越大，但架构形态必须保持克制：

- CLI、harness、verify、doctor、env、pkg、query、future LSP 和 future IDE 都应是 thin entrypoint
- shared core 负责真实语义、解析、计划、执行、状态和诊断
- projection 层负责稳定输出，不负责重新推导业务事实
- result envelope 是机器可消费 contract，不是调试日志
- line-based output 是 human / shell 友好的 mirror，不能成为唯一真相

当一个 entrypoint 开始复制 session、workspace、package、toolchain 或 diagnostics 逻辑时，
这就是架构回退信号。

## 性能设计要前置

性能不能等“功能全部做完”以后再补。nextPas 要成为一流 Pascal 开发环境，必须从数据结构和
失效边界开始考虑性能。

长期实现应优先支持：

- cheap to diff 的 source database、green tree、semantic snapshot 和 workspace model
- 明确的 invalidation boundary，而不是每次都全仓重扫
- 可复用的 typed truth object，而不是跨层反复解析字符串
- 可缓存、可比较、可解释的 build / toolchain / package / language-service plan
- 对 hot path 的分配、拷贝、排序和 IO 行为保持敏感

如果某个设计只能依靠“重新扫描整个仓库”或“重复运行完整工具链”来维持正确性，它最多是临时
实现，不应成为长期架构。

## 可维护性来自清晰所有权

nextPas 的复杂度会自然增长，所以可维护性必须来自结构，而不是来自注释弥补。

每个子系统都应该能回答：

- 它拥有哪些状态
- 它不拥有哪些状态
- 它向下游承诺哪些稳定 API / record / envelope 字段
- 它怎样释放或转交 ownership
- 它的测试或 verify gate 覆盖了哪个 contract

共享 helper 和 abstraction 只有在减少真实重复、收紧边界或匹配既有模式时才值得加入。
为了“看起来更抽象”而加入的层，会让后续自举、IDE 和 package workflow 更难接入。

## 优雅性来自统一语言

一流框架不只是功能多，还要让开发者能预测它怎样表达状态。

nextPas 的公开面应该持续使用统一词汇：

- command / selector / target / workspace / package / artifact / environment / doctor / query
- status / readiness / failure-kind / diagnostic-code / build-trace-ref / tool-status-event
- manifest / lockfile / install-plan / package-root / source-root
- source database / unit graph / semantic model / typed HIR / MIR / backend plan

新增字段前先检查是否已有相同语义的词汇。新增词汇必须能解释为什么不是既有字段的扩展。

## 兼容性必须诚实

nextPas 的目标包含 FreePascal 兼容，但兼容性不能靠口号维持。

当前硬护栏仍然成立：

- 第一阶段只支持 Linux x86_64
- FreePascal 是 `stage0`
- 第一阶段不发明新 Pascal 语法
- `ABI compatibility is deferred`

因此，文档和命令输出不能宣称未落地的 ABI、完整 package manager、完整 IDE、完整 LSP、
完整 GUI framework、多平台发行或自举完成。可以写长期方向，但必须同时写清当前实现边界和
promotion gate。

## 决策流程

每次进入高风险切片前，先按这个顺序收束：

1. 读相关 ADR、`docs/architecture/README.md`、`overview.md`、`master-roadmap.md` 和专题规范。
2. 找到当前实现中的 owner、truth object、projection 和 verify gate。
3. 判断这轮是设计切片、implementation slice、contract hardening，还是 docs truth sync。
4. 对复杂取舍先写清非目标和回退信号，再实现。
5. 实现后 fresh 运行 `bash build/verify_local.sh`，除非用户明确缩小验证范围。
6. 收口前做简短 review，确认没有弱化已有 contract，再提交 git。

这个流程不是为了放慢速度，而是为了让每轮推进都留下可追溯的工程事实。

## Promotion gate 的最低要求

新能力进入长期路线图或公开命令面前，至少需要一个 promotion gate：

- focused fixture 或 smoke 能复现关键成功/失败边界
- `build/verify_local.sh` 冻结关键 line output 和 envelope 字段
- docs 写清当前 ready / deferred / non-goal
- tracking 文件记录为什么这轮值得推进，以及验证结果
- 如果 gate 暂时不能自动化，必须写明手动证据和后续自动化计划

没有 gate 的能力可以作为探索记录存在，但不能被写成稳定已交付能力。

## 回退信号

出现下面情况时，应优先回退到设计和所有权整理：

- 两个子系统开始各自维护 workspace、target、package 或 artifact truth
- shell 文本成为唯一 contract，envelope 没有同步字段
- backend、IDE、package manager 或 language service 复制 compiler semantic truth
- package workflow 绕过 manifest / lock / install-plan truth 直接执行副作用
- performance 只能靠全仓重扫或重复完整构建维持
- 文档声称的能力超过 fresh verify 能证明的范围
- 新抽象只移动代码，没有收紧 owner、lifetime、API 或验证边界

一旦出现这些信号，下一轮优先级应从“继续扩能力”切回“收紧 shared truth 和 gate”。
