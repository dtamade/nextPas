program test_error_handling;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.errors;

type
  TStringResult = specialize TSSLResult<string>;

function DivideStrings(const A, B: string): TStringResult;
var
  LA, LB: Integer;
begin
  LA := StrToIntDef(A, 0);
  LB := StrToIntDef(B, 0);
  
  if LB = 0 then
    Result := TStringResult.ErrCode(errInvalidConfiguration, 'Division by zero')
  else
    Result := TStringResult.Ok(IntToStr(LA div LB));
end;

var
  LResult: TStringResult;
begin
  WriteLn('====================================');
  WriteLn('  Error Handling Demo');
  WriteLn('====================================');
  WriteLn;
  
  // Test 1: Success case
  WriteLn('[Test 1] Success case');
  LResult := DivideStrings('10', '2');
  if LResult.IsOk then
    WriteLn('✓ Result: ', LResult.Value)
  else
    WriteLn('✗ Error: ', LResult.Error.Message);
  WriteLn;
  
  // Test 2: Error case
  WriteLn('[Test 2] Error case');
  LResult := DivideStrings('10', '0');
  if LResult.IsOk then
    WriteLn('✓ Result: ', LResult.Value)
  else
  begin
    WriteLn('✗ Expected error occurred');
    WriteLn('  Code: ', ErrorCodeToString(LResult.Error.ErrorCode));
    WriteLn('  Message: ', LResult.Error.Message);
    WriteLn('  Recoverable: ', LResult.Error.Recoverable);
  end;
  WriteLn;
  
  // Test 3: UnwrapOr
  WriteLn('[Test 3] UnwrapOr with default');
  LResult := DivideStrings('10', '0');
  WriteLn('  Result: ', LResult.UnwrapOr('default_value'));
  WriteLn;
  
  // Test 4: Unwrap (should raise)
  WriteLn('[Test 4] Unwrap on error (should raise)');
  try
    LResult := DivideStrings('10', '0');
    WriteLn('  Result: ', LResult.Unwrap);
  except
    on E: ESSLException do
      WriteLn('✓ Exception caught: ', E.ToString);
  end;
  WriteLn;
  
  WriteLn('====================================');
  WriteLn('✓ Error handling system working!');
  WriteLn('====================================');
end.
