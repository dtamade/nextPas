program test_mail_address;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.mail;

procedure TestValidSimple;
var
  A: TMailAddress;
begin
  Check(TMailAddress.TryParse('test@example.com', A), 'simple valid');
  CheckEqual('test', A.LocalPart, 'local part');
  CheckEqual('example.com', A.Domain, 'domain');
  CheckEqual('test@example.com', A.Full, 'full');
  CheckEqual('test@example.com', A.ToString, 'to string no display');
end;

procedure TestValidDisplayName;
var
  A: TMailAddress;
begin
  Check(TMailAddress.TryParse('"Tester" <test@example.com>', A), 'display name valid');
  CheckEqual('Tester', A.DisplayName, 'display name extracted');
  CheckEqual('test@example.com', A.Full, 'full ignores display');
  CheckEqual('"Tester" <test@example.com>', A.ToString, 'to string with display');
end;

procedure TestNormalize;
var
  A: TMailAddress;
begin
  Check(TMailAddress.TryParse('  User.Name+tag@Sub.Example.COM  ', A), 'trim+lower');
  CheckEqual('user.name+tag', A.LocalPart, 'local lowercased');
  CheckEqual('sub.example.com', A.Domain, 'domain lowercased');
end;

procedure TestValidDomains;
begin
  Check(TMailAddress.IsValidAddress('a@b.c'), 'two labels');
  Check(TMailAddress.IsValidAddress('a@example'), 'single label (RFC + original gateway allow)');
  Check(TMailAddress.IsValidAddress('a@sub.example.com'), 'multi labels');
  Check(TMailAddress.IsValidAddress('a@xn--fsqu00a.xn--0zwm56d'), 'punycode labels');
  Check(TMailAddress.IsValidAddress('a@[1.2.3.4]'), 'ip literal');
  Check(TMailAddress.IsValidAddress('a@[IPv6:2001:db8::1]'), 'ipv6 literal accepted');
  Check(TMailAddress.IsValidAddress('a.b.c.d@example.com'), 'dotted local');
  Check(TMailAddress.IsValidAddress('a+b@example.com'), 'plus local');
  Check(TMailAddress.IsValidAddress('a_b@example.com'), 'underscore local');
end;

procedure TestInvalid;
begin
  Check(not TMailAddress.IsValidAddress(''), 'empty');
  Check(not TMailAddress.IsValidAddress('plainaddress'), 'no at');
  Check(not TMailAddress.IsValidAddress('@example.com'), 'empty local');
  Check(not TMailAddress.IsValidAddress('user@'), 'empty domain');
  Check(not TMailAddress.IsValidAddress('user@@example.com'), 'double at');
  Check(not TMailAddress.IsValidAddress('user @example.com'), 'space in local');
  Check(not TMailAddress.IsValidAddress('.user@example.com'), 'leading dot local');
  Check(not TMailAddress.IsValidAddress('user.@example.com'), 'trailing dot local');
  Check(not TMailAddress.IsValidAddress('user..name@example.com'), 'consecutive dots');
  Check(not TMailAddress.IsValidAddress('user@-example.com'), 'domain label leading dash');
  Check(not TMailAddress.IsValidAddress('user@example-.com'), 'domain label trailing dash');
  Check(not TMailAddress.IsValidAddress('user@exa_mple.com'), 'underscore in domain');
  Check(not TMailAddress.IsValidAddress('user@.example.com'), 'empty first label');
  Check(not TMailAddress.IsValidAddress('user@example..com'), 'empty middle label');
  Check(not TMailAddress.IsValidAddress('user@example.com.'), 'trailing dot domain');
end;

procedure TestLongAddress;
var
  LLong: string;
  I: Integer;
begin
  LLong := '';
  for I := 1 to 200 do
    LLong := LLong + 'a';
  LLong := LLong + '@example.com';
  Check(not TMailAddress.IsValidAddress(LLong), 'over 254 rejected');

  LLong := '';
  for I := 1 to 70 do
    LLong := LLong + 'a';
  Check(not TMailAddress.IsValidAddress(LLong + '@example.com'), 'local over 64 rejected');
end;

procedure TestParseRaises;
var
  A: TMailAddress;
begin
  try
    A := TMailAddress.Parse('not-an-address');
    Check(False, 'Parse should raise for invalid');
  except
    on E: EParseError do
      Check(True, 'raised EParseError');
  end;
  Check(TMailAddress.Parse('ok@example.com').Full = 'ok@example.com', 'Parse valid ok');
end;

procedure TestEquals;
var
  A, B: TMailAddress;
begin
  A := TMailAddress.Parse('user@example.com');
  B := TMailAddress.Parse('USER@EXAMPLE.COM');
  Check(A.Equals(B), 'equals ignores case after normalize');
  CheckEqual('user@example.com', A.Full, 'normalized full');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.mail.address');
  T.Test('ValidSimple', @TestValidSimple);
  T.Test('ValidDisplayName', @TestValidDisplayName);
  T.Test('Normalize', @TestNormalize);
  T.Test('ValidDomains', @TestValidDomains);
  T.Test('Invalid', @TestInvalid);
  T.Test('LongAddress', @TestLongAddress);
  T.Test('ParseRaises', @TestParseRaises);
  T.Test('Equals', @TestEquals);
  if not T.Run then
    Halt(1);
end.