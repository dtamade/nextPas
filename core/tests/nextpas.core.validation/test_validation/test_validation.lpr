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
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
