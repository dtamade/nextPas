program test_oauth_pkce;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.oauth.pkce;

var
  T: TTestSuite;

{ RFC 7636 附录 B 已知向量 }
const
  RFC_VERIFIER = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
  RFC_CHALLENGE = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

procedure TestRfc7636Vector;
begin
  Check(IsValidCodeVerifier(RFC_VERIFIER), 'rfc verifier valid');
  CheckEqual(RFC_CHALLENGE, CodeChallengeS256(RFC_VERIFIER), 'rfc appendix B vector');
end;

procedure TestGenerateCodeVerifier;
var
  LV1, LV2: string;
begin
  LV1 := GenerateCodeVerifier;
  LV2 := GenerateCodeVerifier;
  CheckEqual(43, Length(LV1), 'verifier length 43');
  Check(IsValidCodeVerifier(LV1), 'generated verifier valid');
  Check(LV1 <> LV2, 'two generations differ');
end;

procedure TestVerifierValidationBoundaries;
var
  LMin, LMax: string;
begin
  Check(not IsValidCodeVerifier(''), 'empty invalid');
  Check(not IsValidCodeVerifier('aB3-_~.x'), 'too short invalid');
  { 精确边界用循环构造，避免手数错 }
  LMin := '';
  while Length(LMin) < 42 do
    LMin := LMin + 'a';
  Check(not IsValidCodeVerifier(LMin), '42 chars invalid');
  LMin := LMin + 'a';
  Check(IsValidCodeVerifier(LMin), '43 chars valid (min)');
  LMax := LMin;
  while Length(LMax) < 128 do
    LMax := LMax + 'b';
  Check(IsValidCodeVerifier(LMax), '128 chars valid (max)');
  LMax := LMax + 'c';
  Check(not IsValidCodeVerifier(LMax), '129 chars invalid');
  Check(not IsValidCodeVerifier(LMin + '+'), 'plus not unreserved');
  Check(not IsValidCodeVerifier(LMin + '/'), 'slash not unreserved');
  Check(not IsValidCodeVerifier(LMin + '='), 'equals not unreserved');
end;

procedure TestChallengeRejectsInvalidVerifier;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    CodeChallengeS256('short');
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'challenge on invalid verifier -> EArgumentError');
end;

procedure TestStateRoundTrip;
var
  LState: string;
begin
  LState := SignOAuthState('secret', 1000, 600);
  Check(VerifyOAuthState(LState, 'secret', 1000), 'valid at now');
  Check(VerifyOAuthState(LState, 'secret', 1599), 'valid just before expiry');
  Check(not VerifyOAuthState(LState, 'secret', 1600), 'expired at expiry');
  Check(not VerifyOAuthState(LState, 'secret', 999999), 'expired far later');
end;

procedure TestStateTamperRejected;
var
  LState, LTampered: string;
  LI, LDot1: Integer;

  function FlipAt(const AValue: string; AIdx: Integer): string;
  begin
    Result := AValue;
    if Result[AIdx] = 'a' then
      Result[AIdx] := 'b'
    else
      Result[AIdx] := 'a';
  end;

begin
  LState := SignOAuthState('secret', 1000, 600);
  LDot1 := Pos('.', LState);

  { 篡改 nonce 首字符 }
  LTampered := FlipAt(LState, 1);
  Check(not VerifyOAuthState(LTampered, 'secret', 1000), 'tampered nonce rejected');

  { 篡改 expiry（延后过期时间） }
  LTampered := LState;
  for LI := LDot1 + 1 to Length(LTampered) do
    if LTampered[LI] in ['0'..'8'] then
    begin
      LTampered[LI] := Chr(Ord(LTampered[LI]) + 1);
      Break;
    end;
  Check(not VerifyOAuthState(LTampered, 'secret', 1000), 'tampered expiry rejected');

  { 篡改签名段 }
  LTampered := FlipAt(LState, Length(LState));
  Check(not VerifyOAuthState(LTampered, 'secret', 1000), 'tampered sig rejected');

  { 错 secret }
  Check(not VerifyOAuthState(LState, 'other-secret', 1000), 'wrong secret rejected');
end;

procedure TestStateMalformedRejected;
begin
  Check(not VerifyOAuthState('', 'secret', 1000), 'empty state rejected');
  Check(not VerifyOAuthState('abc', 'secret', 1000), 'no dots rejected');
  Check(not VerifyOAuthState('a.b.c.d', 'secret', 1000), 'four segments rejected');
  Check(not VerifyOAuthState('.1600.sig', 'secret', 1000), 'empty nonce rejected');
  Check(not VerifyOAuthState('nonce..sig', 'secret', 1000), 'empty expiry rejected');
  Check(not VerifyOAuthState('nonce.16x0.sig', 'secret', 1000), 'non-numeric expiry rejected');
  Check(not VerifyOAuthState('nonce.1600.', 'secret', 1000), 'empty sig rejected');
end;

procedure TestStateArgValidation;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    SignOAuthState('', 1000, 600);
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'empty secret -> EArgumentError');

  LOk := False;
  try
    SignOAuthState('secret', 1000, 0);
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'ttl <= 0 -> EArgumentError');
end;

begin
  T := TTestSuite.Create('nextpas.core.oauth.pkce');
  T.Test('RFC 7636 appendix B vector', @TestRfc7636Vector);
  T.Test('Generate code verifier', @TestGenerateCodeVerifier);
  T.Test('Verifier validation boundaries', @TestVerifierValidationBoundaries);
  T.Test('Challenge rejects invalid verifier', @TestChallengeRejectsInvalidVerifier);
  T.Test('State round trip and expiry', @TestStateRoundTrip);
  T.Test('State tamper rejected', @TestStateTamperRejected);
  T.Test('State malformed rejected', @TestStateMalformedRejected);
  T.Test('State arg validation', @TestStateArgValidation);
  if not T.Run then Halt(1);
end.
