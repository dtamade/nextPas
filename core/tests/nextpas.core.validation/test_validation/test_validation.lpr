program test_validation;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.validation,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === Required === }

procedure TestRequiredEmpty;
var V: TValidator;
begin
  V := TValidator.Create('name').Required('');
  Check(not V.IsValid, 'empty should fail');
  CheckEqual('is required', V.FirstError, 'error msg');
end;

procedure TestRequiredNonEmpty;
var V: TValidator;
begin
  V := TValidator.Create('name').Required('hello');
  Check(V.IsValid, 'non-empty should pass');
end;

{ === MinLen / MaxLen === }

procedure TestMinLenPass;
var V: TValidator;
begin
  V := TValidator.Create('f').MinLen('abc', 3);
  Check(V.IsValid, 'exact min should pass');
end;

procedure TestMinLenFail;
var V: TValidator;
begin
  V := TValidator.Create('f').MinLen('ab', 3);
  Check(not V.IsValid, 'below min should fail');
  CheckEqual('must be at least 3 characters', V.FirstError, 'msg');
end;

procedure TestMaxLenPass;
var V: TValidator;
begin
  V := TValidator.Create('f').MaxLen('abc', 3);
  Check(V.IsValid, 'exact max should pass');
end;

procedure TestMaxLenFail;
var V: TValidator;
begin
  V := TValidator.Create('f').MaxLen('abcd', 3);
  Check(not V.IsValid, 'above max should fail');
  CheckEqual('must be at most 3 characters', V.FirstError, 'msg');
end;

{ === MinInt / MaxInt / RangeInt === }

procedure TestMinIntPass;
var V: TValidator;
begin
  V := TValidator.Create('age').MinInt(5, 5);
  Check(V.IsValid, 'equal to min should pass');
end;

procedure TestMinIntFail;
var V: TValidator;
begin
  V := TValidator.Create('age').MinInt(-1, 0);
  Check(not V.IsValid, 'below min should fail');
  CheckEqual('must be at least 0', V.FirstError, 'msg');
end;

procedure TestMaxIntPass;
var V: TValidator;
begin
  V := TValidator.Create('age').MaxInt(150, 150);
  Check(V.IsValid, 'equal to max should pass');
end;

procedure TestMaxIntFail;
var V: TValidator;
begin
  V := TValidator.Create('age').MaxInt(151, 150);
  Check(not V.IsValid, 'above max should fail');
  CheckEqual('must be at most 150', V.FirstError, 'msg');
end;

procedure TestRangeIntPass;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(50, 1, 100);
  Check(V.IsValid, 'in range should pass');
end;

procedure TestRangeIntFailLow;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(0, 1, 100);
  Check(not V.IsValid, 'below range should fail');
end;

procedure TestRangeIntFailHigh;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(101, 1, 100);
  Check(not V.IsValid, 'above range should fail');
end;

{ === Email === }

procedure TestEmailValid;
var V: TValidator;
begin
  V := TValidator.Create('e').Email('user@example.com');
  Check(V.IsValid, 'valid email should pass');
end;

procedure TestEmailNoAt;
var V: TValidator;
begin
  V := TValidator.Create('e').Email('userexample.com');
  Check(not V.IsValid, 'no @ should fail');
end;

procedure TestEmailAtStart;
var V: TValidator;
begin
  V := TValidator.Create('e').Email('@example.com');
  Check(not V.IsValid, '@ at start should fail');
end;

procedure TestEmailAtEnd;
var V: TValidator;
begin
  V := TValidator.Create('e').Email('user@');
  Check(not V.IsValid, '@ at end should fail');
end;

procedure TestEmailEmpty;
var V: TValidator;
begin
  V := TValidator.Create('e').Email('');
  Check(not V.IsValid, 'empty should fail');
end;

{ === NotEmpty === }

procedure TestNotEmptyPass;
var V: TValidator;
begin
  V := TValidator.Create('f').NotEmpty('hello');
  Check(V.IsValid, 'non-whitespace should pass');
end;

procedure TestNotEmptyFail;
var V: TValidator;
begin
  V := TValidator.Create('f').NotEmpty('   ');
  Check(not V.IsValid, 'whitespace-only should fail');
end;

procedure TestNotEmptyBlank;
var V: TValidator;
begin
  V := TValidator.Create('f').NotEmpty('');
  Check(not V.IsValid, 'empty string should fail');
end;

{ === Matches === }

procedure TestMatchesPass;
var V: TValidator;
begin
  V := TValidator.Create('f').Matches('hello.txt', '*.txt');
  Check(V.IsValid, 'glob match should pass');
end;

procedure TestMatchesFail;
var V: TValidator;
begin
  V := TValidator.Create('f').Matches('hello.csv', '*.txt');
  Check(not V.IsValid, 'glob mismatch should fail');
end;

procedure TestMatchesQuestion;
var V: TValidator;
begin
  V := TValidator.Create('f').Matches('cat', 'c?t');
  Check(V.IsValid, '? match should pass');
end;

{ === OneOf === }

procedure TestOneOfPass;
var V: TValidator;
begin
  V := TValidator.Create('status').OneOf('active', ['active', 'inactive', 'pending']);
  Check(V.IsValid, 'valid option should pass');
end;

procedure TestOneOfFail;
var V: TValidator;
begin
  V := TValidator.Create('status').OneOf('deleted', ['active', 'inactive', 'pending']);
  Check(not V.IsValid, 'invalid option should fail');
end;

{ === Custom === }

procedure TestCustomPass;
var V: TValidator;
begin
  V := TValidator.Create('f').Custom(True, 'should not appear');
  Check(V.IsValid, 'custom true should pass');
end;

procedure TestCustomFail;
var V: TValidator;
begin
  V := TValidator.Create('f').Custom(False, 'custom error');
  Check(not V.IsValid, 'custom false should fail');
  CheckEqual('custom error', V.FirstError, 'msg');
end;

{ === Multi-field combination === }

procedure TestMultiFieldValidation;
var R: TValidationResult;
begin
  R := TValidationResult.Create;
  R.Add(TValidator.Create('name').Required('').MinLen('', 2));
  R.Add(TValidator.Create('email').Email('bad'));
  R.Add(TValidator.Create('age').MinInt(200, 0).MaxInt(200, 150));
  Check(not R.IsValid, 'should have errors');
  CheckEqual(Int64(4), Int64(R.ErrorCount), 'should collect 4 errors');
end;

{ === ErrorMessages format === }

procedure TestErrorMessages;
var R: TValidationResult;
begin
  R := TValidationResult.Create;
  R.Add(TValidator.Create('name').Required(''));
  R.Add(TValidator.Create('email').Email('x'));
  CheckEqual('name: is required; email: must be a valid email address', R.ErrorMessages, 'format');
end;

{ === Empty validator (no rules) === }

procedure TestEmptyValidator;
var V: TValidator;
begin
  V := TValidator.Create('f');
  Check(V.IsValid, 'no rules = valid');
  CheckEqual(Int64(0), Int64(Length(V.Errors)), 'no errors');
  CheckEqual('', V.FirstError, 'empty first error');
end;

{ === Chaining multiple rules on same field === }

procedure TestChainMultipleErrors;
var V: TValidator;
begin
  V := TValidator.Create('pw').Required('').MinLen('', 8);
  Check(not V.IsValid, 'should fail');
  CheckEqual(Int64(2), Int64(Length(V.Errors)), 'two errors collected');
end;

{ === TValidationResult.AddError direct === }

procedure TestResultAddErrorDirect;
var R: TValidationResult;
begin
  R := TValidationResult.Create;
  R.AddError('field1', 'manual error');
  Check(not R.IsValid, 'should not be valid');
  CheckEqual(Int64(1), Int64(R.ErrorCount), 'one error');
  CheckEqual('field1: manual error', R.ErrorMessages, 'format');
end;

{ === Additional Boundary Tests === }

procedure TestRangeIntMinEqualsMax;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(5, 5, 5);
  Check(V.IsValid, 'min=max=value should pass');
end;

procedure TestRangeIntAtBoundaryLow;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(1, 1, 100);
  Check(V.IsValid, 'exactly at min should pass');
end;

procedure TestRangeIntAtBoundaryHigh;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(100, 1, 100);
  Check(V.IsValid, 'exactly at max should pass');
end;

procedure TestRangeIntJustBelowMin;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(0, 1, 100);
  Check(not V.IsValid, 'just below min should fail');
end;

procedure TestRangeIntJustAboveMax;
var V: TValidator;
begin
  V := TValidator.Create('x').RangeInt(101, 1, 100);
  Check(not V.IsValid, 'just above max should fail');
end;

procedure TestOneOfEmptyOptions;
var V: TValidator;
begin
  V := TValidator.Create('x').OneOf('anything', []);
  Check(not V.IsValid, 'empty options should always fail');
end;

procedure TestMatchesEmptyPattern;
var V: TValidator;
begin
  V := TValidator.Create('x').Matches('hello', '');
  Check(not V.IsValid, 'empty pattern should fail for non-empty value');
end;

procedure TestMatchesEmptyBoth;
var V: TValidator;
begin
  V := TValidator.Create('x').Matches('', '');
  Check(V.IsValid, 'empty value + empty pattern should pass');
end;

procedure TestFirstErrorNoErrors;
var V: TValidator;
begin
  V := TValidator.Create('x').Required('hello');
  Check(V.IsValid, 'should be valid');
  CheckEqual('', V.FirstError, 'no errors returns empty');
end;

procedure TestErrorMessagesMultiple;
var R: TValidationResult;
begin
  R := TValidationResult.Create;
  R.Add(TValidator.Create('name').Required(''));
  R.Add(TValidator.Create('age').MinInt(-1, 0));
  R.Add(TValidator.Create('email').Email('bad'));
  Check(not R.IsValid, 'should have errors');
  Check(Pos('name:', R.ErrorMessages) > 0, 'has name error');
  Check(Pos('age:', R.ErrorMessages) > 0, 'has age error');
  Check(Pos('email:', R.ErrorMessages) > 0, 'has email error');
  Check(Pos('; ', R.ErrorMessages) > 0, 'semicolon separator');
end;

{ === New: URL === }

procedure TestURLValid;
var V: TValidator;
begin
  V := TValidator.Create('u').URL('https://example.com');
  Check(V.IsValid, 'https valid');
end;

procedure TestURLValidHttp;
var V: TValidator;
begin
  V := TValidator.Create('u').URL('http://example.com/path');
  Check(V.IsValid, 'http valid');
end;

procedure TestURLInvalidNoScheme;
var V: TValidator;
begin
  V := TValidator.Create('u').URL('example.com');
  Check(not V.IsValid, 'no scheme should fail');
end;

procedure TestURLInvalidEmpty;
var V: TValidator;
begin
  V := TValidator.Create('u').URL('');
  Check(not V.IsValid, 'empty should fail');
end;

procedure TestURLInvalidNoHost;
var V: TValidator;
begin
  V := TValidator.Create('u').URL('http://');
  Check(not V.IsValid, 'no host should fail');
end;

{ === New: IPv4 === }

procedure TestIPv4Valid;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('192.168.1.1');
  Check(V.IsValid, 'valid IPv4');
end;

procedure TestIPv4ValidZero;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('0.0.0.0');
  Check(V.IsValid, '0.0.0.0 valid');
end;

procedure TestIPv4ValidMax;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('255.255.255.255');
  Check(V.IsValid, '255.255.255.255 valid');
end;

procedure TestIPv4InvalidOctet;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('256.1.1.1');
  Check(not V.IsValid, '256 octet should fail');
end;

procedure TestIPv4InvalidFormat;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('1.2.3');
  Check(not V.IsValid, 'only 3 octets should fail');
end;

procedure TestIPv4InvalidChars;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('abc.def.ghi.jkl');
  Check(not V.IsValid, 'non-numeric should fail');
end;

procedure TestIPv4InvalidEmpty;
var V: TValidator;
begin
  V := TValidator.Create('ip').IPv4('');
  Check(not V.IsValid, 'empty should fail');
end;

{ === New: Contains === }

procedure TestContainsPass;
var V: TValidator;
begin
  V := TValidator.Create('f').Contains('hello world', 'world');
  Check(V.IsValid, 'contains should pass');
end;

procedure TestContainsFail;
var V: TValidator;
begin
  V := TValidator.Create('f').Contains('hello world', 'xyz');
  Check(not V.IsValid, 'not contains should fail');
end;

{ === New: StartsWith === }

procedure TestStartsWithPass;
var V: TValidator;
begin
  V := TValidator.Create('f').StartsWith('hello world', 'hello');
  Check(V.IsValid, 'starts with should pass');
end;

procedure TestStartsWithFail;
var V: TValidator;
begin
  V := TValidator.Create('f').StartsWith('hello world', 'world');
  Check(not V.IsValid, 'not starts with should fail');
end;

{ === New: EndsWith === }

procedure TestEndsWithPass;
var V: TValidator;
begin
  V := TValidator.Create('f').EndsWith('hello world', 'world');
  Check(V.IsValid, 'ends with should pass');
end;

procedure TestEndsWithFail;
var V: TValidator;
begin
  V := TValidator.Create('f').EndsWith('hello world', 'hello');
  Check(not V.IsValid, 'not ends with should fail');
end;

{ === New: Alpha === }

procedure TestAlphaPass;
var V: TValidator;
begin
  V := TValidator.Create('f').Alpha('Hello');
  Check(V.IsValid, 'alpha should pass');
end;

procedure TestAlphaFail;
var V: TValidator;
begin
  V := TValidator.Create('f').Alpha('Hello123');
  Check(not V.IsValid, 'alpha with digits should fail');
end;

procedure TestAlphaEmpty;
var V: TValidator;
begin
  V := TValidator.Create('f').Alpha('');
  Check(not V.IsValid, 'empty alpha should fail');
end;

{ === New: AlphaNum === }

procedure TestAlphaNumPass;
var V: TValidator;
begin
  V := TValidator.Create('f').AlphaNum('Hello123');
  Check(V.IsValid, 'alphanum should pass');
end;

procedure TestAlphaNumFail;
var V: TValidator;
begin
  V := TValidator.Create('f').AlphaNum('Hello 123');
  Check(not V.IsValid, 'alphanum with space should fail');
end;

procedure TestAlphaNumEmpty;
var V: TValidator;
begin
  V := TValidator.Create('f').AlphaNum('');
  Check(not V.IsValid, 'empty alphanum should fail');
end;

{ === New: Numeric === }

procedure TestNumericPass;
var V: TValidator;
begin
  V := TValidator.Create('f').Numeric('12345');
  Check(V.IsValid, 'numeric should pass');
end;

procedure TestNumericFail;
var V: TValidator;
begin
  V := TValidator.Create('f').Numeric('123abc');
  Check(not V.IsValid, 'numeric with letters should fail');
end;

procedure TestNumericEmpty;
var V: TValidator;
begin
  V := TValidator.Create('f').Numeric('');
  Check(not V.IsValid, 'empty numeric should fail');
end;

begin
  T := TTestRunner.Create('nextpas.core.validation');
  { Required }
  T.Run('required empty', @TestRequiredEmpty);
  T.Run('required non-empty', @TestRequiredNonEmpty);
  { MinLen/MaxLen }
  T.Run('minlen pass', @TestMinLenPass);
  T.Run('minlen fail', @TestMinLenFail);
  T.Run('maxlen pass', @TestMaxLenPass);
  T.Run('maxlen fail', @TestMaxLenFail);
  { MinInt/MaxInt/RangeInt }
  T.Run('minint pass', @TestMinIntPass);
  T.Run('minint fail', @TestMinIntFail);
  T.Run('maxint pass', @TestMaxIntPass);
  T.Run('maxint fail', @TestMaxIntFail);
  T.Run('rangeint pass', @TestRangeIntPass);
  T.Run('rangeint fail low', @TestRangeIntFailLow);
  T.Run('rangeint fail high', @TestRangeIntFailHigh);
  { Email }
  T.Run('email valid', @TestEmailValid);
  T.Run('email no @', @TestEmailNoAt);
  T.Run('email @ start', @TestEmailAtStart);
  T.Run('email @ end', @TestEmailAtEnd);
  T.Run('email empty', @TestEmailEmpty);
  { NotEmpty }
  T.Run('notempty pass', @TestNotEmptyPass);
  T.Run('notempty fail', @TestNotEmptyFail);
  T.Run('notempty blank', @TestNotEmptyBlank);
  { Matches }
  T.Run('matches pass', @TestMatchesPass);
  T.Run('matches fail', @TestMatchesFail);
  T.Run('matches question', @TestMatchesQuestion);
  { OneOf }
  T.Run('oneof pass', @TestOneOfPass);
  T.Run('oneof fail', @TestOneOfFail);
  { Custom }
  T.Run('custom pass', @TestCustomPass);
  T.Run('custom fail', @TestCustomFail);
  { Combination }
  T.Run('multi-field validation', @TestMultiFieldValidation);
  T.Run('error messages format', @TestErrorMessages);
  T.Run('empty validator', @TestEmptyValidator);
  T.Run('chain multiple errors', @TestChainMultipleErrors);
  T.Run('result add error direct', @TestResultAddErrorDirect);
  T.Run('rangeint min=max', @TestRangeIntMinEqualsMax);
  T.Run('rangeint at boundary low', @TestRangeIntAtBoundaryLow);
  T.Run('rangeint at boundary high', @TestRangeIntAtBoundaryHigh);
  T.Run('rangeint just below min', @TestRangeIntJustBelowMin);
  T.Run('rangeint just above max', @TestRangeIntJustAboveMax);
  T.Run('oneof empty options', @TestOneOfEmptyOptions);
  T.Run('matches empty pattern', @TestMatchesEmptyPattern);
  T.Run('matches empty both', @TestMatchesEmptyBoth);
  T.Run('first error no errors', @TestFirstErrorNoErrors);
  T.Run('error messages multiple', @TestErrorMessagesMultiple);
  { New: URL }
  T.Run('url valid https', @TestURLValid);
  T.Run('url valid http', @TestURLValidHttp);
  T.Run('url invalid no scheme', @TestURLInvalidNoScheme);
  T.Run('url invalid empty', @TestURLInvalidEmpty);
  T.Run('url invalid no host', @TestURLInvalidNoHost);
  { New: IPv4 }
  T.Run('ipv4 valid', @TestIPv4Valid);
  T.Run('ipv4 valid 0.0.0.0', @TestIPv4ValidZero);
  T.Run('ipv4 valid 255.255.255.255', @TestIPv4ValidMax);
  T.Run('ipv4 invalid 256', @TestIPv4InvalidOctet);
  T.Run('ipv4 invalid format', @TestIPv4InvalidFormat);
  T.Run('ipv4 invalid chars', @TestIPv4InvalidChars);
  T.Run('ipv4 invalid empty', @TestIPv4InvalidEmpty);
  { New: Contains/StartsWith/EndsWith }
  T.Run('contains pass', @TestContainsPass);
  T.Run('contains fail', @TestContainsFail);
  T.Run('startswith pass', @TestStartsWithPass);
  T.Run('startswith fail', @TestStartsWithFail);
  T.Run('endswith pass', @TestEndsWithPass);
  T.Run('endswith fail', @TestEndsWithFail);
  { New: Alpha/AlphaNum/Numeric }
  T.Run('alpha pass', @TestAlphaPass);
  T.Run('alpha fail', @TestAlphaFail);
  T.Run('alpha empty', @TestAlphaEmpty);
  T.Run('alphanum pass', @TestAlphaNumPass);
  T.Run('alphanum fail', @TestAlphaNumFail);
  T.Run('alphanum empty', @TestAlphaNumEmpty);
  T.Run('numeric pass', @TestNumericPass);
  T.Run('numeric fail', @TestNumericFail);
  T.Run('numeric empty', @TestNumericEmpty);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
