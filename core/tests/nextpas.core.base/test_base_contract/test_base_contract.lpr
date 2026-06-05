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

begin
  T := TTestRunner.Create('nextpas.core.base contract');
  T.Run('forward_list uses invariant violation', @TestForwardListUsesInvariantViolation);
  T.Summary;
end.
