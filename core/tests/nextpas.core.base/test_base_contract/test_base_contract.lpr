program test_base_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ReadText(const APath: string): string;
var
  LStream: TFileStream;
  LSize: Int64;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    LSize := LStream.Size;
    SetLength(Result, LSize);
    if LSize > 0 then
      LStream.ReadBuffer(Result[1], LSize);
  finally
    LStream.Free;
  end;
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
  T := TTestRunner.Create('nextpas.core.base contract');
  T.Run('forward_list uses invariant violation', @TestForwardListUsesInvariantViolation);
  T.Run('SizeUInt try guards preserve output contract', @TestSizeUIntTryGuardsPreserveOutputContract);
  T.Summary;
end.
