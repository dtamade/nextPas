program test_nanoid_rejection_progress_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.id.rng,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure TestRejectedEntropyFailsFast;
var
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  LRaised := False;
  try
    NanoIdCustom('abc', 1);
  except
    on E: EIOError do
    begin
      LRaised := True;
      Check(E.Category = ecIO, 'NanoID no-progress failure must be categorized as IO');
      Check(Pos('NanoIdCustom', E.Message) > 0,
        'NanoID no-progress failure message must name NanoIdCustom');
      Check(Pos('made no progress', E.Message) > 0,
        'NanoID no-progress failure message must describe progress failure');
    end;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'NanoID rejected entropy stream must fail fast');
  Check(TestRandomCallCount > 0, 'NanoID must reach deterministic entropy source');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.nanoid.rejection_progress_contract');
  T.Run('rejected entropy fails fast', @TestRejectedEntropyFailsFast);
  T.Summary;
end.
