program test_deliverability_dmarc;
{**
 * DMARC(RFC 7489): 记录解析全标签、sp= 缺省跟随 p=、pct、对齐 relaxed/strict、
 * 精确域→组织域回退、多记录终止、网络错误、空 From(契约 INV-9~12)。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.deliverability.base,
  nextpas.core.deliverability.dmarc,
  mock_deliverability_dns;

{ ── 记录解析 ─────────────────────────────────────────────────── }

procedure TestParseFull;
var
  R: TDmarcRecord;
  E: string;
begin
  Check(DmarcParseRecord(
    'v=DMARC1; p=reject; sp=quarantine; aspf=s; adkim=r; pct=25;' +
    ' rua=mailto:agg@example.com; ruf=mailto:fr@example.com', R, E),
    'parse full: ' + E);
  Check(R.Policy = dmpReject, 'p reject');
  Check(R.SubdomainPolicy = dmpQuarantine, 'sp quarantine');
  Check(R.SPFAlign = amStrict, 'aspf strict');
  Check(R.DKIMAlign = amRelaxed, 'adkim relaxed');
  Check(R.Pct = 25, 'pct 25');
  Check(R.RUA = 'mailto:agg@example.com', 'rua');
  Check(R.RUF = 'mailto:fr@example.com', 'ruf');
end;

procedure TestParseDefaults;
var
  R: TDmarcRecord;
  E: string;
begin
  Check(DmarcParseRecord('v=DMARC1; p=quarantine', R, E), 'parse minimal');
  Check(R.Policy = dmpQuarantine, 'p');
  { sp= 缺省跟随 p= }
  Check(R.SubdomainPolicy = dmpQuarantine, 'sp follows p');
  Check(R.SPFAlign = amRelaxed, 'aspf default relaxed');
  Check(R.DKIMAlign = amRelaxed, 'adkim default relaxed');
  Check(R.Pct = 100, 'pct default 100');
end;

procedure TestParseErrors;
var
  R: TDmarcRecord;
  E: string;
begin
  { 缺 v= }
  Check(not DmarcParseRecord('p=reject', R, E), 'missing v');
  { v= 非 DMARC1 }
  Check(not DmarcParseRecord('v=DMARC2; p=reject', R, E), 'bad v');
  { 缺 p= }
  Check(not DmarcParseRecord('v=DMARC1; sp=quarantine', R, E), 'missing p');
  { p= 非法 }
  Check(not DmarcParseRecord('v=DMARC1; p=bogus', R, E), 'bad p');
  { pct 非法 → 缺省 100 }
  Check(DmarcParseRecord('v=DMARC1; p=none; pct=150', R, E), 'pct parse');
  Check(R.Pct = 100, 'pct fallback 100');
end;

procedure TestParseSpInvalid;
var
  R: TDmarcRecord;
  E: string;
begin
  { sp= 非法值 → 缺省跟随 p=(宽松, 记录仍有效) }
  Check(DmarcParseRecord('v=DMARC1; p=none; sp=bogus', R, E), 'sp invalid ok');
  Check(R.SubdomainPolicy = dmpNone, 'sp follows p');
end;

{ ── 对齐与策略发现 ───────────────────────────────────────────── }

procedure TestAlignRelaxed;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject');
  { relaxed: 组织域相同即对齐 }
  R := DmarcCheck(D, 'mail.example.com', srPass, 'example.com', dkFail, '',
    1000, E);
  Check(R = dmPass, 'spf relaxed align: ' + DmarcResultToString(R) + ' ' + E);
  R := DmarcCheck(D, 'example.com', srFail, 'example.com', dkPass,
    'mail.example.com', 1000, E);
  Check(R = dmPass, 'dkim relaxed align');
  { 组织域相同但 SPF/DKIM 均不对齐 → fail }
  R := DmarcCheck(D, 'mail.example.com', srFail, 'other.example.net', dkFail, '',
    1000, E);
  Check(R = dmFail, 'no align -> fail');
end;

procedure TestAlignStrict;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject; aspf=s; adkim=s');
  { strict: FQDN 完全相等 }
  R := DmarcCheck(D, 'example.com', srPass, 'example.com', dkFail, '', 1000, E);
  Check(R = dmPass, 'strict exact');
  R := DmarcCheck(D, 'mail.example.com', srPass, 'example.com', dkFail, '',
    1000, E);
  Check(R = dmFail, 'strict subdomain -> fail');
  R := DmarcCheck(D, 'example.com', srFail, 'example.com', dkPass, 'example.com',
    1000, E);
  Check(R = dmPass, 'strict dkim exact');
end;

procedure TestPolicyDiscoveryFallback;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  { 精确域无记录, 组织域有记录 → 回退 }
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=none');
  R := DmarcCheck(D, 'mail.example.com', srPass, 'example.com', dkFail, '',
    1000, E);
  Check(R = dmPass, 'org fallback');
end;

procedure TestNoRecord;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  R := DmarcCheck(D, 'example.com', srFail, 'example.com', dkFail, '', 1000, E);
  Check(R = dmNone, 'no record -> none');
end;

procedure TestMultipleRecords;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=reject');
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=none');
  R := DmarcCheck(D, 'example.com', srPass, 'example.com', dkPass,
    'example.com', 1000, E);
  Check(R = dmNone, 'multiple records terminate -> none');
end;

procedure TestInvalidRecord;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=bogus');
  R := DmarcCheck(D, 'example.com', srPass, 'example.com', dkFail, '', 1000, E);
  Check(R = dmNone, 'invalid record -> none');
end;

procedure TestNetworkError;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddFailure('_dmarc.example.com');
  R := DmarcCheck(D, 'example.com', srFail, 'example.com', dkFail, '', 1000, E);
  Check(R = dmTempError, 'network -> temperror');
end;

procedure TestEmptyFrom;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  R := DmarcCheck(D, '', srFail, 'example.com', dkFail, '', 1000, E);
  Check(R = dmNone, 'empty from -> none');
end;

procedure TestNonDmarcTxt;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  R: TDmarcResult;
  E: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  { 精确域有 TXT 但非 DMARC → 回退组织域; 组织域也没有 → none }
  D.AddTXT('_dmarc.mail.example.com', 'some other txt');
  D.AddTXT('_dmarc.example.com', 'v=DMARC1; p=quarantine');
  R := DmarcCheck(D, 'mail.example.com', srPass, 'example.com', dkFail, '',
    1000, E);
  Check(R = dmPass, 'non-dmarc txt falls back');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.deliverability.dmarc');
  T.Test('ParseFull', @TestParseFull);
  T.Test('ParseDefaults', @TestParseDefaults);
  T.Test('ParseErrors', @TestParseErrors);
  T.Test('ParseSpInvalid', @TestParseSpInvalid);
  T.Test('AlignRelaxed', @TestAlignRelaxed);
  T.Test('AlignStrict', @TestAlignStrict);
  T.Test('PolicyDiscoveryFallback', @TestPolicyDiscoveryFallback);
  T.Test('NoRecord', @TestNoRecord);
  T.Test('MultipleRecords', @TestMultipleRecords);
  T.Test('InvalidRecord', @TestInvalidRecord);
  T.Test('NetworkError', @TestNetworkError);
  T.Test('EmptyFrom', @TestEmptyFrom);
  T.Test('NonDmarcTxt', @TestNonDmarcTxt);
  if not T.Run then
    Halt(1);
end.