program test_password;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.crypto.argon2,
  nextpas.core.encoding.base64,
  nextpas.core.auth.password;

var
  T: TTestSuite;

const
  { 测试加速画像:算法下限附近(m=8 KiB/t=1/p=1),单次哈希毫秒级;
    默认画像全强度路径单独跑一次证明可用。 }
  FAST_PROFILE_MEM = 8;

function FastProfile: TArgon2Profile;
begin
  Result.MemoryKiB := FAST_PROFILE_MEM;
  Result.TimeCost := 1;
  Result.Parallelism := 1;
  Result.HashLen := 16;
end;

{ PHC 第 N 个 '$' 段(0 基,形态 '' / argon2id / v=19 / m,t,p / salt / hash)。 }
function DollarSegment(const APhc: string; AIndex: Integer): string;
var
  LSeg, I, LStart: Integer;
begin
  Result := '';
  LSeg := -1;
  LStart := 1;
  for I := 1 to Length(APhc) + 1 do
    if (I > Length(APhc)) or (APhc[I] = '$') then
    begin
      Inc(LSeg);
      if LSeg = AIndex then
      begin
        Result := Copy(APhc, LStart, I - LStart);
        Exit;
      end;
      LStart := I + 1;
    end;
end;

procedure TestDefaultProfileValues;
var
  P: TArgon2Profile;
begin
  P := DefaultArgon2Profile;
  CheckEqual(Int64(19456), Int64(P.MemoryKiB), 'default m=19456 KiB (19 MiB)');
  CheckEqual(Int64(2), Int64(P.TimeCost), 'default t=2');
  CheckEqual(Int64(1), Int64(P.Parallelism), 'default p=1');
  CheckEqual(Int64(32), Int64(P.HashLen), 'default hash=32');
  Check(IsValidArgon2Profile(P), 'default profile valid');
end;

procedure TestProfileValidationMatrix;
var
  P: TArgon2Profile;
begin
  { 合法边界。 }
  P := FastProfile;
  Check(IsValidArgon2Profile(P), 'fast profile valid');

  { m < 8*p }
  P := FastProfile;
  P.Parallelism := 4;
  Check(not IsValidArgon2Profile(P), 'mem < 8*parallelism invalid');
  { m < 8 }
  P.MemoryKiB := 7;
  P.Parallelism := 1;
  Check(not IsValidArgon2Profile(P), 'mem < 8 invalid');
  { t = 0 }
  P.MemoryKiB := 8;
  P.TimeCost := 0;
  Check(not IsValidArgon2Profile(P), 't=0 invalid');
  { p = 0 }
  P.TimeCost := 1;
  P.Parallelism := 0;
  Check(not IsValidArgon2Profile(P), 'p=0 invalid');
  { hashLen < 16(本单元地板) }
  P.Parallelism := 1;
  P.HashLen := 15;
  Check(not IsValidArgon2Profile(P), 'hashlen < 16 invalid');
end;

procedure TestPhcShapeGolden;
var
  LHash, LMemSeg: string;
  LSalt, LDigest: TBytes;
begin
  LHash := HashPassword('correct horse', FastProfile);

  { 结构:$argon2id$v=19$m=..,t=..,p=..$salt$hash。 }
  Check(Pos('$argon2id$v=19$', LHash) = 1, 'prefix $argon2id$v=19$');
  LMemSeg := DollarSegment(LHash, 3);
  Check(Pos('m=8,', LMemSeg) = 1, 'm= fast profile memory');
  Check(Pos('t=1', LMemSeg) > 0, 't= fast timecost');
  Check(Pos('p=1', LMemSeg) > 0, 'p= parallelism');
  Check(DollarSegment(LHash, 0) = '', 'leading empty segment');
  Check(DollarSegment(LHash, 1) = 'argon2id', 'type segment');

  { 盐固定 16 字节、摘要等于画像 HashLen。 }
  LSalt := Base64UrlDecode(DollarSegment(LHash, 4));
  CheckEqual(Int64(16), Int64(Length(LSalt)), 'salt is 16 bytes');
  LDigest := Base64UrlDecode(DollarSegment(LHash, 5));
  CheckEqual(Int64(FastProfile.HashLen), Int64(Length(LDigest)), 'digest length = profile');
end;

procedure TestRoundTripAndNegatives;
var
  LHash, LTampered: string;
begin
  LHash := HashPassword('s3cret!', FastProfile);
  Check(VerifyPassword('s3cret!', LHash), 'round trip verify true');
  Check(not VerifyPassword('s3cret ', LHash), 'wrong password false');
  Check(not VerifyPassword('', LHash), 'empty candidate verify false (data state)');
  Check(not VerifyPassword('s3cret!', ''), 'malformed hash false');
  Check(not VerifyPassword('s3cret!',
    '$argon2id$v=18$m=8,t=1,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAA'),
    'wrong version false');

  { 篡改 salt / hash 段(段内扩一位,解码长度即变)→ False。 }
  LTampered := DollarSegment(LHash, 0) + '$' + DollarSegment(LHash, 1) + '$' +
    DollarSegment(LHash, 2) + '$' + DollarSegment(LHash, 3) + '$' +
    DollarSegment(LHash, 4) + 'A' + '$' + DollarSegment(LHash, 5);
  Check(not VerifyPassword('s3cret!', LTampered), 'tampered salt rejected');
  Check(not VerifyPassword('s3cret!', LHash + 'A'), 'tampered hash rejected');
end;

procedure TestRandomSaltDistinct;
var
  H1, H2: string;
begin
  H1 := HashPassword('same-input', FastProfile);
  H2 := HashPassword('same-input', FastProfile);
  Check(H1 <> H2, 'same password -> distinct hashes (random salt)');
  Check(VerifyPassword('same-input', H1), 'first verifies');
  Check(VerifyPassword('same-input', H2), 'second verifies');
end;

procedure TestUnicodePasswordRoundTrip;
var
  LHash: string;
begin
  { UTF-8 规范形契约:多字节口令往返一致。 }
  LHash := HashPassword('密码p@sswörd🎉', FastProfile);
  Check(VerifyPassword('密码p@sswörd🎉', LHash), 'unicode round trip');
  Check(not VerifyPassword('密码p@ssword', LHash), 'lookalike rejected');
end;

procedure TestEmptyPasswordFailFast;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HashPassword('');
  except
    on E: EArgumentError do LRaised := True;
  end;
  Check(LRaised, 'empty string password raises');

  LRaised := False;
  try
    HashPassword(nil, FastProfile);
  except
    on E: EArgumentError do LRaised := True;
  end;
  Check(LRaised, 'empty bytes password raises');
end;

procedure TestInvalidProfileFailFast;
var
  LRaised: Boolean;
  P: TArgon2Profile;
begin
  P := FastProfile;
  P.HashLen := 8;  { < 16 地板 }
  LRaised := False;
  try
    HashPassword('x', P);
  except
    on E: EArgumentError do LRaised := True;
  end;
  Check(LRaised, 'invalid profile raises');
end;

procedure TestNeedsRehashStates;
var
  LEq, LStronger, LWeaker: TArgon2Profile;
  HEq, HStrong: string;
begin
  { 等参 → False。 }
  LEq := FastProfile;
  HEq := HashPassword('pw', LEq);
  Check(not NeedsRehash(HEq, LEq), 'equal profile no rehash');

  { 强存储 + 弱画像 → False(不降级扰动)。 }
  LStronger := FastProfile;
  LStronger.TimeCost := 3;
  HStrong := HashPassword('pw', LStronger);
  Check(not NeedsRehash(HStrong, LEq), 'stronger stored than profile -> no rehash');

  { 弱参存储 + 强画像 → True。 }
  LWeaker := FastProfile;
  LWeaker.TimeCost := 4;
  Check(NeedsRehash(HEq, LWeaker), 'weaker stored time cost -> rehash');

  { 类型非 argon2id → True。 }
  Check(NeedsRehash('$argon2i$v=19$m=8,t=1,p=1$AAAA$AAAA', LEq),
    'argon2i stored -> rehash to id');
  Check(NeedsRehash('$argon2d$v=19$m=8,t=1,p=1$AAAA$AAAA', LEq),
    'argon2d stored -> rehash to id');

  { 畸形形态一律 True(fail-closed 升级倾向)。 }
  Check(NeedsRehash('garbage', LEq), 'garbage -> rehash');
  Check(NeedsRehash('', LEq), 'empty -> rehash');
  Check(NeedsRehash('$argon2id$v=19$m=abc,t=1,p=1$x$y', LEq),
    'non-numeric param -> rehash');
  Check(NeedsRehash('$argon2id$v=19$m=8,t=1$p$q$r', LEq),
    'missing param field -> rehash');
  Check(NeedsRehash('$bcrypt$v=19$m=8,t=1,p=1$x$y', LEq),
    'foreign type name -> rehash');

  { 无画像重载 = Default 判定。 }
  Check(not NeedsRehash(HashPassword('pw')), 'default overload equal -> no rehash');
end;

procedure TestDefaultStrengthRoundTripOnce;
var
  LHash: string;
begin
  { 全强度默认画像端到端一次(OWASP 数值真实可用性)。 }
  LHash := HashPassword('production-grade-passphrase');
  Check(Pos('$argon2id$v=19$m=19456,', LHash) = 1, 'default phc carries owasp m');
  Check(VerifyPassword('production-grade-passphrase', LHash),
    'default strength round trip');
  Check(not NeedsRehash(LHash), 'default hash current vs default profile');
end;

begin
  T := TTestSuite.Create('nextpas.core.auth.password');
  T.Test('Default profile values', @TestDefaultProfileValues);
  T.Test('Profile validation matrix', @TestProfileValidationMatrix);
  T.Test('PHC shape golden', @TestPhcShapeGolden);
  T.Test('Round trip and negatives', @TestRoundTripAndNegatives);
  T.Test('Random salt distinct hashes', @TestRandomSaltDistinct);
  T.Test('Unicode password round trip', @TestUnicodePasswordRoundTrip);
  T.Test('Empty password fail-fast', @TestEmptyPasswordFailFast);
  T.Test('Invalid profile fail-fast', @TestInvalidProfileFailFast);
  T.Test('NeedsRehash states', @TestNeedsRehashStates);
  T.Test('Default strength round trip once', @TestDefaultStrengthRoundTripOnce);
  if not T.Run then Halt(1);
end.
