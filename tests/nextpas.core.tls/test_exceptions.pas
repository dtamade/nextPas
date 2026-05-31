program test_exceptions;

{$mode objfpc}{$H+}

{
  test_exceptions - 异常处理测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 异常处理测试
    验证 nextpas.core.tls.exceptions.pas 中的异常类定义和行为

    此测试可在 Linux 上运行,不需要实际的 SSL 操作

  测试内容:
    1. 异常类层次结构
    2. 异常构造函数
    3. 异常属性访问
    4. 异常继承关系
    5. 异常消息格式化
}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestBaseExceptionClass;
var
  LException: ESSLException;
begin
  WriteLn('【测试 1】基础异常类');
  WriteLn('---');

  // 测试简单构造函数
  LException := ESSLException.Create('Test error');
  try
    Assert(LException.Message = 'Test error', '简单构造函数设置消息');
    Assert(LException.ErrorCode = sslErrNone, '默认错误码为 sslErrNone');
    Assert(LException.NativeError = 0, '默认原生错误码为 0');
    Assert(LException.Context = '', '默认上下文为空');
  finally
    LException.Free;
  end;

  // 测试带错误码的构造函数
  LException := ESSLException.Create('Test error', sslErrTimeout);
  try
    Assert(LException.Message = 'Test error', '带错误码构造函数设置消息');
    Assert(LException.ErrorCode = sslErrTimeout, '错误码正确设置');
  finally
    LException.Free;
  end;

  // 测试带上下文的构造函数
  LException := ESSLException.Create('Test error', sslErrCertificate, 'TestContext');
  try
    Assert(LException.Message = 'Test error', '带上下文构造函数设置消息');
    Assert(LException.ErrorCode = sslErrCertificate, '错误码正确设置');
    Assert(LException.Context = 'TestContext', '上下文正确设置');
  finally
    LException.Free;
  end;

  WriteLn;
end;

procedure TestExceptionWithContext;
var
  LException: ESSLException;
begin
  WriteLn('【测试 2】完整上下文异常');
  WriteLn('---');

  // 测试 CreateWithContext
  LException := ESSLException.CreateWithContext(
    'Connection failed',
    sslErrConnection,
    'TOpenSSLConnection.Connect',
    12345,
    sslOpenSSL
  );
  try
    // CreateWithContext 会在消息中添加上下文和原生错误码
    Assert(Pos('Connection failed', LException.Message) > 0, '消息包含原始文本');
    Assert(LException.ErrorCode = sslErrConnection, '错误码正确');
    Assert(LException.Context = 'TOpenSSLConnection.Connect', '上下文正确');
    Assert(LException.NativeError = 12345, '原生错误码正确');
    Assert(LException.LibraryType = sslOpenSSL, '库类型正确');
  finally
    LException.Free;
  end;

  WriteLn;
end;

procedure TestExceptionFormatting;
var
  LException: ESSLException;
begin
  WriteLn('【测试 3】异常消息格式化');
  WriteLn('---');

  // 测试 CreateFmt
  LException := ESSLException.CreateFmt('Error code: %d, message: %s', [42, 'test']);
  try
    Assert(Pos('42', LException.Message) > 0, '格式化包含数字');
    Assert(Pos('test', LException.Message) > 0, '格式化包含字符串');
  finally
    LException.Free;
  end;

  WriteLn;
end;

procedure TestInitializationExceptions;
var
  LException: ESSLInitError;
  LInitException: ESSLInitializationException;
  LConfigException: ESSLConfigurationException;
begin
  WriteLn('【测试 4】初始化相关异常');
  WriteLn('---');

  // 测试 ESSLInitError
  LException := ESSLInitError.Create('Init failed');
  try
    Assert(LException is ESSLException, 'ESSLInitError 继承自 ESSLException');
    Assert(LException.Message = 'Init failed', 'ESSLInitError 消息正确');
  finally
    LException.Free;
  end;

  // 测试 ESSLInitializationException (别名)
  LInitException := ESSLInitializationException.Create('Init failed');
  try
    Assert(LInitException is ESSLInitError, 'ESSLInitializationException 继承自 ESSLInitError');
    Assert(LInitException is ESSLException, 'ESSLInitializationException 继承自 ESSLException');
  finally
    LInitException.Free;
  end;

  // 测试 ESSLConfigurationException
  LConfigException := ESSLConfigurationException.Create('Config error');
  try
    Assert(LConfigException is ESSLException, 'ESSLConfigurationException 继承自 ESSLException');
    Assert(LConfigException.Message = 'Config error', 'ESSLConfigurationException 消息正确');
  finally
    LConfigException.Free;
  end;

  WriteLn;
end;

procedure TestCryptoExceptions;
var
  LCryptoError: ESSLCryptoError;
  LKeyException: ESSLKeyException;
  LEncryptException: ESSLEncryptionException;
  LDecryptException: ESSLDecryptionException;
begin
  WriteLn('【测试 5】加密操作异常');
  WriteLn('---');

  // 测试 ESSLCryptoError
  LCryptoError := ESSLCryptoError.Create('Crypto error');
  try
    Assert(LCryptoError is ESSLException, 'ESSLCryptoError 继承自 ESSLException');
  finally
    LCryptoError.Free;
  end;

  // 测试 ESSLKeyException
  LKeyException := ESSLKeyException.Create('Key error');
  try
    Assert(LKeyException is ESSLCryptoError, 'ESSLKeyException 继承自 ESSLCryptoError');
    Assert(LKeyException is ESSLException, 'ESSLKeyException 继承自 ESSLException');
  finally
    LKeyException.Free;
  end;

  // 测试 ESSLEncryptionException
  LEncryptException := ESSLEncryptionException.Create('Encryption failed');
  try
    Assert(LEncryptException is ESSLCryptoError, 'ESSLEncryptionException 继承自 ESSLCryptoError');
  finally
    LEncryptException.Free;
  end;

  // 测试 ESSLDecryptionException
  LDecryptException := ESSLDecryptionException.Create('Decryption failed');
  try
    Assert(LDecryptException is ESSLCryptoError, 'ESSLDecryptionException 继承自 ESSLCryptoError');
  finally
    LDecryptException.Free;
  end;

  WriteLn;
end;

procedure TestCertificateExceptions;
var
  LCertError: ESSLCertError;
  LCertException: ESSLCertificateException;
  LLoadException: ESSLCertificateLoadException;
  LParseException: ESSLCertificateParseException;
  LVerifyException: ESSLCertificateVerificationException;
  LExpiredException: ESSLCertificateExpiredException;
begin
  WriteLn('【测试 6】证书相关异常');
  WriteLn('---');

  // 测试 ESSLCertError
  LCertError := ESSLCertError.Create('Cert error');
  try
    Assert(LCertError is ESSLException, 'ESSLCertError 继承自 ESSLException');
  finally
    LCertError.Free;
  end;

  // 测试 ESSLCertificateException (别名)
  LCertException := ESSLCertificateException.Create('Cert error');
  try
    Assert(LCertException is ESSLCertError, 'ESSLCertificateException 继承自 ESSLCertError');
  finally
    LCertException.Free;
  end;

  // 测试 ESSLCertificateLoadException
  LLoadException := ESSLCertificateLoadException.Create('Load failed');
  try
    Assert(LLoadException is ESSLCertError, 'ESSLCertificateLoadException 继承自 ESSLCertError');
  finally
    LLoadException.Free;
  end;

  // 测试 ESSLCertificateParseException
  LParseException := ESSLCertificateParseException.Create('Parse failed');
  try
    Assert(LParseException is ESSLCertError, 'ESSLCertificateParseException 继承自 ESSLCertError');
  finally
    LParseException.Free;
  end;

  // 测试 ESSLCertificateVerificationException
  LVerifyException := ESSLCertificateVerificationException.Create('Verify failed');
  try
    Assert(LVerifyException is ESSLCertError, 'ESSLCertificateVerificationException 继承自 ESSLCertError');
  finally
    LVerifyException.Free;
  end;

  // 测试 ESSLCertificateExpiredException
  LExpiredException := ESSLCertificateExpiredException.Create('Cert expired');
  try
    Assert(LExpiredException is ESSLCertificateVerificationException,
           'ESSLCertificateExpiredException 继承自 ESSLCertificateVerificationException');
    Assert(LExpiredException is ESSLCertError,
           'ESSLCertificateExpiredException 继承自 ESSLCertError');
  finally
    LExpiredException.Free;
  end;

  WriteLn;
end;

procedure TestNetworkExceptions;
var
  LNetworkError: ESSLNetworkError;
  LConnectionException: ESSLConnectionException;
  LHandshakeException: ESSLHandshakeException;
  LProtocolException: ESSLProtocolException;
  LTimeoutException: ESSLTimeoutException;
begin
  WriteLn('【测试 7】网络相关异常');
  WriteLn('---');

  // 测试 ESSLNetworkError
  LNetworkError := ESSLNetworkError.Create('Network error');
  try
    Assert(LNetworkError is ESSLException, 'ESSLNetworkError 继承自 ESSLException');
  finally
    LNetworkError.Free;
  end;

  // 测试 ESSLConnectionException
  LConnectionException := ESSLConnectionException.Create('Connection failed');
  try
    Assert(LConnectionException is ESSLNetworkError, 'ESSLConnectionException 继承自 ESSLNetworkError');
  finally
    LConnectionException.Free;
  end;

  // 测试 ESSLHandshakeException
  LHandshakeException := ESSLHandshakeException.Create('Handshake failed');
  try
    Assert(LHandshakeException is ESSLConnectionException,
           'ESSLHandshakeException 继承自 ESSLConnectionException');
  finally
    LHandshakeException.Free;
  end;

  // 测试 ESSLProtocolException
  LProtocolException := ESSLProtocolException.Create('Protocol error');
  try
    Assert(LProtocolException is ESSLConnectionException,
           'ESSLProtocolException 继承自 ESSLConnectionException');
  finally
    LProtocolException.Free;
  end;

  // 测试 ESSLTimeoutException
  LTimeoutException := ESSLTimeoutException.Create('Timeout');
  try
    Assert(LTimeoutException is ESSLConnectionException,
           'ESSLTimeoutException 继承自 ESSLConnectionException');
  finally
    LTimeoutException.Free;
  end;

  WriteLn;
end;

procedure TestResourceExceptions;
var
  LInvalidArg: ESSLInvalidArgument;
  LResourceException: ESSLResourceException;
  LOutOfMemory: ESSLOutOfMemoryException;
  LFileNotFound: ESSLFileNotFoundException;
begin
  WriteLn('【测试 8】资源相关异常');
  WriteLn('---');

  // 测试 ESSLInvalidArgument
  LInvalidArg := ESSLInvalidArgument.Create('Invalid argument');
  try
    Assert(LInvalidArg is ESSLException, 'ESSLInvalidArgument 继承自 ESSLException');
  finally
    LInvalidArg.Free;
  end;

  // 测试 ESSLResourceException
  LResourceException := ESSLResourceException.Create('Resource error');
  try
    Assert(LResourceException is ESSLException, 'ESSLResourceException 继承自 ESSLException');
  finally
    LResourceException.Free;
  end;

  // 测试 ESSLOutOfMemoryException
  LOutOfMemory := ESSLOutOfMemoryException.Create('Out of memory');
  try
    Assert(LOutOfMemory is ESSLResourceException,
           'ESSLOutOfMemoryException 继承自 ESSLResourceException');
  finally
    LOutOfMemory.Free;
  end;

  // 测试 ESSLFileNotFoundException
  LFileNotFound := ESSLFileNotFoundException.Create('File not found');
  try
    Assert(LFileNotFound is ESSLException, 'ESSLFileNotFoundException 继承自 ESSLException');
  finally
    LFileNotFound.Free;
  end;

  WriteLn;
end;

procedure TestSystemErrorException;
var
  LSystemError: ESSLSystemError;
begin
  WriteLn('【测试 9】系统错误异常');
  WriteLn('---');

  // 测试 ESSLSystemError
  LSystemError := ESSLSystemError.CreateWithSysCode('System error', 42);
  try
    Assert(LSystemError is ESSLException, 'ESSLSystemError 继承自 ESSLException');
    // CreateWithSysCode 会在消息中添加系统错误码
    Assert(Pos('System error', LSystemError.Message) > 0, 'ESSLSystemError 消息包含原始文本');
    Assert(LSystemError.SystemErrorCode = 42, 'SystemErrorCode 正确设置');
  finally
    LSystemError.Free;
  end;

  WriteLn;
end;

procedure TestExceptionHierarchy;
begin
  WriteLn('【测试 10】异常层次结构验证');
  WriteLn('---');

  // 验证所有异常都继承自 ESSLException
  Assert(ESSLInitError.ClassParent = ESSLException, 'ESSLInitError 父类正确');
  Assert(ESSLCryptoError.ClassParent = ESSLException, 'ESSLCryptoError 父类正确');
  Assert(ESSLCertError.ClassParent = ESSLException, 'ESSLCertError 父类正确');
  Assert(ESSLNetworkError.ClassParent = ESSLException, 'ESSLNetworkError 父类正确');

  // 验证二级异常继承
  Assert(ESSLKeyException.ClassParent = ESSLCryptoError, 'ESSLKeyException 父类正确');
  Assert(ESSLConnectionException.ClassParent = ESSLNetworkError, 'ESSLConnectionException 父类正确');
  Assert(ESSLCertificateLoadException.ClassParent = ESSLCertError, 'ESSLCertificateLoadException 父类正确');

  // 验证三级异常继承
  Assert(ESSLHandshakeException.ClassParent = ESSLConnectionException, 'ESSLHandshakeException 父类正确');
  Assert(ESSLCertificateExpiredException.ClassParent = ESSLCertificateVerificationException,
         'ESSLCertificateExpiredException 父类正确');

  WriteLn;
end;

procedure TestExceptionProperties;
var
  LException: ESSLException;
begin
  WriteLn('【测试 11】异常属性完整性');
  WriteLn('---');

  LException := ESSLException.CreateWithContext(
    'Test message',
    sslErrHandshake,
    'TestContext',
    999,
    sslWinSSL
  );
  try
    // 验证所有属性可读
    Assert(LException.Message <> '', 'Message 属性可读');
    Assert(LException.ErrorCode = sslErrHandshake, 'ErrorCode 属性可读');
    Assert(LException.Context = 'TestContext', 'Context 属性可读');
    Assert(LException.NativeError = 999, 'NativeError 属性可读');
    Assert(LException.LibraryType = sslWinSSL, 'LibraryType 属性可读');

    // 测试 Component 属性（向后兼容）
    LException.Component := 'TestComponent';
    Assert(LException.Component = 'TestComponent', 'Component 属性可读写');
  finally
    LException.Free;
  end;

  WriteLn;
end;

procedure TestExceptionRaising;
var
  LRaised: Boolean;
begin
  WriteLn('【测试 12】异常抛出和捕获');
  WriteLn('---');

  // 测试抛出和捕获基础异常
  LRaised := False;
  try
    raise ESSLException.Create('Test exception');
  except
    on E: ESSLException do
      LRaised := True;
  end;
  Assert(LRaised, '可以抛出和捕获 ESSLException');

  // 测试捕获派生异常为基类
  LRaised := False;
  try
    raise ESSLConnectionException.Create('Connection failed');
  except
    on E: ESSLException do
      LRaised := True;
  end;
  Assert(LRaised, '可以将派生异常捕获为基类');

  // 测试特定异常捕获
  LRaised := False;
  try
    raise ESSLTimeoutException.Create('Timeout');
  except
    on E: ESSLTimeoutException do
      LRaised := True;
  end;
  Assert(LRaised, '可以捕获特定异常类型');

  WriteLn;
end;

procedure PrintSummary;
begin
  WriteLn('=========================================');
  WriteLn('测试总结');
  WriteLn('=========================================');
  WriteLn('通过: ', GTestsPassed);
  WriteLn('失败: ', GTestsFailed);
  WriteLn('总计: ', GTestsPassed + GTestsFailed);

  if GTestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('✓ 所有异常测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查异常实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('异常处理测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  try
    TestBaseExceptionClass;
    TestExceptionWithContext;
    TestExceptionFormatting;
    TestInitializationExceptions;
    TestCryptoExceptions;
    TestCertificateExceptions;
    TestNetworkExceptions;
    TestResourceExceptions;
    TestSystemErrorException;
    TestExceptionHierarchy;
    TestExceptionProperties;
    TestExceptionRaising;

    WriteLn;
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
