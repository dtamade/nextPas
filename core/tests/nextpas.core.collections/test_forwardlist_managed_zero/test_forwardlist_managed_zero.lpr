program test_forwardlist_managed_zero;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections.forward_list;

type
  TManagedRecord = record
    Initialized: Boolean;
    Id: Int32;
    class operator Initialize(var ARecord: TManagedRecord);
    class operator Finalize(var ARecord: TManagedRecord);
  end;

  TManagedForwardList = specialize TForwardList<TManagedRecord>;

var
  T: TTestRunner;
  GManagedRecordAlive: Int32 = 0;
  GManagedRecordBadFinalize: Int32 = 0;

class operator TManagedRecord.Initialize(var ARecord: TManagedRecord);
begin
  ARecord.Initialized := True;
  ARecord.Id := 0;
  Inc(GManagedRecordAlive);
end;

class operator TManagedRecord.Finalize(var ARecord: TManagedRecord);
begin
  if not ARecord.Initialized then
    Inc(GManagedRecordBadFinalize)
  else
  begin
    ARecord.Initialized := False;
    Dec(GManagedRecordAlive);
  end;
end;

function MakeManagedRecord(AId: Int32): TManagedRecord;
begin
  Result.Id := AId;
end;

procedure TestManagedZeroReinitializesSlots;
var
  LList: TManagedForwardList;
begin
  GManagedRecordAlive := 0;
  GManagedRecordBadFinalize := 0;
  LList := TManagedForwardList.Create;
  try
    LList.PushFront(MakeManagedRecord(10));
    LList.PushFront(MakeManagedRecord(20));
    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'records alive after push');

    LList.Zero;
    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'zero reinitializes managed slots');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'zero does not finalize uninitialized slots');

    LList.Clear;
    CheckEqual(Int64(0), Int64(GManagedRecordAlive), 'clear releases zeroed records once');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'clear does not double-finalize zeroed records');
  finally
    LList.Free;
  end;

  CheckEqual(Int64(0), Int64(GManagedRecordAlive), 'records released after forward_list free');
  CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'no bad finalize after forward_list free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.forwardlist_managed_zero');
  T.Run('managed Zero reinitializes forward_list slots', @TestManagedZeroReinitializesSlots);
  T.Summary;
end.
