program file_encryption;

{$mode objfpc}{$H+}

{ ============================================================================
  示例 3: 文件加密与解密
  
  功能：使用 AES-256-GCM 加密和解密文件
  用途：学习对称加密、密钥派生和文件处理
  
  编译：fpc -Fusrc -Fusrc\openssl 03_file_encryption.pas
  运行：03_file_encryption.exe encrypt <input_file> <output_file> <password>
        03_file_encryption.exe decrypt <input_file> <output_file> <password>
  ============================================================================ }

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.scrypt_whirlpool;

const
  SALT_SIZE = 16;
  KEY_SIZE = 32;   // 256 bits
  IV_SIZE = 12;    // GCM recommended
  TAG_SIZE = 16;
  ITERATIONS = 100000;

type
  TFileHeader = packed record
    Magic: array[0..7] of AnsiChar;  // 'FAFAFA01'
    Version: Byte;
    Algorithm: Byte;  // 1=AES-256-GCM
    Reserved: Word;
    Salt: array[0..SALT_SIZE-1] of Byte;
    IV: array[0..IV_SIZE-1] of Byte;
    Tag: array[0..TAG_SIZE-1] of Byte;
  end;

function DeriveKey(const aPassword: string; const aSalt: TBytes): TBytes;
var
  LPasswordBytes: TBytes;
begin
  LPasswordBytes := BytesOf(AnsiString(aPassword));
  SetLength(Result, KEY_SIZE);
  
  if PKCS5_PBKDF2_HMAC(
    @LPasswordBytes[0], Length(LPasswordBytes),
    @aSalt[0], Length(aSalt),
    ITERATIONS,
    EVP_sha256(),
    KEY_SIZE, @Result[0]
  ) <> 1 then
    raise Exception.Create('Failed to derive key');
end;

function GetFileSize(const aFileName: string): Int64;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyNone);
  try
    Result := LStream.Size;
  finally
    LStream.Free;
  end;
end;

procedure EncryptFile(const aInputFile, aOutputFile, aPassword: string);
var
  LInput, LOutput: TFileStream;
  LHeader: TFileHeader;
  LSalt, LIV, LKey, LTag: TBytes;
  LPlainChunk, LCipherChunk: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LOutLen, LTotalIn, LTotalOut: Integer;
  LBytesRead: Integer;
begin
  WriteLn('加密文件: ', aInputFile);
  WriteLn('输出到: ', aOutputFile);
  WriteLn;
  
  // 1. 打开文件
  WriteLn('[1/7] 打开文件...');
  LInput := TFileStream.Create(aInputFile, fmOpenRead or fmShareDenyWrite);
  try
    LOutput := TFileStream.Create(aOutputFile, fmCreate);
    try
      WriteLn('      ✓ 输入文件: ', aInputFile, ' (', LInput.Size, ' 字节)');
      
      // 2. 生成随机 Salt 和 IV
      WriteLn('[2/7] 生成随机参数...');
      SetLength(LSalt, SALT_SIZE);
      SetLength(LIV, IV_SIZE);
      RAND_bytes(@LSalt[0], SALT_SIZE);
      RAND_bytes(@LIV[0], IV_SIZE);
      WriteLn('      ✓ Salt: ', SALT_SIZE, ' 字节');
      WriteLn('      ✓ IV: ', IV_SIZE, ' 字节');
      
      // 3. 从密码派生密钥
      WriteLn('[3/7] 派生加密密钥...');
      LKey := DeriveKey(aPassword, LSalt);
      WriteLn('      ✓ 使用 PBKDF2-HMAC-SHA256');
      WriteLn('      ✓ 迭代次数: ', ITERATIONS);
      WriteLn('      ✓ 密钥长度: ', KEY_SIZE, ' 字节');
      
      // 4. 准备文件头（先预留空间）
      WriteLn('[4/7] 写入文件头...');
      FillChar(LHeader, SizeOf(LHeader), 0);
      Move('FAFAFA01', LHeader.Magic[0], 8);
      LHeader.Version := 1;
      LHeader.Algorithm := 1;  // AES-256-GCM
      Move(LSalt[0], LHeader.Salt[0], SALT_SIZE);
      Move(LIV[0], LHeader.IV[0], IV_SIZE);
      // Tag 将在加密完成后写入
      
      LOutput.WriteBuffer(LHeader, SizeOf(LHeader));
      WriteLn('      ✓ 文件头已写入');
      
      // 5. 初始化加密上下文
      WriteLn('[5/7] 初始化加密器...');
      LCtx := EVP_CIPHER_CTX_new();
      if LCtx = nil then
        raise Exception.Create('Failed to create cipher context');
      
      try
        if EVP_EncryptInit_ex(LCtx, EVP_aes_256_gcm(), nil, @LKey[0], @LIV[0]) <> 1 then
          raise Exception.Create('Failed to initialize encryption');
        
        WriteLn('      ✓ 算法: AES-256-GCM');
        WriteLn('      ✓ 加密器已初始化');
        
        // 6. 分块加密文件内容
        WriteLn('[6/7] 加密文件内容...');
        SetLength(LPlainChunk, 64 * 1024);  // 64 KB chunks
        SetLength(LCipherChunk, 64 * 1024 + EVP_MAX_BLOCK_LENGTH);
        
        LTotalIn := 0;
        LTotalOut := 0;
        
        repeat
          LBytesRead := LInput.Read(LPlainChunk[0], Length(LPlainChunk));
          if LBytesRead > 0 then
          begin
            if EVP_EncryptUpdate(LCtx, @LCipherChunk[0], LOutLen,
                                 @LPlainChunk[0], LBytesRead) <> 1 then
              raise Exception.Create('Failed to encrypt data');
            
            if LOutLen > 0 then
              LOutput.WriteBuffer(LCipherChunk[0], LOutLen);
            
            Inc(LTotalIn, LBytesRead);
            Inc(LTotalOut, LOutLen);
            
            Write(#13, '      处理中: ', LTotalIn, ' / ', LInput.Size, ' 字节 (',
                  (LTotalIn * 100) div LInput.Size, '%)');
          end;
        until LBytesRead = 0;
        
        WriteLn;
        
        // 完成加密
        if EVP_EncryptFinal_ex(LCtx, @LCipherChunk[0], LOutLen) <> 1 then
          raise Exception.Create('Failed to finalize encryption');
        
        if LOutLen > 0 then
        begin
          LOutput.WriteBuffer(LCipherChunk[0], LOutLen);
          Inc(LTotalOut, LOutLen);
        end;
        
        WriteLn('      ✓ 加密完成: ', LTotalOut, ' 字节');
        
        // 7. 获取并写入认证标签
        WriteLn('[7/7] 写入认证标签...');
        SetLength(LTag, TAG_SIZE);
        if EVP_CIPHER_CTX_ctrl(LCtx, EVP_CTRL_GCM_GET_TAG, TAG_SIZE, Pointer(@LTag[0])) <> 1 then
          raise Exception.Create('Failed to get authentication tag');
        
        // 回到头部位置写入 Tag
        LOutput.Position := 0;
        LOutput.ReadBuffer(LHeader, SizeOf(LHeader));
        Move(LTag[0], LHeader.Tag[0], TAG_SIZE);
        LOutput.Position := 0;
        LOutput.WriteBuffer(LHeader, SizeOf(LHeader));
        
        WriteLn('      ✓ 认证标签已写入');
        
      finally
        EVP_CIPHER_CTX_free(LCtx);
      end;
      
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
  
  WriteLn;
  WriteLn('✓ 加密成功！');
  WriteLn('  输出文件: ', aOutputFile);
  WriteLn('  文件大小: ', GetFileSize(aOutputFile), ' 字节');
end;

procedure DecryptFile(const aInputFile, aOutputFile, aPassword: string);
var
  LInput, LOutput: TFileStream;
  LHeader: TFileHeader;
  LSalt, LIV, LKey, LTag: TBytes;
  LCipherChunk, LPlainChunk: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LOutLen, LTotalIn, LTotalOut: Integer;
  LBytesRead: Integer;
begin
  WriteLn('解密文件: ', aInputFile);
  WriteLn('输出到: ', aOutputFile);
  WriteLn;
  
  // 1. 打开文件
  WriteLn('[1/6] 打开文件...');
  LInput := TFileStream.Create(aInputFile, fmOpenRead or fmShareDenyWrite);
  try
    LOutput := TFileStream.Create(aOutputFile, fmCreate);
    try
      WriteLn('      ✓ 输入文件: ', aInputFile, ' (', LInput.Size, ' 字节)');
      
      // 2. 读取文件头
      WriteLn('[2/6] 读取文件头...');
      if LInput.Size < SizeOf(LHeader) then
        raise Exception.Create('Invalid encrypted file: too small');
      
      LInput.ReadBuffer(LHeader, SizeOf(LHeader));
      
      if string(LHeader.Magic) <> 'FAFAFA01' then
        raise Exception.Create('Invalid encrypted file: wrong magic');
      
      if LHeader.Version <> 1 then
        raise Exception.CreateFmt('Unsupported version: %d', [LHeader.Version]);
      
      if LHeader.Algorithm <> 1 then
        raise Exception.CreateFmt('Unsupported algorithm: %d', [LHeader.Algorithm]);
      
      SetLength(LSalt, SALT_SIZE);
      SetLength(LIV, IV_SIZE);
      SetLength(LTag, TAG_SIZE);
      Move(LHeader.Salt[0], LSalt[0], SALT_SIZE);
      Move(LHeader.IV[0], LIV[0], IV_SIZE);
      Move(LHeader.Tag[0], LTag[0], TAG_SIZE);
      
      WriteLn('      ✓ 文件头有效');
      WriteLn('      ✓ 版本: ', LHeader.Version);
      WriteLn('      ✓ 算法: AES-256-GCM');
      
      // 3. 从密码派生密钥
      WriteLn('[3/6] 派生解密密钥...');
      LKey := DeriveKey(aPassword, LSalt);
      WriteLn('      ✓ 密钥派生完成');
      
      // 4. 初始化解密上下文
      WriteLn('[4/6] 初始化解密器...');
      LCtx := EVP_CIPHER_CTX_new();
      if LCtx = nil then
        raise Exception.Create('Failed to create cipher context');
      
      try
        if EVP_DecryptInit_ex(LCtx, EVP_aes_256_gcm(), nil, @LKey[0], @LIV[0]) <> 1 then
          raise Exception.Create('Failed to initialize decryption');
        
        WriteLn('      ✓ 解密器已初始化');
        
        // 5. 分块解密文件内容
        WriteLn('[5/6] 解密文件内容...');
        SetLength(LCipherChunk, 64 * 1024);
        SetLength(LPlainChunk, 64 * 1024 + EVP_MAX_BLOCK_LENGTH);
        
        LTotalIn := 0;
        LTotalOut := 0;
        
        repeat
          LBytesRead := LInput.Read(LCipherChunk[0], Length(LCipherChunk));
          if LBytesRead > 0 then
          begin
            if EVP_DecryptUpdate(LCtx, @LPlainChunk[0], LOutLen,
                                 @LCipherChunk[0], LBytesRead) <> 1 then
              raise Exception.Create('Failed to decrypt data');
            
            if LOutLen > 0 then
              LOutput.WriteBuffer(LPlainChunk[0], LOutLen);
            
            Inc(LTotalIn, LBytesRead);
            Inc(LTotalOut, LOutLen);
            
            Write(#13, '      处理中: ', LTotalIn, ' / ', LInput.Size - SizeOf(LHeader),
                  ' 字节 (', (LTotalIn * 100) div (LInput.Size - SizeOf(LHeader)), '%)');
          end;
        until LBytesRead = 0;
        
        WriteLn;
        
        // 6. 验证认证标签并完成解密
        WriteLn('[6/6] 验证认证标签...');
        if EVP_CIPHER_CTX_ctrl(LCtx, EVP_CTRL_GCM_SET_TAG, TAG_SIZE, Pointer(@LTag[0])) <> 1 then
          raise Exception.Create('Failed to set authentication tag');
        
        if EVP_DecryptFinal_ex(LCtx, @LPlainChunk[0], LOutLen) <> 1 then
          raise Exception.Create('Authentication failed: file may be corrupted or wrong password');
        
        if LOutLen > 0 then
        begin
          LOutput.WriteBuffer(LPlainChunk[0], LOutLen);
          Inc(LTotalOut, LOutLen);
        end;
        
        WriteLn('      ✓ 认证通过');
        WriteLn('      ✓ 解密完成: ', LTotalOut, ' 字节');
        
      finally
        EVP_CIPHER_CTX_free(LCtx);
      end;
      
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
  
  WriteLn;
  WriteLn('✓ 解密成功！');
  WriteLn('  输出文件: ', aOutputFile);
  WriteLn('  文件大小: ', GetFileSize(aOutputFile), ' 字节');
end;

procedure ShowUsage;
begin
  WriteLn('用法:');
  WriteLn('  加密: ', ExtractFileName(ParamStr(0)), ' encrypt <input_file> <output_file> <password>');
  WriteLn('  解密: ', ExtractFileName(ParamStr(0)), ' decrypt <input_file> <output_file> <password>');
  WriteLn;
  WriteLn('示例:');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' encrypt document.txt document.enc mypassword');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' decrypt document.enc document.txt mypassword');
end;

var
  LCommand, LInputFile, LOutputFile, LPassword: string;

begin
  WriteLn('================================================================================');
  WriteLn('  示例 3: 文件加密与解密');
  WriteLn('================================================================================');
  WriteLn;
  
  // 检查参数
  if ParamCount < 4 then
  begin
    ShowUsage;
    ExitCode := 1;
    Exit;
  end;
  
  LCommand := LowerCase(ParamStr(1));
  LInputFile := ParamStr(2);
  LOutputFile := ParamStr(3);
  LPassword := ParamStr(4);
  
  // 初始化 OpenSSL
  if not LoadOpenSSLLibrary then
  begin
    WriteLn('✗ 无法加载 OpenSSL 库');
    ExitCode := 1;
    Exit;
  end;
  
  try
    // 检查输入文件
    if not FileExists(LInputFile) then
      raise Exception.CreateFmt('输入文件不存在: %s', [LInputFile]);
    
    // 执行操作
    if LCommand = 'encrypt' then
      EncryptFile(LInputFile, LOutputFile, LPassword)
    else if LCommand = 'decrypt' then
      DecryptFile(LInputFile, LOutputFile, LPassword)
    else
    begin
      WriteLn('✗ 未知命令: ', LCommand);
      WriteLn;
      ShowUsage;
      ExitCode := 1;
      Exit;
    end;
    
    WriteLn;
    WriteLn('================================================================================');
    WriteLn('  完成！');
    WriteLn('================================================================================');
    WriteLn;
    WriteLn('🔒 安全提示：');
    WriteLn('  - 使用强密码（至少 12 个字符）');
    WriteLn('  - 妥善保管密码');
    WriteLn('  - 加密文件不能恢复如果密码丢失');
    WriteLn('  - 认证标签确保文件完整性');
    WriteLn;
    WriteLn('💡 技术细节：');
    WriteLn('  - 算法: AES-256-GCM（认证加密）');
    WriteLn('  - 密钥派生: PBKDF2-HMAC-SHA256');
    WriteLn('  - 迭代次数: ', ITERATIONS);
    WriteLn('  - 随机 Salt: ', SALT_SIZE, ' 字节');
    WriteLn('  - 随机 IV: ', IV_SIZE, ' 字节');
    WriteLn('  - 认证标签: ', TAG_SIZE, ' 字节');
    WriteLn;
    
    ExitCode := 0;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('================================================================================');
      WriteLn('  ✗ 错误: ', E.Message);
      WriteLn('================================================================================');
      WriteLn;
      ExitCode := 1;
    end;
  end;
end.
