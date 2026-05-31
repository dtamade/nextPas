# fafafa.ssl 当前路线图

> **更新**: 2026-05-29
> **用途**: 当前项目状态、演进方向、验证入口。

---

## 当前状态

- engineering_state: RELEASED
- approval_gate: sequential execution plan selected
- current_execution_control_plane: `framework excellence sequential execution`
- current_release_plan: `docs/plans/2026-05-12-release-v1.5.0-formalization.md`
- current_release_readiness: `docs/test_reports/RELEASE_READINESS_V1.5.0.md`
- current_release_status: `RELEASED`
- current_workflow_surface: `.github/README.md`
- wave_c_role: `closeout / approval / historical reference only`
- product_mainline: `SSL/TLS backend completeness roadmap`
- current_active_batch: `docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md`
- next_route_candidate: `docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md`
- current_architecture_north_star: `docs/plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md`
- current_default_build: `python3 scripts/compile_all_modules.py`
- current_default_gate: `bash scripts/run_minimal_ci_gate.sh --fast-local`
- current_focused_gate: `bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local`

---

## 后端成熟度

| 后端 | 状态 | 备注 |
|------|------|------|
| OpenSSL | 生产就绪 | 完整 TLS 1.2/1.3, OCSP, CT, Early Data |
| MbedTLS | 生产就绪 | TLS 1.2/1.3 核心功能 |
| WolfSSL | 生产就绪 | TLS 1.2/1.3, Early Data (需 helper) |
| WinSSL | 生产就绪 | Windows 原生 Schannel |
| FreePascal | 生产就绪 | 纯 Pascal TLS 1.2/1.3, 7 轮安全审查通过 (L6 3/3) |

---

## 架构演进记录

- `v1.5.0` 的发布链已经闭环
- 当前默认执行控制面已从 post-release route selection 切到 framework excellence sequential execution

当前活跃批次转入 framework excellence sequential execution master plan，把
`TSSLConfig` scope surgery、facade simplification、FreePascal excellence 和
performance / ops excellence 排成一个顺序执行队列。

`TSSLConfig` scope surgery 已经完成四条实现 slice：
- `TSSLContextConfig` additive surface / projection / factory overload
- `TSSLContextBuilder` 通过 `TSSLContextConfig` 创建 context
- `TSSLFactory.CreateContext(const TSSLContextConfig)` 已经直接应用 context-safe fields
- builder ordinary certificate/key/trust material 已经通过 `TSSLContextConfig` 投影

下一条 Stage 2 切片继续收 active docs/examples 与 high-level guidance，再进入 facade simplification、FreePascal excellence、performance / ops excellence。

---

## 构建与验证

```bash
python3 scripts/compile_all_modules.py
bash scripts/run_minimal_ci_gate.sh --fast-local
bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local
python3 scripts/check_code_style.py src
```

---

## 相关计划

- [Release v1.5.0 formalization](plans/2026-05-12-release-v1.5.0-formalization.md)
- [Release Readiness v1.5.0](test_reports/RELEASE_READINESS_V1.5.0.md)
- [Framework excellence spec](plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md)
- [Framework excellence sequential master plan](plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md)
- [TSSLConfig scope surgery blueprint](plans/2026-05-25-tsslconfig-scope-surgery-blueprint.md)
- [TSSLConfig slimming roadmap](plans/2026-05-18-tsslconfig-public-surface-slimming-roadmap.md)
