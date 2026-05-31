# fafafa.ssl 文档索引

## 🧭 当前工程入口（post-release）

- **[plans/2026-05-12-release-v1.5.0-formalization.md](plans/2026-05-12-release-v1.5.0-formalization.md)**
- **[test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)**
- [ROADMAP.md](ROADMAP.md)
- [plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md](plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md)

### Wave C closeout / 审批 / 历史参考

以下条目不再是默认工程入口，仅在需要审批、closeout 或历史对照时使用。

- `test_reports/WAVE_C_CLOSEOUT_STATUS_2026-03-18.md`
- `test_reports/WAVE_C_LOCAL_FIRST_AND_PRE_CI_CHAIN_STATUS_2026-03-16.md`
- `test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md`
- `test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md`

## 入门

- [ROADMAP.md](ROADMAP.md)
- [架构概览](ARCHITECTURE.md)
- [平台支持](PLATFORM_SUPPORT.md)
- [依赖说明](DEPENDENCIES.md)

## 发布与演进

- [plans/2026-05-12-release-v1.5.0-formalization.md](plans/2026-05-12-release-v1.5.0-formalization.md)
- [test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)
- [plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md](plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md)

## 用户指南

- [5 分钟快速入门](guides/5_MINUTE_QUICKSTART.md)
- [用户指南](guides/USER_GUIDE.md)
- [部署指南](guides/DEPLOYMENT_GUIDE.md)
- [FAQ](guides/FAQ.md)
- [常见陷阱](guides/COMMON_PITFALLS.md)
- [错误处理最佳实践](guides/ERROR_HANDLING_BEST_PRACTICES.md)

## 后端指南

- [后端选择指南](BACKEND_SELECTION_GUIDE.md)
- [后端能力矩阵](BACKEND_CAPABILITY_MATRIX.md)
- [MbedTLS 指南](guides/MBEDTLS_USER_GUIDE.md)
- [WinSSL 指南](guides/WINSSL_USER_GUIDE.md)
- [DANE 指南](guides/DANE_USER_GUIDE.md)

## 功能指南

- [Early Data 指南](guides/EARLY_DATA_GUIDE.md)
- [OCSP 使用指南](guides/OCSP_USAGE_GUIDE.md)
- [CT 实现指南](guides/CT_IMPLEMENTATION_GUIDE.md)
- [CMS 用户指南](guides/CMS_USER_GUIDE.md)
- [性能优化指南](guides/PERFORMANCE_GUIDE.md)

## 参考

- [API 参考](reference/API_REFERENCE.md)
- [Native Handle 快速参考](NATIVE_HANDLE_QUICK_REF.md)
- [迁移指南](MIGRATION_GUIDE_V1.1.md)

## 构建与测试

```bash
python3 scripts/compile_all_modules.py
bash scripts/run_minimal_ci_gate.sh --fast-local
bash scripts/run_all_module_tests.sh --fast-local
python3 scripts/check_code_style.py src
```
