program test_hash;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.crypto.hash;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure CheckHash(const ATestName: string; const AExpected, AActual: string);
begin
  if LowerCase(AExpected) = LowerCase(AActual) then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    WriteLn('  期望: ', LowerCase(AExpected));
    WriteLn('  实际: ', LowerCase(AActual));
    Inc(TestsFailed);
  end;
end;

// ========================================================================
// MD5 测试 (RFC 1321 测试向量)
// ========================================================================
procedure TestMD5;
begin
  WriteLn;
  WriteLn('=== MD5 测试 ===');

  // 空字符串
  CheckHash('MD5("")',
    'd41d8cd98f00b204e9800998ecf8427e',
    HashToHex(MD5('')));

  // "a"
  CheckHash('MD5("a")',
    '0cc175b9c0f1b6a831c399e269772661',
    HashToHex(MD5('a')));

  // "abc"
  CheckHash('MD5("abc")',
    '900150983cd24fb0d6963f7d28e17f72',
    HashToHex(MD5('abc')));

  // "message digest"
  CheckHash('MD5("message digest")',
    'f96b697d7cb7938d525a2f31aaf161d0',
    HashToHex(MD5('message digest')));

  // "abcdefghijklmnopqrstuvwxyz"
  CheckHash('MD5("a-z")',
    'c3fcd3d76192e4007dfb496cca67e13b',
    HashToHex(MD5('abcdefghijklmnopqrstuvwxyz')));

  // 长字符串
  CheckHash('MD5("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")',
    'd174ab98d277d9f5a5611c2c9f419d9f',
    HashToHex(MD5('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789')));
end;

// ========================================================================
// SHA-1 测试 (FIPS 180-4 测试向量)
// ========================================================================
procedure TestSHA1;
begin
  WriteLn;
  WriteLn('=== SHA-1 测试 ===');

  // 空字符串
  CheckHash('SHA1("")',
    'da39a3ee5e6b4b0d3255bfef95601890afd80709',
    HashToHex(SHA1('')));

  // "abc"
  CheckHash('SHA1("abc")',
    'a9993e364706816aba3e25717850c26c9cd0d89d',
    HashToHex(SHA1('abc')));

  // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
  CheckHash('SHA1(448位消息)',
    '84983e441c3bd26ebaae4aa1f95129e5e54670f1',
    HashToHex(SHA1('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')));
end;

// ========================================================================
// SHA-256 测试 (FIPS 180-4 测试向量)
// ========================================================================
procedure TestSHA256;
begin
  WriteLn;
  WriteLn('=== SHA-256 测试 ===');

  // 空字符串
  CheckHash('SHA256("")',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    HashToHex(SHA256('')));

  // "abc"
  CheckHash('SHA256("abc")',
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    HashToHex(SHA256('abc')));

  // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
  CheckHash('SHA256(448位消息)',
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    HashToHex(SHA256('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')));
end;

// ========================================================================
// SHA-384 测试 (FIPS 180-4 测试向量)
// ========================================================================
procedure TestSHA384;
begin
  WriteLn;
  WriteLn('=== SHA-384 测试 ===');

  // 空字符串
  CheckHash('SHA384("")',
    '38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b',
    HashToHex(SHA384('')));

  // "abc"
  CheckHash('SHA384("abc")',
    'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7',
    HashToHex(SHA384('abc')));

  // "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  CheckHash('SHA384(896位消息)',
    '09330c33f71147e83d192fc782cd1b4753111b173b3b05d22fa08086e3b0f712fcc7c71a557e2db966c3e9fa91746039',
    HashToHex(SHA384('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu')));
end;

// ========================================================================
// SHA-512 测试 (FIPS 180-4 测试向量)
// ========================================================================
procedure TestSHA512;
begin
  WriteLn;
  WriteLn('=== SHA-512 测试 ===');

  // 空字符串
  CheckHash('SHA512("")',
    'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
    HashToHex(SHA512('')));

  // "abc"
  CheckHash('SHA512("abc")',
    'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
    HashToHex(SHA512('abc')));

  // "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  CheckHash('SHA512(896位消息)',
    '8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909',
    HashToHex(SHA512('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu')));
end;

// ========================================================================
// 上下文 API 测试
// ========================================================================
procedure TestContextAPI;
var
  Ctx: THashContext;
  Hash1, Hash2: TBytes;
begin
  WriteLn;
  WriteLn('=== 上下文 API 测试 ===');

  // 测试增量更新
  Ctx := TSHA256Context.Create;
  try
    Ctx.Update('abc');
    Hash1 := Ctx.Final;
  finally
    Ctx.Free;
  end;

  Ctx := TSHA256Context.Create;
  try
    Ctx.Update('a');
    Ctx.Update('b');
    Ctx.Update('c');
    Hash2 := Ctx.Final;
  finally
    Ctx.Free;
  end;

  Check('增量更新一致性', HashToHex(Hash1) = HashToHex(Hash2));

  // 测试 CreateHashContext
  Ctx := CreateHashContext(haSHA256);
  try
    Check('CreateHashContext 返回正确类型', Ctx is TSHA256Context);
    Check('DigestSize', Ctx.DigestSize = 32);
    Check('BlockSize', Ctx.BlockSize = 64);
    Check('AlgorithmName', Ctx.AlgorithmName = 'SHA-256');
  finally
    Ctx.Free;
  end;

  // 测试辅助函数
  Check('GetHashDigestSize(SHA256)', GetHashDigestSize(haSHA256) = 32);
  Check('GetHashBlockSize(SHA512)', GetHashBlockSize(haSHA512) = 128);
  Check('GetHashAlgorithmName(MD5)', GetHashAlgorithmName(haMD5) = 'MD5');
end;

// ========================================================================
// 边界条件测试
// ========================================================================
procedure TestEdgeCases;
var
  LongData: TBytes;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== 边界条件测试 ===');

  // 测试正好是块大小的数据
  SetLength(LongData, 64);  // SHA-256 块大小
  for I := 0 to 63 do
    LongData[I] := I;

  Check('SHA256 精确块大小', Length(SHA256(LongData)) = 32);

  // 测试块大小 + 1
  SetLength(LongData, 65);
  for I := 0 to 64 do
    LongData[I] := I;

  Check('SHA256 块大小+1', Length(SHA256(LongData)) = 32);

  // 测试多块
  SetLength(LongData, 200);
  for I := 0 to 199 do
    LongData[I] := I mod 256;

  Check('SHA256 多块', Length(SHA256(LongData)) = 32);

  // SHA-512 测试
  SetLength(LongData, 128);  // SHA-512 块大小
  for I := 0 to 127 do
    LongData[I] := I;

  Check('SHA512 精确块大小', Length(SHA512(LongData)) = 64);

  // 大数据测试
  SetLength(LongData, 10000);
  for I := 0 to 9999 do
    LongData[I] := I mod 256;

  Check('SHA256 大数据', Length(SHA256(LongData)) = 32);
end;

// ========================================================================
// HashToHex 测试
// ========================================================================
procedure TestHashToHex;
var
  TestData: TBytes;
begin
  WriteLn;
  WriteLn('=== HashToHex 测试 ===');

  SetLength(TestData, 4);
  TestData[0] := $01;
  TestData[1] := $23;
  TestData[2] := $45;
  TestData[3] := $67;

  Check('HashToHex 格式', HashToHex(TestData) = '01234567');

  SetLength(TestData, 2);
  TestData[0] := $AB;
  TestData[1] := $CD;

  Check('HashToHex 小写', HashToHex(TestData) = 'abcd');
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls.crypto.hash 单元测试');
  WriteLn('========================================');

  TestsPassed := 0;
  TestsFailed := 0;

  TestMD5;
  TestSHA1;
  TestSHA256;
  TestSHA384;
  TestSHA512;
  TestContextAPI;
  TestEdgeCases;
  TestHashToHex;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
