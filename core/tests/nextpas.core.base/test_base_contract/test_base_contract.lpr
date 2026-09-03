program test_base_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test;

var
  T: TTestSuite;

function ReadText(const APath: string): string;
begin
  Result := ReadFileText(APath);
end;

procedure TestForwardListUsesInvariantViolation;
var
  LSource: string;
begin
  LSource := ReadText('../../../src/nextpas.core.collections.forward_list.pas');
  Check(Pos('EInvariantViolation.Create(', LSource) > 0,
    'forward_list should raise EInvariantViolation at invariant break sites');
  Check(Pos('raise EWow.Create(', LSource) = 0,
    'forward_list should not keep direct EWow raises');
end;

procedure TestSizeUIntTryGuardsPreserveOutputContract;
var
  LSource: string;
begin
  LSource := ReadText('../../../src/nextpas.core.base.utils.pas');
  Check(Pos('function TryAddSizeUInt(const ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean;', LSource) > 0,
    'TryAddSizeUInt should use var output to preserve caller value on overflow');
  Check(Pos('function TryMulSizeUInt(const ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean;', LSource) > 0,
    'TryMulSizeUInt should use var output to preserve caller value on overflow');
  Check(Pos('function TryAddSizeUInt(const ALeft, ARight: SizeUInt; out ASum: SizeUInt): Boolean;', LSource) = 0,
    'TryAddSizeUInt should not use out output for a preserve-on-failure contract');
  Check(Pos('function TryMulSizeUInt(const ALeft, ARight: SizeUInt; out AProduct: SizeUInt): Boolean;', LSource) = 0,
    'TryMulSizeUInt should not use out output for a preserve-on-failure contract');
end;

begin
  T := TTestSuite.Create('nextpas.core.base contract');
  T.Test('forward_list uses invariant violation', @TestForwardListUsesInvariantViolation);
  T.Test('SizeUInt try guards preserve output contract', @TestSizeUIntTryGuardsPreserveOutputContract);
  if not T.Run then Halt(1);
end.
