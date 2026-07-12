program test_double_free;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.sentinel,
  nextpas.core.mem.intf,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ Local header mirrors for post-free inspection (layout matches implementation). }
type
  PGuardHdrView = ^TGuardHdrView;
  TGuardHdrView = record
    Magic: UInt32;
    Base: Pointer;
    TotalSize: SizeUInt;
    UserSize: SizeUInt;
  end;

  PSentinelHdrView = ^TSentinelHdrView;
  TSentinelHdrView = record
    PreSentinel: UInt64;
    UserSize: SizeUInt;
    AllocId: QWord;
    Checksum: UInt64;
  end;

const
  GUARD_MAGIC = $47554152;  { 'GUAR' }
  SENTINEL_PRE = UInt64($DEADBEEFCAFEBABE);

procedure TestGuardDetectsDoubleFree;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
  LError: TAllocError;
begin
  LAllocator := TGuardAllocator.Create;
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should return non-nil pointer');
  LAllocator.FreeMem(LPtr);
  LRaised := False;
  LError := aeNone;
  try
    LAllocator.FreeMem(LPtr);
  except
    on E: EAllocError do
    begin
      LRaised := True;
      LError := E.Error;
      Check(E.Error = aeInvalidPointer, 'Should be aeInvalidPointer');
    end;
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'Double-free should raise an exception');
  { When EAllocError is raised, error code must be aeInvalidPointer.
    When the page is already unmapped, AccessViolation is also accepted. }
  if LError <> aeNone then
    Check(LError = aeInvalidPointer, 'EAllocError code must be aeInvalidPointer');
end;

procedure TestSentinelDetectsDoubleFree;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAllocator := TSentinelAllocator.Create(GetRtlAllocator);
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should return non-nil pointer');
  LAllocator.FreeMem(LPtr);
  LRaised := False;
  try
    LAllocator.FreeMem(LPtr);
  except
    on E: EAllocError do
    begin
      LRaised := True;
      Check(E.Error = aeSentinelCorrupted, 'Should be aeSentinelCorrupted');
    end;
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'Double-free should raise an exception');
end;

procedure TestGuardDoubleFreePreservesMagic;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LHdr: PGuardHdrView;
  LRaised: Boolean;
begin
  LAllocator := TGuardAllocator.Create;
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should return non-nil pointer');

  LHdr := PGuardHdrView(PtrUInt(LPtr) - SizeOf(TGuardHdrView));
  Check(LHdr^.Magic = GUARD_MAGIC, 'Magic should be GUARD_MAGIC before free');

  LAllocator.FreeMem(LPtr);
  { FreeMem clears magic then unmaps the region. Second free must raise
    (EAllocError if magic is readable and zero, or AV if page is unmapped). }
  LRaised := False;
  try
    LAllocator.FreeMem(LPtr);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'Second free after magic clear should raise');
end;

procedure TestSentinelDoubleFreePreservesSentinel;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
  LHdr: PSentinelHdrView;
  LRaised: Boolean;
begin
  { Quarantine keeps the block mapped so PreSentinel=0 remains readable. }
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 16);
  try
    LPtr := LAlloc.GetMem(100);
    Check(LPtr <> nil, 'GetMem should return non-nil pointer');

    LHdr := PSentinelHdrView(PtrUInt(LPtr) - SizeOf(TSentinelHdrView));
    Check(LHdr^.PreSentinel = SENTINEL_PRE, 'PreSentinel should be set before free');

    LAlloc.FreeMem(LPtr);
    Check(LHdr^.PreSentinel = 0, 'PreSentinel should be cleared to 0 after free');
    Check(LAlloc.QuarantineCount >= 1, 'Freed block should stay in quarantine');

    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: EAllocError do
      begin
        LRaised := True;
        Check(E.Error = aeSentinelCorrupted, 'Double free should be aeSentinelCorrupted');
      end;
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'Double-free after PreSentinel clear should raise');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGuardValidFreeSucceeds;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAllocator := TGuardAllocator.Create;
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should return non-nil pointer');
  LRaised := False;
  try
    LAllocator.FreeMem(LPtr);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(not LRaised, 'Normal single free should NOT raise any exception');
end;

procedure TestSentinelValidFreeSucceeds;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAllocator := TSentinelAllocator.Create(GetRtlAllocator);
  LPtr := LAllocator.GetMem(100);
  Check(LPtr <> nil, 'GetMem should return non-nil pointer');
  LRaised := False;
  try
    LAllocator.FreeMem(LPtr);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(not LRaised, 'Normal single free should NOT raise any exception');
end;

begin
  T := TTestSuite.Create('test_double_free');
  T.Test('GuardDetectsDoubleFree', @TestGuardDetectsDoubleFree);
  T.Test('SentinelDetectsDoubleFree', @TestSentinelDetectsDoubleFree);
  T.Test('GuardDoubleFreePreservesMagic', @TestGuardDoubleFreePreservesMagic);
  T.Test('SentinelDoubleFreePreservesSentinel', @TestSentinelDoubleFreePreservesSentinel);
  T.Test('GuardValidFreeSucceeds', @TestGuardValidFreeSucceeds);
  T.Test('SentinelValidFreeSucceeds', @TestSentinelValidFreeSucceeds);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
