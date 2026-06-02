# Findings: config startup example focused smoke

## Repo / Git Safety

- 共享 checkout `main` 当前为 `fbd37d606bd7c5a6c4940bfaf7a54425aa4fca39`。
- 共享 checkout 存在无关脏改动与未跟踪文件，不能在那上面直接开发或做危险操作。
- `codex/config-phase3-example-main-20260603` worktree clean，且 `HEAD` 与当前 `main` 一致，
  适合承接本轮 test-only 收口。

## Config Phase 3 Current Truth

- `README` 已对齐 Phase 3 已落地 API。
- `examples/nextpas.core.config/config_startup_patterns` 已存在并可运行。
- Phase 3D2 仍然没有进主线：`WithInterpolation(...)`、`TConfigInterpolationMode`、
  borrowed view 等都不在当前实现范围内。

## Example Behavior

- example 的成功标记是 `config-startup-patterns-status=pass`。
- example 还会输出多条关键 smoke 行：
  - `snapshot-host=127.0.0.1`
  - `snapshot-port=8080`
  - `snapshot-url=http://127.0.0.1:8080`
  - `configload-host=127.0.0.1`
  - `trybuild-valid=pass`
  - `trybuild-invalid=pass`
  - `mutable-port=9090`
  - `snapshot-still-port=8080`
- 这些输出正好覆盖 `Build`、`ConfigLoad`、`TryBuild`、`BuildConfig` 四条 Phase 3 启动路径。

## Existing Test / Build Patterns

- `tests/nextpas.core.config/` 当前只有 `test_config`、`test_config_phase3`、
  `test_config_nested` 三组 suite。
- 顶层 `core/Makefile` 会自动发现 `tests/**/Makefile`，因此新增 `test_config_examples`
  会自动进入 `make test` 总入口。
- 现有独立 suite 的 Makefile 模式统一为：
  `-MObjFPC -Sh -O2 -gl -gh` + `build/projects/...` 输出目录。
- 进程输出捕获可直接复用 `test_winssl_session_resumption` 的
  `TProcess + poUsePipes + poStderrToOutPut + AppendAvailableProcessOutput` 模式。

## Design Boundaries For This Batch

- 本轮只做 example smoke 自动化，不改 `nextpas.core.config.pas` 的生产实现。
- suite 应优先覆盖“能否跑通”与“关键标记是否出现”，而不是重新在测试里复制 example 内部逻辑。
- 即便本轮没有生产代码改动，也要保持 TDD 纪律：先写新 suite，再跑第一次结果，诚实记录是 RED
  还是 coverage-only 直接 GREEN。

## Final Batch Findings

- 新建 `test_config_examples` 后，首跑就是直接 GREEN：
  - `startup example run passes`
  - `startup example reports key phase3 markers`
- 这说明本轮的真实性质是 coverage expansion / automation closeout，而不是修复现有 config 生产缺陷。
- 顶层总入口 `make TESTS_DIR=tests/nextpas.core.config test` 已确认会自动发现
  `test_config_examples`，因此这组 smoke proof 不会只停留在手工单跑。
- 当前新增 suite 不触碰 `TConfigWatcher`、`ReplaceFrom`、`IRWLock`、struct mapping，也没有引入
  Phase 3D2 的 mode / borrowed-view 设计漂移。
