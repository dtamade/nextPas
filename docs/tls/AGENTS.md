# Repository Guidelines

## 项目结构与模块组织
核心 Pascal 源码位于 `src/`。主门面入口是 `src/fafafa.ssl.pas`，推荐 builder 入口是 `src/fafafa.ssl.context.builder.pas`；`src/fafafa.ssl.base.pas` 主要承载底层 source truth / supporting types。后端实现按 `fafafa.ssl.openssl.*` 与 `fafafa.ssl.winssl.*` 等拆分，日志与工具集中在 `fafafa.ssl.utils`。`bin/` 中包含可复现的示例可执行文件，`lib/x86_64-{linux,win64}` 保存可直接引用的单元输出，除非必要不要手动改写。示例与复现脚本放在 `examples/`（生产示例使用 `examples/production`）。测试集中在 `tests/`，按诊断、集成、性能、单元分类，文件命名保持 `test_<领域>_<场景>.pas`，以便脚本检索。规范、审计和架构说明位于 `docs/` 或根目录报告，自动化脚本和工具分别放在 `scripts/`、`tools/`。

## 构建、测试与开发命令
在仓库根目录优先运行 `python3 scripts/compile_all_modules.py` 作为默认编译门禁；需要覆盖当前本地最小回归时，再运行 `bash scripts/run_minimal_ci_gate.sh --fast-local`。如果只想确认 Phase 2 入口是否仍可执行，可追加 `bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local`。`build_linux.sh` 仍保留为历史兼容入口，但不再是默认文档路径。评审前执行 `python3 scripts/check_code_style.py src` 捕捉模式或缩进问题。Windows 贡献者可通过 `powershell -ExecutionPolicy Bypass -File run_all_tests.ps1` 自动编译运行每个 `test_openssl_*.pas`；Linux 开发者可用 `fpc -Fu./src -Fu./src/openssl tests/test_<name>.pas` 或自定义脚本逐个执行。

本地最小门禁（推荐 fast-local，不污染 git 工作区）：

```bash
bash scripts/run_minimal_ci_gate.sh --fast-local
```

## 代码风格与命名约定
所有 Pascal 单元须以 `{$mode ObjFPC}{$H+}` 开头，面向 Windows 的单元（`winssl`、`factory`、`abstract` 等）还需 `{$CODEPAGE UTF8}`。统一使用两个空格缩进、禁止 Tab，单行不超过 120 个字符。命名遵循 T/I/L/A/F 前缀：`TMyClass`、`IMyInterface`、局部 `LValue`、参数 `AValue`、字段 `FValue`；常量使用全大写下划线（如 `MAX_BUFFER_SIZE`）。对外 API 需要块注释说明用途，`scripts/check_code_style.py` 会验证这些规则。

## 测试指引
功能和诊断测试紧邻对应模块（如 `tests/test_ssl_handshake.pas`、`tests/diagnose_*`、`tests/integration`），共用的日志与统计例程位于 `tests/framework`，新增测试应复用这些工具并保持文件名与被测模块一致。目标是维持 `TEST_COVERAGE_FINAL_REPORT.md` 中 ≥95% 的场景覆盖，新功能需同时提供成功与失败路径，必要时补充 WinSSL/OpenSSL 对照。若新增长时间测试，请放入 `tests/performance` 并在相关 PowerShell 运行脚本中标注。

## 提交与 Pull Request 规范
分支命名遵循 `feature/<topic>`、`fix/<bug>`、`docs/<section>` 等格式。提交信息使用 `type: 简要说明`（`feat`、`fix`、`docs`、`test`、`refactor`、`perf`、`chore`、`style`），正文可补充细节与 Issue 关联（如 `Fixes #123`）。创建 PR 前确认：可编译、测试通过、文档/CHANGELOG 已更新，并完成 CONTRIBUTING 中的核对单。提交流程需要填写 PR 模板（说明、变更类型、测试证明、检查清单），若触及诊断或工具，请附日志、截图或命令输出摘要。

## 安全与配置提示
不要硬编码私密材料；证书与密钥请放在 `examples/production` 或本地忽略路径，并通过 `fafafa.ssl.openssl.certstore.pas`、`fafafa.ssl.winssl.certstore.pas` 指向 `/etc/ssl/certs` 或 `%ProgramData%\Microsoft\Crypto\RSA`。需要临时 TLS 端点时优先使用 `scripts/local_tls_server.sh`，避免暴露真实服务。若调整加密默认值或系统库行为，请在 `ARCHITECTURE.md` 或独立说明中记录原因，确保后续贡献者了解安全边界。
