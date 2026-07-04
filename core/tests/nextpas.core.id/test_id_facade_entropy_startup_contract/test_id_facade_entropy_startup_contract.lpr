program test_id_facade_entropy_startup_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.id,
  nextpas.core.platform.random;

var
  T: TTestSuite;

procedure TestFacadeImportDoesNotTouchEntropy;
begin
  CheckEqual(Int64(0), Int64(TestRandomCallCount),
    'uses nextpas.core.id must not touch entropy before begin');
end;

procedure TestXidEntropyFailureIsCatchableAtCallSite;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XidNew;
  except
    on E: EIOError do
    begin
      LRaised := True;
      Check(E.Category = ecIO, 'entropy failure must be categorized as IO');
    end;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'XidNew entropy failure must be catchable at the call site');
  Check(TestRandomCallCount > 0, 'XidNew must be the first entropy consumer');
end;

procedure TestXidRetriesAfterEntropyFailure;
var
  LId: string;
begin
  TestRandomSetFailure(False);
  LId := XidNew;
  CheckEqual(Int64(20), Int64(Length(LId)),
    'XidNew must retry initialization after a failed entropy call');
end;

begin
  T := TTestSuite.Create('nextpas.core.id.facade_entropy_startup_contract');
  T.Test('facade import does not touch entropy', @TestFacadeImportDoesNotTouchEntropy);
  T.Test('XidNew entropy failure is catchable at call site', @TestXidEntropyFailureIsCatchableAtCallSite);
  T.Test('XidNew retries after entropy failure', @TestXidRetriesAfterEntropyFailure);
  if not T.Run then Halt(1);
end.
