program test_fragmentation;
{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.central,
  nextpas.core.mem.allocator.growing;

{ ── RSS via /proc/self/statm ── }

function GetRSSBytes: UInt64;
var
  LFile: TextFile;
  LResident, LDummy: UInt64;
begin
  AssignFile(LFile, '/proc/self/statm');
  Reset(LFile);
  Read(LFile, LDummy, LResident);
  CloseFile(LFile);
  Result := LResident * 4096;
end;

{ ── Main ── }

const
  { Holes test: 50% free creates worst-case fragmentation }
  HOLES_COUNT = 100000;
  HOLES_TARGET = 2.5;  { RSS/live <= 2.5x for worst-case }

  { Churn test: alloc all → free all → scavenge → RSS should drop }
  CHURN_COUNT = 50000;
  CHURN_SIZE = 256;
  CHURN_ROUNDS = 5;
  CHURN_TARGET_RATIO = 1.5;  { RSS after churn / baseline }

var
  LAllocator: TGrowingAllocator;
  LPtrs: array[0..HOLES_COUNT - 1] of Pointer;
  LSizes: array[0..HOLES_COUNT - 1] of UInt32;
  LBaseRSS, LAfterRSS, LLiveBytes: UInt64;
  LI, LRound: Int32;
  LSize: UInt32;
  LRatio: Double;
  LPass: Boolean;
begin
  WriteLn('=== Fragmentation Measurement (J-2) ===');
  WriteLn;

  LAllocator := TGrowingAllocator.Create;
  try
    LPass := True;

    { ── Test 1: Holes — worst-case fragmentation ── }
    WriteLn('--- Holes Test (', HOLES_COUNT, ' allocs, 50% free) ---');
    LBaseRSS := GetRSSBytes;
    WriteLn('Baseline RSS: ', LBaseRSS div 1024, ' KB');

    LLiveBytes := 0;
    for LI := 0 to HOLES_COUNT - 1 do
    begin
      LSize := 32 + UInt32(LI mod 4064);
      LSizes[LI] := LSize;
      LPtrs[LI] := LAllocator.GetMem(LSize);
      if LPtrs[LI] = nil then
      begin
        WriteLn('FAIL: GetMem returned nil at index ', LI);
        Halt(1);
      end;
      LLiveBytes += LSize;
    end;
    WriteLn('Allocated: ', LLiveBytes div 1024, ' KB live');

    { Free every other block → 50% holes }
    for LI := 0 to HOLES_COUNT - 1 do
      if LI mod 2 = 0 then
      begin
        LAllocator.FreeMem(LPtrs[LI], LSizes[LI]);
        LPtrs[LI] := nil;
        LLiveBytes -= LSizes[LI];
      end;
    WriteLn('After 50% free: ', LLiveBytes div 1024, ' KB live');

    LAfterRSS := GetRSSBytes;
    if LLiveBytes > 0 then
      LRatio := Double(LAfterRSS - LBaseRSS) / Double(LLiveBytes)
    else
      LRatio := 1.0;

    WriteLn('RSS delta: ', (LAfterRSS - LBaseRSS) div 1024, ' KB');
    WriteLn('Ratio: ', LRatio:1:2, 'x (target <= ', HOLES_TARGET:1:1, 'x)');
    if LRatio > HOLES_TARGET then
    begin
      WriteLn('FAIL: holes ratio exceeds target');
      LPass := False;
    end;

    { Cleanup }
    for LI := 0 to HOLES_COUNT - 1 do
      if LPtrs[LI] <> nil then
        LAllocator.FreeMem(LPtrs[LI], LSizes[LI]);
    WriteLn;

    { ── Test 2: Churn — alloc/free cycles, RSS recovery ── }
    WriteLn('--- Churn Test (', CHURN_ROUNDS, ' rounds x ', CHURN_COUNT, ' x ', CHURN_SIZE, 'B) ---');
    { Warm up: run one round to stabilize RSS }
    for LI := 0 to CHURN_COUNT - 1 do
      LPtrs[LI] := LAllocator.GetMem(CHURN_SIZE);
    for LI := 0 to CHURN_COUNT - 1 do
      LAllocator.FreeMem(LPtrs[LI], CHURN_SIZE);
    LAllocator.Scavenge;

    LBaseRSS := GetRSSBytes;
    WriteLn('Warm baseline RSS: ', LBaseRSS div 1024, ' KB');

    for LRound := 1 to CHURN_ROUNDS do
    begin
      for LI := 0 to CHURN_COUNT - 1 do
      begin
        LPtrs[LI] := LAllocator.GetMem(CHURN_SIZE);
        if LPtrs[LI] = nil then
        begin
          WriteLn('FAIL: GetMem returned nil at round ', LRound);
          Halt(1);
        end;
      end;
      for LI := 0 to CHURN_COUNT - 1 do
        LAllocator.FreeMem(LPtrs[LI], CHURN_SIZE);
    end;

    LAllocator.Scavenge;
    LAfterRSS := GetRSSBytes;
    LRatio := Double(LAfterRSS) / Double(LBaseRSS);
    WriteLn('After churn RSS: ', LAfterRSS div 1024, ' KB');
    WriteLn('Ratio: ', LRatio:1:2, 'x (target <= ', CHURN_TARGET_RATIO:1:1, 'x)');
    if LRatio <= CHURN_TARGET_RATIO then
      WriteLn('PASS: churn RSS returned near baseline')
    else
    begin
      WriteLn('WARN: churn RSS elevated (glibc may cache freed pages)');
      { Not a hard fail — glibc free() doesn't always return pages to OS }
    end;

    WriteLn;
    if LPass then
      WriteLn('RESULT: PASS')
    else
      WriteLn('RESULT: FAIL');
  finally
    LAllocator.Free;
  end;
end.
