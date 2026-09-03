program test_deliverability_dkim;
{**
 * DKIM(RFC 6376/8463): 黄金向量(独立 Python 实现生成, 见 dkim_vectors.inc)
 * body/header 规范化、hash input 构建、b= 置空、RSA-SHA256/Ed25519 完整
 * 验签、DkimSign 与 openssl/cryptography 签名对拍、错误路径(INV-5~8)。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.base.utils,
  nextpas.core.test,
  nextpas.core.deliverability.base,
  nextpas.core.deliverability.dkim,
  nextpas.core.encoding.base64,
  mock_deliverability_dns;

{$INCLUDE dkim_vectors.inc}

{ ── 助手 ─────────────────────────────────────────────────────── }

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
  LV: Integer;
  function Nibble(const C: Char): Integer;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := -1;
    end;
  end;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
  begin
    LV := Nibble(AHex[I * 2 + 1]) * 16 + Nibble(AHex[I * 2 + 2]);
    Result[I] := Byte(LV);
  end;
end;

function StrToBytes(const AStr: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    Result[I - 1] := Byte(AStr[I]);
end;

function BytesToString(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(AData));
  for I := 1 to Length(AData) do
    Result[I] := Chr(AData[I - 1]);
end;

{ 把邮件中 b=<base64> 替换为 ASigB64 }
function ReplaceSignature(const AMail, ASigB64: string): string;
var
  LB: Integer;
  LStart, LEnd: Integer;
begin
  LB := Pos('; b=', AMail);
  if LB = 0 then
    Exit(AMail);
  LStart := LB + Length('; b=');
  LEnd := LStart;
  while (LEnd <= Length(AMail)) and (AMail[LEnd] <> ';') do
    Inc(LEnd);
  Result := Copy(AMail, 1, LStart - 1) + ASigB64 +
    Copy(AMail, LEnd, MaxInt);
end;

{ ── 规范化黄金向量 ──────────────────────────────────────────── }

{ 向量表(按索引取 body 规范化期望值) }
function BodyVec(const AIdx: Integer; const ARelaxed: Boolean): string;
begin
  case AIdx of
    0:
      if ARelaxed then
        Result := DKV_BODY0_RELAXED
      else
        Result := DKV_BODY0_SIMPLE;
    1:
      if ARelaxed then
        Result := DKV_BODY1_RELAXED
      else
        Result := DKV_BODY1_SIMPLE;
    2:
      if ARelaxed then
        Result := DKV_BODY2_RELAXED
      else
        Result := DKV_BODY2_SIMPLE;
    3:
      if ARelaxed then
        Result := DKV_BODY3_RELAXED
      else
        Result := DKV_BODY3_SIMPLE;
    4:
      if ARelaxed then
        Result := DKV_BODY4_RELAXED
      else
        Result := DKV_BODY4_SIMPLE;
  else
    if ARelaxed then
      Result := DKV_BODY5_RELAXED
    else
      Result := DKV_BODY5_SIMPLE;
  end;
end;

procedure TestBodyVectors;
var
  I: Integer;
  LBodies: array[0..5] of string;
begin
  LBodies[0] := '';
  LBodies[1] := 'abc';
  LBodies[2] := 'abc'#13#10;
  LBodies[3] := 'abc'#13#10#13#10;
  LBodies[4] := 'a  b'#9' c'#13#10'  d  '#13#10;
  LBodies[5] := 'line one  '#13#10'line two'#9#13#10#13#10#13#10;
  for I := 0 to 5 do
  begin
    Check(DkimCanonicalizeBody(LBodies[I], cmSimple) = BodyVec(I, False),
      TextFormat('body%d simple', [I]));
    Check(DkimCanonicalizeBody(LBodies[I], cmRelaxed) = BodyVec(I, True),
      TextFormat('body%d relaxed', [I]));
  end;
end;

procedure TestRfcExample1;
var
  LHdr: string;
begin
  { RFC 6376 §3.4.5 示例 1: 消息头区(含折叠) }
  LHdr := 'A: X'#13#10 + 'B : Y'#9#13#10 + #9'Z  ';
  Check(DkimCanonicalizeBody(' C '#13#10 + 'D '#9' E'#13#10#13#10,
    cmRelaxed) = DKV_RFC_EX1_RELAXED_BODY, 'rfc ex1 relaxed body');
  Check(DkimCanonicalizeBody(' C '#13#10 + 'D '#9' E'#13#10#13#10,
    cmSimple) = DKV_RFC_EX1_SIMPLE_BODY, 'rfc ex1 simple body');
end;

procedure TestHeaderVectors;
begin
  { DKV_HDR0: Subject / 多空白 }
  Check(DkimCanonicalizeHeader('Subject', '  Hello   World  ', cmSimple) =
    DKV_HDR0_SIMPLE, 'hdr0 simple');
  Check(DkimCanonicalizeHeader('Subject', '  Hello   World  ', cmRelaxed) =
    DKV_HDR0_RELAXED, 'hdr0 relaxed');
  { DKV_HDR1: 冒号前空白名 + 值尾 tab(simple 原样) }
  Check(DkimCanonicalizeHeader('B ', ' Y'#9, cmSimple) = DKV_HDR1_SIMPLE,
    'hdr1 simple');
  Check(DkimCanonicalizeHeader('B ', ' Y'#9, cmRelaxed) = DKV_HDR1_RELAXED,
    'hdr1 relaxed');
  { DKV_HDR2: 折叠续行 }
  Check(DkimCanonicalizeHeader('Subject', ' foo'#13#10#9'bar', cmSimple) =
    DKV_HDR2_SIMPLE, 'hdr2 simple');
  Check(DkimCanonicalizeHeader('Subject', ' foo'#13#10#9'bar', cmRelaxed) =
    DKV_HDR2_RELAXED, 'hdr2 relaxed');
end;

{ ── 签名头解析 ──────────────────────────────────────────────── }

procedure TestParseSignature;
var
  LSig: TDkimSignature;
  LE: string;
begin
  Check(DkimParseSignature(
    'v=1; a=rsa-sha256; c=relaxed/simple; d=example.com; s=sel;' +
    ' h=from:to; bh=YWJj; b=ZGVm', LSig, LE), 'parse ok');
  Check(LSig.Algo = daRsaSha256, 'algo rsa');
  Check(LSig.CanonHeader = cmRelaxed, 'canon header relaxed');
  Check(LSig.CanonBody = cmSimple, 'canon body simple');
  Check(LSig.Domain = 'example.com', 'domain');
  Check(LSig.Selector = 'sel', 'selector');
  Check(Length(LSig.SignedHeaders) = 2, 'h= count');
  Check(LSig.SignedHeaders[0] = 'from', 'h= [0]');
  Check(LSig.SignedHeaders[1] = 'to', 'h= [1]');
  Check(Length(LSig.BodyHash) = 3, 'bh bytes');

  { c=relaxed 单段 = relaxed/simple }
  Check(DkimParseSignature(
    'v=1; a=rsa-sha256; c=relaxed; d=x.example; s=s; h=from; bh=YQ==; b=Yg==',
    LSig, LE), 'c=relaxed ok');
  Check(LSig.CanonHeader = cmRelaxed, 'c=relaxed header');
  Check(LSig.CanonBody = cmSimple, 'c=relaxed body default simple');
end;

procedure TestParseSignatureErrors;
var
  LSig: TDkimSignature;
  LE: string;
begin
  { 缺 v= }
  Check(not DkimParseSignature(
    'a=rsa-sha256; d=x.example; s=s; h=from; bh=YQ==; b=Yg==', LSig, LE),
    'missing v=');
  { v= 非 1 }
  Check(not DkimParseSignature(
    'v=2; a=rsa-sha256; d=x.example; s=s; h=from; bh=YQ==; b=Yg==', LSig, LE),
    'v=2 rejected');
  { 缺必需 tag(s=) }
  Check(not DkimParseSignature(
    'v=1; a=rsa-sha256; d=x.example; h=from; bh=YQ==; b=Yg==', LSig, LE),
    'missing s=');
  { c= 非法 }
  Check(not DkimParseSignature(
    'v=1; a=rsa-sha256; c=bogus; d=x.example; s=s; h=from; bh=YQ==; b=Yg==',
    LSig, LE), 'bad c=');
  { a= 非法 }
  Check(not DkimParseSignature(
    'v=1; a=sha1; d=x.example; s=s; h=from; bh=YQ==; b=Yg==', LSig, LE),
    'unsupported a=');
  { b= 坏 base64 }
  Check(not DkimParseSignature(
    'v=1; a=rsa-sha256; d=x.example; s=s; h=from; bh=YQ==; b=!!!', LSig, LE),
    'bad b= b64');
end;

{ ── hash input 构建 ──────────────────────────────────────────── }

procedure TestHashInputNullHeader;
var
  LSig: TDkimSignature;
  LData: TBytes;
  LE: string;
  LExp: TBytes;
begin
  { h= 中 x-date 头缺失 → null input 跳过; 无 dkim-signature 头时须报错 }
  Check(DkimParseSignature(
    'v=1; a=rsa-sha256; c=simple/simple; d=example.com; s=s;' +
    ' h=from:subject:x-date; bh=YQ==; b=Yg==', LSig, LE), 'parse');
  Check(not DkimBuildHeaderHashInput(
    'From: a@example.com'#13#10'Subject: s'#13#10#13#10'body',
    LSig, LData, LE), 'missing dkim-signature -> error');
end;

procedure TestHashInputMulti;
var
  LSig: TDkimSignature;
  LData: TBytes;
  LE: string;
  LMail: string;
begin
  { 同名头 X-Multi 两次 + relaxed; 底部起取(first, second) }
  Check(DkimParseSignature(
    'v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com; s=s;' +
    ' h=x-multi:x-multi; bh=YQ==; b=Yg==', LSig, LE), 'parse');
  LMail := 'From: a@example.com'#13#10'Subject: s'#13#10 +
    'X-Multi: first'#13#10'X-Multi: second'#13#10 +
    'DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com;' +
    ' s=s; h=x-multi:x-multi; bh=YQ==; b=Yg=='#13#10#13#10'body';
  Check(DkimBuildHeaderHashInput(LMail, LSig, LData, LE), 'build');
  Check(BytesToString(LData) = DKV_HASHIN_MULTI, 'hashin multi');
end;

procedure TestRemoveBValue;
begin
  { 仅 b= 值置空, 其余段原样; 避开 bh= }
  Check(DkimRemoveBValue('v=1; a=rsa-sha256; b=abc123  ; bh=xyz; h=from; c=simple')
    = DKV_REMOVEBVAL, 'removeb 1');
  Check(DkimRemoveBValue('v=1;a=rsa-sha256;bh=qq;b=AAbb ;h=from') = DKV_REMOVEBVAL2,
    'removeb 2');
end;

{ ── 完整验签 ────────────────────────────────────────────────── }

procedure TestVerifyRsa;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  R := DkimVerify(D, DKV_MAIL_RSA, 1000, E);
  Check(R = dkPass, 'rsa verify pass: ' + DkimResultToString(R) + ' ' + E);
end;

procedure TestVerifyEd25519;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com',
    'v=DKIM1; k=ed25519; p=' + Base64Encode(HexToBytes(DKV_ED25519_PUB_HEX)));
  R := DkimVerify(D, DKV_MAIL_ED25519, 1000, E);
  Check(R = dkPass, 'ed25519 verify pass: ' + DkimResultToString(R) + ' ' + E);
end;

procedure TestVerifyBodyTampered;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
  LEnd: Integer;
  LMail: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  LEnd := Pos(#13#10#13#10, DKV_MAIL_RSA);
  LMail := Copy(DKV_MAIL_RSA, 1, LEnd + 3) + 'Body line 1'#13#10'HACKED';
  R := DkimVerify(D, LMail, 1000, E);
  Check(R = dkFail, 'body tamper -> fail: ' + DkimResultToString(R));
end;

procedure TestVerifySignatureTampered;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
  LMail: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  LMail := ReplaceSignature(DKV_MAIL_RSA, 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
  R := DkimVerify(D, LMail, 1000, E);
  Check(R = dkFail, 'sig tamper -> fail: ' + DkimResultToString(R));
end;

procedure TestVerifyNoSignature;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  R := DkimVerify(D, 'From: a@example.com'#13#10#13#10'body', 1000, E);
  Check(R = dkNeutral, 'no sig -> neutral');
end;

procedure TestVerifyBadB64;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
  LMail: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  LMail := ReplaceSignature(DKV_MAIL_RSA, '!!!not-base64!!!');
  R := DkimVerify(D, LMail, 1000, E);
  Check(R = dkPermError, 'bad b64 -> permerror: ' + DkimResultToString(R));
end;

procedure TestVerifyRevokedKey;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=');
  R := DkimVerify(D, DKV_MAIL_RSA, 1000, E);
  Check(R = dkPermError, 'empty p= -> permerror(revoked)');
end;

procedure TestVerifyKeyNotFound;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  R := DkimVerify(D, DKV_MAIL_RSA, 1000, E);
  Check(R = dkPermError, 'no key -> permerror: ' + DkimResultToString(R));
end;

procedure TestVerifyNetworkError;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddFailure('sel._domainkey.example.com');
  R := DkimVerify(D, DKV_MAIL_RSA, 1000, E);
  Check(R = dkTempError, 'network -> temperror: ' + DkimResultToString(R));
end;

procedure TestVerifyBadVersion;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM2; p=' + DKV_RSA_SPKI_B64);
  R := DkimVerify(D, DKV_MAIL_RSA, 1000, E);
  Check(R = dkPermError, 'key v=DKIM2 discarded -> permerror');
end;

procedure TestVerifyNoFromInH;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDkimResult;
  E: string;
  LMail: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  LMail := StringReplace(DKV_MAIL_RSA, 'h=from:to:subject:x-date',
    'h=to:subject:x-date');
  R := DkimVerify(D, LMail, 1000, E);
  Check(R = dkPermError, 'h= without from -> permerror: ' + E);
end;

{ ── DkimSign 对拍(openssl/cryptography 生成) ────────────────── }

procedure TestSignRsaVector;
var
  LSig: TBytes;
  LE: string;
  LExp: TBytes;
begin
  { 与 python cryptography / openssl 签名一致 = 交叉验证 }
  Check(DkimSign(StrToBytes(DKV_HASHIN_RSA), daRsaSha256,
    HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil,
    LSig, LE), 'rsa sign ok: ' + LE);
  LExp := Base64Decode(DKV_SIG_RSA_B64);
  Check(Length(LSig) = Length(LExp), 'rsa sig len');
  Check(CompareMem(@LSig[0], @LExp[0], Length(LSig)), 'rsa sig matches vector');
end;

procedure TestSignEd25519Vector;
var
  LSig: TBytes;
  LE: string;
  LExp: TBytes;
begin
  Check(DkimSign(StrToBytes(DKV_HASHIN_ED25519), daEd25519Sha256,
    nil, nil, HexToBytes(DKV_ED25519_PRIV_HEX), LSig, LE),
    'ed25519 sign ok: ' + LE);
  LExp := Base64Decode(DKV_SIG_ED25519_B64);
  Check(Length(LSig) = Length(LExp), 'ed25519 sig len');
  Check(CompareMem(@LSig[0], @LExp[0], Length(LSig)),
    'ed25519 sig matches vector');
end;

procedure TestSignThenVerify;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  LSig: TBytes;
  LE: string;
  R: TDkimResult;
  LMail: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  { 对黄金向量 hash input 签名, 替换进邮件, 验签闭环 }
  Check(DkimSign(StrToBytes(DKV_HASHIN_RSA), daRsaSha256,
    HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil, LSig, LE),
    'sign ok');
  LMail := ReplaceSignature(DKV_MAIL_RSA, Base64Encode(LSig));
  R := DkimVerify(D, LMail, 1000, LE);
  Check(R = dkPass, 'sign-verify loop pass: ' + DkimResultToString(R) + ' ' + LE);
end;

{ ── 私钥 PEM 加载(plan 2026-08-25 D2) ──────────────────────── }

function StrArr(const AItems: array of string): TDeliverabilityStringArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AItems));
  for I := 0 to High(AItems) do
    Result[I] := AItems[I];
end;

function SameBytes(const AA, AB: TBytes): Boolean;
begin
  Result := (Length(AA) = Length(AB)) and
    ((Length(AA) = 0) or CompareMem(@AA[0], @AB[0], Length(AA)));
end;

procedure TestLoadKeyPemForms;
var
  LN, LD: TBytes;
  LE: string;
begin
  Check(DkimLoadRsaPrivateKey(DKV_RSA_PEM_PKCS1, LN, LD, LE),
    'pkcs1 load: ' + LE);
  Check(SameBytes(LN, HexToBytes(DKV_RSA_N_HEX)), 'pkcs1 n matches vector');
  Check(SameBytes(LD, HexToBytes(DKV_RSA_D_HEX)), 'pkcs1 d matches vector');

  Check(DkimLoadRsaPrivateKey(DKV_RSA_PEM_PKCS8, LN, LD, LE),
    'pkcs8 load: ' + LE);
  Check(SameBytes(LN, HexToBytes(DKV_RSA_N_HEX)), 'pkcs8 n matches vector');
  Check(SameBytes(LD, HexToBytes(DKV_RSA_D_HEX)), 'pkcs8 d matches vector');
end;

procedure TestLoadKeyBadPem;
var
  LN, LD: TBytes;
  LE: string;
begin
  LN := nil;
  LD := nil;
  Check(not DkimLoadRsaPrivateKey('not a pem at all', LN, LD, LE),
    'garbage rejected');
  Check(LE <> '', 'error text set');
  Check(not DkimLoadRsaPrivateKey(
    '-----BEGIN CERTIFICATE-----'#13#10'AQIDBA=='#13#10 +
    '-----END CERTIFICATE-----'#13#10, LN, LD, LE), 'cert-only rejected');
  Check(not DkimLoadRsaPrivateKey(
    '-----BEGIN PRIVATE KEY-----'#13#10'AQIDBA=='#13#10 +
    '-----END PRIVATE KEY-----'#13#10, LN, LD, LE),
    'pkcs8 non-rsa der rejected: ' + LE);
end;

{ ── DkimSignMail 组装(plan 2026-08-25 D1) ──────────────────── }

procedure TestSignMailGolden;
var
  LOut1, LOut2, LE: string;
begin
  Check(DkimSignMail(DKV_SIGNMAIL_INPUT, 'example.com', 'sel',
    StrArr(['from', 'to', 'subject', 'x-date']), cmRelaxed, cmSimple,
    daRsaSha256, HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil,
    LOut1, LE), 'signmail ok: ' + LE);
  Check(LOut1 = DKV_SIGNMAIL_EXPECTED, 'signmail golden bytes match');
  { 无 t=/x=: 同输入两次签名输出逐字节一致; h= 大小写/空白归一 }
  Check(DkimSignMail(DKV_SIGNMAIL_INPUT, 'example.com', 'sel',
    StrArr(['FROM', 'To', 'SUBJECT', ' X-Date ']), cmRelaxed, cmSimple,
    daRsaSha256, HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil,
    LOut2, LE), 'signmail 2nd ok');
  Check(LOut2 = LOut1, 'signmail deterministic + h= 归一');
end;

procedure TestSignMailLoopbackRsa;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  LOut, LE: string;
  R: TDkimResult;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  Check(DkimSignMail(DKV_SIGNMAIL_INPUT, 'example.com', 'sel',
    StrArr(['from', 'to', 'subject']), cmRelaxed, cmSimple,
    daRsaSha256, HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil,
    LOut, LE), 'sign: ' + LE);
  Check(Pos('DKIM-Signature: ', LOut) = 1, 'signature is physical first header');
  Check(Pos(DKV_SIGNMAIL_INPUT, LOut) =
    Length(LOut) - Length(DKV_SIGNMAIL_INPUT) + 1, 'original mail untouched');
  R := DkimVerify(I, LOut, 1000, LE);
  Check(R = dkPass, 'signmail->verify loop pass: ' +
    DkimResultToString(R) + ' ' + LE);
end;

procedure TestSignMailLoopbackEd25519;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  LOut, LE: string;
  R: TDkimResult;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('sel._domainkey.example.com',
    'v=DKIM1; k=ed25519; p=' + Base64Encode(HexToBytes(DKV_ED25519_PUB_HEX)));
  Check(DkimSignMail(
    'From: alice@example.com'#13#10'To: b@example.net'#13#10#13#10'hi',
    'example.com', 'sel', StrArr(['from', 'to']),
    cmSimple, cmSimple, daEd25519Sha256, nil, nil,
    HexToBytes(DKV_ED25519_PRIV_HEX), LOut, LE), 'ed sign: ' + LE);
  R := DkimVerify(I, LOut, 1000, LE);
  Check(R = dkPass, 'ed25519 loop pass: ' + DkimResultToString(R) + ' ' + LE);
end;

procedure TestSignMailErrors;
var
  LOut, LE: string;
begin
  { h= 缺 from(RFC 6376 §3.5 必签 From) }
  Check(not DkimSignMail(DKV_SIGNMAIL_INPUT, 'example.com', 'sel',
    StrArr(['to', 'subject']), cmRelaxed, cmSimple,
    daRsaSha256, HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil,
    LOut, LE), 'h= without from rejected');
  Check(LE = 'h= must include from', 'error text');
  { 空 domain / selector }
  Check(not DkimSignMail(DKV_SIGNMAIL_INPUT, '', 'sel',
    StrArr(['from']), cmRelaxed, cmSimple, daRsaSha256,
    HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil, LOut, LE),
    'empty domain rejected');
  Check(not DkimSignMail(DKV_SIGNMAIL_INPUT, 'example.com', '',
    StrArr(['from']), cmRelaxed, cmSimple, daRsaSha256,
    HexToBytes(DKV_RSA_N_HEX), HexToBytes(DKV_RSA_D_HEX), nil, LOut, LE),
    'empty selector rejected');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.deliverability.dkim');
  T.Test('BodyVectors', @TestBodyVectors);
  T.Test('RfcExample1', @TestRfcExample1);
  T.Test('HeaderVectors', @TestHeaderVectors);
  T.Test('ParseSignature', @TestParseSignature);
  T.Test('ParseSignatureErrors', @TestParseSignatureErrors);
  T.Test('HashInputNullHeader', @TestHashInputNullHeader);
  T.Test('HashInputMulti', @TestHashInputMulti);
  T.Test('RemoveBValue', @TestRemoveBValue);
  T.Test('VerifyRsa', @TestVerifyRsa);
  T.Test('VerifyEd25519', @TestVerifyEd25519);
  T.Test('VerifyBodyTampered', @TestVerifyBodyTampered);
  T.Test('VerifySignatureTampered', @TestVerifySignatureTampered);
  T.Test('VerifyNoSignature', @TestVerifyNoSignature);
  T.Test('VerifyBadB64', @TestVerifyBadB64);
  T.Test('VerifyRevokedKey', @TestVerifyRevokedKey);
  T.Test('VerifyKeyNotFound', @TestVerifyKeyNotFound);
  T.Test('VerifyNetworkError', @TestVerifyNetworkError);
  T.Test('VerifyBadVersion', @TestVerifyBadVersion);
  T.Test('VerifyNoFromInH', @TestVerifyNoFromInH);
  T.Test('SignRsaVector', @TestSignRsaVector);
  T.Test('SignEd25519Vector', @TestSignEd25519Vector);
  T.Test('SignThenVerify', @TestSignThenVerify);
  T.Test('LoadKeyPemForms', @TestLoadKeyPemForms);
  T.Test('LoadKeyBadPem', @TestLoadKeyBadPem);
  T.Test('SignMailGolden', @TestSignMailGolden);
  T.Test('SignMailLoopbackRsa', @TestSignMailLoopbackRsa);
  T.Test('SignMailLoopbackEd25519', @TestSignMailLoopbackEd25519);
  T.Test('SignMailErrors', @TestSignMailErrors);
  if not T.Run then
    Halt(1);
end.