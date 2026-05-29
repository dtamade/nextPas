# 扩展哈希算法性能测试报告

**日期**: 2025-10-04  
**OpenSSL版本**: 3.4.1  
**测试平台**: Windows x64  
**编译器**: Free Pascal 3.3.1

## 测试概述

本测试评估了 fafafa.ssl 库对多种哈希算法的性能表现，涵盖了 SHA-1、SHA-2 系列（SHA-224、SHA-256、SHA-384）以及 RIPEMD-160 算法。

## 测试配置

- **数据大小**: 100 KB (102,400 bytes)
- **迭代次数**: 1,000 次
- **预热运行**: 10 次
- **测试方法**: 每个算法执行完整的初始化、更新、终结流程

## 测试结果

### 性能数据 (OpenSSL 3.4.1)

| 算法 | 平均耗时 (ms) | 吞吐量 (MB/s) | 状态 |
|------|--------------|--------------|------|
| SHA-1 | 0.319 | 306.13 | ✓ PASS |
| SHA-224 | 0.553 | 176.59 | ✓ PASS |
| SHA-256 | 0.494 | 197.68 | ✓ PASS |
| SHA-384 | 0.432 | 226.06 | ✓ PASS |
| RIPEMD-160 | 0.650 | 150.24 | ✓ PASS |

### 性能排名

按吞吐量从高到低:

1. **SHA-1**: 306.13 MB/s (最快，但不推荐用于安全敏感场景)
2. **SHA-384**: 226.06 MB/s 
3. **SHA-256**: 197.68 MB/s (推荐用于一般安全需求)
4. **SHA-224**: 176.59 MB/s
5. **RIPEMD-160**: 150.24 MB/s

## 分析与结论

### 1. 性能表现

- **SHA-1** 展现了最高的吞吐量（306 MB/s），这符合预期，因为它的哈希长度较短(160位)
- **SHA-384** 性能优于 SHA-256，这是因为 SHA-384 基于 64 位操作，在 x64 平台上更有优势
- **RIPEMD-160** 性能最慢，但仍然满足大多数应用需求

### 2. 安全性建议

虽然 SHA-1 性能最佳，但由于已知的安全漏洞，**不推荐**用于新项目的安全敏感场景：
- **推荐**: SHA-256 或 SHA-384（SHA-2 系列）
- **避免**: SHA-1（除非用于非安全场景，如校验和）

### 3. 实际应用建议

- **一般文件完整性校验**: SHA-256（性能和安全的平衡点）
- **高安全性需求**: SHA-384 或 SHA-512
- **高性能需求（非安全敏感）**: SHA-1
- **特殊兼容性需求**: RIPEMD-160

## API 改进

本次测试过程中对 fafafa.ssl.openssl.api 模块进行了以下改进：

1. **添加了缺失的函数加载**:
   - `EVP_get_digestbyname` - 通过名称获取哈希算法
   - `EVP_sha224` - SHA-224 算法
   - `EVP_ripemd160` - RIPEMD-160 算法

2. **功能完整性**: 现在支持通过字符串名称动态查找和使用哈希算法

## 测试代码

测试程序位于: `tests/performance/test_hash_extended_perf.pas`

运行测试:
```bash
cd tests/performance
./test_hash_extended_perf.exe
```

## 下一步计划

1. ✅ 基础哈希算法性能测试 (SHA-256, SHA-512) - 已完成
2. ✅ 扩展哈希算法测试 (SHA-1, SHA-224, SHA-384, RIPEMD-160) - 已完成
3. 📋 BLAKE2 系列性能测试
4. 📋 SHA-3 系列性能测试
5. 📋 对比 OpenSSL 1.1.x vs 3.x 各算法性能差异

## 参考资料

- [OpenSSL EVP Digest Documentation](https://www.openssl.org/docs/man3.0/man3/EVP_DigestInit.html)
- [SHA-2 (Wikipedia)](https://en.wikipedia.org/wiki/SHA-2)
- [RIPEMD (Wikipedia)](https://en.wikipedia.org/wiki/RIPEMD)

## 结论

fafafa.ssl 库在 OpenSSL 3.4.1 上对所有测试的哈希算法均提供了稳定且高性能的支持：

- ✅ 所有算法测试通过（100% 成功率）
- ✅ 性能表现符合预期
- ✅ API 完整性得到验证和增强
- ✅ 适合在生产环境中使用

---

*本报告由 fafafa.ssl 项目测试团队生成*
