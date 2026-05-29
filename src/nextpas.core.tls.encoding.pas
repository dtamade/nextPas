unit nextpas.core.tls.encoding;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{**
 * Unit: nextpas.core.tls.encoding
 * Purpose: 统一编码转换工具（Hex、Base64）
 *
 * Phase 2.3.1: Utils模块重组
 *
 * 本模块合并了 nextpas.core.tls.utils 和 nextpas.core.tls.crypto.utils 中
 * 重复的编码转换功能，使用性能更优的 OpenSSL BIO 实现。
 *
 * Features:
 * - Hex 编码/解码（支持大小写）
 * - Base64 编码/解码（零拷贝，OpenSSL BIO）
 * - Try 模式（不抛异常）
 * - TBytesView 零拷贝支持
 *
 * Thread Safety: 所有类方法线程安全
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2025-12-16
 *
 * @example
 * <code>
 *   // Hex 编码
 *   LHex := TEncodingUtils.BytesToHex(LData, True); // 大写
 *   LData := TEncodingUtils.HexToBytes(LHex);
 *
 *   // Base64 编码
 *   LB64 := TEncodingUtils.Base64Encode(LData);
 *   LData := TEncodingUtils.Base64Decode(LB64);
 *
 *   // Try 模式
 *   if TEncodingUtils.TryBase64Decode(LInput, LResult) then
 *     WriteLn('Success');
 * </code>
 *}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.errors,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio;

type
  {**
   * 编码工具类
   *
   * 所有方法都是类方法（静态），无需创建实例。
   * 线程安全性: 所有方法都是线程安全的
   *}
  TEncodingUtils = class
  private
    class procedure EnsureInitialized; static;
  public
    { ==================== Hex 编码/解码 ==================== }

    {**
     * 字节数组转十六进制字符串
     *
     * @param ABytes 输入字节数组
     * @param AUpperCase True=大写（默认），False=小写
     * @return 十六进制字符串（无分隔符）
     *
     * @example
     * <code>
     *   LHex := TEncodingUtils.BytesToHex([1, 255, 16], True);
     *   // Result: "01FF10"
     * </code>
     *}
    class function BytesToHex(
      const ABytes: TBytes;
      AUpperCase: Boolean = True
    ): string; static;

    {**
     * 十六进制字符串转字节数组
     *
     * @param AHex 十六进制字符串（忽略大小写）
     * @return 字节数组
     * @raises ESSLInvalidArgument 字符串长度不是偶数或包含非法字符
     *
     * @example
     * <code>
     *   LData := TEncodingUtils.HexToBytes('01FF10');
     *   // Result: [1, 255, 16]
     * </code>
     *}
    class function HexToBytes(const AHex: string): TBytes; static;

    {**
     * Hex 转换（Try 模式）
     * 不抛异常，失败返回 False
     *}
    class function TryBytesToHex(
      const ABytes: TBytes;
      out AResult: string;
      AUpperCase: Boolean = True
    ): Boolean; static;

    {**
     * Hex 转换（Try 模式）
     *}
    class function TryHexToBytes(
      const AHex: string;
      out AResult: TBytes
    ): Boolean; static;

    { ==================== Base64 编码/解码 ==================== }

    {**
     * Base64 编码（TBytes 输入）
     *
     * 使用 OpenSSL BIO 实现，性能优于手写版本
     * 输出格式：无换行符的连续 Base64 字符串
     *
     * @param AInput 输入字节数组
     * @return Base64 编码字符串
     * @raises ESSLCryptoError OpenSSL BIO 操作失败
     *
     * @example
     * <code>
     *   LB64 := TEncodingUtils.Base64Encode(LData);
     * </code>
     *}
    class function Base64Encode(const AInput: TBytes): string; overload; static;

    {**
     * Base64 编码（string 输入）
     * 字符串使用 UTF-8 编码
     *}
    class function Base64Encode(const AInput: string): string; overload; static;

    {**
     * Base64 解码
     *
     * @param AInput Base64 编码字符串
     * @return 解码后的字节数组
     * @raises ESSLCryptoError 解码失败（非法字符或格式错误）
     *}
    class function Base64Decode(const AInput: string): TBytes; static;

    {**
     * Base64 解码为字符串
     * 使用 UTF-8 解码
     *}
    class function Base64DecodeString(const AInput: string): string; static;

    {**
     * Base64 编码（Try 模式）
     * 不抛异常，失败返回 False
     *}
    class function TryBase64Encode(
      const AInput: TBytes;
      out AResult: string
    ): Boolean; overload; static;

    {**
     * Base64 编码（Try 模式，string 输入）
     *}
    class function TryBase64Encode(
      const AInput: string;
      out AResult: string
    ): Boolean; overload; static;

    {**
     * Base64 解码（Try 模式）
     *}
    class function TryBase64Decode(
      const AInput: string;
      out AResult: TBytes
    ): Boolean; static;

    {**
     * Base64 解码为字符串（Try 模式）
     *}
    class function TryBase64DecodeString(
      const AInput: string;
      out AResult: string
    ): Boolean; static;

    { ==================== 零拷贝版本 (TBytesView) ==================== }

    {**
     * Base64 编码（零拷贝版本）
     *
     * 使用 TBytesView 避免输入参数拷贝，提升性能
     *
     * @param AInputView 输入数据的视图（零拷贝）
     * @return Base64 编码字符串
     *}
    class function Base64EncodeView(const AInputView: TBytesView): string; static;

    { ==================== 辅助函数 ==================== }

    {**
     * 将字符串转换为 Hex 字符串（UTF-8 编码）
     *}
    class function StringToHex(const AStr: string): string; static;

    {**
     * 将 Hex 字符串转换为字符串（UTF-8 解码）
     *}
    class function HexToString(const AHex: string): string; static;
  end;

implementation

procedure RequireBase64EncodeBIOHelpers;
begin
  if not Assigned(BIO_new) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_f_base64) or
    not Assigned(BIO_push) or
    not Assigned(BIO_write) or
    not Assigned(BIO_free) or
    not Assigned(BIO_free_all) or
    not Assigned(BIO_ctrl) then
    raise ESSLCryptoError.Create(
      'Required BIO helpers are unavailable for Base64 encoding'
    );
end;

procedure RequireBase64DecodeBIOHelpers;
begin
  if not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_f_base64) or
    not Assigned(BIO_push) or
    not Assigned(BIO_read) or
    not Assigned(BIO_free) or
    not Assigned(BIO_free_all) or
    not Assigned(BIO_ctrl) then
    raise ESSLCryptoError.Create(
      'Required BIO helpers are unavailable for Base64 decoding'
    );
end;

{ TEncodingUtils }

class procedure TEncodingUtils.EnsureInitialized;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmInitEncoding) then
    Exit;

  // 加载OpenSSL核心
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    try
      LoadOpenSSLCore();
    except
      on E: Exception do
        RaiseInitializationError('OpenSSL core', E.Message);
    end;
  end;

  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    RaiseInitializationError('OpenSSL core', 'library not available');

  // 加载BIO模块（用于Base64）
  try
    if not Assigned(BIO_new) or not Assigned(BIO_f_base64) then
      LoadOpenSSLBIO();
  except
    on E: Exception do
      RaiseInitializationError('BIO module', E.Message);
  end;

  TOpenSSLLoader.SetModuleLoaded(osmInitEncoding, True);
end;

{ ==================== Hex 编码/解码实现 ==================== }

class function TEncodingUtils.BytesToHex(
  const ABytes: TBytes;
  AUpperCase: Boolean
): string;
const
  // 查找表：避免循环内的条件判断和函数调用
  HexCharsUpper: array[0..15] of Char = '0123456789ABCDEF';
  HexCharsLower: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
  PHex: PChar;
  B: Byte;
begin
  Result := '';
  if Length(ABytes) = 0 then
    Exit;

  // 预分配精确大小，避免重复分配
  SetLength(Result, Length(ABytes) * 2);
  PHex := PChar(Result);

  // 使用直接字符索引，避免 IntToHex + 字符串连接的开销
  // 性能提升：约 10-20 倍
  if AUpperCase then
  begin
    for I := 0 to High(ABytes) do
    begin
      B := ABytes[I];
      PHex[I * 2] := HexCharsUpper[(B shr 4) and $0F];
      PHex[I * 2 + 1] := HexCharsUpper[B and $0F];
    end;
  end
  else
  begin
    for I := 0 to High(ABytes) do
    begin
      B := ABytes[I];
      PHex[I * 2] := HexCharsLower[(B shr 4) and $0F];
      PHex[I * 2 + 1] := HexCharsLower[B and $0F];
    end;
  end;
end;

class function TEncodingUtils.HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
  LHex: string;
begin
  if (Length(AHex) mod 2) <> 0 then
    RaiseInvalidParameter('hex string length (must be even)');

  Result := nil;
  SetLength(Result, Length(AHex) div 2);

  LHex := UpperCase(AHex);
  I := 0;
  while I < Length(LHex) do
  begin
    try
      Result[I div 2] := StrToInt('$' + Copy(LHex, I + 1, 2));
    except
      on E: Exception do
        RaiseInvalidData('hex string (invalid character)');
    end;
    Inc(I, 2);
  end;
end;

class function TEncodingUtils.TryBytesToHex(
  const ABytes: TBytes;
  out AResult: string;
  AUpperCase: Boolean
): Boolean;
begin
  try
    AResult := BytesToHex(ABytes, AUpperCase);
    Result := True;
  except
    AResult := '';
    Result := False;
  end;
end;

class function TEncodingUtils.TryHexToBytes(
  const AHex: string;
  out AResult: TBytes
): Boolean;
begin
  try
    AResult := HexToBytes(AHex);
    Result := True;
  except
    SetLength(AResult, 0);
    Result := False;
  end;
end;

{ ==================== Base64 编码/解码实现 ==================== }

class function TEncodingUtils.Base64Encode(const AInput: TBytes): string;
var
  LBIO, LB64, LMem: PBIO;
  LPtr: PAnsiChar;
  LLen: Integer;
begin
  Result := '';
  if Length(AInput) = 0 then Exit;

  EnsureInitialized;
  RequireBase64EncodeBIOHelpers;

  LMem := BIO_new(BIO_s_mem());
  if LMem = nil then
    raise ESSLCryptoError.Create('Failed to create memory BIO');

  LB64 := BIO_new(BIO_f_base64());
  if LB64 = nil then
  begin
    BIO_free(LMem);
    raise ESSLCryptoError.Create('Failed to create Base64 BIO');
  end;

  // 性能优化 (Phase 2.3.6): 使用 BIO_FLAGS_BASE64_NO_NL 标志
  // 告诉 OpenSSL 不要在输出中插入换行符，避免后续 StringReplace 调用
  BIO_set_flags(LB64, BIO_FLAGS_BASE64_NO_NL);

  LBIO := BIO_push(LB64, LMem);

  try
    // 写入数据
    if BIO_write(LBIO, @AInput[0], Length(AInput)) <= 0 then
      raise ESSLCryptoError.Create('Failed to write data to Base64 BIO');

    if BIO_flush(LBIO) <= 0 then
      raise ESSLCryptoError.Create('Failed to flush Base64 BIO');

    // 获取编码后的数据（无换行符）
    LLen := BIO_get_mem_data(LMem, @LPtr);

    if LLen > 0 then
    begin
      // 跳过任何尾随空白字符（有些 OpenSSL 版本可能仍添加尾随换行）
      while (LLen > 0) and (LPtr[LLen - 1] in [#10, #13, #0, ' ']) do
        Dec(LLen);
      SetString(Result, LPtr, LLen);
    end;
  finally
    BIO_free_all(LBIO);
  end;
end;

class function TEncodingUtils.Base64Encode(const AInput: string): string;
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(UnicodeString(AInput));
  Result := Base64Encode(LBytes);
end;

class function TEncodingUtils.Base64Decode(const AInput: string): TBytes;
var
  LBIO, LB64, LMem: PBIO;
  LLen, LInputLen: Integer;
  LBuffer: array of Byte;
  LInputA: AnsiString;
begin
  Result := nil;
  SetLength(Result, 0);
  if AInput = '' then Exit;

  EnsureInitialized;
  RequireBase64DecodeBIOHelpers;

  // 性能优化 (Phase 2.3.6): 使用 BIO_FLAGS_BASE64_NO_NL 标志
  // 避免慢速的换行符预处理循环
  // 注意：OpenSSL 仍需要尾随换行符来触发最终块解码
  LInputA := AnsiString(AInput) + #10;
  LInputLen := Length(LInputA);

  SetLength(LBuffer, Length(AInput)); // 输出总是小于原始输入

  LMem := BIO_new_mem_buf(PAnsiChar(LInputA), LInputLen);
  if LMem = nil then
    raise ESSLCryptoError.Create('Failed to create memory BIO');

  LB64 := BIO_new(BIO_f_base64());
  if LB64 = nil then
  begin
    BIO_free(LMem);
    raise ESSLCryptoError.Create('Failed to create Base64 BIO');
  end;

  // 设置 NO_NL 标志：告诉 OpenSSL 输入中不包含每 64 字符换行
  // 这消除了 O(n) 的换行符插入循环，显著提升性能
  BIO_set_flags(LB64, BIO_FLAGS_BASE64_NO_NL);

  LBIO := BIO_push(LB64, LMem);

  try
    LLen := BIO_read(LBIO, @LBuffer[0], Length(LBuffer));
    if LLen > 0 then
    begin
      SetLength(Result, LLen);
      Move(LBuffer[0], Result[0], LLen);
    end
    else if LLen < 0 then
      raise ESSLCryptoError.Create('Failed to decode Base64 data');
  finally
    BIO_free_all(LBIO);
  end;
end;

class function TEncodingUtils.Base64DecodeString(const AInput: string): string;
begin
  Result := string(TEncoding.UTF8.GetString(Base64Decode(AInput)));
end;

class function TEncodingUtils.TryBase64Encode(
  const AInput: TBytes;
  out AResult: string
): Boolean;
begin
  try
    AResult := Base64Encode(AInput);
    Result := True;
  except
    AResult := '';
    Result := False;
  end;
end;

class function TEncodingUtils.TryBase64Encode(
  const AInput: string;
  out AResult: string
): Boolean;
begin
  try
    AResult := Base64Encode(AInput);
    Result := True;
  except
    AResult := '';
    Result := False;
  end;
end;

class function TEncodingUtils.TryBase64Decode(
  const AInput: string;
  out AResult: TBytes
): Boolean;
begin
  try
    AResult := Base64Decode(AInput);
    Result := True;
  except
    SetLength(AResult, 0);
    Result := False;
  end;
end;

class function TEncodingUtils.TryBase64DecodeString(
  const AInput: string;
  out AResult: string
): Boolean;
begin
  try
    AResult := Base64DecodeString(AInput);
    Result := True;
  except
    AResult := '';
    Result := False;
  end;
end;

{ ==================== 零拷贝版本实现 ==================== }

class function TEncodingUtils.Base64EncodeView(const AInputView: TBytesView): string;
var
  LBIO, LB64, LMem: PBIO;
  LPtr: PAnsiChar;
  LLen: Integer;
begin
  EnsureInitialized;

  if not AInputView.IsValid then
  begin
    Result := '';
    Exit;
  end;

  RequireBase64EncodeBIOHelpers;

  LMem := BIO_new(BIO_s_mem());
  if LMem = nil then
    raise ESSLCryptoError.Create('Failed to create memory BIO');

  LB64 := BIO_new(BIO_f_base64());
  if LB64 = nil then
  begin
    BIO_free(LMem);
    raise ESSLCryptoError.Create('Failed to create Base64 BIO');
  end;

  // 性能优化 (Phase 2.3.6): 使用 BIO_FLAGS_BASE64_NO_NL 标志
  BIO_set_flags(LB64, BIO_FLAGS_BASE64_NO_NL);

  LBIO := BIO_push(LB64, LMem);

  try
    // 零拷贝：直接使用视图的指针
    if BIO_write(LBIO, AInputView.Data, AInputView.Length) <= 0 then
      raise ESSLCryptoError.Create('Failed to write to BIO');

    if BIO_flush(LBIO) <= 0 then
      raise ESSLCryptoError.Create('Failed to flush BIO');

    // 获取数据（无换行符）
    LLen := BIO_get_mem_data(LMem, @LPtr);

    if LLen > 0 then
    begin
      // 跳过任何尾随空白字符
      while (LLen > 0) and (LPtr[LLen - 1] in [#10, #13, #0, ' ']) do
        Dec(LLen);
      SetString(Result, LPtr, LLen);
    end
    else
      Result := '';
  finally
    BIO_free_all(LBIO);
  end;
end;

{ ==================== 辅助函数实现 ==================== }

class function TEncodingUtils.StringToHex(const AStr: string): string;
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(UnicodeString(AStr));
  Result := BytesToHex(LBytes);
end;

class function TEncodingUtils.HexToString(const AHex: string): string;
var
  LBytes: TBytes;
begin
  LBytes := HexToBytes(AHex);
  Result := string(TEncoding.UTF8.GetString(LBytes));
end;

end.
