program test_platform_virtual;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.platform.memory;

const
  PAGE_SIZE = 4096;
  CHUNK_2MB = 2 * 1024 * 1024;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ platform_virtual_reserve tests }

procedure TestReserveBasic;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(P <> nil, 'reserve basic: returns non-nil');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestReserveZeroSize;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(0);
  Check(P = nil, 'reserve zero size: returns nil');
end;

procedure TestReserveMultiplePages;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB * 4);
  Check(P <> nil, 'reserve multiple pages: returns non-nil');
  platform_virtual_release(P, CHUNK_2MB * 4);
end;

procedure TestReserveSmall;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(PAGE_SIZE);
  Check(P <> nil, 'reserve one page: returns non-nil');
  platform_virtual_release(P, PAGE_SIZE);
end;

{ platform_virtual_commit tests }

procedure TestCommitBasic;
var
  P: Pointer;
  R: Boolean;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(P <> nil, 'commit basic: reserve succeeded');
  R := platform_virtual_commit(P, PAGE_SIZE);
  Check(R, 'commit basic: commit one page succeeded');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestCommitMultiplePages;
var
  P: Pointer;
  R: Boolean;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  R := platform_virtual_commit(P, PAGE_SIZE * 4);
  Check(R, 'commit multiple pages: succeeded');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestCommitAndWrite;
var
  P: Pointer;
  R: Boolean;
  PP: PByte;
  I: Integer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  R := platform_virtual_commit(P, PAGE_SIZE);
  Check(R, 'commit+write: commit succeeded');
  { Write to committed memory - should not segfault }
  PP := PByte(P);
  for I := 0 to PAGE_SIZE - 1 do
    PP[I] := Byte(I and $FF);
  { Verify }
  R := True;
  for I := 0 to PAGE_SIZE - 1 do
    if PP[I] <> Byte(I and $FF) then
    begin
      R := False;
      Break;
    end;
  Check(R, 'commit+write: data verified');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestCommitNil;
var
  R: Boolean;
begin
  R := platform_virtual_commit(nil, PAGE_SIZE);
  Check(not R, 'commit nil: returns false');
end;

procedure TestCommitZeroSize;
var
  P: Pointer;
  R: Boolean;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  R := platform_virtual_commit(P, 0);
  Check(not R, 'commit zero size: returns false');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestCommitIncremental;
var
  P: Pointer;
  R1, R2, R3: Boolean;
  PP: PByte;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  R1 := platform_virtual_commit(P, PAGE_SIZE);
  R2 := platform_virtual_commit(Pointer(PtrUInt(P) + PAGE_SIZE), PAGE_SIZE);
  R3 := platform_virtual_commit(Pointer(PtrUInt(P) + 2 * PAGE_SIZE), PAGE_SIZE);
  Check(R1 and R2 and R3, 'commit incremental: 3 pages committed');
  { Write to all 3 pages }
  PP := PByte(P);
  PP[0] := $AA;
  PP[PAGE_SIZE] := $BB;
  PP[2 * PAGE_SIZE] := $CC;
  Check((PP[0] = $AA) and (PP[PAGE_SIZE] = $BB) and (PP[2 * PAGE_SIZE] = $CC),
    'commit incremental: data in all 3 pages verified');
  platform_virtual_release(P, CHUNK_2MB);
end;

{ platform_virtual_decommit tests }

procedure TestDecommitBasic;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(platform_virtual_commit(P, PAGE_SIZE), 'decommit basic: commit succeeded');
  { decommit should not crash }
  platform_virtual_decommit(P, PAGE_SIZE);
  Check(True, 'decommit basic: decommit did not crash');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestDecommitNil;
begin
  { Should be safe no-op }
  platform_virtual_decommit(nil, PAGE_SIZE);
  Check(True, 'decommit nil: safe no-op');
end;

procedure TestDecommitZeroSize;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  platform_virtual_decommit(P, 0);
  Check(True, 'decommit zero size: safe no-op');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestDecommitThenRecommit;
var
  P: Pointer;
  PP: PByte;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(platform_virtual_commit(P, PAGE_SIZE), 'decommit+recommit: first commit');
  PP := PByte(P);
  PP[0] := $FF;
  Check(PP[0] = $FF, 'decommit+recommit: write before decommit');
  platform_virtual_decommit(P, PAGE_SIZE);
  { Recommit - the page content is undefined after decommit }
  Check(platform_virtual_commit(P, PAGE_SIZE), 'decommit+recommit: recommit succeeded');
  { We can write again }
  PP[0] := $EE;
  Check(PP[0] = $EE, 'decommit+recommit: write after recommit');
  platform_virtual_release(P, CHUNK_2MB);
end;

{ platform_virtual_release tests }

procedure TestReleaseBasic;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(P <> nil, 'release basic: reserve succeeded');
  platform_virtual_release(P, CHUNK_2MB);
  Check(True, 'release basic: release did not crash');
end;

procedure TestReleaseNil;
begin
  platform_virtual_release(nil, CHUNK_2MB);
  Check(True, 'release nil: safe no-op');
end;

procedure TestReleaseZeroSize;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  platform_virtual_release(P, 0);
  Check(True, 'release zero size: safe no-op (no-op for Windows too)');
  { Note: on POSIX, munmap with size 0 is a no-op. The memory is still reserved. }
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestReleaseAfterCommit;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(platform_virtual_commit(P, PAGE_SIZE), 'release after commit: commit succeeded');
  platform_virtual_release(P, CHUNK_2MB);
  Check(True, 'release after commit: release succeeded');
end;

procedure TestReserveReleaseCycle;
var
  I: Integer;
  P: Pointer;
  OK: Boolean;
begin
  OK := True;
  for I := 0 to 99 do
  begin
    P := platform_virtual_reserve(CHUNK_2MB);
    if P = nil then
    begin
      OK := False;
      Break;
    end;
    platform_virtual_release(P, CHUNK_2MB);
  end;
  Check(OK, 'reserve/release 100 cycles: no leak');
end;

{ platform_madvise_thp tests }

procedure TestMadviseThp;
var
  P: Pointer;
begin
  P := platform_virtual_reserve(CHUNK_2MB);
  Check(platform_virtual_commit(P, CHUNK_2MB), 'thp: commit 2MB succeeded');
  platform_madvise_thp(P, CHUNK_2MB);
  Check(True, 'thp: madvise did not crash');
  platform_virtual_release(P, CHUNK_2MB);
end;

procedure TestMadviseThpNil;
begin
  platform_madvise_thp(nil, CHUNK_2MB);
  Check(True, 'thp nil: safe no-op');
end;

{ Combined scenario tests }

procedure TestReserveCommitDecommitRelease;
var
  P: Pointer;
  PP: PByte;
begin
  P := platform_virtual_reserve(CHUNK_2MB * 4);
  Check(P <> nil, 'scenario: reserve 8MB');

  Check(platform_virtual_commit(P, CHUNK_2MB), 'scenario: commit first 2MB');
  PP := PByte(P);
  PP[0] := $11;
  PP[CHUNK_2MB - 1] := $22;
  Check((PP[0] = $11) and (PP[CHUNK_2MB - 1] = $22), 'scenario: write to first 2MB');

  Check(platform_virtual_commit(Pointer(PtrUInt(P) + CHUNK_2MB), CHUNK_2MB),
    'scenario: commit second 2MB');
  PP := PByte(PtrUInt(P) + CHUNK_2MB);
  PP[0] := $33;
  Check(PP[0] = $33, 'scenario: write to second 2MB');

  platform_virtual_decommit(P, CHUNK_2MB);
  Check(True, 'scenario: decommit first 2MB');

  platform_virtual_release(P, CHUNK_2MB * 4);
  Check(True, 'scenario: release all 8MB');
end;

procedure TestLargeReserve;
var
  P: Pointer;
  Size: SizeUInt;
begin
  { 256MB reservation - same as TVirtualArena }
  Size := 256 * 1024 * 1024;
  P := platform_virtual_reserve(Size);
  Check(P <> nil, 'large reserve 256MB: succeeded');
  { Commit just one page }
  Check(platform_virtual_commit(P, PAGE_SIZE), 'large reserve: commit one page');
  PByte(P)[0] := $42;
  Check(PByte(P)[0] = $42, 'large reserve: write to committed page');
  platform_virtual_release(P, Size);
end;

var
  P: Pointer;

begin
  T := TTestSuite.Create('nextpas.core.mem.platform_virtual');

  { Reserve }
  T.Test('reserve basic', @TestReserveBasic);
  T.Test('reserve zero size returns nil', @TestReserveZeroSize);
  T.Test('reserve multiple pages', @TestReserveMultiplePages);
  T.Test('reserve one page', @TestReserveSmall);

  { Commit }
  T.Test('commit basic', @TestCommitBasic);
  T.Test('commit multiple pages', @TestCommitMultiplePages);
  T.Test('commit and write verification', @TestCommitAndWrite);
  T.Test('commit nil returns false', @TestCommitNil);
  T.Test('commit zero size returns false', @TestCommitZeroSize);
  T.Test('commit incremental 3 pages', @TestCommitIncremental);

  { Decommit }
  T.Test('decommit basic', @TestDecommitBasic);
  T.Test('decommit nil safe no-op', @TestDecommitNil);
  T.Test('decommit zero size safe no-op', @TestDecommitZeroSize);
  T.Test('decommit then recommit', @TestDecommitThenRecommit);

  { Release }
  T.Test('release basic', @TestReleaseBasic);
  T.Test('release nil safe no-op', @TestReleaseNil);
  T.Test('release zero size safe no-op', @TestReleaseZeroSize);
  T.Test('release after commit', @TestReleaseAfterCommit);
  T.Test('reserve/release 100 cycles', @TestReserveReleaseCycle);

  { THP }
  T.Test('madvise thp', @TestMadviseThp);
  T.Test('madvise thp nil safe no-op', @TestMadviseThpNil);

  { Combined scenarios }
  T.Test('reserve-commit-decommit-release scenario', @TestReserveCommitDecommitRelease);
  T.Test('large 256MB reserve', @TestLargeReserve);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
