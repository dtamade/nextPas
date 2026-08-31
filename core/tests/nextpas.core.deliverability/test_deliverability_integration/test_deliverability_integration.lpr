program test_deliverability_integration;
{**
 * 全链编排: 一封带 DKIM 签名的邮件 + SPF/DMARC 记录在同一 mock DNS 下,
 * CheckDeliverability 输出 Verdict(SPF/DKIM/DKIMSigningDomain/DMARC)。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.deliverability.base,
  nextpas.core.deliverability,
  mock_deliverability_dns;

{$INCLUDE dkim_vectors.inc}

procedure TestAllPass;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  V: TDeliverabilityVerdict;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.10 -all');
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  D.AddTXT('_dmarc.example.com',
    'v=DMARC1; p=reject; rua=mailto:agg@example.com');
  V := CheckDeliverability(D, DKV_MAIL_RSA, 'example.com', 'smtp@example.com',
    '192.0.2.10', 1000);
  Check(V.SPF = srPass, 'spf pass: ' + SpfResultToString(V.SPF));
  Check(V.DKIM = dkPass, 'dkim pass: ' + DkimResultToString(V.DKIM));
  Check(V.DKIMSigningDomain = 'example.com', 'dkim signing domain');
  Check(V.DMARC = dmPass, 'dmarc pass: ' + DmarcResultToString(V.DMARC));
end;

procedure TestSpfFailDkimPass;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  V: TDeliverabilityVerdict;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.99 -all');
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject');
  V := CheckDeliverability(D, DKV_MAIL_RSA, 'example.com', 'smtp@example.com',
    '192.0.2.10', 1000);
  Check(V.SPF = srFail, 'spf fail');
  Check(V.DKIM = dkPass, 'dkim pass');
  { DKIM 对齐(relaxed)通过 → DMARC pass }
  Check(V.DMARC = dmPass, 'dmarc pass via dkim: '
    + DmarcResultToString(V.DMARC));
end;

procedure TestAllFail;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  V: TDeliverabilityVerdict;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.99 -all');
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject');
  { 无 DKIM 记录 + IP 不匹配 → SPF fail, 无 DKIM, DMARC fail }
  V := CheckDeliverability(D, DKV_MAIL_RSA, 'example.com', 'smtp@example.com',
    '192.0.2.10', 1000);
  Check(V.SPF = srFail, 'spf fail');
  Check(V.DKIM = dkPermError, 'dkim permerror (no key)');
  Check(V.DMARC = dmFail, 'dmarc fail: ' + DmarcResultToString(V.DMARC));
end;

procedure TestNoDmarc;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  V: TDeliverabilityVerdict;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.10 -all');
  D.AddTXT('sel._domainkey.example.com', 'v=DKIM1; p=' + DKV_RSA_SPKI_B64);
  V := CheckDeliverability(D, DKV_MAIL_RSA, 'example.com', 'smtp@example.com',
    '192.0.2.10', 1000);
  Check(V.SPF = srPass, 'spf pass');
  Check(V.DKIM = dkPass, 'dkim pass');
  Check(V.DMARC = dmNone, 'dmarc none');
end;

procedure TestUnsignedMail;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  V: TDeliverabilityVerdict;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.10 -all');
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject');
  V := CheckDeliverability(D,
    'From: alice@example.com'#13#10#13#10'no signature here',
    'example.com', 'smtp@example.com', '192.0.2.10', 1000);
  Check(V.SPF = srPass, 'spf pass');
  Check(V.DKIM = dkNeutral, 'dkim neutral');
  { SPF 对齐即视为 DMARC 通过(RFC 7489 §6.4), 无需 DKIM }
  Check(V.DMARC = dmPass, 'dmarc pass');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.deliverability.integration');
  T.Test('AllPass', @TestAllPass);
  T.Test('SpfFailDkimPass', @TestSpfFailDkimPass);
  T.Test('AllFail', @TestAllFail);
  T.Test('NoDmarc', @TestNoDmarc);
  T.Test('UnsignedMail', @TestUnsignedMail);
  if not T.Run then
    Halt(1);
end.