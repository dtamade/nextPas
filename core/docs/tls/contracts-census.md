# nextpas.core.tls 契约脚本批量试跑普查（2026-08-23）

**范围**：`core/tests/nextpas.core.tls/scripts/*.sh` 共 383 个移植契约脚本
**方法**：限时 45s 并行实跑，按退出码与输出特征分类；对 PATH-BROKEN 类做机械路径重修后复跑二次分堆
**结论**：本轮落地「纯文档死目标删除 71 个 + 可自动修复转绿若干」；其余按清单移交后续 slice

## 一、首轮普查分布

| 类别 | 数量 | 含义 |
|------|------|------|
| PASS | 30 | 现树可直接通过 |
| PATH-BROKEN | 181 | 断言旧布局路径（`src/`、`tests/…` 相对模块根）|
| CONTENT-FAIL | 131 | 路径可达但内容断言失配 |
| OTHER-rc1/rc127/rc2 | 27/10/4 | 其余失败（含调用旧位置辅助脚本的 rc127）|

## 二、PATH-BROKEN 机械修复与复跑

变换：repo_root 深度 `../..`→`../../../..`；`"src/`→`"core/src/`、`"tests/`→`"core/tests/nextpas.core.tls/`（含括号前缀形态）；`tests/scripts/` 与 `core/tests/scripts/` 统一改指本目录。

| 复跑结果 | 数量 | 处置 |
|------|------|------|
| PASS | 12 | 已转绿 |
| PATH-BROKEN | 162 | 进入二次分堆 |

## 三、二次分堆与本轮处置

| 堆 | 数量 | 处置 |
|----|------|------|
| DOCS（仅断言未移植文档树 docs/*、README、.github）| 66+5 | **本轮删除**（与既有死目标判例一致）|
| CODE-RESIDUAL / CODE?（引用真实 .pas 但仍失败）| ~84 | **积压**，逐契约人工对账 |
| STILL-NOMATCH | 8 | **积压**，失败面非典型需个案分析 |
| CONTENT-FAIL（路径已通、内容漂移）| 6 | **积压** |
| OTHER-rc1 | 1 | **积压** |

## 四、存活契约积压清单（后续 slice 工作集）

以下清单即剩余待对账全集（不含本轮已删项）。逐条修复模式参照
`test_winssl_session_resumption_runtime_truth_contract.sh` 的两步法：
① 布局路径重定向至仓库根相对；② 对未移植产物断言做诚实裁剪或按现树重建。

### CONTENT-FAIL
- `test_optional_interface_capability_alignment_contract.sh`
- `test_winssl_session_shim_safe_fallback_contract.sh`
- `test_wolfssl_context_stale_connection_contract.sh`
- `test_wolfssl_ocsp_stapling_source_contract.sh`
### OTHER-rc1
- `test_builder_empty_verifymode_validation_contract.sh`
### PATH-BROKEN
- `test_active_direct_context_servername_surface_classification_contract.sh`
- `test_alpn_owner_path_active_guidance_contract.sh`
- `test_api_surface_context_level_sni_labels_contract.sh`
- `test_backend_capability_matrix_quick_reference_truth_contract.sh`
- `test_backend_capability_matrix_version_history_truth_contract.sh`
- `test_backend_comparison_factory_registration_contract.sh`
- `test_backend_comparison_online_stability_contract.sh`
- `test_backend_framework_context_level_sni_labels_contract.sh`
- `test_cafile_capath_trust_loading_parity_contract.sh`
- `test_callback_capability_truth_contract.sh`
- `test_callback_setter_fail_closed_contract.sh`
- `test_capability_matrix_v12_freepascal_coverage_contract.sh`
- `test_capability_matrix_v12_runtime_truth_contract.sh`
- `test_capability_matrix_v12_session_and_publication_contract.sh`
- `test_capability_precedence_docs_truth_contract.sh`
- `test_clibrary_direct_library_runtime_parity_contract.sh`
- `test_compile_all_modules_fail_closed_contract.sh`
- `test_compile_all_modules_fpc_host_units_override_contract.sh`
- `test_compile_all_modules_unit_output_isolation_contract.sh`
- `test_custom_cipher_capability_truth_contract.sh`
- `test_deprecated_context_servername_compat_surface_labels_contract.sh`
- `test_direct_context_servername_surface_truth_contract.sh`
- `test_direct_library_default_config_parity_contract.sh`
- `test_direct_library_early_data_replay_store_parity_contract.sh`
- `test_direct_library_server_name_backend_contract.sh`
- `test_direct_library_servername_compatibility_contract.sh`
- `test_error_mapping_contract_enum_and_registration_guard.sh`
- `test_freepascal_connectioninfo_completion_contract.sh`
- `test_getconnectioninfo_winssl_direct_core_classification_contract.sh`
- `test_hardware_key_capability_truth_contract.sh`
- `test_intentional_context_level_sni_compatibility_labels_contract.sh`
- `test_interface_audit_capability_current_truth_contract.sh`
- `test_interface_audit_current_truth_contract.sh`
- `test_isslcertificateverification_mbedtls_residual_contract.sh`
- `test_isslcertificateverification_ocsp_runtime_duo_contract.sh`
- `test_isslcertificateverification_root_test_residual_contract.sh`
- `test_isslcertificateverification_winssl_runtime_residual_contract.sh`
- `test_isslconnection_whole_surface_taxonomy_contract.sh`
- `test_isslsessionresumption_generic_examples_contract.sh`
- `test_isslsessionresumption_runtime_owner_path_contract.sh`
- `test_isslsessionresumption_runtime_residual_classification_contract.sh`
- `test_isslsessionresumption_tls13_early_data_owner_path_contract.sh`
- `test_library_default_logcallback_detachment_contract.sh`
- `test_macos_batch_loader_regression_closure_contract.sh`
- `test_managed_result_init_safety_contract.sh`
- `test_managed_result_init_safety_wave2_contract.sh`
- `test_managed_result_init_safety_wave3_contract.sh`
- `test_managed_result_init_safety_wave4_contract.sh`
- `test_managed_result_init_safety_wave5_contract.sh`
- `test_managed_result_init_safety_wave6_contract.sh`
- `test_mbedtls_session_resumption_doc_truth_contract.sh`
- `test_minimal_ci_gate_module_injection_contract.sh`
- `test_optional_backends_pkcs12_capability_truth_contract.sh`
- `test_optional_backends_pkcs12_runtime_freepascal_coverage_contract.sh`
- `test_optional_backends_session_cache_capability_contract.sh`
- `test_password_protected_key_capability_truth_contract.sh`
- `test_pkcs12_helper_guide_active_truth_contract.sh`
- `test_readstring_active_example_signature_truth_contract.sh`
- `test_run_all_module_tests_fpc_host_override_contract.sh`
- `test_security_best_practices_pinning_helper_truth_contract.sh`
- `test_security_entry_examples_public_import_truth_contract.sh`
- `test_specialized_utility_examples_public_import_truth_contract.sh`
- `test_system_roots_public_surface_contract.sh`
- `test_top_level_active_examples_public_import_truth_contract.sh`
- `test_tsslconfig_option_bridge_default_truth_contract.sh`
- `test_tsslconfig_option_bridge_precedence_freeze_contract.sh`
- `test_tsslconfig_option_bridge_surface_truth_contract.sh`
- `test_tsslconfig_servername_surface_truth_contract.sh`
- `test_validate_all_modules_module_scan_and_threshold_contract.sh`
- `test_validate_all_modules_windows_unit_fallback_contract.sh`
- `test_verify_examples_compile_bash32_compat_contract.sh`
- `test_winssl_acceptsecuritycontext_import_contract.sh`
- `test_winssl_capability_source_contract.sh`
- `test_winssl_certificate_extension_contract.sh`
- `test_winssl_certificate_identity_getter_truth_contract.sh`
- `test_winssl_certificate_metadata_truth_contract.sh`
- `test_winssl_certificate_publickey_contract.sh`
- `test_winssl_comprehensive_context_level_sni_labels_contract.sh`
- `test_winssl_comprehensive_factory_registration_contract.sh`
- `test_winssl_connection_safe_statistics_update_contract.sh`
- `test_winssl_context_external_store_contract.sh`
- `test_winssl_integration_multi_expected_failure_contract.sh`
- `test_winssl_integration_multi_negative_path_wrap_contract.sh`
- `test_winssl_integration_multi_tls13_optional_contract.sh`
- `test_winssl_password_callback_partial_publication_contract.sh`
- `test_winssl_private_key_format_truth_contract.sh`
- `test_winssl_runtime_callback_markers_contract.sh`
- `test_winssl_session_cache_runtime_flag_contract.sh`
- `test_winssl_session_reuse_benchmark_truth_contract.sh`
- `test_winssl_session_serialization_roundtrip_contract.sh`
- `test_winssl_session_truth_source_contract.sh`
- `test_winssl_windows_validation_bundle_contract.sh`
- `test_withsni_surface_truth_contract.sh`

## 五、第二轮：路径类清零与复活战果（2026-08-23 续）

对首轮积压 110 个施加第二遍变换（`$ROOT_DIR/src|tests` 变量前缀、
`$SCRIPT_DIR/../.."` 深度变体、裸 `src|tests/<子目录>` 形态）并逐簇甄别后：

| 终态 | 数量 | 说明 |
|------|------|------|
| PASS | **83** | 首轮 30 → 净增 53（含 managed-init wave2/4/5/6 家族复活）|
| PATH-BROKEN | **0** | 布局失配类全数消灭 |
| CONTENT-FAIL | 142 | 路径已通，断言与现树内容漂移——下一对账 slice 主战场 |
| OTHER-rc1/rc2 | 28/4 | 个案分析 |

本轮删除累计：纯文档死目标 71 + 引用消失工具/样例的契约 23 +
被重构吞没单元（tls13.primitives）与旧门面快照（CreateDefaultConfig）
的过期契约 2，共 **96**。

修复手册新增两条判例：
- `$ROOT_DIR/scripts/*_draft.sh` 类调用：draft 工具未随移植存活，
  对应契约一律删；活工具例外重指（如 `scripts/tls/compile_all_modules.py`，
  其旧契约已随批删除，可按新路径重建）。
- 断言「残留直调集合」的契约（isslcertificateverification residual 系）：
  rg glob 必须带模块前缀且目录参数无尾斜杠形态也要覆盖。

## 六、第三轮：内容级对账（2026-08-23 续）

对第二轮积压 174 个（CONTENT-FAIL 142 + OTHER 32）逐簇对账，
按「断言过期→更新现树真值 / 实现回归→修实现 / 死目标→删」三判例处置：

| 终态 | 数量 | 说明 |
|------|------|------|
| PASS | **174** | 第二轮末 83 → 净增 91 |
| CONTENT-FAIL | 5 | 见下方已知积压 |
| OTHER-rc1/rc143 | 4+1 | 运行时互操作与环境依赖类 |
| 存活契约总数 | 184 | 本轮删除 73 个死契约 |

本轮删除（累计 96 → 169）：
- 纯 legacy 文档/workflows 树断言 42（含 6 个变量拼接形态的 workflow 契约）
- 未迁移工具守护契约 18（verify_examples_compile、run_phase2_*、
  run_minimal_ci_gate、run_all_module_tests、run_winssl_tests.ps1 等）
- transport-first 门面再导出枢纽契约 7（门面已按 rustls/go 叙事重构，
  类型由 owner 单元直接提供，"facade must re-export X" 契约整体过时）
- 断言已消失 legacy 示例树的契约 2（digital_signature 示例、
  scan_active_docs_noise_draft 工具）
- 断言未迁移测试程序清单的 run_unit_tests.sh 死运行器 1
- 混合契约裁剪后空壳若干

关键复活修复（断言更新到现树真值）：
- FPC 相对 `-Fu` 按**主文件目录**解析而非 cwd——所有编译型契约
  单元路径统一改为 `"$PWD/..."` 绝对形式
- 根行深度归一化：`$SCRIPT_DIR/../..` 家族（含小写 repo_root）重建为四层
- wolfssl 流工厂参数 AStream→LTransport；winssl 会话 ID 从 SysUtils.Format
  迁至 nextpas.core.text.format.TextFormat；OpenSSL/WolfSSL 子类矩阵
  CreateConnection 参数 TStream→IStream
- 能力落地翻转：FreePascal SupportsPasswordProtectedKeys False→True
  （PKCS#8/OpenSSL PEM 已实现），口令拒绝断言相应撤除
- 版本常量更名 NEXTPAS_SSL_VERSION_STRING→SSL_VERSION_STRING（值不变）
- api_reference 清单重定向到活源码并改声明名干匹配（对签名演进稳健）
- residual 分类四件套按 rg 真值重建期望集（legacy mirror 文件已退役）

反哺修复（迁移受损的工具自身 bug）：
- `scripts/tls/cleanup_fast_local_outputs.sh`：显式相对 --tmp-root 应按
  cwd 解析而非工具位置；PROJECT_ROOT 深度随 scripts/tls 迁移修正
- `core/tests/nextpas.core.tls/benchmarks/run_all_benchmarks.sh`：同族
  路径修正 + BENCHMARKS_DIR 回归脚本同源 + 编译单元路径现代化 +
  benchmark_cert_verify_cache 测试证书路径更新
- `scripts/tls/run_freepascal_tls13_completeness_gate.sh`：PROJECT_ROOT
  与编译单元路径现代化；gate 已可端到端运行（157s），内部尚有红组见下
- `test_context_builder_try.pas` mock 类补齐 IStream 重载（接口演进）

## 七、剩余已知积压（10 个）

| 契约 | 状态 | 备注 |
|------|------|------|
| test_freepascal_tls13_completeness_gate_contract.sh | gate 可运行但内部 12 组红 | 需逐组修 test_freepascal_* 程序 |
| test_tls13_interop_matrix.sh / test_tls13_advanced_interop.sh | 运行时互操作失败 | TLS1.3 client-cert 握手等场景，需真实 s_server 调试 |
| test_freepascal_tls12_interop_matrix.sh | 8 过 1 败 | 单套件待查 |
| test_cross_backend_interop.sh / server_groups_interop.sh | 编译错误 | 冒烟程序需 API 现代化 |
| test_freepascal_tls13_client_e2e.sh | 超时(143) | 加密层 7 过，后续段依赖外部服务 |
| test_mbedtls_framework_owner_surface_contract.sh | 二进制 80.2% 通过（35 败） | legacy framework 测试程序深层对账 |

## 变更记录

| 日期 | 内容 |
|------|------|
| 2026-08-23 | 首次全量普查；删除纯文档死目标 71；机械路径修复转绿 12 |
| 2026-08-23 | 第二轮路径清零 PASS 30→83；第三轮内容对账 PASS 83→174，删死契约 73，反哺修复 3 个迁移受损工具 |
