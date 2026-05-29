# WinSSL Session 复用性能基准测试指南

**测试文件**: `tests/winssl/test_winssl_session_reuse_benchmark.pas`
**创建日期**: 2026-01-18
**目标**: 对比 WinSSL repeated-handshake 基准，并把 `session_configured` 与 `observed_reuse` 分开记录

> 当前 dedicated Windows CI truth 以 `v1.5.0` 后的 WinSSL session lane 为准：
> `observed_reuse=false`，`session_configured=true`。
> 因而这个 benchmark 现在更适合回答：
> - same-context repeated handshake 的时延差异是多少
> - `ISSLSessionResumption` owner path 是否成功配置了待恢复 session
> - 当前运行环境是否真的观测到了 `observed_reuse=true`
>
> `timing delta alone is not proof of native resumed-handshake`。

---

## 测试环境要求

### 必需条件
- **操作系统**: Windows 10+ 或 Windows Server 2016+
- **编译器**: Free Pascal Compiler (FPC) 3.2.0+
- **网络**: 稳定的互联网连接（默认测试使用 `www.cloudflare.com`，可通过环境变量覆盖）

### 可选条件
- **IDE**: Lazarus IDE（便于编译和调试）
- **管理员权限**: 某些网络操作可能需要

---

## 编译测试程序

### 使用 FPC 命令行编译

```bash
cd tests/winssl
fpc test_winssl_session_reuse_benchmark.pas
```

### 使用 Lazarus IDE 编译

1. 打开 Lazarus IDE
2. File → Open → 选择 `test_winssl_session_reuse_benchmark.pas`
3. Run → Build (Ctrl+F9)
4. Run → Run (F9)

---

## 运行测试

### 命令行运行

```bash
cd tests/winssl
test_winssl_session_reuse_benchmark.exe
```

### 预期输出

```
=========================================
WinSSL Session 复用性能基准测试
测试日期: 2026-01-18 14:30:00
=========================================

测试配置:
  目标服务器: www.cloudflare.com
  迭代次数: 50
  协议版本: TLS 1.2
  结果解释: 区分 session_configured 与 observed_reuse

【测试 1】无 Session 复用 - 每次完整握手
测试服务器: www.cloudflare.com
迭代次数: 50
---
..........
完成: 50/50 次成功
平均握手时间: 120.45 ms

【测试 2】同 Context + 配置待恢复 Session
测试服务器: www.cloudflare.com
迭代次数: 50
---
首次连接成功，保存 Session metadata
..........
完成: 50/50 次成功
Session 已配置: 49/50 次
观测到复用: 0/50 次 (0.0%)
平均握手时间: 25.32 ms

=========================================
WinSSL Session 基准对比报告
=========================================

【无 Session 配置（每次新 Context）】
  成功连接: 50
  平均时间: 120.45 ms
  最小时间: 95.23 ms
  最大时间: 156.78 ms
  总时间: 6022.50 ms

【同 Context + 配置待恢复 Session】
  成功连接: 50
  Session 已配置: 49 次
  观测到复用: 0 次 (0.0%)
  平均时间: 25.32 ms
  最小时间: 18.45 ms
  最大时间: 42.67 ms
  总时间: 1266.00 ms

【同 Context 延迟差异】
  时间减少: 95.13 ms
  性能提升: 79.0%

⚠ 当前 conservative truth: observed_reuse=false / session_configured=true
  timing delta alone is not proof of native resumed-handshake
=========================================

按回车键退出...
```

---

## 测试说明

### 测试 1: 无 Session 复用
- **方法**: 每次连接创建新的 Context（不复用凭据句柄）
- **预期**: 每次都执行完整的 TLS 握手
- **典型耗时**: 100-200ms（取决于网络延迟）

### 测试 2: 同 Context + 配置待恢复 Session
- **方法**:
  1. 首次连接通过 `ISSLSessionResumption.GetSession` 获取 Session metadata
  2. 后续连接复用同一个 Context，并通过 `ISSLSessionResumption.SetSession` 配置待恢复 Session
- **预期**:
  - `session_configured` 与 `observed_reuse` 分开记录
  - timing delta 可以存在
  - 但若 `observed_reuse=false`，不能把该结果解释成 native resumed-handshake 已被证实
- **典型耗时**: 视目标服务器与网络条件而定

### 性能提升计算

```
性能提升 = (无Session时间 - 有Session时间) / 无Session时间 × 100%
```

---

## 结果分析

### 成功标准

✅ **结果可用**
- benchmark 程序成功完成
- 同时输出：
  - `Session 已配置`
  - `观测到复用`
- 可以把 timing delta 与 owner-path configured/observed truth 分开分析

⚠️ **保守解释**
- `session_configured=true` 但 `observed_reuse=false`
- 这与当前 dedicated Windows CI truth 一致
- 表示 public surface 已成功配置待恢复 Session，但当前环境没有给出 native resumed-handshake 证据

❌ **需要继续调查**
- 需要检查：
  - 是否通过 `ISSLSessionResumption` 成功配置 Session
  - 当前目标服务器是否真的允许 reconnect/session-ticket 命中
  - Context 是否正确复用
  - 网络环境是否稳定

### 影响因素

1. **网络延迟**
   - 本地网络: 预期提升 70-80%
   - 互联网: 预期提升 80-90%
   - 高延迟网络: 预期提升 85-90%

2. **服务器策略**
   - 某些服务器可能不支持 Session 复用
   - Session 超时策略影响复用率

3. **系统负载**
   - CPU 使用率高时可能影响性能
   - 建议在系统空闲时测试

---

## 故障排查

### 问题 1: 编译失败

**错误**: `Fatal: Can't find unit Windows`
**解决**: 确保在 Windows 系统上编译，WinSSL 仅支持 Windows

**错误**: `Fatal: Can't find unit fafafa.ssl.winssl.lib`
**解决**:
```bash
# 设置 FPC 单元路径
fpc -Fu../../src test_winssl_session_reuse_benchmark.pas
```

### 问题 2: 连接失败

**错误**: `错误: 无法初始化 Winsock`
**解决**: 检查网络连接，确保 Winsock 正常

**错误**: 连接超时
**解决**:
- 检查防火墙设置
- 尝试更换测试服务器（修改代码中的 `LHost`）
- 增加超时时间（修改 `LTimeout` 值）

### 问题 3: Session 复用率低

**现象**: Session 复用率 < 80%
**可能原因**:
1. 服务器不支持 Session 复用
2. Session 超时过短
3. Context 未正确复用

**解决**:
- 检查 `ISSLSessionResumption.IsSessionReused` 与 `session_configured` 是否分开输出
- 尝试不同的测试服务器
- 增加 Session 超时时间

### 问题 4: 性能提升不明显

**现象**: 性能提升 < 50%
**可能原因**:
1. 网络延迟过低（本地测试）
2. 当前环境虽然成功配置 Session，但未真正观测到 reuse
3. 系统负载过高

**解决**:
- 使用远程服务器测试（增加网络延迟）
- 验证 `ISSLSessionResumption` 配置逻辑与 `observed_reuse` 输出
- 在系统空闲时重新测试

---

## 自定义测试

### 修改测试服务器

编辑 `test_winssl_session_reuse_benchmark.pas`:

```pascal
// 可选：通过环境变量覆盖
set FAFAFA_WINSSL_SESSION_HOST=example.com
```

### 修改迭代次数

```pascal
// 可选：通过环境变量覆盖
set FAFAFA_WINSSL_BENCH_ITERATIONS=100
```

### 修改协议版本

```pascal
// 当前默认是 TLS 1.2；如果你要实验其他协议，请单独记录环境差异
LContext.SetProtocolVersions([sslProtocolTLS12]);
```

---

## 预期结果总结

### 当前解释重点

- 先看 `Session 已配置`
- 再看 `观测到复用`
- 如果只有 timing delta，而 `observed_reuse=false`，说明这次 benchmark 还不能证明 native resumed-handshake
- 当前 dedicated Windows CI truth 就是：
  - `observed_reuse=false`
  - `session_configured=true`

### 测试稳定性

- **成功率**: 以环境稳定完成为主
- **失败原因**: 网络超时、服务器拒绝连接
- **建议**: 多次运行取平均值

---

## 下一步

### 测试完成后

1. **记录结果**
   - 保存测试输出
   - 记录性能提升百分比
   - 分别记录 `session_configured` 与 `observed_reuse`

2. **创建性能报告**
   - 不再对比历史固定性能目标
   - 分析影响因素
   - 提出优化建议

3. **生产环境验证**
   - 在实际项目中测试
   - 收集真实使用数据
   - 验证稳定性

---

## 联系和反馈

如有问题或建议，请：
- 查看 `docs/TROUBLESHOOTING.md`
- 查看 `docs/WINSSL_PERFORMANCE_TUNING.md`
- 提交 Issue 到项目仓库

---

**文档版本**: 1.0
**最后更新**: 2026-01-18
**相关文档**:
- `docs/WINSSL_PERFORMANCE_TUNING.md` - 性能调优指南
- `docs/WINSSL_BEST_PRACTICES.md` - 最佳实践
- `.claude/plan/winssl_p2_phase2_completion_report.md` - Phase 2 完成报告
