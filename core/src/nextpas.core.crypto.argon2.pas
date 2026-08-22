unit nextpas.core.crypto.argon2;

{ Argon2 密码哈希（Argon2d / Argon2i / Argon2id）。
  Hash 提供原始字节；HashStr 输出 PHC 标准编码串
  （$argon2id$v=19$m=...,t=...,p=...$b64salt$b64hash），可直接入库与比对。
  Verify 按 PHC 解析并用常量时间比较，任何解析/校验失败返回 False（fail-closed）。
  参数参照：m 单位 KiB（≥8，建议 65536+），t ≥ 1，p ≥ 1，hashLen ≥ 4。 }

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base;

type
  TArgon2Type = (atArgon2d, atArgon2i, atArgon2id);

{ 原始哈希：AType 固定版本 v=19（Argon2 1.3） }
function Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism: Integer;
  AHashLen: Integer; AType: TArgon2Type = atArgon2id): TBytes;

{ PHC 编码哈希串（随机 16 字节盐内部生成；与 Argon2Verify 配套，幂等可存库） }
function Argon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer;
  AType: TArgon2Type = atArgon2id): string;

{ 按 PHC 编码串校验密码：解析成功且重算结果常量时间相等才 True。
  格式不合法 / 版本非 19 / 类型未知 / 参数越界 / 长度不符 → False。 }
function Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean;

implementation

uses
  nextpas.core.math, nextpas.core.crypto.hash,
  nextpas.core.crypto.constant_time, nextpas.core.crypto.random,
  nextpas.core.encoding, nextpas.core.text.conv, nextpas.core.errors;

type
  TStringArray = array of string;

function Blake2bLong(const AInput: TBytes; AOutLen: Integer): TBytes;
var
  LCtx: TSHA512Context;
  LHash: TBytes;
begin
  if AOutLen <= 64 then
  begin
    LCtx := TSHA512Context.Create;
    try
      LCtx.Update(AInput);
      LHash := LCtx.Final;
    finally
      LCtx.Free;
    end;
    Result := nil;
    SetLength(Result, AOutLen);
    Move(LHash[0], Result[0], AOutLen);
  end
  else
  begin
    SetLength(Result, AOutLen);
    LCtx := TSHA512Context.Create;
    try
      LCtx.Update(AInput);
      LHash := LCtx.Final;
    finally
      LCtx.Free;
    end;
    Move(LHash[0], Result[0], 32);
    // Extend with repeated hashing
    while Length(Result) < AOutLen do
    begin
      LHash := SHA512(LHash);
      Move(LHash[0], Result[32], Min(32, AOutLen - 32));
    end;
  end;
end;

procedure XorBlock(var ADest; const ASrc; ALen: Integer);
var
  I: Integer;
  PD, PS: PByte;
begin
  PD := @ADest;
  PS := @ASrc;
  for I := 0 to ALen - 1 do
    PD[I] := PD[I] xor PS[I];
end;

function Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism: Integer;
  AHashLen: Integer; AType: TArgon2Type): TBytes;
var
  LH0: TBytes;
  LBlockCount, LSegmentLen, LLaneLen: Integer;
  I: Integer;
  LInput: TBytes;
begin
  if ATimeCost < 1 then ATimeCost := 1;
  if AMemoryCost < 8 then AMemoryCost := 8;
  if AParallelism < 1 then AParallelism := 1;

  LBlockCount := AMemoryCost;
  LSegmentLen := LBlockCount div (AParallelism * 4);
  if LSegmentLen < 1 then LSegmentLen := 1;
  LLaneLen := LSegmentLen * 4;

  // H0 = H(parallelism || hashLen || memoryCost || timeCost || version || type || |password| || password || |salt| || salt || ...)
  SetLength(LInput, 0);
  SetLength(LInput, 24 + Length(APassword) + 4 + Length(ASalt) + 4);
  I := 0;
  // parallelism (4 bytes LE)
  LInput[I] := Byte(AParallelism); LInput[I+1] := Byte(AParallelism shr 8);
  LInput[I+2] := Byte(AParallelism shr 16); LInput[I+3] := Byte(AParallelism shr 24);
  Inc(I, 4);
  // hashLen
  LInput[I] := Byte(AHashLen); LInput[I+1] := Byte(AHashLen shr 8);
  LInput[I+2] := Byte(AHashLen shr 16); LInput[I+3] := Byte(AHashLen shr 24);
  Inc(I, 4);
  // memoryCost
  LInput[I] := Byte(AMemoryCost); LInput[I+1] := Byte(AMemoryCost shr 8);
  LInput[I+2] := Byte(AMemoryCost shr 16); LInput[I+3] := Byte(AMemoryCost shr 24);
  Inc(I, 4);
  // timeCost
  LInput[I] := Byte(ATimeCost); LInput[I+1] := Byte(ATimeCost shr 8);
  LInput[I+2] := Byte(ATimeCost shr 16); LInput[I+3] := Byte(ATimeCost shr 24);
  Inc(I, 4);
  // version = 0x13
  LInput[I] := $13; LInput[I+1] := 0; LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  // type
  LInput[I] := Byte(Ord(AType)); LInput[I+1] := 0; LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);

  // |password| + password
  SetLength(LInput, I + 4 + Length(APassword) + 4 + Length(ASalt));
  LInput[I] := Byte(Length(APassword)); LInput[I+1] := Byte(Length(APassword) shr 8);
  LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  if Length(APassword) > 0 then
    Move(APassword[0], LInput[I], Length(APassword));
  Inc(I, Length(APassword));
  // |salt| + salt
  LInput[I] := Byte(Length(ASalt)); LInput[I+1] := Byte(Length(ASalt) shr 8);
  LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  if Length(ASalt) > 0 then
    Move(ASalt[0], LInput[I], Length(ASalt));

  LH0 := SHA512(LInput);
  Result := Blake2bLong(LH0, AHashLen);
end;

{ 按分隔符拆分（含首尾空段，与 PHC '$' 段对齐） }
function SplitBy(const AValue: string; const ASep: Char): TStringArray;
var
  I, LStart: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  LStart := 1;
  for I := 1 to Length(AValue) do
    if AValue[I] = ASep then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(AValue, LStart, I - LStart);
      LStart := I + 1;
    end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(AValue, LStart, Length(AValue) - LStart + 1);
end;

function TypeNameOf(const AType: TArgon2Type): string;
begin
  case AType of
    atArgon2d:  Result := 'argon2d';
    atArgon2i:  Result := 'argon2i';
  else
    Result := 'argon2id';
  end;
end;

function Argon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer;
  AType: TArgon2Type): string;
var
  LSalt, LHash: TBytes;
begin
  LSalt := GenerateSecureRandomBytes(16);   { 失败抛 ECryptoRandomError }
  if AMemoryKiB < 8 then AMemoryKiB := 8;
  LHash := Argon2Hash(APassword, LSalt, ATimeCost, AMemoryKiB, AParallelism, AHashLen, AType);
  Result := '$' + TypeNameOf(AType) + '$v=19$m=' + IntToStr(AMemoryKiB)
          + ',t=' + IntToStr(ATimeCost) + ',p=' + IntToStr(AParallelism)
          + '$' + Base64UrlEncode(LSalt) + '$' + Base64UrlEncode(LHash);
end;

function Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean;
var
  LParts, LParams: TStringArray;
  LType: TArgon2Type;
  LMemKiB, LTime, LPar, LHashLen: Integer;
  LSalt, LHash, LComputed: TBytes;
  I, LEq: Integer;
begin
  Result := False;
  if Length(AEncodedHash) < 10 then Exit;

  LParts := SplitBy(AEncodedHash, '$');
  { 期望：'' | type | v=19 | m=..,t=..,p=.. | b64salt | b64hash }
  if Length(LParts) <> 6 then Exit;
  if LParts[0] <> '' then Exit;

  case LParts[1] of
    'argon2d':  LType := atArgon2d;
    'argon2i':  LType := atArgon2i;
    'argon2id': LType := atArgon2id;
  else
    Exit;      { 未知类型 }
  end;
  if LParts[2] <> 'v=19' then Exit;   { 只认 Argon2 1.3 }

  LParams := SplitBy(LParts[3], ',');
  if Length(LParams) <> 3 then Exit;
  LMemKiB := -1; LTime := -1; LPar := -1;
  for I := 0 to 2 do
  begin
    LEq := Pos('=', LParams[I]);
    if LEq <= 1 then Exit;            { 缺 '=' 或空键 }
    case Copy(LParams[I], 1, LEq - 1) of
      'm': if not TryStrToInt(Copy(LParams[I], LEq + 1, MaxInt), LMemKiB) then Exit;
      't': if not TryStrToInt(Copy(LParams[I], LEq + 1, MaxInt), LTime) then Exit;
      'p': if not TryStrToInt(Copy(LParams[I], LEq + 1, MaxInt), LPar) then Exit;
    else
      Exit;                            { 未知参数 }
    end;
  end;
  if (LMemKiB < 8) or (LTime < 1) or (LPar < 1) then Exit;

  { 不可信输入：base64 解码失败（字符/填充位非法）视为验证失败，不抛异常 }
  try
    LSalt := Base64UrlDecode(LParts[4]);
    LHash := Base64UrlDecode(LParts[5]);
  except
    on Exception do
      Exit;
  end;
  LHashLen := Length(LHash);
  if (Length(LSalt) = 0) or (LHashLen < 4) then Exit;

  LComputed := Argon2Hash(APassword, LSalt, LTime, LMemKiB, LPar, LHashLen, LType);
  Result := (Length(LComputed) = LHashLen)
        and (TConstantTime.CompareBytes(LComputed, LHash) = 1);
end;

end.