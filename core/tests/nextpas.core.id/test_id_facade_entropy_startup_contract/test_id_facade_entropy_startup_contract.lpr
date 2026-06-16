program test_id_facade_entropy_startup_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.platform.random;

var
  T: TTestRunner;

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
  T := TTestRunner.Create('nextpas.core.id.facade_entropy_startup_contract');
  T.Run('facade import does not touch entropy', @TestFacadeImportDoesNotTouchEntropy);
  T.Run('XidNew entropy failure is catchable at call site', @TestXidEntropyFailureIsCatchableAtCallSite);
  T.Run('XidNew retries after entropy failure', @TestXidRetriesAfterEntropyFailure);
  T.Summary;
end.
