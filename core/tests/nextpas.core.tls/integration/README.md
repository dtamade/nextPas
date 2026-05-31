# OpenSSL Pascal Bindings - Integration Tests

这是 `fafafa.ssl` OpenSSL Pascal 绑定库的集成测试套件。

## 测试模块

### 已完成的测试 ✅

1. **test_asn1_module.pas** - ASN.1 数据结构测试
   - ASN1_INTEGER 基本操作和 64 位操作
   - ASN1_INTEGER 复制和比较
   - ASN1_STRING 基本操作和类型特定操作
   - ASN1_OCTET_STRING 操作
   - ASN1_TIME 操作
   - **7 个测试,100% 通过率**

2. **test_bio_simple.pas** - BIO (Basic I/O) 测试
   - 内存 BIO 创建和销毁
   - 内存 BIO 读写操作
   - BIO puts/gets 操作
   - BIO 重置功能
   - 从缓冲区创建 BIO
   - 空 BIO 操作
   - BIO 链操作 (push/pop)
   - **7 个测试,100% 通过率**

3. **test_hmac_simple.pas** - HMAC (哈希消息认证码) 测试
   - HMAC-SHA1 单次调用
   - HMAC-SHA256 单次调用
   - HMAC-SHA512 单次调用
   - HMAC 上下文操作 (Init, Update, Final)
   - HMAC 上下文重置
   - HMAC 上下文复制
   - HMAC 大小查询
   - **7 个测试,100% 通过率**

4. **test_bn_simple.pas** - 大数运算测试
   - 大数创建和转换
   - 大数算术运算 (加减乘除)
   - 大数比较
   - 大数模运算

5. **test_rsa_simple.pas** - RSA 加密测试
   - RSA 密钥生成
   - RSA 公钥/私钥加密解密
   - RSA 签名验证

6. **test_dsa_simple.pas** - DSA 签名测试
   - DSA 密钥生成
   - DSA 签名和验证

7. **test_ecdsa_simple.pas** - ECDSA 签名测试
   - ECDSA 密钥生成
   - ECDSA 签名和验证

## 运行测试

### 运行单个测试

```powershell
# 编译测试
fpc -Mobjfpc -Sh -Fu"..\..\src" -Fi"..\..\src" -FU"lib" -FE"bin" test_asn1_module.pas

# 运行测试
.\bin\test_asn1_module.exe
```

### 运行所有测试

使用 PowerShell 脚本运行所有测试:

```powershell
.\run_all_tests.ps1
```

此脚本将:
- 运行所有编译的测试可执行文件
- 显示每个测试的结果和耗时
- 生成总结报告,包括通过/失败统计

## 测试结构

每个测试程序都遵循相同的结构:

1. **初始化** - 加载 OpenSSL 核心和相关模块
2. **测试函数** - 每个测试函数验证特定功能
3. **总结** - 汇总测试结果并返回退出代码

测试输出格式:
- `[PASS]` - 测试通过
- `[FAIL]` - 测试失败
- 最终显示通过率和总结

## 退出代码

- `0` - 所有测试通过
- `1` - 部分或全部测试失败

这使得测试可以轻松集成到 CI/CD 流水线中。

## 测试覆盖的模块

- ✅ `fafafa.ssl.openssl.asn1` - ASN.1 数据结构
- ✅ `fafafa.ssl.openssl.bio` - 基本 I/O
- ✅ `fafafa.ssl.openssl.hmac` - HMAC 消息认证
- ✅ `fafafa.ssl.openssl.bn` - 大数运算
- ✅ `fafafa.ssl.openssl.rsa` - RSA 加密
- ✅ `fafafa.ssl.openssl.dsa` - DSA 签名
- ✅ `fafafa.ssl.openssl.ecdsa` - ECDSA 签名
- ✅ `fafafa.ssl.openssl.ec` - 椭圆曲线
- ✅ `fafafa.ssl.openssl.x509` - X.509 证书

## 添加新测试

要添加新测试模块:

1. 创建新的 `.pas` 文件,命名为 `test_<module>_<type>.pas`
2. 遵循现有测试的结构和模式
3. 确保测试函数返回布尔值 (True = 通过, False = 失败)
4. 使用 `PrintTestHeader` 和 `PrintTestResult` 辅助函数
5. 在主程序中汇总结果并设置正确的退出代码

## 依赖项

- Free Pascal Compiler (FPC) 3.2.0 或更高版本
- OpenSSL 1.1.1 或 3.x
- Windows x64 (当前测试在此平台上)

## 许可证

与主库相同的许可证。
