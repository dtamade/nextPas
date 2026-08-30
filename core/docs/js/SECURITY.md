# nextpas.core.js 安全模型

**Owner**：`codex/core-js`
**关联**：`CONTRACT §8`（安全契约）、`DESIGN §6`（超时/内存限）、`TESTING.md`（边界）
**版本**：1.0
**最后更新**：2026-08-30

---

## 1. 威胁模型

| 威胁 | 描述 | 等级 |
|------|------|------|
| T1 恶意脚本 | 不可信 JS 代码（如用户模板）导致 OOM/死循环 | 高 |
| T2 宿主暴露 | `SetHostFunction` 过度暴露 `os/fs/process` | 高 |
| T3 供应链 | `libquickjs.so` 被篡改或多版本不一致 | 中 |
| T4 悬垂/重入 | `TJsValue` 悬垂、`Eval` 重入导致 UAF | 中 |
| T5 二进制注入 | 裸二进制帧绕过 JSON 转义 | 低 |

**非目标**：完整沙箱（`js` 不承诺 VM 级隔离，超时/内存限为唯一护栏）。

---

## 2. 缓解

| 威胁 | 缓解 | 验证 |
|------|------|------|
| T1 | `MemoryLimit`（`JS_SetMemoryLimit`）+ `TimeoutMs`（`JS_SetInterruptHandler` 原子 Deadline） | `test_js_fake` 超时/内存限模拟 + `quickjs_runtime` 真中断 |
| T2 | 默认不暴露 `os/fs/process`；`SetHostFunction` 需显式注册，文档明示攻击面 | `AI_GUIDE` C7 审查 + `SECURITY` 示例白名单 |
| T3 | `platform.dl` 三名探测 + `JsBackendAvailable` 缓存 + 版本无关 ABI（QuickJS-NG 兼容） | `loader` 矩阵测试 |
| T4 | `IsValid` + `TryAs*` + 线程亲和 fail-fast + 重入允许但并发禁止（INV-6/INV-7） | `TESTING §3` 悬垂/线程矩阵 |
| T5 | 二进制走 `TBytes` + `AsJson` base64，经 `encoding` owner，不做裸帧 | `CONTRACT INV-5` + `json` 审查 |

---

## 3. 攻击面清单

| 面 | 暴露 | 控制 |
|----|------|------|
| `Eval` | 任意 JS 代码 | `MemoryLimit`/`TimeoutMs` + 调用方白名单 |
| `SetHostFunction` | 任意 Pascal 闭包 | 显式注册 + 闭包弱引用（防循环） |
| `TryEvalFile` | 任意文件（经 `AFileName`） | `FORMAT_BULK_PARSE_MAX_BYTES` 64 MiB 约束 |
| `NewJson/ToJson` | `json` 互通 | 经 `json` owner 转义，不手写拼接 |

---

## 4. 安全编码规范

- 二进制不裸传，必 `TBytes` + base64。
- 序列化不手写扫描，必 `json` owner。
- `AName` 必 JS Identifier 校验，非法抛 `jecSyntax`。
- `MemoryLimit` 超限 fail-closed，不静默回收。

---

## 5. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：威胁模型 + 缓解 + 攻击面 |

