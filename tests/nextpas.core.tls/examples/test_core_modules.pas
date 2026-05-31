program test_core_modules;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.bn;

procedure TestCore;
begin
  WriteLn('测试 OpenSSL Core 模块...');
  WriteLn('=============================');
  
  try
    WriteLn('正在加载 OpenSSL 库...');
    LoadOpenSSLCore;
    
    if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('✓ OpenSSL 库加载成功');
      
      // 获取版本信息
      if Assigned(OpenSSL_version_num) then
      begin
        WriteLn('  版本号: ', IntToHex(OpenSSL_version_num(), 8));
      end;
      
      if Assigned(OpenSSL_version) then
      begin
        WriteLn('  版本字符串: ', OpenSSL_version(0));
      end;
    end
    else
      WriteLn('✗ OpenSSL 库加载失败');
      
  except
    on E: Exception do
      WriteLn('✗ Core 模块测试失败: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestRAND;
var
  LBuffer: array[0..15] of Byte;
  i: Integer;
  LHex, LBase64: string;
begin
  WriteLn('测试 OpenSSL RAND 模块...');
  WriteLn('=============================');
  
  try
    WriteLn('正在加载 RAND 模块...');
    if LoadOpenSSLRAND then
    begin
      WriteLn('✓ RAND 模块加载成功');
      
      // 测试随机数生成
      if Assigned(RAND_bytes) then
      begin
        FillChar(LBuffer, SizeOf(LBuffer), 0);
        if RAND_bytes(@LBuffer[0], SizeOf(LBuffer)) = 1 then
        begin
          Write('  生成的随机数据: ');
          for i := 0 to 15 do
            Write(IntToHex(LBuffer[i], 2), ' ');
          WriteLn;
        end
        else
          WriteLn('  ✗ 随机数生成失败');
      end;
      
      // 测试 Helper 函数
      if RAND_bytes_secure(@LBuffer[0], 8) then
      begin
        Write('  安全随机数据: ');
        for i := 0 to 7 do
          Write(IntToHex(LBuffer[i], 2), ' ');
        WriteLn;
      end;
      
      // 测试 Hex 生成
      LHex := RAND_generate_hex(16);
      if LHex <> '' then
        WriteLn('  Hex 字符串: ', LHex);
        
      // 测试 Base64 生成
      LBase64 := RAND_generate_base64(16);
      if LBase64 <> '' then
        WriteLn('  Base64 字符串: ', LBase64);
        
      // 检查 RAND 状态
      if Assigned(RAND_status) then
        WriteLn('  RAND 状态: ', RAND_status());
    end
    else
      WriteLn('✗ RAND 模块加载失败');
      
  except
    on E: Exception do
      WriteLn('✗ RAND 模块测试失败: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestBN;
var
  a, b, r: PBIGNUM;
  ctx: PBN_CTX;
  LStr: PAnsiChar;
begin
  WriteLn('测试 OpenSSL BN (大数) 模块...');
  WriteLn('=============================');
  
  try
    WriteLn('正在加载 BN 模块...');
    if LoadOpenSSLBN then
    begin
      WriteLn('✓ BN 模块加载成功');
      
      // 测试基本的大数操作
      if Assigned(BN_new) and Assigned(BN_CTX_new) then
      begin
        ctx := BN_CTX_new();
        if ctx <> nil then
        begin
          WriteLn('  ✓ BN_CTX 创建成功');
          
          a := BN_new();
          b := BN_new();
          r := BN_new();
          
          if (a <> nil) and (b <> nil) and (r <> nil) then
          begin
            WriteLn('  ✓ BIGNUM 对象创建成功');
            
            // 设置值
            if Assigned(BN_set_word) then
            begin
              BN_set_word(a, 123456);
              BN_set_word(b, 789012);
              WriteLn('  设置 a = 123456, b = 789012');
              
              // 加法测试
              if Assigned(BN_add) then
              begin
                if BN_add(r, a, b) = 1 then
                begin
                  if Assigned(BN_bn2dec) then
                  begin
                    LStr := BN_bn2dec(r);
                    if LStr <> nil then
                    begin
                      WriteLn('  a + b = ', LStr);
                      // 注意：应该调用 OPENSSL_free(LStr) 来释放内存
                    end;
                  end;
                end;
              end;
              
              // 乘法测试
              if Assigned(BN_mul) then
              begin
                if BN_mul(r, a, b, ctx) = 1 then
                begin
                  if Assigned(BN_bn2dec) then
                  begin
                    LStr := BN_bn2dec(r);
                    if LStr <> nil then
                    begin
                      WriteLn('  a * b = ', LStr);
                      // 注意：应该调用 OPENSSL_free(LStr) 来释放内存
                    end;
                  end;
                end;
              end;
            end;
            
            // 清理
            if Assigned(BN_free) then
            begin
              BN_free(a);
              BN_free(b);
              BN_free(r);
            end;
          end;
          
          if Assigned(BN_CTX_free) then
            BN_CTX_free(ctx);
        end;
      end;
    end
    else
      WriteLn('✗ BN 模块加载失败');
      
  except
    on E: Exception do
      WriteLn('✗ BN 模块测试失败: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestModules;
begin
  WriteLn('========================================');
  WriteLn('OpenSSL 核心模块测试程序');
  WriteLn('========================================');
  WriteLn;
  
  // 测试核心模块
  TestCore;
  
  // 测试 RAND 模块
  TestRAND;
  
  // 测试 BN 模块
  TestBN;
  
  WriteLn('========================================');
  WriteLn('测试完成');
  WriteLn('========================================');
end;

begin
  try
    TestModules;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('发生错误: ', E.Message);
    end;
  end;
  
  // 清理
  UnloadOpenSSLBN;
  UnloadOpenSSLRAND;
  UnloadOpenSSLCore;
  
  WriteLn;
  WriteLn('按 Enter 键退出...');
  ReadLn;
end.