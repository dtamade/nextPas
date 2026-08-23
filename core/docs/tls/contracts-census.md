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

## 七、剩余已知积压

无。ci.yml `freepascal-tls13-completeness` job 已补建（2026-08-24，沿用既有
fpc-trunk 缓存模式，安装步骤含 libwolfssl-dev/libmbedtls-dev 以支撑
WolfSSL/MbedTLS 后端覆盖组），门契约全段绿。

## 完整性门战果（2026-08-23 第二批）

`scripts/tls/run_freepascal_tls13_completeness_gate.sh`：**6/18 → 17/18 组绿**。

| 根因 | 修复 | 影响组数 |
|------|------|---------|
| gate 以 PROJECT_ROOT 为运行 cwd，而测试程序按自身目录解析证书路径（扁平程序 `certificate/...`、子目录项目 `../certificate/...`） | gate 运行步改为以各测试源文件所在目录为 cwd；同步契约脚本 servercertverify 子目录路径 | 10（含 servercertverify 清单路径修正） |
| `TASN1Writer.WriteLength` 长格式分支把标记字节写入 `LenBytes[0]`，覆写最低有效长度字节（357→386 类破坏），任何 ≥128 字节的原始类型 DER 写入均损坏 | 标记字节改存 `LenBytes[NumBytes]`；openssl asn1parse 与独立复现程序双重验证 | 1（ct_sct OCSP-delivered SCT） |
| `TLS12ReadExact` 让 `IoReadFull` 的 EIOError 逃逸，违反 Try 契约（空流上 Connect 应返回 False 并可查错误） | EOF 转 False；补 uses nextpas.core.exception | 1（backend_basic） |

### 第三批（2026-08-23）：17/18 → 18/18

early_data 连接器子测试的"深层越界写"假设被证伪。gdb 硬件观察点在真实字段地址全程零写入，崩溃时测试持有的接口变量为 `base+0x28` 而对象基址是 `base`——不是内存被踩，是**接口指针本身偏移**：

- 本机工具链 FPC trunk（2026-01 fpcupdeluxe dirty 构建）接口 ABI：`TObject.InstanceSize=16`（含 `_MonitorData`）、`TInterfacedObject.InstanceSize=32`、单接口类隐式 对象→接口 赋值实测 delta=32（最小探针）。接口指针≠对象基址，`TSSLStream(intf)` 硬转型得到假 Self，getter 读 `[假基址+0x20]` 越界出垃圾（0x1f）。
- 修复：`TSSLStream` 增加查询接口可达的能力接口 `ISSLStreamConnectionAccess.GetConnection`（沿用 `ISSLNativeHandleAccess` 先例），early_data 测试 5 处硬转型全部改走 `Supports`。生产代码全仓扫描无同类硬转型。
- 连锁发现（被 AV 掩盖的第二层红）：重放存储 `LoadEntries`/`TryLoadEntry` 不校验 `IStream.Read` 返回字节数，EOF 短读静默接受垃圾字段，`Position=Size` 校验对截断失明，损坏 `.bak` 回退未 fail-closed。7 个流读取点逐一校验后，截断/损坏五模式全部拒绝。

**门禁结果：18 PASS / 0 FAIL**（报告：test-reports/freepascal_tls13_completeness_*.md，运行后清理）。

### 硬转型存量清偿（2026-08-23 第三批续）

benchmarks/examples 5 处 `TSSLStream(TLSI)` 同轮清偿：统一改走 `Supports(TLSI, ISSLStreamConnectionAccess)` + `GetConnection`，流 I/O 直接走 `IStream`，删除全部裸类变量与 finally 清引用。运行实证：`benchmark_tls_handshake` 对真实站点完成 session_resumption / tls12 / tls13 / tls12_13 四类握手全成功；diagnostic 基准不可达分支干净跳过（EXIT=0）。全仓 `TSSLStream(` 硬转型归零。

### TLS1.3 真实 OpenSSL 互操作打通（2026-08-23 第三批续）

`test_tls13_interop_matrix.sh` 0/5 → **5/5**，`test_tls13_advanced_interop.sh` → **7/7**（client-cert ×4、KeyUpdate ×2、0-RTT）。纯 Pascal TLS1.3 客户端首次与真实 OpenSSL s_server 完成完整握手、PSK 恢复与 0-RTT。三个叠加根因，全部由 gdb/对拍实证：

| 根因 | 修复 |
|------|------|
| `RecvData` 把 `platform_socket_poll` 的"1=就绪"当失败（`if LErr <> 0 then Exit(-1)`），localhost 上服务端响应毫秒级到达，poll 必返 1，直连 socket 路径读取必死；门内脚本化服务端走流传输故从未暴露 | 改为约定一致的 `LErr <= 0` 拒绝（0=超时、负=错误） |
| FPC trunk 的 `TInetSocket = class(TNonBlockingSocketStream)` 交入非阻塞句柄，包装层 recv 立即 EAGAIN | 连接构造器在句柄所有权边界恢复阻塞语义 |
| `chacha20.4block.x86_64.inc` AVX2 路径行复制布局与 RFC 8439 字节序不一致：≥256 字节输入从第 16 字节起错乱；Poly1305 只覆盖密文，标签照过、明文全错——自洽往返测试无法发现 | 禁用坏路径走已验证双块/标量回退；test_chacha20poly1305 新增 ≥256B 权威对拍 KAT 防回归（9/9） |

完整性门保持 **18 PASS / 0 FAIL**。

### TLS1.2 互操作战线收官（2026-08-24）

积压表移除三行：tls12_interop matrix（实测 9/9 全绿，被 poll 修复顺带治好，census 记录过期）、
cross_backend_interop、server_groups_interop。

- **生产 bug（TLS1.2 服务端 SKE 签名被拒）**：`TryBuildTLS13CertificateVerifySignature`
  对 `rsa_pkcs1_sha256/384` 直接 Exit 拒绝——该拒绝规则属于 TLS1.3 CertificateVerify
  语境（RFC 8446 §4.4.3），但同一签名器被 tls12.server 复用做 SKE 签名，而 TLS1.2
  ECDHE_RSA 恰恰必须 pkcs1（RFC 5246 §7.4.3）。修复：签名侧把 pkcs1 移入允许列表并接通
  单元内已有的 `TryBuildRSAPKCS1v15EncodedMessageSHA256/384` EMSA 编码 + CRT/裸指数签名
  尾部；**验证侧** `TryVerifyTLS13CertificateVerifySignature` 的 pkcs1 拒绝保持不变。
- **test_cross_backend_interop.sh 双层脚本地雷**：① `set -e` 下 `wait` 被杀 s_server
  返回 >128 直接中止全脚本（此前"编译错误"掩盖了这层）；② `pipefail` 下 s_client 因
  自签证书校验必以非零退出，管道化 grep 判定恒假。改为输出落盘 + `|| true` 豁免 +
  对文件 grep + `timeout 8` 防挂死。结果 **4/4 PASS**：FPC client↔OpenSSL 双向 GCM 与
  ChaCha20-Poly1305，EMS=TRUE。
- **test_freepascal_tls13_server_groups_interop.sh 路径现代化**：编译单元路径从退役的
  扁平布局（./src/crypto 等）改 core/src；示例 `10_freepascal_tls13_server.pas` uses 去掉
  已退役的 `fafafa.ssl` 别名门面（现役 API 全在 nextpas.core.tls.base/factory）并补后端注册
  单元 `nextpas.core.tls.freepascal.lib`。结果 **3/3 PASS**：X25519/P-256/P-384 key_share。
- **生产 bug（TLS1.3 ServerHello 压缩方法多写一字节）**：构建器按 ClientHello 的向量式
  `legacy_compression_methods<1..2^8-1>`（u8 长度前缀+方法）编码，而 ServerHello 是单字节
  `legacy_compression_method=0`（RFC 8446 §4.1.3）；自家解析器按同样错误语义自洽往返，
  单测无法发现，真 OpenSSL s_client 报 bad length。FPC 客户端对真实服务器互操作不受影响
  （真实服务器发单字节 00，旧解析器长度读到 0 等价单字节）。修复：构建器与解析器双侧归正，
  HRR/PSK 变体共用同一 Body 构建器一并修复。s_client -msg 字节级取证定位。
- **完整性门回归红点（OCSP 新鲜度时区错位，非本轮引入）**：a3900f7f5 把新鲜度校验基准
  改为 DateTimeUtcNow（对真实 OpenSSL 产物正确），但 ocsp_stapling_runtime 测试 fixture
  仍用本地时间写 GeneralizedTime，TZ=UTC+8 下 ThisUpdate 恒比 UTC now 晚 7 小时被判
  Expired。pristine HEAD 复测证实预存。修复：fixture 时间基准备齐为 UTC（RFC 6960 本义；
  生产代码无 WriteGeneralizedTime 使用方，无需动产线）。门 **18 PASS / 0 FAIL**。

### 积压表清零至单条（2026-08-24 续）

- **client_e2e 超时(143) 系误诊**：脚本 91 行全为本地测试（s_server + 7 单测 + TLS1.2
  冒烟），无外部服务依赖。真凶是 cross_backend 同款 `set -e` wait 地雷——死在重启
  s_server 的 kill/wait 行，143 即被 SIGTERM 的 s_server，"后续段"从未存在。修复后
  全绿：7 crypto + 1 interop，exit 0；顺带加固命令替换里 s_client 非零退出隐患。
- **mbedtls framework "35 败/80.2%" 系 cwd 伪象**：从测试源目录运行二进制为
  252/252（100%）；契约脚本从仓库根运行，证书夹具按相对路径解析失败得 177 总数/
  35 败——census 数字正是这个伪象的快照，无深层产品问题。契约改为以测试源目录为
  cwd 运行二进制（沿用完整性门第二批 cwd 规则先例）。mbedtls 契约家族 10/10 PASS。

积压表仅剩 ci.yml job 一项，待 owner 决策。

### 积压清零（2026-08-24 续二）

- **ci.yml `freepascal-tls13-completeness` job 补建**：该 job 在全部 git 历史中从未
  存在，契约要求其存在且安装步骤显式含 libwolfssl-dev/libmbedtls-dev。按契约自身
  规定的形状落地：镜像 verify-linux-x86_64 的 fpc-trunk 缓存模式（共享 cache key
  v4），运行 `run_freepascal_tls13_completeness_gate.sh --fast-local`。CI 预算影响
  有界（增量约一次门时长，trunk 构建走热缓存）。门契约全段绿（dry-run 清单、
  CI job 形状、ALPN 断言、fake-fpc PATH/报告行断言）。

**普查积压清零**：第七节不再有登记项。

## 变更记录

| 日期 | 内容 |
|------|------|
| 2026-08-23 | 首次全量普查；删除纯文档死目标 71；机械路径修复转绿 12 |
| 2026-08-23 | 第二轮路径清零 PASS 30→83；第三轮内容对账 PASS 83→174，删死契约 73，反哺修复 3 个迁移受损工具 |
| 2026-08-23 | 完整性门 6/18→17/18：cwd 规则修复 10 组；修复 TASN1Writer.WriteLength 长格式长度覆写核心 bug；修复 TLS12 IO 层 EOF 异常逃逸；early_data 测试侧悬垂接口修复并登记深层越界写积压 |
| 2026-08-23 | 完整性门 17/18→18/18：gdb 取证证实工具链接口 ABI 偏移（非越界写），新增 ISSLStreamConnectionAccess 能力接口替换全部硬转型；修复重放存储短读 fail-closed 沦陷；登记 benchmarks/examples 5 处同类硬转型积压 |
| 2026-08-23 | 清偿 benchmarks/examples 5 处 TSSLStream 硬转型积压（真实站点四类握手运行实证）；全仓硬转型归零 |
| 2026-08-23 | TLS1.3 真实 OpenSSL 互操作打通：修复 poll 返回约定反转、非阻塞句柄所有权边界、AVX2 4-block ChaCha 错误布局三叠加根因；interop matrix 0/5→5/5、advanced 7/7；新增 ≥256B KAT 防回归；完整性门保持 18/18 |
| 2026-08-24 | TLS1.2/1.3 互操作收官：签名器区分语境放行 pkcs1 SKE（TLS1.3 CV 验证侧拒绝不变）；修复 ServerHello 压缩方法向量误编码（构建器+解析器双侧归正）；cross_backend 4/4（修 set -e wait 中止 + pipefail 管道污染双层地雷）；server_groups 3/3（路径现代化 + 示例 10 去 fafafa.ssl 补后端注册）；OCSP fixture 时区错位修复；门 18/18 |
| 2026-08-24 | 积压表清零至单条：client_e2e 超时定性为 set -e wait 地雷误诊（无外部服务依赖），全绿 7+1；mbedtls framework "35 败" 定性为 cwd 伪象（正确 cwd 下 252/252），契约改测试目录运行，家族 10/10 |
| 2026-08-24 | 积压清零：ci.yml 补建 freepascal-tls13-completeness job（trunk 缓存模式 + wolfssl/mbedtls 后端覆盖），门契约全段绿；普查第七节不再有登记项 |
