program test_token;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.encoding.base64,
  nextpas.core.auth.token;

var
  T: TTestSuite;

{ 无 RTL 依赖的整数→十进制(对齐 test_jwt 先例)。 }
function IntToStr(const V: Int32): string;
begin
  Str(V, Result);
end;

{ 字节长度 → base64url 无填充字符数 = ceil(bytes*4/3)。 }
function ExpectedTokenLength(ABytes: Integer): Integer;
begin
  Result := (ABytes * 4 + 2) div 3;
end;

procedure TestLengthMapping;
begin
  CheckEqual(Int64(ExpectedTokenLength(16)), Int64(Length(NewAuthToken(16))),
    '16 bytes -> 22 chars');
  CheckEqual(Int64(22), Int64(Length(NewAuthToken(16))), '16 -> 22 exact');
  CheckEqual(Int64(43), Int64(Length(NewAuthToken(32))), '32 -> 43 exact');
  CheckEqual(Int64(64), Int64(Length(NewAuthToken(48))), '48 -> 64 exact');
end;

procedure TestCharsetAndNoPadding;
const
  CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
var
  LTok: string;
  I, J: Integer;
  LOk: Boolean;
begin
  for J := 1 to 8 do
  begin
    LTok := NewAuthToken(32);
    LOk := Length(LTok) > 0;
    for I := 1 to Length(LTok) do
      if Pos(LTok[I], CHARS) = 0 then
        LOk := False;
    Check(LOk, 'token charset [A-Za-z0-9_-] no padding, iter ' + IntToStr(J));
  end;
end;

procedure TestUniqueness;
var
  LSeen: array[0..63] of string;
  I, J: Integer;
  LDup: Boolean;
begin
  for I := 0 to High(LSeen) do
    LSeen[I] := NewAuthToken(32);
  LDup := False;
  for I := 0 to High(LSeen) do
    for J := I + 1 to High(LSeen) do
      if LSeen[I] = LSeen[J] then
        LDup := True;
  Check(not LDup, '64 generated tokens all distinct');
end;

procedure TestDecodeRoundTrip;
var
  LTok: string;
  LRaw: TBytes;
begin
  LTok := NewAuthToken(32);
  Check(TryDecodeAuthToken(LTok, LRaw), 'generated token decodes');
  CheckEqual(Int64(32), Int64(Length(LRaw)), 'decoded size = entropy bytes');
  CheckEqual(LTok, Base64UrlEncode(LRaw), 're-encode identity');
end;

procedure TestMalformedDecode;
var
  LRaw: TBytes;
begin
  Check(not TryDecodeAuthToken('++++', LRaw), '+ not in url alphabet');
  Check(not TryDecodeAuthToken('a===b', LRaw), 'misplaced padding rejected');
  Check(not TryDecodeAuthToken('abcde', LRaw), 'length mod 4 = 1 rejected');
  Check(not TryDecodeAuthToken('====', LRaw), 'pure padding rejected');

  { 填充仅当总长为 4 的倍数(core 解码器同规则)。 }
  Check(TryDecodeAuthToken('AA==', LRaw), 'canonical padded quantum accepted');
  CheckEqual(Int64(1), Int64(Length(LRaw)), 'AA== -> 1 byte');
  Check(not TryDecodeAuthToken('a===', LRaw), '3 pad chars rejected');
  Check(not TryDecodeAuthToken('abcde=', LRaw), 'padded but len not multiple of 4');

  { 尾量子规范位:非规范编码拒绝(防同文多形)。 }
  Check(not TryDecodeAuthToken('ab', LRaw), 'trailing low4=1011 non-canonical');
  Check(TryDecodeAuthToken('AA', LRaw), 'trailing low4=0000 canonical');
  Check(not TryDecodeAuthToken('AAB', LRaw), 'trailing low2=01 non-canonical');
  Check(TryDecodeAuthToken('AAA', LRaw), 'trailing low2=00 canonical');
  Check(not TryDecodeAuthToken('AB==', LRaw), 'padded non-canonical rejected');

  { 空串合法(空字节);带填充输入解码宽容。 }
  Check(TryDecodeAuthToken('', LRaw), 'empty token decodes');
  CheckEqual(Int64(0), Int64(Length(LRaw)), 'empty -> zero bytes');
end;

procedure TestEntropyBitsSentinel;
var
  LBits: Integer;
begin
  LBits := AuthTokenEntropyBits(NewAuthToken(32));
  CheckEqual(Int64(256), Int64(LBits), 'default token = 256 bits');
  LBits := AuthTokenEntropyBits(NewAuthToken(16));
  CheckEqual(Int64(128), Int64(LBits), 'floor token = 128 bits');
  CheckEqual(Int64(-1), Int64(AuthTokenEntropyBits('++++')), 'malformed -> -1 sentinel');
end;

procedure TestBelowFloorFailFast;
var
  LRaised: Boolean;

  procedure ExpectRaise(ABytes: Integer; AWhat: string);
  begin
    LRaised := False;
    try
      NewAuthToken(ABytes);
    except
      on E: EArgumentError do LRaised := True;
    end;
    Check(LRaised, AWhat);
  end;

begin
  ExpectRaise(15, '15 bytes below floor raises');
  ExpectRaise(0, 'zero bytes raises');
  ExpectRaise(-1, 'negative bytes raises');
end;

procedure TestConstantTimeEqual;
var
  LA, LB: string;
begin
  LA := NewAuthToken(32);
  LB := NewAuthToken(32);
  Check(AuthTokensEqual(LA, LA), 'identical equal true');
  Check(not AuthTokensEqual(LA, LB), 'distinct same-length false');
  Check(not AuthTokensEqual(LA, Copy(LA, 1, Length(LA) - 1)),
    'length difference false');
  Check(AuthTokensEqual('', ''), 'empty pair equal true');
end;

begin
  T := TTestSuite.Create('nextpas.core.auth.token');
  T.Test('Length mapping', @TestLengthMapping);
  T.Test('Charset and no padding', @TestCharsetAndNoPadding);
  T.Test('Uniqueness', @TestUniqueness);
  T.Test('Decode round trip', @TestDecodeRoundTrip);
  T.Test('Malformed decode', @TestMalformedDecode);
  T.Test('Entropy bits sentinel', @TestEntropyBitsSentinel);
  T.Test('Below floor fail-fast', @TestBelowFloorFailFast);
  T.Test('Constant time equal', @TestConstantTimeEqual);
  if not T.Run then Halt(1);
end.
