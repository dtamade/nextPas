program test_quic_crypto;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesgcm,
  nextpas.core.errors,
  nextpas.core.tls.quic.crypto;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Byte(Ord(AChar) - Ord('0'));
    'a'..'f': Result := Byte(Ord(AChar) - Ord('a') + 10);
    'A'..'F': Result := Byte(Ord(AChar) - Ord('A') + 10);
  else
    raise Exception.Create('Invalid hex digit: ' + AChar);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  if (Length(AHex) and 1) <> 0 then
    raise Exception.Create('Hex string length must be even');

  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := Byte((HexNibble(AHex[I * 2 + 1]) shl 4) or HexNibble(AHex[I * 2 + 2]));
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  if Length(ALeft) = 0 then
    Exit(True);
  Result := CompareMem(@ALeft[0], @ARight[0], Length(ALeft));
end;

function BytesToHex(const AData: TBytes): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to Length(AData) - 1 do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[AData[I] shr 4];
    Result[I * 2 + 2] := HEX_DIGITS[AData[I] and $0F];
  end;
end;

procedure CheckBytesEqual(const AActual, AExpected: TBytes; const AMessage: string);
var
  I: Integer;
  LDetail: string;
begin
  if BytesEqual(AActual, AExpected) then
  begin
    Check(True, AMessage);
    Exit;
  end;

  LDetail := '';
  if Length(AActual) <> Length(AExpected) then
    LDetail := ' length actual=' + IntToStr(Length(AActual)) + ' expected=' + IntToStr(Length(AExpected))
  else
    for I := 0 to Length(AActual) - 1 do
      if AActual[I] <> AExpected[I] then
      begin
        LDetail := ' first-diff[' + IntToStr(I) + ']=actual:' +
          IntToHex(AActual[I], 2) + ' expected:' + IntToHex(AExpected[I], 2);
        Break;
      end;

  Check(False, AMessage + LDetail + ' actual=' + BytesToHex(AActual));
end;

function ConcatBytes(const ALeft, ARight: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(ALeft) + Length(ARight));
  if Length(ALeft) > 0 then
    Move(ALeft[0], Result[0], Length(ALeft));
  if Length(ARight) > 0 then
    Move(ARight[0], Result[Length(ALeft)], Length(ARight));
end;

function SliceBytes(const AData: TBytes; AOffset, ALength: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ALength);
  if ALength > 0 then
    Move(AData[AOffset], Result[0], ALength);
end;

function ZeroBytes(ACount: Integer): TBytes;
begin
  Result := nil;
  if ACount <= 0 then
    Exit;
  SetLength(Result, ACount);
  FillChar(Result[0], ACount, 0);
end;

procedure TestInitialSecretDeterminism;
var
  LConnID: TBytes;
  LSecretA: TBytes;
  LSecretB: TBytes;
begin
  WriteLn('Test: QUIC initial secret determinism');
  SetLength(LConnID, 8);
  FillChar(LConnID[0], Length(LConnID), $AB);

  LSecretA := QUICDeriveInitialSecret(LConnID);
  LSecretB := QUICDeriveInitialSecret(LConnID);

  Check(Length(LSecretA) = 32, 'Initial secret should be 32 bytes');
  Check(BytesEqual(LSecretA, LSecretB), 'Same connection ID should derive same secret');
end;

procedure TestClientAndServerLabelsProduceDistinctKeys;
var
  LConnID: TBytes;
  LSecret: TBytes;
  LClientKeys: TQUICKeys;
  LServerKeys: TQUICKeys;
begin
  WriteLn('Test: QUIC client/server labels produce distinct keys');
  SetLength(LConnID, 4);
  FillChar(LConnID[0], Length(LConnID), $CD);

  LSecret := QUICDeriveInitialSecret(LConnID);
  LClientKeys := QUICDeriveClientInitialKeys(LSecret);
  LServerKeys := QUICDeriveServerInitialKeys(LSecret);

  Check(Length(LClientKeys.Key) = 16, 'Client key should be 16 bytes');
  Check(Length(LClientKeys.IV) = 12, 'Client IV should be 12 bytes');
  Check(Length(LClientKeys.HP) = 16, 'Client HP should be 16 bytes');
  Check(Length(LServerKeys.Key) = 16, 'Server key should be 16 bytes');
  Check(Length(LServerKeys.IV) = 12, 'Server IV should be 12 bytes');
  Check(Length(LServerKeys.HP) = 16, 'Server HP should be 16 bytes');

  Check(not BytesEqual(LClientKeys.Key, LServerKeys.Key),
    'Client and server label bytes should derive different keys');
  Check(not BytesEqual(LClientKeys.IV, LServerKeys.IV),
    'Client and server label bytes should derive different IVs');
  Check(not BytesEqual(LClientKeys.HP, LServerKeys.HP),
    'Client and server label bytes should derive different HP keys');
end;

procedure TestRFC9001KnownVector;
var
  LConnID: TBytes;
  LInitialSecret: TBytes;
  LClientKeys: TQUICKeys;
  LServerKeys: TQUICKeys;
begin
  WriteLn('Test: QUIC RFC 9001 initial secret and key vector');
  LConnID := HexToBytes('8394c8f03e515708');

  LInitialSecret := QUICDeriveInitialSecret(LConnID);
  Check(BytesEqual(LInitialSecret,
    HexToBytes('7db5df06e7a69e432496adedb00851923595221596ae2ae9fb8115c1e9ed0a44')),
    'Initial secret should match RFC 9001 Appendix A.1');

  LClientKeys := QUICDeriveClientInitialKeys(LInitialSecret);
  Check(BytesEqual(LClientKeys.Key,
    HexToBytes('1f369613dd76d5467730efcbe3b1a22d')),
    'Client key should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LClientKeys.IV,
    HexToBytes('fa044b2f42a3fd3b46fb255c')),
    'Client IV should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LClientKeys.HP,
    HexToBytes('9f50449e04a0e810283a1e9933adedd2')),
    'Client HP key should match RFC 9001 Appendix A.1');

  LServerKeys := QUICDeriveServerInitialKeys(LInitialSecret);
  Check(BytesEqual(LServerKeys.Key,
    HexToBytes('cf3a5331653c364c88f0f379b6067e37')),
    'Server key should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LServerKeys.IV,
    HexToBytes('0ac1493ca1905853b0bba03e')),
    'Server IV should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LServerKeys.HP,
    HexToBytes('c206b8d9b9f0f37644430b490eeaa314')),
    'Server HP key should match RFC 9001 Appendix A.1');
end;

procedure TestRFC9001ClientInitialPacketProtection;
const
  HEADER_HEX =
    'c300000001088394c8f03e5157080000449e00000002';
  PAYLOAD_HEX =
    '060040f1010000ed0303ebf8fa56f12939b9584a3896472ec40bb863cfd3e868' +
    '04fe3a47f06a2b69484c00000413011302010000c000000010000e00000b6578' +
    '616d706c652e636f6dff01000100000a00080006001d00170018001000070005' +
    '04616c706e000500050100000000003300260024001d00209370b2c9caa47fba' +
    'baf4559fedba753de171fa71f50f1ce15d43e994ec74d748002b000302030400' +
    '0d0010000e0403050306030203080408050806002d00020101001c0002400100' +
    '3900320408ffffffffffffffff05048000ffff07048000ffff08011001048000' +
    '75300901100f088394c8f03e51570806048000ffff';
  NONCE_HEX = 'fa044b2f42a3fd3b46fb255e';
  SAMPLE_HEX = 'd1b1c98dd7689fb8ec11d242b123dc9b';
  MASK_HEX = '437b9aec36';
  PROTECTED_PACKET_HEX =
    'c000000001088394c8f03e5157080000449e7b9aec34d1b1c98dd7689fb8ec11' +
    'd242b123dc9bd8bab936b47d92ec356c0bab7df5976d27cd449f63300099f399' +
    '1c260ec4c60d17b31f8429157bb35a1282a643a8d2262cad67500cadb8e7378c' +
    '8eb7539ec4d4905fed1bee1fc8aafba17c750e2c7ace01e6005f80fcb7df6212' +
    '30c83711b39343fa028cea7f7fb5ff89eac2308249a02252155e2347b63d58c5' +
    '457afd84d05dfffdb20392844ae812154682e9cf012f9021a6f0be17ddd0c208' +
    '4dce25ff9b06cde535d0f920a2db1bf362c23e596d11a4f5a6cf3948838a3aec' +
    '4e15daf8500a6ef69ec4e3feb6b1d98e610ac8b7ec3faf6ad760b7bad1db4ba3' +
    '485e8a94dc250ae3fdb41ed15fb6a8e5eba0fc3dd60bc8e30c5c4287e53805db' +
    '059ae0648db2f64264ed5e39be2e20d82df566da8dd5998ccabdae053060ae6c' +
    '7b4378e846d29f37ed7b4ea9ec5d82e7961b7f25a9323851f681d582363aa5f8' +
    '9937f5a67258bf63ad6f1a0b1d96dbd4faddfcefc5266ba6611722395c906556' +
    'be52afe3f565636ad1b17d508b73d8743eeb524be22b3dcbc2c7468d54119c74' +
    '68449a13d8e3b95811a198f3491de3e7fe942b330407abf82a4ed7c1b311663a' +
    'c69890f4157015853d91e923037c227a33cdd5ec281ca3f79c44546b9d90ca00' +
    'f064c99e3dd97911d39fe9c5d0b23a229a234cb36186c4819e8b9c5927726632' +
    '291d6a418211cc2962e20fe47feb3edf330f2c603a9d48c0fcb5699dbfe58964' +
    '25c5bac4aee82e57a85aaf4e2513e4f05796b07ba2ee47d80506f8d2c25e50fd' +
    '14de71e6c418559302f939b0e1abd576f279c4b2e0feb85c1f28ff18f58891ff' +
    'ef132eef2fa09346aee33c28eb130ff28f5b766953334113211996d20011a198' +
    'e3fc433f9f2541010ae17c1bf202580f6047472fb36857fe843b19f5984009dd' +
    'c324044e847a4f4a0ab34f719595de37252d6235365e9b84392b061085349d73' +
    '203a4a13e96f5432ec0fd4a1ee65accdd5e3904df54c1da510b0ff20dcc0c77f' +
    'cb2c0e0eb605cb0504db87632cf3d8b4dae6e705769d1de354270123cb11450e' +
    'fc60ac47683d7b8d0f811365565fd98c4c8eb936bcab8d069fc33bd801b03ade' +
    'a2e1fbc5aa463d08ca19896d2bf59a071b851e6c239052172f296bfb5e724047' +
    '90a2181014f3b94a4e97d117b438130368cc39dbb2d198065ae3986547926cd2' +
    '162f40a29f0c3c8745c0f50fba3852e566d44575c29d39a03f0cda721984b6f4' +
    '40591f355e12d439ff150aab7613499dbd49adabc8676eef023b15b65bfc5ca0' +
    '6948109f23f350db82123535eb8a7433bdabcb909271a6ecbcb58b936a88cd4e' +
    '8f2e6ff5800175f113253d8fa9ca8885c2f552e657dc603f252e1a8e308f76f0' +
    'be79e2fb8f5d5fbbe2e30ecadd220723c8c0aea8078cdfcb3868263ff8f09400' +
    '54da48781893a7e49ad5aff4af300cd804a6b6279ab3ff3afb64491c85194aab' +
    '760d58a606654f9f4400e8b38591356fbf6425aca26dc85244259ff2b19c41b9' +
    'f96f3ca9ec1dde434da7d2d392b905ddf3d1f9af93d1af5950bd493f5aa731b4' +
    '056df31bd267b6b90a079831aaf579be0a39013137aac6d404f518cfd4684064' +
    '7e78bfe706ca4cf5e9c5453e9f7cfd2b8b4c8d169a44e55c88d4a9a7f9474241' +
    'e221af44860018ab0856972e194cd934';
var
  LConnID: TBytes;
  LInitialSecret: TBytes;
  LClientKeys: TQUICKeys;
  LHeader: TBytes;
  LPlaintext: TBytes;
  LNonce: TBytes;
  LCiphertext: TBytes;
  LTag: TBytes;
  LPacket: TBytes;
  LExpectedPacket: TBytes;
  LSample: TBytes;
  LMask: TBytes;
  LPNOffset: Integer;
begin
  WriteLn('Test: QUIC RFC 9001 client initial packet protection');
  LConnID := HexToBytes('8394c8f03e515708');
  LInitialSecret := QUICDeriveInitialSecret(LConnID);
  LClientKeys := QUICDeriveClientInitialKeys(LInitialSecret);

  LHeader := HexToBytes(HEADER_HEX);
  LPlaintext := HexToBytes(PAYLOAD_HEX);
  LExpectedPacket := HexToBytes(PROTECTED_PACKET_HEX);
  LPlaintext := ConcatBytes(LPlaintext,
    ZeroBytes(Length(LExpectedPacket) - Length(LHeader) - 16 - Length(LPlaintext)));
  LPNOffset := Length(LHeader) - 4;

  LNonce := QUICBuildPacketProtectionNonce(LClientKeys.IV, 2);
  Check(BytesEqual(LNonce, HexToBytes(NONCE_HEX)),
    'Client nonce should match QUIC packet number XOR construction');

  Check(PurePascalAESGCMEncrypt(LClientKeys.Key, LNonce, LPlaintext, LHeader, LCiphertext, LTag),
    'Client initial payload AEAD should succeed');

  LPacket := ConcatBytes(LHeader, ConcatBytes(LCiphertext, LTag));
  LSample := SliceBytes(LPacket, LPNOffset + 4, 16);
  Check(BytesEqual(LSample, HexToBytes(SAMPLE_HEX)),
    'Client sample should match RFC 9001 Appendix A.2');

  LMask := QUICComputeAESHeaderProtectionMask(LClientKeys.HP, LSample);
  Check(BytesEqual(LMask, HexToBytes(MASK_HEX)),
    'Client header protection mask should match RFC 9001 Appendix A.2');

  QUICApplyHeaderProtection(LPacket, LPNOffset, 4, LMask);
  CheckBytesEqual(LPacket, LExpectedPacket,
    'Client protected packet should match RFC 9001 Appendix A.2');
end;

procedure TestRFC9001ServerInitialPacketProtection;
const
  HEADER_HEX =
    'c1000000010008f067a5502a4262b50040750001';
  PAYLOAD_HEX =
    '02000000000600405a020000560303eefce7f7b37ba1d1632e96677825ddf739' +
    '88cfc79825df566dc5430b9a045a1200130100002e00330024001d00209d3c94' +
    '0d89690b84d08a60993c144eca684d1081287c834d5311bcf32bb9da1a002b00' +
    '020304';
  NONCE_HEX = '0ac1493ca1905853b0bba03f';
  SAMPLE_HEX = '2cd0991cd25b0aac406a5816b6394100';
  MASK_HEX = '2ec0d8356a';
  PROTECTED_PACKET_HEX =
    'cf000000010008f067a5502a4262b5004075c0d95a482cd0991cd25b0aac406a' +
    '5816b6394100f37a1c69797554780bb38cc5a99f5ede4cf73c3ec2493a1839b3' +
    'dbcba3f6ea46c5b7684df3548e7ddeb9c3bf9c73cc3f3bded74b562bfb19fb84' +
    '022f8ef4cdd93795d77d06edbb7aaf2f58891850abbdca3d20398c276456cbc4' +
    '2158407dd074ee';
var
  LConnID: TBytes;
  LInitialSecret: TBytes;
  LServerKeys: TQUICKeys;
  LHeader: TBytes;
  LPlaintext: TBytes;
  LNonce: TBytes;
  LCiphertext: TBytes;
  LTag: TBytes;
  LPacket: TBytes;
  LSample: TBytes;
  LMask: TBytes;
  LPNOffset: Integer;
begin
  WriteLn('Test: QUIC RFC 9001 server initial packet protection');
  LConnID := HexToBytes('8394c8f03e515708');
  LInitialSecret := QUICDeriveInitialSecret(LConnID);
  LServerKeys := QUICDeriveServerInitialKeys(LInitialSecret);

  LHeader := HexToBytes(HEADER_HEX);
  LPlaintext := HexToBytes(PAYLOAD_HEX);
  LPNOffset := Length(LHeader) - 2;

  LNonce := QUICBuildPacketProtectionNonce(LServerKeys.IV, 1);
  Check(BytesEqual(LNonce, HexToBytes(NONCE_HEX)),
    'Server nonce should match QUIC packet number XOR construction');

  Check(PurePascalAESGCMEncrypt(LServerKeys.Key, LNonce, LPlaintext, LHeader, LCiphertext, LTag),
    'Server initial payload AEAD should succeed');

  LPacket := ConcatBytes(LHeader, ConcatBytes(LCiphertext, LTag));
  LSample := SliceBytes(LPacket, LPNOffset + 4, 16);
  Check(BytesEqual(LSample, HexToBytes(SAMPLE_HEX)),
    'Server sample should match RFC 9001 Appendix A.3');

  LMask := QUICComputeAESHeaderProtectionMask(LServerKeys.HP, LSample);
  Check(BytesEqual(LMask, HexToBytes(MASK_HEX)),
    'Server header protection mask should match RFC 9001 Appendix A.3');

  QUICApplyHeaderProtection(LPacket, LPNOffset, 2, LMask);
  CheckBytesEqual(LPacket, HexToBytes(PROTECTED_PACKET_HEX),
    'Server protected packet should match RFC 9001 Appendix A.3');
end;

procedure TestPacketProtectionHelpersRejectInvalidArguments;
var
  LRaised: Boolean;
  LPacket: TBytes;
begin
  WriteLn('Test: QUIC packet protection helpers reject invalid arguments');

  LRaised := False;
  try
    QUICBuildPacketProtectionNonce(nil, 1);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Empty IV should raise EArgumentError');

  LRaised := False;
  try
    QUICComputeAESHeaderProtectionMask(HexToBytes('00112233445566778899aabbccddeeff'),
      HexToBytes('00112233445566778899aabbccddee'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Short sample should raise EArgumentError');

  LRaised := False;
  try
    QUICComputeAESHeaderProtectionMask(HexToBytes('00112233445566778899aabbccddeeff'),
      HexToBytes('00112233445566778899aabbccddeeff00'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Long sample should raise EArgumentError');

  LRaised := False;
  try
    QUICComputeAESHeaderProtectionMask(HexToBytes('001122334455778899aabbccddeeff00ff'),
      HexToBytes('00112233445566778899aabbccddeeff'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Invalid header protection key length should raise EArgumentError');

  LPacket := HexToBytes('c300000001088394c8f03e5157080000449e00000002');
  LRaised := False;
  try
    QUICApplyHeaderProtection(LPacket, Length(LPacket) - 4, 0,
      HexToBytes('437b9aec36'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Invalid packet number length should raise EArgumentError');

  LRaised := False;
  try
    QUICApplyHeaderProtection(LPacket, Length(LPacket) - 4, 4,
      HexToBytes('437b9aec'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Short header protection mask should raise EArgumentError');

  LRaised := False;
  try
    QUICApplyHeaderProtection(LPacket, Length(LPacket) - 4, 4,
      HexToBytes('437b9aec3600'));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Long header protection mask should raise EArgumentError');
end;

begin
  WriteLn('=== QUIC Crypto Tests ===');
  WriteLn('');

  TestInitialSecretDeterminism;
  TestClientAndServerLabelsProduceDistinctKeys;
  TestRFC9001KnownVector;
  TestRFC9001ClientInitialPacketProtection;
  TestRFC9001ServerInitialPacketProtection;
  TestPacketProtectionHelpersRejectInvalidArguments;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
