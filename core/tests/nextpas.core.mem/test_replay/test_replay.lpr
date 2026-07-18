program test_replay;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.replay,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateWithoutInner;
var
  LR: TReplayAllocator;
begin
  LR := TReplayAllocator.Create;
  try
    Check(not LR.IsRecording, 'should not be recording');
    Check(LR.EntryCount = 0, 'entry count should be 0');
  finally
    LR.Free;
  end;
end;

procedure TestCreateWithInner;
var
  LR: TReplayAllocator;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    Check(not LR.IsRecording, 'should not be recording');
  finally
    LR.Free;
  end;
end;

procedure TestRecordGetMem;
var
  LR: TReplayAllocator;
  LPtr: Pointer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    LPtr := LR.GetMem(1024);
    LR.StopRecording;

    Check(LR.EntryCount = 1, 'should have 1 entry');
    Check(LR.GetEntry(0).Op = roGetMem, 'op should be GetMem');
    Check(LR.GetEntry(0).Size = 1024, 'size should be 1024');

    DefaultAllocator.FreeMem(LPtr);
  finally
    LR.Free;
  end;
end;

procedure TestRecordFreeMem;
var
  LR: TReplayAllocator;
  LPtr: Pointer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    LPtr := LR.GetMem(512);
    LR.FreeMem(LPtr);
    LR.StopRecording;

    Check(LR.EntryCount = 2, 'should have 2 entries');
    Check(LR.GetEntry(0).Op = roGetMem, 'first should be GetMem');
    Check(LR.GetEntry(1).Op = roFreeMem, 'second should be FreeMem');
  finally
    LR.Free;
  end;
end;

procedure TestRecordSequence;
var
  LR: TReplayAllocator;
  LPtrs: array[0..2] of Pointer;
  LI: Integer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    for LI := 0 to 2 do
      LPtrs[LI] := LR.GetMem(128 * (LI + 1));
    for LI := 2 downto 0 do
      LR.FreeMem(LPtrs[LI]);
    LR.StopRecording;

    Check(LR.EntryCount = 6, 'should have 6 entries');
    Check(LR.GetEntry(0).Size = 128, 'first alloc size');
    Check(LR.GetEntry(1).Size = 256, 'second alloc size');
    Check(LR.GetEntry(2).Size = 384, 'third alloc size');
  finally
    LR.Free;
  end;
end;

procedure TestClear;
var
  LR: TReplayAllocator;
  LPtr: Pointer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    LPtr := LR.GetMem(1024);
    LR.StopRecording;
    Check(LR.EntryCount = 1, 'should have 1 entry');

    DefaultAllocator.FreeMem(LPtr);

    LR.Clear;
    Check(LR.EntryCount = 0, 'should have 0 entries after clear');
  finally
    LR.Free;
  end;
end;

procedure TestGetResult;
var
  LR: TReplayAllocator;
  LResult: TReplayResult;
  LPtr1, LPtr2: Pointer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    LPtr1 := LR.GetMem(1024);
    LR.FreeMem(LPtr1);
    LPtr2 := LR.GetMem(2048);
    LR.StopRecording;

    LResult := LR.GetResult;
    Check(LResult.TotalOps = 3, 'total ops should be 3');
    Check(LResult.AllocOps = 2, 'alloc ops should be 2');
    Check(LResult.FreeOps = 1, 'free ops should be 1');
    Check(LResult.PeakAllocs = 1, 'peak allocs should be 1');
    Check(LResult.PeakBytes = 3072, 'peak bytes should be 3072 (1024+2048)');

    DefaultAllocator.FreeMem(LPtr2);
  finally
    LR.Free;
  end;
end;

procedure TestSaveAndLoad;
var
  LR1, LR2: TReplayAllocator;
  LPtr: Pointer;
  LFile: file;
const
  TEST_FILE = '/tmp/test_replay.bin';
begin
  LR1 := TReplayAllocator.Create(DefaultAllocator);
  try
    LR1.StartRecording;
    LPtr := LR1.GetMem(1024);
    LR1.FreeMem(LPtr);
    LPtr := LR1.GetMem(2048);
    LR1.StopRecording;
    DefaultAllocator.FreeMem(LPtr);
    LR1.SaveToFile(TEST_FILE);
  finally
    LR1.Free;
  end;

  LR2 := TReplayAllocator.Create;
  try
    LR2.LoadFromFile(TEST_FILE);
    Check(LR2.EntryCount = 3, 'should have 3 entries');
    Check(LR2.GetEntry(0).Op = roGetMem, 'first should be GetMem');
    Check(LR2.GetEntry(0).Size = 1024, 'first size should be 1024');
    Check(LR2.GetEntry(1).Op = roFreeMem, 'second should be FreeMem');
    Check(LR2.GetEntry(2).Op = roGetMem, 'third should be GetMem');
    Check(LR2.GetEntry(2).Size = 2048, 'third size should be 2048');
  finally
    LR2.Free;
  end;

  { 清理 }
  AssignFile(LFile, TEST_FILE);
  Erase(LFile);
end;

procedure TestReplay;
var
  LR: TReplayAllocator;
  LPtr: Pointer;
begin
  LR := TReplayAllocator.Create(DefaultAllocator);
  try
    LR.StartRecording;
    LPtr := LR.GetMem(1024);
    LR.FreeMem(LPtr);
    LPtr := LR.GetMem(2048);
    LR.StopRecording;

    DefaultAllocator.FreeMem(LPtr);

    { 回放到另一个分配器 }
    LR.Replay(DefaultAllocator);
    Check(True, 'replay should not crash');
  finally
    LR.Free;
  end;
end;

procedure TestGetEntryOutOfRange;
var
  LR: TReplayAllocator;
  LRaised: Boolean;
begin
  LR := TReplayAllocator.Create;
  try
    LRaised := False;
    try
      LR.GetEntry(0);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'should raise for out of range');
  finally
    LR.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_replay');
  T.Test('create_without_inner', @TestCreateWithoutInner);
  T.Test('create_with_inner', @TestCreateWithInner);
  T.Test('record_get_mem', @TestRecordGetMem);
  T.Test('record_free_mem', @TestRecordFreeMem);
  T.Test('record_sequence', @TestRecordSequence);
  T.Test('clear', @TestClear);
  T.Test('get_result', @TestGetResult);
  T.Test('save_and_load', @TestSaveAndLoad);
  T.Test('replay', @TestReplay);
  T.Test('get_entry_out_of_range', @TestGetEntryOutOfRange);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
