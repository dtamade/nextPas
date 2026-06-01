# nextpas.core.http Inbox

最近更新：2026-06-01

## 当前重点

- 我现在负责 `nextpas.core.http`，目标是把它推进为 nextPas 的 L3 核心 HTTP 框架模块。
- 当前阶段不是继续堆功能，而是先把公开接口、测试覆盖、H1 正确性和协作节奏管住。
- 已确认现有 HTTP 面积：22 个源码单元、19 个测试项目、7 个 benchmark 项目。
- 当前仓库是 `main` 普通检出，且已有无关未提交/未跟踪内容；HTTP 工作必须小范围改动，不能碰无关文件。

## 工作纪律

- 每批工作先给任务清单，再执行，最后报告：改了什么、验证证据、复盘、下一步、Git 状态。
- HTTP 公开 API 没有对应单元测试和 heaptrc 零泄漏证据，不算完成。
- benchmark 放到每个切片最后一轮；先保证接口设计、正确性、边界行为和可维护性。
- 重要规划放在这个 inbox；执行细节放在 `task_plan.md`、`findings.md`、`progress.md`。

## 路线图

1. **接管与基线**
   建立 HTTP 控制面板，整理规范、架构、源码、测试、benchmark 现状。

2. **公开契约审计**
   为 facade、`http.base`、`http.intf`、headers、URL、message、router、middleware、server、client、static、websocket、H1 parser/writer/scan/fast 建 API 覆盖矩阵。

3. **H1 正确性加固**
   优先处理请求/响应解析、序列化、chunked、limits、keep-alive、upgrade、恶意/畸形输入。

4. **Server/Client 集成加固**
   验证 handler dispatch、response writer 状态机、错误边界、连接生命周期、shutdown、client 请求行为。

5. **文档与示例**
   API 稳定后更新 `docs/http/README.md` 和架构说明，再补示例。

6. **Benchmark 与优化**
   正确性和覆盖率达标后，再做 FPC RTL、Go、Rust 对照；SIMD 快路径必须由测试和 benchmark 共同证明。

## 下一批建议

下一批先做 **HTTP 公开 API 覆盖矩阵 + 当前测试/heaptrc 基线**。这会告诉我们哪些接口已经可靠，哪些只是“看起来有实现”，然后再按缺口做 TDD 修复。
