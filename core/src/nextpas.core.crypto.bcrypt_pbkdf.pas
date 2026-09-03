unit nextpas.core.crypto.bcrypt_pbkdf;

{** nextpas.core.crypto - bcrypt_pbkdf 密钥派生（OpenBSD libutil 语义）。
 *
 * 与 PKCS#5 PBKDF2 的两点偏离（有意为之，见 OpenBSD 原注释）：
 *   1. 口令与盐先经 SHA512 折叠；bcrypt 轮内再做 64 轮状态扩张。
 *   2. 输出按 stride 交织打散——凑不齐全部输出块就无法组装任何子密钥。
 *
 * OpenSSH 加密私钥容器即用本 KDF（bcrypt_kdf：48 字节输出 =
 * AES-256-CTR 的 32 字节密钥 + 16 字节 IV）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{** 派生 AKeyLen 字节密钥。参数非法返回 False 并给出原因：
  * 口令/盐为空、AKeyLen<=0 或 >4096、ARounds<1。*}
function TryBcryptPbkdf(const APass, ASalt: TBytes; AKeyLen: Integer;
  ARounds: Cardinal; out AKey: TBytes; out AError: string): Boolean;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.blowfish;

const
  BCRYPT_HASHSIZE = 32;   { 单次 bcrypt_hash 输出 256 位 }

  { bcrypt 魔串（OpenBSD：加长版 magic string）}
  MAGIC_TEXT = 'OxychromaticBlowfishSwatDynamite';

{ 单次 bcrypt hash：sha2pass/sha2salt 双流重键 + 64 轮状态扩张，
  再对魔串连续加密 64 轮，输出 32 字节（字按小端落字节序）}
procedure BcryptHash(const AShaPass, AShaSalt: TBytes; out AOut: TBytes);
var
  LState: TBlowfishState;
  LMagic: TBytes;
  LCData: array[0..7] of UInt32;
  I, B, J: Integer;
begin
  BlowfishInitState(LState);
  BlowfishExpandState(LState, AShaSalt, AShaPass);
  for I := 1 to 64 do
  begin
    BlowfishExpand0State(LState, AShaSalt);
    BlowfishExpand0State(LState, AShaPass);
  end;

  LMagic := nil;
  SetLength(LMagic, Length(MAGIC_TEXT));
  for I := 1 to Length(MAGIC_TEXT) do
    LMagic[I - 1] := Ord(MAGIC_TEXT[I]);
  J := 0;
  for I := 0 to 7 do
    LCData[I] := BlowfishStream2Word(LMagic, Length(LMagic), J);

  { blf_enc(cdata, 4)：每轮把 4 个相邻半块对依次加密，重复 64 次 }
  for I := 1 to 64 do
    for B := 0 to 3 do
      BlowfishEncryptBlock(LState, LCData[B * 2], LCData[B * 2 + 1]);

  SetLength(AOut, BCRYPT_HASHSIZE);
  for I := 0 to 7 do
  begin
    AOut[4 * I + 3] := Byte(LCData[I] shr 24);
    AOut[4 * I + 2] := Byte(LCData[I] shr 16);
    AOut[4 * I + 1] := Byte(LCData[I] shr 8);
    AOut[4 * I + 0] := Byte(LCData[I]);
  end;
end;

function TryBcryptPbkdf(const APass, ASalt: TBytes; AKeyLen: Integer;
  ARounds: Cardinal; out AKey: TBytes; out AError: string): Boolean;
var
  LShaPass, LShaSalt, LSaltPlusCount, LOut, LTmpOut: TBytes;
  LCountsalt: array[0..3] of Byte;
  I, J, LStride, LAmt, LDest, LPlaced, LOrigLen, LRemaining: Integer;
  LCount: Cardinal;
begin
  Result := False;
  AKey := nil;
  AError := '';
  if ARounds < 1 then
  begin
    AError := 'bcrypt_pbkdf: rounds must be >= 1';
    Exit;
  end;
  if (Length(APass) = 0) or (Length(ASalt) = 0) or (AKeyLen <= 0) or
     (AKeyLen > BCRYPT_HASHSIZE * BCRYPT_HASHSIZE) then
  begin
    AError := 'bcrypt_pbkdf: invalid pass/salt/keylen';
    Exit;
  end;

  { 折叠口令 }
  LShaPass := SHA512(APass);

  LOrigLen := AKeyLen;
  LRemaining := AKeyLen;
  LStride := (AKeyLen + BCRYPT_HASHSIZE - 1) div BCRYPT_HASHSIZE;
  LAmt := (AKeyLen + LStride - 1) div LStride;
  SetLength(AKey, AKeyLen);
  SetLength(LSaltPlusCount, Length(ASalt) + 4);

  LCount := 1;
  while LRemaining > 0 do
  begin
    LCountsalt[0] := Byte(LCount shr 24);
    LCountsalt[1] := Byte(LCount shr 16);
    LCountsalt[2] := Byte(LCount shr 8);
    LCountsalt[3] := Byte(LCount);
    BytesCopy(@LSaltPlusCount[0], @ASalt[0], SizeUInt(Length(ASalt))); // perf: inline single Move via bytes.ops BytesCopy single source zero-copy
    BytesCopy(@LSaltPlusCount[Length(ASalt)], @LCountsalt[0], 4); // perf: inline single Move via bytes.ops single source zero-copy

    { 首轮以真实盐起链，后续轮以上轮输出为盐、结果 XOR 累积 }
    LShaSalt := SHA512(LSaltPlusCount);
    BcryptHash(LShaPass, LShaSalt, LTmpOut);
    LOut := Copy(LTmpOut, 0, Length(LTmpOut));
    for I := 2 to Integer(ARounds) do
    begin
      LShaSalt := SHA512(LTmpOut);
      BcryptHash(LShaPass, LShaSalt, LTmpOut);
      for J := 0 to BCRYPT_HASHSIZE - 1 do
        LOut[J] := LOut[J] xor LTmpOut[J];
    end;

    { pbkdf2 偏离点：输出按 stride 交织落位 }
    if LAmt > LRemaining then
      LAmt := LRemaining;
    LPlaced := 0;
    for I := 0 to LAmt - 1 do
    begin
      LDest := I * LStride + (Integer(LCount) - 1);
      if LDest >= LOrigLen then
        Break;
      AKey[LDest] := LOut[I];
      Inc(LPlaced);
    end;
    Dec(LRemaining, LPlaced);
    Inc(LCount);
  end;
  Result := True;
end;

end.
