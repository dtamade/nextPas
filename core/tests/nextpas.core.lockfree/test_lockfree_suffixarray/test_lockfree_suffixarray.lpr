{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_suffixarray;

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.text.format,
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.suffixarray;

var
  GPassed, GFailed: Int32;

type
  PSuffixBuildCtx = ^TSuffixBuildCtx;
  TSuffixBuildCtx = record
    SuffixArray: TSuffixArray;
    Iterations: Int32;
  end;

  PSuffixSearchCtx = ^TSuffixSearchCtx;
  TSuffixSearchCtx = record
    SuffixArray: TSuffixArray;
    Iterations: Int32;
    InvalidSnapshot: PInt32;
  end;

function SuffixBuildProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PSuffixBuildCtx;
  LI: Int32;
begin
  LCtx := PSuffixBuildCtx(AArg);
  for LI := 1 to LCtx^.Iterations do
    if Odd(LI) then
      LCtx^.SuffixArray.Build(TextOfChar('a', 32))
    else
      LCtx^.SuffixArray.Build(TextOfChar('b', 63));
  Result := nil;
end;

function SuffixSearchProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PSuffixSearchCtx;
  LI, LMatchCount: Int32;
  LMatches: specialize TArray<TSuffixArrayMatch>;
begin
  LCtx := PSuffixSearchCtx(AArg);
  for LI := 1 to LCtx^.Iterations do
  begin
    LMatches := LCtx^.SuffixArray.Search('a');
    LMatchCount := Length(LMatches);
    if (LMatchCount <> 0) and (LMatchCount <> 32) then
      atomic_store(LCtx^.InvalidSnapshot^, 1, mo_release);
  end;
  Result := nil;
end;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_BasicSearch;
var
  LSa: TSuffixArray;
  LMatches: specialize TArray<TSuffixArrayMatch>;
begin
  WriteLn('--- Basic Search ---');
  LSa := TSuffixArray.Create;
  try
    Check(LSa.Build('banana') = sarOk, 'Build(banana) = ok');
    Check(LSa.TextLength = 6, 'TextLength = 6');
    Check(LSa.IsBuilt, 'IsBuilt = true');

    { Search for 'ana' — should find at positions 1 and 3 }
    LMatches := LSa.Search('ana');
    Check(Length(LMatches) = 2, 'Search(ana) returns 2 matches');
    Check(LMatches[0].Index = 1, 'Search(ana) first match at 1');
    Check(LMatches[1].Index = 3, 'Search(ana) second match at 3');

    { Search for 'ban' — should find at position 0 }
    LMatches := LSa.Search('ban');
    Check(Length(LMatches) = 1, 'Search(ban) returns 1 match');

    { Search for 'xyz' — should find nothing }
    LMatches := LSa.Search('xyz');
    Check(Length(LMatches) = 0, 'Search(xyz) returns 0 matches');
  finally
    LSa.Free;
  end;
end;

procedure Test_Contains;
var
  LSa: TSuffixArray;
begin
  WriteLn('--- Contains ---');
  LSa := TSuffixArray.Create;
  try
    LSa.Build('hello world');

    Check(LSa.Contains('hello'), 'Contains(hello) = true');
    Check(LSa.Contains('world'), 'Contains(world) = true');
    Check(LSa.Contains('lo wo'), 'Contains(lo wo) = true');
    Check(not LSa.Contains('xyz'), 'Contains(xyz) = false');
  finally
    LSa.Free;
  end;
end;

procedure Test_Count;
var
  LSa: TSuffixArray;
begin
  WriteLn('--- Count ---');
  LSa := TSuffixArray.Create;
  try
    LSa.Build('abababab');

    Check(LSa.Count('ab') = 4, 'Count(ab) = 4');
    Check(LSa.Count('aba') = 3, 'Count(aba) = 3');
    Check(LSa.Count('abab') = 3, 'Count(abab) = 3');
    Check(LSa.Count('xyz') = 0, 'Count(xyz) = 0');
  finally
    LSa.Free;
  end;
end;

procedure Test_EmptyBuild;
var
  LSa: TSuffixArray;
begin
  WriteLn('--- Empty Build ---');
  LSa := TSuffixArray.Create;
  try
    Check(LSa.Build('') = sarEmpty, 'Build empty = empty');
    Check(not LSa.IsBuilt, 'IsBuilt = false');
  finally
    LSa.Free;
  end;
end;

procedure Test_EmptyRebuildClearsPublishedState;
var
  LSa: TSuffixArray;
begin
  WriteLn('--- Empty Rebuild ---');
  LSa := TSuffixArray.Create;
  try
    Check(LSa.Build('banana') = sarOk, 'Initial build succeeds');
    Check(LSa.Build('') = sarEmpty, 'Empty rebuild reports empty');
    Check(not LSa.IsBuilt, 'Empty rebuild clears built state');
    Check(LSa.TextLength = 0, 'Empty rebuild clears text length');
    Check(Length(LSa.Search('ana')) = 0,
      'Empty rebuild clears searchable suffixes');
  finally
    LSa.Free;
  end;
end;

procedure Test_ConcurrentBuildSearchSnapshots;
var
  LSa: TSuffixArray;
  LBuilderRec, LSearcherRec: TPlatformThreadRecord;
  LBuilderCtx: TSuffixBuildCtx;
  LSearcherCtx: TSuffixSearchCtx;
  LInvalidSnapshot: Int32;
begin
  WriteLn('--- Concurrent Build/Search ---');
  LSa := TSuffixArray.Create;
  try
    LInvalidSnapshot := 0;
    LSa.Build(TextOfChar('a', 32));
    LBuilderCtx.SuffixArray := LSa;
    LBuilderCtx.Iterations := 500;
    LSearcherCtx.SuffixArray := LSa;
    LSearcherCtx.Iterations := 5000;
    LSearcherCtx.InvalidSnapshot := @LInvalidSnapshot;
    Check(platform_thread_spawn(LBuilderRec, @SuffixBuildProc,
      @LBuilderCtx) = 0, 'spawn build worker');
    Check(platform_thread_spawn(LSearcherRec, @SuffixSearchProc,
      @LSearcherCtx) = 0, 'spawn search worker');
    Check(platform_thread_wait(LBuilderRec) = 0, 'join build worker');
    Check(platform_thread_wait(LSearcherRec) = 0, 'join search worker');
    Check(atomic_load(LInvalidSnapshot, mo_acquire) = 0,
      'Search observes only complete suffix-array publications');
  finally
    LSa.Free;
  end;
end;

procedure Test_SingleChar;
var
  LSa: TSuffixArray;
  LMatches: specialize TArray<TSuffixArrayMatch>;
begin
  WriteLn('--- Single Char ---');
  LSa := TSuffixArray.Create;
  try
    LSa.Build('a');

    LMatches := LSa.Search('a');
    Check(Length(LMatches) = 1, 'Search(a) returns 1 match');
    Check(LMatches[0].Index = 0, 'Match at index 0');

    LMatches := LSa.Search('b');
    Check(Length(LMatches) = 0, 'Search(b) returns 0');
  finally
    LSa.Free;
  end;
end;

procedure Test_AllSameChar;
var
  LSa: TSuffixArray;
  LMatches: specialize TArray<TSuffixArrayMatch>;
begin
  WriteLn('--- All Same Char ---');
  LSa := TSuffixArray.Create;
  try
    LSa.Build('aaaaa');

    LMatches := LSa.Search('aa');
    Check(Length(LMatches) = 4, 'Search(aa) returns 4 matches');

    LMatches := LSa.Search('aaa');
    Check(Length(LMatches) = 3, 'Search(aaa) returns 3 matches');
  finally
    LSa.Free;
  end;
end;

procedure Test_LongText;
var
  LSa: TSuffixArray;
  LText: AnsiString;
  I: Int32;
  LMatches: specialize TArray<TSuffixArrayMatch>;
begin
  WriteLn('--- Long Text ---');
  LSa := TSuffixArray.Create;
  try
    { Build a long text }
    LText := '';
    for I := 0 to 99 do
      LText := LText + 'pattern' + IntToStr(I) + ' ';

    Check(LSa.Build(LText) = sarOk, 'Build long text = ok');
    Check(LSa.IsBuilt, 'IsBuilt = true');

    { Search for known patterns }
    LMatches := LSa.Search('pattern0');
    Check(Length(LMatches) >= 1, 'Search(pattern0) found');

    LMatches := LSa.Search('pattern99');
    Check(Length(LMatches) >= 1, 'Search(pattern99) found');
  finally
    LSa.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Suffix Array Tests ===');
  Test_BasicSearch;
  Test_Contains;
  Test_Count;
  Test_EmptyBuild;
  Test_EmptyRebuildClearsPublishedState;
  Test_ConcurrentBuildSearchSnapshots;
  Test_SingleChar;
  Test_AllSameChar;
  Test_LongText;

  WriteLn;
  WriteLn(TextFormat('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
