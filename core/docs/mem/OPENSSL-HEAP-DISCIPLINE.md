# OpenSSL 绑定与 DefaultHeap 纪律

**状态**: Active（Era E · E4-c）
**Owner**: mem + tls
**关联**: [CONSUMER-OBSERVATION](CONSUMER-OBSERVATION-2026-07-17.md) · [PARITY-GO-RUST](PARITY-GO-RUST.md)

---

## 1. 双堆事实

| 堆 | 分配 | 释放 |
|----|------|------|
| **nextpas DefaultHeap** | `GetMem` / `AllocOpenSSLMem` / `CreateParamArray` / `CreateStringStack` 元素 | `FreeMem(ptr,size)` / `FreeParamArray` / `FreeStringStack` 元素 / `FreeOpenSSLMem` |
| **OpenSSL CRYPTO** | `OPENSSL_malloc`、多数 `*_new` / `*_dup` | 对应 `*_free` / `OSSL_PARAM_free` / `OPENSSL_sk_free` 等 |

**禁止**：对 CRYPTO 指针调用 Growing `FreeMem(ptr,size)`；对 CreateParamArray 结果调用 `OSSL_PARAM_free`。

---

## 2. 本模块 helper 约定

| API | 堆 | free |
|-----|-----|------|
| `CreateParamArray` | DefaultHeap | **`FreeParamArray` only**（walk 至 key=nil 计元素数，含 terminator） |
| `OSSL_PARAM_dup` / merge 等 | CRYPTO | **`OSSL_PARAM_free` only** |
| `CreateStringStack` 推入的 C 串 | DefaultHeap | `FreeStringStack`（NUL 长） |
| 外来 sk 元素 | 视来源 | 勿用 FreeStringStack 假设 |
| `AllocOpenSSLMem` | DefaultHeap | `FreeOpenSSLMem`（TryBlockSize → sized） |

---

## 3. E4-c 已修

- `openssl.certificate` fingerprint DER：sized free
- `api.stack` FreeStringStack：sized free + 注释
- `api.utils` FreeOpenSSLMem：TryBlockSize
- `api.param` FreeParamArray：**不再** 误调 `OSSL_PARAM_free`

---

## 4. WAIVE（非 openssl）

见 CONSUMER-OBSERVATION 残余矩阵：platform L0、bench/test harness、simd.memutils TryBlockSize 回落、IAllocator 单参 free。
