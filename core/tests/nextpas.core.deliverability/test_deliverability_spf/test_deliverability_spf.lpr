program test_deliverability_spf;
{**
 * SPF(RFC 7208)表驱动测试: qualifier/ip4/ip6/a/mx/include/redirect/exists/
 * 宏/查询上限/void 上限/多记录/语法预校验/错误映射(契约 INV-1~4)。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.deliverability.base,
  nextpas.core.deliverability.spf,
  mock_deliverability_dns;

procedure CheckSpf(ADns: TMockDeliverabilityDns; const ADomain, AClientIP,
  ASender: string; const AExpected: TSpfResult; const AName: string);
var
  R: TSpfResult;
  E: string;
begin
  R := SpfCheck(ADns, ADomain, AClientIP, ASender, 1000, E);
  Check(R = AExpected,
    AName + ': got ' + SpfResultToString(R) + ' (' + E + ')');
end;

{ ── qualifier 与 ip 机制 ─────────────────────────────────────── }

procedure TestQualifiers;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 +all');
  D.AddTXT('fail.example.com', 'v=spf1 -all');
  D.AddTXT('soft.example.com', 'v=spf1 ~all');
  D.AddTXT('neut.example.com', 'v=spf1 ?all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPass, '+all');
  CheckSpf(D, 'fail.example.com', '192.0.2.1', 'a@example.com', srFail, '-all');
  CheckSpf(D, 'soft.example.com', '192.0.2.1', 'a@example.com', srSoftFail, '~all');
  CheckSpf(D, 'neut.example.com', '192.0.2.1', 'a@example.com', srNeutral, '?all');
end;

procedure TestIp4;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.1 -all');
  D.AddTXT('cidr.example.com', 'v=spf1 ip4:192.0.2.0/24 -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPass, 'ip4 exact');
  CheckSpf(D, 'example.com', '192.0.2.2', 'a@example.com', srFail, 'ip4 miss');
  CheckSpf(D, 'cidr.example.com', '192.0.2.55', 'a@example.com', srPass, 'ip4 cidr in');
  CheckSpf(D, 'cidr.example.com', '192.0.3.1', 'a@example.com', srFail, 'ip4 cidr out');
end;

procedure TestIp6;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip6:2001:db8::/32 -all');
  CheckSpf(D, 'example.com', '2001:db8::1', 'a@example.com', srPass, 'ip6 in');
  CheckSpf(D, 'example.com', '2001:db9::1', 'a@example.com', srFail, 'ip6 out');
end;

procedure TestIp4BadCidr;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.1/33 -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'ip4 /33 permerror');
end;

{ ── a / mx ───────────────────────────────────────────────────── }

procedure TestAMechanism;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 a -all');
  D.AddA('example.com', '192.0.2.10');
  CheckSpf(D, 'example.com', '192.0.2.10', 'a@example.com', srPass, 'a hit');
  CheckSpf(D, 'example.com', '192.0.2.11', 'a@example.com', srFail, 'a miss');
end;

procedure TestACidr;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 a:example.com/24 -all');
  D.AddA('example.com', '192.0.2.10');
  D.AddA('example.com', '2001:db8::1');
  CheckSpf(D, 'example.com', '192.0.2.50', 'a@example.com', srPass,
    'a /24 v4 in');
  { 单 cidr 的 v6 缺省 /128: 2001:db8::2 与记录 2001:db8::1 不相等 }
  CheckSpf(D, 'example.com', '2001:db8::2', 'a@example.com', srFail,
    'a /24 v6 uses default /128');
end;

procedure TestADualCidr;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 a:example.com/24/64 -all');
  D.AddA('example.com', '2001:db8::1');
  CheckSpf(D, 'example.com', '2001:db8::1234', 'a@example.com', srPass,
    'a dual cidr v6 in');
end;

procedure TestMx;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 mx -all');
  D.AddMX('example.com', 'mail.example.com');
  D.AddA('mail.example.com', '192.0.2.20');
  CheckSpf(D, 'example.com', '192.0.2.20', 'a@example.com', srPass, 'mx hit');
  CheckSpf(D, 'example.com', '192.0.2.21', 'a@example.com', srFail, 'mx miss');
end;

procedure TestMxAddressLimit;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  J: Integer;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 mx -all');
  D.AddMX('example.com', 'mail.example.com');
  for J := 0 to 10 do
    D.AddA('mail.example.com', Format('192.0.2.%d', [J + 1]));
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'mx >10 addresses permerror');
end;

{ ── include / redirect ───────────────────────────────────────── }

procedure TestInclude;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 include:spf.example.com -all');
  D.AddTXT('spf.example.com', 'v=spf1 ip4:192.0.2.30 -all');
  CheckSpf(D, 'example.com', '192.0.2.30', 'a@example.com', srPass,
    'include pass');
  CheckSpf(D, 'example.com', '192.0.2.31', 'a@example.com', srFail,
    'include no-match then -all');
end;

procedure TestIncludeNone;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 include:ghost.example.com -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'include none -> permerror');
end;

procedure TestRedirect;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 redirect=spf.example.com');
  D.AddTXT('spf.example.com', 'v=spf1 ip4:192.0.2.40 -all');
  CheckSpf(D, 'example.com', '192.0.2.40', 'a@example.com', srPass,
    'redirect pass');
  CheckSpf(D, 'example.com', '192.0.2.41', 'a@example.com', srFail,
    'redirect fail');
end;

procedure TestRedirectNone;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 redirect=ghost.example.com');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'redirect none -> permerror');
end;

procedure TestRedirectIgnoredWithAll;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 -all redirect=spf.example.com');
  D.AddTXT('spf.example.com', 'v=spf1 ip4:192.0.2.40 -all');
  CheckSpf(D, 'example.com', '192.0.2.40', 'a@example.com', srFail,
    'all ignores redirect');
end;

procedure TestRedirectMacro;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 redirect=%{d}._spf');
  D.AddTXT('example.com._spf', 'v=spf1 ip4:192.0.2.45 -all');
  CheckSpf(D, 'example.com', '192.0.2.45', 'a@example.com', srPass,
    'redirect macro %d');
end;

{ ── exists / 宏 ──────────────────────────────────────────────── }

procedure TestExists;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 exists:hosts.example.com -all');
  D.AddA('hosts.example.com', '192.0.2.1');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPass,
    'exists A hit');
end;

procedure TestExistsMiss;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 exists:ghost.example.com -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srFail,
    'exists miss -> -all');
end;

procedure TestMacros;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  { %s 完整信封; %o 域; %l 本地部分; %d 当前域; %i 客户端 IP; %v 族 }
  D.AddTXT('example.com', 'v=spf1 exists:%{s} -all');
  D.AddA('user@example.com', '192.0.2.1');
  CheckSpf(D, 'example.com', '192.0.2.1', 'user@example.com', srPass, '%s');

  D.AddTXT('macro2.example.com', 'v=spf1 exists:%{o} -all');
  D.AddA('example.com', '192.0.2.1');
  CheckSpf(D, 'macro2.example.com', '192.0.2.1', 'user@example.com', srPass,
    '%o domain');

  D.AddTXT('macro3.example.com', 'v=spf1 exists:%{l}.hosts.example.com -all');
  D.AddA('user.hosts.example.com', '192.0.2.1');
  CheckSpf(D, 'macro3.example.com', '192.0.2.1', 'user@example.com', srPass,
    '%l local-part');

  D.AddTXT('macro4.example.com', 'v=spf1 exists:%{d}.check -all');
  D.AddA('macro4.example.com.check', '192.0.2.1');
  CheckSpf(D, 'macro4.example.com', '192.0.2.1', 'user@example.com', srPass,
    '%d current domain');

  { %i 客户端 IP 文本作为名字标签 }
  D.AddTXT('macro5.example.com', 'v=spf1 exists:%{i}.rbl.example.net -all');
  D.AddA('192.0.2.1.rbl.example.net', '192.0.2.1');
  CheckSpf(D, 'macro5.example.com', '192.0.2.1', 'user@example.com', srPass,
    '%i client ip');

  { %v 族名 in-addr / ip6 }
  D.AddTXT('macro6.example.com', 'v=spf1 exists:%{v}.example.net -all');
  D.AddA('in-addr.example.net', '192.0.2.1');
  CheckSpf(D, 'macro6.example.com', '192.0.2.1', 'user@example.com', srPass,
    '%v in-addr');

  { a: 机制宏展开 }
  D.AddTXT('macro7.example.com', 'v=spf1 a:%{d}/24 -all');
  D.AddA('macro7.example.com', '192.0.2.9');
  CheckSpf(D, 'macro7.example.com', '192.0.2.9', 'user@example.com', srPass,
    'a %d cidr');
end;

procedure TestMacroModifierUnsupported;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 exists:%{s1-} -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'user@example.com', srPermError,
    'macro modifier -> permerror');
end;

procedure TestUnknownMacro;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 exists:%{z} -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'user@example.com', srPermError,
    'unknown macro -> permerror');
end;

{ ── 上限与错误 ───────────────────────────────────────────────── }

procedure TestLookupLimit;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
  J: Integer;
  LRec: string;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  LRec := 'v=spf1';
  for J := 1 to 10 do
    LRec := LRec + ' include:inc' + IntToStr(J) + '.example.com';
  LRec := LRec + ' -all';
  D.AddTXT('example.com', LRec);
  for J := 1 to 10 do
    D.AddTXT('inc' + IntToStr(J) + '.example.com', 'v=spf1 -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'lookup limit 10 -> permerror');
end;

procedure TestVoidLimit;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com',
    'v=spf1 a:void1.example.com a:void2.example.com a:void3.example.com -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'void limit 2 -> permerror');
end;

procedure TestNoRecord;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srNone, 'none');
end;

procedure TestNetworkError;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddFailure('example.com');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srTempError,
    'network -> temperror');
end;

procedure TestMalformed;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 bogus -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'unknown mechanism -> permerror');
end;

procedure TestSyntaxPrecheck;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  { ip4 先匹配, 但记录后面有未知机制: RFC 7208 §4.6 全量校验 → permerror }
  D.AddTXT('example.com', 'v=spf1 ip4:192.0.2.1 bogus -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'syntax anywhere -> permerror');
end;

procedure TestAllAfterIgnored;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  { all 之后机制忽略(RFC 7208 §5.1), 含未知机制 }
  D.AddTXT('example.com', 'v=spf1 -all bogus');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srFail,
    'after-all ignored');
end;

procedure TestInvalidClientIp;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 -all');
  CheckSpf(D, 'example.com', 'not-an-ip', 'a@example.com', srPermError,
    'invalid client ip -> permerror');
end;

procedure TestMultipleRecords;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 -all');
  D.AddTXT('example.com', 'v=spf1 +all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srPermError,
    'multiple records -> permerror');
end;

procedure TestNoVspf;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'some other txt');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srNone,
    'no v=spf1 -> none');
end;

procedure TestNeutralDefault;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srNeutral,
    'no mechanism -> neutral');
end;

procedure TestPtrNoMatch;
var
  D: TMockDeliverabilityDns;
  I: IDeliverabilityDns;
begin
  D := TMockDeliverabilityDns.Create;
  I := D;
  D.AddTXT('example.com', 'v=spf1 ptr -all');
  CheckSpf(D, 'example.com', '192.0.2.1', 'a@example.com', srFail,
    'ptr treated as no-match');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.deliverability.spf');
  T.Test('Qualifiers', @TestQualifiers);
  T.Test('Ip4', @TestIp4);
  T.Test('Ip6', @TestIp6);
  T.Test('Ip4BadCidr', @TestIp4BadCidr);
  T.Test('AMechanism', @TestAMechanism);
  T.Test('ACidr', @TestACidr);
  T.Test('ADualCidr', @TestADualCidr);
  T.Test('Mx', @TestMx);
  T.Test('MxAddressLimit', @TestMxAddressLimit);
  T.Test('Include', @TestInclude);
  T.Test('IncludeNone', @TestIncludeNone);
  T.Test('Redirect', @TestRedirect);
  T.Test('RedirectNone', @TestRedirectNone);
  T.Test('RedirectIgnoredWithAll', @TestRedirectIgnoredWithAll);
  T.Test('RedirectMacro', @TestRedirectMacro);
  T.Test('Exists', @TestExists);
  T.Test('ExistsMiss', @TestExistsMiss);
  T.Test('Macros', @TestMacros);
  T.Test('MacroModifierUnsupported', @TestMacroModifierUnsupported);
  T.Test('UnknownMacro', @TestUnknownMacro);
  T.Test('LookupLimit', @TestLookupLimit);
  T.Test('VoidLimit', @TestVoidLimit);
  T.Test('NoRecord', @TestNoRecord);
  T.Test('NetworkError', @TestNetworkError);
  T.Test('Malformed', @TestMalformed);
  T.Test('SyntaxPrecheck', @TestSyntaxPrecheck);
  T.Test('AllAfterIgnored', @TestAllAfterIgnored);
  T.Test('InvalidClientIp', @TestInvalidClientIp);
  T.Test('MultipleRecords', @TestMultipleRecords);
  T.Test('NoVspf', @TestNoVspf);
  T.Test('NeutralDefault', @TestNeutralDefault);
  T.Test('PtrNoMatch', @TestPtrNoMatch);
  if not T.Run then
    Halt(1);
end.