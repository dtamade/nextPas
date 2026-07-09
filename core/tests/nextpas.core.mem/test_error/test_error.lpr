program test_error;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.error;

var
  T: TTestSuite;

procedure TestAllocErrorToString;
begin
  Check(AllocErrorToString(aeNone) = 'Success', 'aeNone');
  Check(AllocErrorToString(aeOutOfMemory) = 'Out of memory', 'aeOutOfMemory');
  Check(AllocErrorToString(aeInvalidLayout) = 'Invalid layout', 'aeInvalidLayout');
  Check(AllocErrorToString(aeDoubleFree) = 'Double free detected', 'aeDoubleFree');
  Check(AllocErrorToString(aePoolClosed) = 'Pool closed', 'aePoolClosed');
end;

procedure TestEAllocErrorCreate;
var
  LErr: EAllocError;
begin
  LErr := EAllocError.Create(aeOutOfMemory, 'test');
  try
    Check(LErr.Error = aeOutOfMemory, 'Error should be aeOutOfMemory');
    Check(Pos('Out of memory', LErr.Message) > 0, 'Message should contain error text');
    Check(Pos('test', LErr.Message) > 0, 'Message should contain custom text');
  finally
    LErr.Free;
  end;
end;

procedure TestEAllocErrorCreateNoMsg;
var
  LErr: EAllocError;
begin
  LErr := EAllocError.Create(aeInvalidLayout);
  try
    Check(LErr.Error = aeInvalidLayout, 'Error should be aeInvalidLayout');
    Check(LErr.Message = 'Invalid layout', 'Message should be just error text');
  finally
    LErr.Free;
  end;
end;

procedure TestEAllocErrorNoneRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    EAllocError.Create(aeNone);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'Creating with aeNone should raise');
end;

procedure TestEOutOfMemoryCreate;
var
  LErr: EOutOfMemory;
begin
  LErr := EOutOfMemory.Create(aeOutOfMemory, 'no more memory');
  try
    Check(LErr.Error = aeOutOfMemory, 'Error should be aeOutOfMemory');
  finally
    LErr.Free;
  end;
end;

procedure TestEOutOfMemoryCreateMsg;
var
  LErr: EOutOfMemory;
begin
  LErr := EOutOfMemory.CreateMsg('alloc failed');
  try
    Check(LErr.Error = aeOutOfMemory, 'Error should be aeOutOfMemory');
    Check(Pos('alloc failed', LErr.Message) > 0, 'Message should contain custom text');
  finally
    LErr.Free;
  end;
end;

procedure TestSanitizeRuntimeAlignment;
begin
  { Valid alignments }
  Check(SanitizeRuntimeAlignment(8) = 8, '8 should be valid');
  Check(SanitizeRuntimeAlignment(16) = 16, '16 should be valid');
  Check(SanitizeRuntimeAlignment(4096) = 4096, '4096 should be valid');

  { Too small: clamped to SizeOf(Pointer) }
  Check(SanitizeRuntimeAlignment(1) = SizeOf(Pointer), '1 should be clamped');
  Check(SanitizeRuntimeAlignment(0) = SizeOf(Pointer), '0 should be clamped');

  { 3 < SizeOf(Pointer): clamped to 8 (power of 2), no raise }
  Check(SanitizeRuntimeAlignment(3) = SizeOf(Pointer), '3 should be clamped to SizeOf(Pointer)');

  { Non-power-of-two ABOVE SizeOf(Pointer): should raise }
  try
    SanitizeRuntimeAlignment(12);
    Check(False, '12 should raise (not power of 2)');
  except
    on E: EAllocError do
    begin
      Check(E.Error = aeAlignmentNotSupported, 'Should be alignment error');
      Check(Pos('power of two', E.Message) > 0, 'Message should mention power of two');
    end;
  end;
end;

procedure TestSanitizeConfigAlignment;
begin
  { Zero → DEFAULT_ALIGNMENT }
  Check(SanitizeConfigAlignment(0) = 16, '0 should become DEFAULT_ALIGNMENT');

  { Valid power-of-two ≥ DEFAULT_ALIGNMENT }
  Check(SanitizeConfigAlignment(16) = 16, '16 should be valid');
  Check(SanitizeConfigAlignment(64) = 64, '64 should be valid');

  { Below DEFAULT_ALIGNMENT: clamped up }
  Check(SanitizeConfigAlignment(8) = 16, '8 should be clamped to DEFAULT_ALIGNMENT');

  { Non-power-of-two: should raise }
  try
    SanitizeConfigAlignment(3);
    Check(False, '3 should raise');
  except
    on E: EAllocError do
      Check(E.Error = aeAlignmentNotSupported, 'Should be alignment error');
  end;
end;

begin
  T := TTestSuite.Create('test_error');
  T.Test('AllocErrorToString', @TestAllocErrorToString);
  T.Test('EAllocErrorCreate', @TestEAllocErrorCreate);
  T.Test('EAllocErrorCreateNoMsg', @TestEAllocErrorCreateNoMsg);
  T.Test('EAllocErrorNoneRaises', @TestEAllocErrorNoneRaises);
  T.Test('EOutOfMemoryCreate', @TestEOutOfMemoryCreate);
  T.Test('EOutOfMemoryCreateMsg', @TestEOutOfMemoryCreateMsg);
  T.Test('SanitizeRuntimeAlignment', @TestSanitizeRuntimeAlignment);
  T.Test('SanitizeConfigAlignment', @TestSanitizeConfigAlignment);
  T.Run;
  T.Summary;
end.
