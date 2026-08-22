{ nextpas.core.test.fuzz — Mutation-based Fuzzing (v8.32)
  ========================================================
  Fuzzing family split from nextpas.core.test.prop (F-03): random mutation
  (Fuzz/FuzzString), persistent corpus (TFuzzCorpus, FuzzWithCorpus),
  user-marked coverage tracking (ICoverageTracker), structured fuzzing over
  generators (FuzzStructured), and sequential multi-strategy campaigns
  (FuzzMultiStrategy; FuzzParallel is a deprecated alias — NOT parallel).

  RNG is per-thread (GFuzzRng threadvar, F-08); mutation itself is
  sequential — parallel fuzzing is a v9/toolchain topic (F-17/F-18).

  Usage:
    Fuzz('parser survives noise', procedure(const Data: TBytes)
    begin
      ParseSomething(Data);  { any EAssertionFailed is minimized+reported }
    end, [Seed1, Seed2], 10000); }

unit nextpas.core.test.fuzz;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.base,
  nextpas.core.test.prop.gen;

type
  { Test procedure that receives raw bytes }
  TFuzzBytesTest = reference to procedure(const Data: TBytes);

  { Test procedure that receives a string }
  TFuzzStringTest = reference to procedure(const S: string);

{ Fuzz test with raw bytes corpus.
  Randomly mutates corpus items and runs ATest on each.
  If ATest raises EAssertionFailed, reports the minimal failing input.
  AMaxIterations: total mutations to try (default 10000). }
procedure Fuzz(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AMaxIterations: Integer = 10000);

{ Fuzz test with string corpus.
  Strings are encoded to UTF-8 bytes for mutation, then decoded back. }
procedure FuzzString(const AName: string; ATest: TFuzzStringTest;
  const ACorpus: array of string; AMaxIterations: Integer = 10000);

{ Generate random bytes for seed corpus }
function FuzzGenBytes(ALen: Integer): TBytes;

{ Generate random printable ASCII string for seed corpus }
function FuzzGenString(ALen: Integer): string;

{ Minimize a failing input to a smaller one that still fails ATest (v8.40).
  Deterministic two-phase greedy shrink:
    1. repeatedly keep only the first ceil(n/2) bytes while that prefix
       still fails; stop at the first passing prefix (no finer granularity);
    2. left-to-right single-byte removal, retrying the same index after
       each accepted removal.
  Only EAssertionFailed counts as "still failing" — any other exception
  propagates to the caller. An input that does not fail ATest is returned
  unchanged. Result is 1-minimal w.r.t. single-byte removal, not globally
  minimal. Used internally by Fuzz/FuzzWithCorpus/FuzzMultiStrategy. }
function FuzzMinimize(const AData: TBytes; ATest: TFuzzBytesTest): TBytes;

{ ── Corpus Management (v7.3a) ─────────────────────────────────────────────── }

type
  { Corpus manager for persistent fuzzing campaigns.
    Loads initial corpus from a directory, saves new inputs found during fuzzing. }
  TFuzzCorpus = class
  private
    FDir: string;
    FItems: array of TBytes;
    FCount: Integer;
    procedure EnsureDir;
  public
    { Create corpus manager. ADir is the directory to store corpus files.
      Files are named by index: 0.bin, 1.bin, etc. }
    constructor Create(const ADir: string);
    destructor Destroy; override;

    { Add an item to the corpus. Returns True if item is new (not duplicate). }
    function Add(const AData: TBytes): Boolean;

    { Add a string item (converted to UTF-8). Returns True if new. }
    function AddString(const AData: string): Boolean;

    { Get item by index }
    function GetItem(AIndex: Integer): TBytes;

    { Get string item by index }
    function GetString(AIndex: Integer): string;

    { Number of items in corpus }
    function Count: Integer;

    { Save all items to disk }
    procedure Save;

    { Load items from disk }
    procedure Load;

    { Check if corpus directory exists and has files }
    function HasFiles: Boolean;
  end;

{ Fuzz with corpus management. Loads initial corpus from ACorpusDir,
  saves new inputs found during fuzzing. }
procedure FuzzWithCorpus(const AName: string; ATest: TFuzzBytesTest;
  const ACorpusDir: string; AMaxIterations: Integer = 10000);

{ Fuzz string with corpus management }
procedure FuzzStringWithCorpus(const AName: string; ATest: TFuzzStringTest;
  const ACorpusDir: string; AMaxIterations: Integer = 10000);

{ ── Coverage Tracking (v8.0b) ──────────────────────────────────────────────── }

type
  { Coverage tracker for guided fuzzing.
    Users mark coverage points with Hit(); the tracker records which inputs
    trigger new coverage, and only those inputs are added to the corpus. }
  ICoverageTracker = interface
    { Mark a coverage point. AId is an arbitrary integer identifying the point. }
    procedure Hit(AId: Integer);

    { Check if the current input triggered new coverage since last ResetNewCoverage.
      Returns True if any new coverage points were hit. }
    function HasNewCoverage: Boolean;

    { Reset the "new coverage" flag. Call before each fuzz iteration. }
    procedure ResetNewCoverage;

    { Total unique coverage points hit so far }
    function CoverageCount: Integer;

    { Total hit count (including duplicates) }
    function TotalHits: Integer;
  end;

function CreateCoverageTracker: ICoverageTracker;

{ ── Structured Fuzzing (v8.0b) ─────────────────────────────────────────────── }

type
  { Test procedure for structured fuzzing — receives an Int64 value }
  TFuzzStructuredIntTest = reference to procedure(const V: Int64; ACoverage: ICoverageTracker);

{ Fuzz using an Int64 generator for structured input.
  Mutates in generator space (generate → mutate value → test).
  ACoverage tracks which inputs trigger new coverage — only those
  are added to the corpus for further mutation. }
procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredIntTest;
  AGen: IIntGenerator; ACorpus: ICoverageTracker;
  AMaxIterations: Integer = 10000); overload;

{ Fuzz using a string generator for structured input. }
type
  TFuzzStructuredStringTest = reference to procedure(const S: string; ACoverage: ICoverageTracker);

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredStringTest;
  AGen: IStringGenerator; ACorpus: ICoverageTracker;
  AMaxIterations: Integer = 10000); overload;

{ ── Parallel Fuzzing (v8.0b) ───────────────────────────────────────────────── }

type
  { Fuzzer strategy: each worker uses a different mutation approach }
  TFuzzStrategy = (
    fsBitFlip,      { Bit-level mutations }
    fsByteReplace,  { Byte-level replacements }
    fsHavoc,        { Mixed heavy mutations (insert/delete/dup/swap) }
    fsStructured    { Generator-based structured mutations }
  );

{ Run multiple fuzzing workers sequentially, each with a different strategy.
  Shared corpus: workers share discoveries. Uses coverage tracking to
  only keep inputs that expand coverage.
  AWorkers: number of workers (1-4, each gets a different strategy).
  AIterationsPerWorker: iterations per worker. }
procedure FuzzMultiStrategy(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer = 4;
  AIterationsPerWorker: Integer = 2500);

{ Deprecated name: NOT parallel. Sequential multi-strategy only (F-07).
  Use FuzzMultiStrategy. }
procedure FuzzParallel(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer = 4;
  AIterationsPerWorker: Integer = 2500); deprecated 'NOT parallel — use FuzzMultiStrategy';

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.math.random,
  nextpas.core.fs,
  nextpas.core.test.output,
  nextpas.core.test.config;  { DefaultConfig for coverage warning sink }

threadvar
  GCoverageWarned: Boolean;  { P2 #14: warn once per thread on out-of-range coverage ID }
  GFuzzRng: TRandomGen;
  GFuzzRngInitialized: Boolean;

{ ── Mutation-based Fuzzing (v7.2a) ───────────────────────────────────────── }

{ Per-thread RNG (F-08). Mutate GFuzzRng in place — never copy via function return. }
procedure EnsureFuzzRng;
begin
  if not GFuzzRngInitialized then
  begin
    GFuzzRng := TRandomGen.Init(0);
    GFuzzRngInitialized := True;
  end;
end;

{ Convert bytes to hex string efficiently (pre-allocates) }
function BytesToHexStr(const AData: TBytes): string;
var
  I, LLen: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Result, LLen * 3 - 1);
  for I := 0 to LLen - 1 do
  begin
    if I > 0 then
      Result[I * 3] := ' ';
    Result[I * 3 + 1] := IntToHex(AData[I], 2)[1];
    Result[I * 3 + 2] := IntToHex(AData[I], 2)[2];
  end;
end;

{ Mutate a byte array randomly. Strategy is chosen weighted-random:
  40% bit flip, 25% byte replace, 15% byte insert, 10% byte delete,
  5% block dup, 5% block swap }
function FuzzMutate(const AData: TBytes): TBytes;
var
  LRng: TRandomGen;
  LLen, LPos, LPos2, LBlockLen, LStrategy, I, LTmp: Integer;
begin
  EnsureFuzzRng;
  LLen := Length(AData);

  { Empty input → insert a random byte }
  if LLen = 0 then
  begin
    Result := nil;
    SetLength(Result, 1);
    Result[0] := Byte(GFuzzRng.NextIntRange(0, 255));
    Exit;
  end;

  LStrategy := GFuzzRng.NextIntRange(0, 99);
  LPos := GFuzzRng.NextIntRange(0, LLen - 1);

  if LStrategy < 40 then
  begin
    { Bit flip: flip 1-3 random bits in one byte }
    Result := Copy(AData);
    Result[LPos] := Result[LPos] xor Byte(1 shl GFuzzRng.NextIntRange(0, 7));
    if GFuzzRng.NextIntRange(0, 2) = 0 then
      Result[LPos] := Result[LPos] xor Byte(1 shl GFuzzRng.NextIntRange(0, 7));
  end
  else if LStrategy < 65 then
  begin
    { Byte replace: replace with random byte }
    Result := Copy(AData);
    EnsureFuzzRng;
    Result[LPos] := Byte(GFuzzRng.NextIntRange(0, 255));
  end
  else if LStrategy < 80 then
  begin
    { Byte insert: insert random byte at position }
    SetLength(Result, LLen + 1);
    if LPos > 0 then
      Move(AData[0], Result[0], LPos);
    Result[LPos] := Byte(GFuzzRng.NextIntRange(0, 255));
    if LPos < LLen then
      Move(AData[LPos], Result[LPos + 1], LLen - LPos);
  end
  else if LStrategy < 90 then
  begin
    { Byte delete: remove one byte }
    SetLength(Result, LLen - 1);
    if LPos > 0 then
      Move(AData[0], Result[0], LPos);
    if LPos < LLen - 1 then
      Move(AData[LPos + 1], Result[LPos], LLen - 1 - LPos);
  end
  else if LStrategy < 95 then
  begin
    { Block duplicate: duplicate a random block (1-16 bytes) }
    if 15 < LLen - 1 then
      LBlockLen := 1 + GFuzzRng.NextIntRange(0, 15)
    else
      LBlockLen := 1 + GFuzzRng.NextIntRange(0, LLen - 1);
    if LPos + LBlockLen > LLen then
      LBlockLen := LLen - LPos;
    SetLength(Result, LLen + LBlockLen);
    Move(AData[0], Result[0], LLen);  { copy original }
    Move(AData[LPos], Result[LLen], LBlockLen);  { append block }
  end
  else
  begin
    { Block swap: swap two random positions (1-8 bytes) }
    Result := Copy(AData);
    if 7 < LLen div 2 then
      LBlockLen := 1 + GFuzzRng.NextIntRange(0, 7)
    else
      LBlockLen := 1 + GFuzzRng.NextIntRange(0, LLen div 2);
    { Re-choose LPos: must fit LBlockLen bytes from LPos }
    LPos := GFuzzRng.NextIntRange(0, LLen - LBlockLen);
    LPos2 := GFuzzRng.NextIntRange(0, LLen - LBlockLen);
    { Swap bytes at LPos and LPos2 }
    for I := 0 to LBlockLen - 1 do
    begin
      LTmp := Result[LPos + I];
      Result[LPos + I] := Result[LPos2 + I];
      Result[LPos2 + I] := LTmp;
    end;
  end;
end;

{ Minimize a failing input by progressively removing bytes }
function FuzzMinimize(const AData: TBytes; ATest: TFuzzBytesTest): TBytes;
var
  LLen, LHalf, I: Integer;
  LChunk: TBytes;
  LFailed: Boolean;
begin
  Result := Copy(AData);
  LLen := Length(Result);

  { Try removing progressively larger chunks from the end }
  while LLen > 1 do
  begin
    LHalf := LLen div 2;
    LFailed := False;
    SetLength(LChunk, LLen - LHalf);
    Move(Result[0], LChunk[0], LLen - LHalf);
    try
      ATest(LChunk);
    except
      on E: EAssertionFailed do
      begin
        Result := LChunk;
        LLen := Length(Result);
        LFailed := True;
      end;
    end;
    if not LFailed then
      Break;
  end;

  { Try removing individual bytes from the front }
  I := 0;
  while I < Length(Result) do
  begin
    if Length(Result) <= 1 then
      Break;
    SetLength(LChunk, Length(Result) - 1);
    if I > 0 then
      Move(Result[0], LChunk[0], I);
    if I < Length(Result) - 1 then
      Move(Result[I + 1], LChunk[I], Length(Result) - 1 - I);
    try
      ATest(LChunk);
    except
      on E: EAssertionFailed do
      begin
        Result := LChunk;
        Continue;  { retry same index }
      end;
    end;
    Inc(I);
  end;
end;

procedure Fuzz(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AMaxIterations: Integer);
var
  LCorpus: array of TBytes;
  LLen, I, J, LIdx, LFailCount: Integer;
  LInput, LMin: TBytes;
  LHex: string;
begin
  { Build corpus array }
  LLen := Length(ACorpus);
  if LLen = 0 then
  begin
    FailTest('Fuzz "' + AName + '": corpus is empty');
    Exit;
  end;
  SetLength(LCorpus, LLen);
  for I := 0 to LLen - 1 do
    LCorpus[I] := Copy(ACorpus[I]);

  LFailCount := 0;
  for I := 1 to AMaxIterations do
  begin
    { Pick random corpus item and mutate }
    EnsureFuzzRng;
    LIdx := GFuzzRng.NextIntRange(0, High(LCorpus));
    LInput := FuzzMutate(LCorpus[LIdx]);

    try
      ATest(LInput);
    except
      on E: EAssertionFailed do
      begin
        Inc(LFailCount);
        { Minimize the failing input }
        LMin := FuzzMinimize(LInput, ATest);
        { Convert to hex for display }
        LHex := BytesToHexStr(LMin);
        FailTest('Fuzz "' + AName + '" found failure after ' + IntToStr(I) +
          ' iterations (' + IntToStr(LFailCount) + ' failures), ' +
          'minimal input (' + IntToStr(Length(LMin)) + ' bytes): ' + LHex);
        Exit;
      end;
    end;
  end;
  PassTest('Fuzz "' + AName + '" passed ' + IntToStr(AMaxIterations) +
    ' iterations, 0 failures');
end;

procedure FuzzString(const AName: string; ATest: TFuzzStringTest;
  const ACorpus: array of string; AMaxIterations: Integer);
var
  LBytesCorpus: array of TBytes;
  LLen, I: Integer;
begin
  LLen := Length(ACorpus);
  if LLen = 0 then
  begin
    FailTest('FuzzString "' + AName + '": corpus is empty');
    Exit;
  end;
  SetLength(LBytesCorpus, LLen);
  for I := 0 to LLen - 1 do
    LBytesCorpus[I] := StringToUTF8Bytes(ACorpus[I]);

  Fuzz(AName, procedure(const Data: TBytes)
  begin
    ATest(UTF8BytesToString(Data));
  end, LBytesCorpus, AMaxIterations);
end;

function FuzzGenBytes(ALen: Integer): TBytes;
var
  I: Integer;
begin
  EnsureFuzzRng;
  Result := nil;
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := Byte(GFuzzRng.NextIntRange(0, 255));
end;

function FuzzGenString(ALen: Integer): string;
var
  I: Integer;
begin
  EnsureFuzzRng;
  SetLength(Result, ALen);
  for I := 1 to ALen do
    Result[I] := Char(32 + GFuzzRng.NextIntRange(0, 94)); { printable ASCII 32..126 }
end;

{ ── Corpus Management (v7.3a) ───────────────────────────────────────────── }

constructor TFuzzCorpus.Create(const ADir: string);
begin
  inherited Create;
  FDir := ADir;
  FCount := 0;
  SetLength(FItems, 0);
end;

destructor TFuzzCorpus.Destroy;
begin
  SetLength(FItems, 0);
  inherited;
end;

procedure TFuzzCorpus.EnsureDir;
begin
  if not DirectoryExists(FDir) then
    ForceDirectories(FDir);
end;

function TFuzzCorpus.Add(const AData: TBytes): Boolean;
var
  I: Integer;
  LDup: Boolean;
begin
  { Check for duplicates (simple byte-by-byte comparison) }
  LDup := False;
  for I := 0 to FCount - 1 do
  begin
    if Length(FItems[I]) = Length(AData) then
    begin
      if (Length(AData) = 0) or CompareMem(@FItems[I][0], @AData[0], Length(AData)) then
      begin
        LDup := True;
        Break;
      end;
    end;
  end;

  if LDup then
  begin
    Result := False;
    Exit;
  end;

  { Add new item }
  if FCount >= Length(FItems) then
    SetLength(FItems, FCount + 16);
  FItems[FCount] := Copy(AData);
  Inc(FCount);
  Result := True;
end;

function TFuzzCorpus.AddString(const AData: string): Boolean;
begin
  Result := Add(StringToUTF8Bytes(AData));
end;

function TFuzzCorpus.GetItem(AIndex: Integer): TBytes;
begin
  if (AIndex >= 0) and (AIndex < FCount) then
    Result := Copy(FItems[AIndex])
  else
    Result := nil;
end;

function TFuzzCorpus.GetString(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FCount) then
    Result := UTF8BytesToString(FItems[AIndex])
  else
    Result := '';
end;

function TFuzzCorpus.Count: Integer;
begin
  Result := FCount;
end;

procedure TFuzzCorpus.Save;
var
  I: Integer;
  LPath: string;
begin
  EnsureDir;
  for I := 0 to FCount - 1 do
  begin
    LPath := FDir + '/' + IntToStr(I) + '.bin';
    WriteFile(LPath, FItems[I]);
  end;
end;

procedure TFuzzCorpus.Load;
var
  LEntries: TDirEntryArray;
  LPath: string;
  LData: TBytes;
  I, LIdx, LMaxIdx: Integer;
  LIdxMap: array of Integer;
begin
  if not DirectoryExists(FDir) then
    Exit;

  { First pass: find max index }
  LMaxIdx := -1;
  LEntries := ReadDir(FDir);
  for I := 0 to High(LEntries) do
  begin
    LPath := LEntries[I].Name;
    if (Length(LPath) > 4) and (Copy(LPath, Length(LPath) - 3, 4) = '.bin') then
    begin
      LIdx := StrToIntDef(Copy(LPath, 1, Length(LPath) - 4), -1);
      if LIdx > LMaxIdx then
        LMaxIdx := LIdx;
    end;
  end;

  if LMaxIdx < 0 then
    Exit;

  { Second pass: load by index }
  for LIdx := 0 to LMaxIdx do
  begin
    LPath := FDir + '/' + IntToStr(LIdx) + '.bin';
    if FileExists(LPath) then
    begin
      LData := ReadFile(LPath);
      if Length(LData) > 0 then
        Add(LData);
    end;
  end;
end;

function TFuzzCorpus.HasFiles: Boolean;
var
  LEntries: TDirEntryArray;
  I: Integer;
begin
  if not DirectoryExists(FDir) then
  begin
    Result := False;
    Exit;
  end;

  LEntries := ReadDir(FDir);
  for I := 0 to High(LEntries) do
  begin
    if (Length(LEntries[I].Name) > 4) and
       (Copy(LEntries[I].Name, Length(LEntries[I].Name) - 3, 4) = '.bin') then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

procedure FuzzWithCorpus(const AName: string; ATest: TFuzzBytesTest;
  const ACorpusDir: string; AMaxIterations: Integer);
var
  LCorpus: TFuzzCorpus;
  I, J, LIdx, LFailCount: Integer;
  LInput, LMin: TBytes;
  LHex: string;
  LNew: Boolean;
begin
  LCorpus := TFuzzCorpus.Create(ACorpusDir);
  try
    { Load existing corpus from disk }
    LCorpus.Load;

    { If no corpus loaded, seed with random data }
    if LCorpus.Count = 0 then
    begin
      LCorpus.Add(FuzzGenBytes(8));
      LCorpus.Add(FuzzGenBytes(16));
      LCorpus.Add(FuzzGenBytes(32));
    end;

    LFailCount := 0;
    for I := 1 to AMaxIterations do
    begin
      { Pick random corpus item and mutate }
      EnsureFuzzRng;
      LIdx := GFuzzRng.NextIntRange(0, LCorpus.Count - 1);
      LInput := FuzzMutate(LCorpus.GetItem(LIdx));

      try
        ATest(LInput);
        { If test passes and input is "interesting" (new), add to corpus }
        LNew := LCorpus.Add(LInput);
        if LNew and (I mod 100 = 0) then
          LCorpus.Save;  { Periodically save }
      except
        on E: EAssertionFailed do
        begin
          Inc(LFailCount);
          { Minimize the failing input }
          LMin := FuzzMinimize(LInput, ATest);
          { Save failing input to corpus }
          LCorpus.Add(LMin);
          LCorpus.Save;
          { Convert to hex for display }
          LHex := BytesToHexStr(LMin);
          FailTest('Fuzz "' + AName + '" found failure after ' + IntToStr(I) +
            ' iterations (' + IntToStr(LFailCount) + ' failures), ' +
            'minimal input (' + IntToStr(Length(LMin)) + ' bytes): ' + LHex);
          Exit;
        end;
      end;
    end;

    { Save final corpus }
    LCorpus.Save;
    PassTest('Fuzz "' + AName + '" passed ' + IntToStr(AMaxIterations) +
      ' iterations, 0 failures, corpus: ' + IntToStr(LCorpus.Count) + ' items');
  finally
    LCorpus.Free;
  end;
end;

procedure FuzzStringWithCorpus(const AName: string; ATest: TFuzzStringTest;
  const ACorpusDir: string; AMaxIterations: Integer);
begin
  FuzzWithCorpus(AName, procedure(const Data: TBytes)
  begin
    ATest(UTF8BytesToString(Data));
  end, ACorpusDir, AMaxIterations);
end;

{ ── Coverage Tracking (v8.0b) ──────────────────────────────────────────────── }

type
  TCoverageTracker = class(TInterfacedObject, ICoverageTracker)
  private
    { Bitset for coverage points — supports up to 32768 coverage IDs }
    FCoverage: array[0..4095] of Byte;  { 32768 bits }
    FNewCoverage: Boolean;
    FCoverageCount: Integer;
    FTotalHits: Integer;
  public
    constructor Create;
    procedure Hit(AId: Integer);
    function HasNewCoverage: Boolean;
    procedure ResetNewCoverage;
    function CoverageCount: Integer;
    function TotalHits: Integer;
  end;

constructor TCoverageTracker.Create;
begin
  inherited Create;
  FillChar(FCoverage[0], SizeOf(FCoverage), 0);
  FNewCoverage := False;
  FCoverageCount := 0;
  FTotalHits := 0;
end;

procedure TCoverageTracker.Hit(AId: Integer);
var
  LByteIdx, LBitIdx: Integer;
begin
  Inc(FTotalHits);
  if (AId < 0) or (AId > 32767) then
  begin
    { P2 #14 fix: warn once on out-of-range coverage ID instead of silent discard }
    if not GCoverageWarned then
    begin
      ResolveErrSink(DefaultConfig).WriteLn(
        'WARNING: Coverage ID ' + IntToStr(AId) +
        ' out of range [0..32767], coverage data discarded');
      GCoverageWarned := True;
    end;
    Exit;
  end;
  LByteIdx := AId shr 3;
  LBitIdx := AId and 7;
  if (FCoverage[LByteIdx] and (1 shl LBitIdx)) = 0 then
  begin
    FCoverage[LByteIdx] := FCoverage[LByteIdx] or Byte(1 shl LBitIdx);
    FNewCoverage := True;
    Inc(FCoverageCount);
  end;
end;

function TCoverageTracker.HasNewCoverage: Boolean;
begin
  Result := FNewCoverage;
end;

procedure TCoverageTracker.ResetNewCoverage;
begin
  FNewCoverage := False;
end;

function TCoverageTracker.CoverageCount: Integer;
begin
  Result := FCoverageCount;
end;

function TCoverageTracker.TotalHits: Integer;
begin
  Result := FTotalHits;
end;

function CreateCoverageTracker: ICoverageTracker;
begin
  Result := TCoverageTracker.Create;
end;

{ ── Structured Fuzzing (v8.0b) ─────────────────────────────────────────────── }

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredIntTest;
  AGen: IIntGenerator; ACorpus: ICoverageTracker;
  AMaxIterations: Integer);
var
  LCorpus: array of Int64;
  LCorpusCount: Integer;
  I, LIdx, LFailCount: Integer;
  LValue, LMin: Int64;
  LShrunk: specialize TArray<Int64>;
  LTracker: ICoverageTracker;
begin
  LTracker := ACorpus;
  if LTracker = nil then
    LTracker := CreateCoverageTracker;

  { Seed corpus with generator values }
  SetLength(LCorpus, 8);
  LCorpusCount := 0;
  for I := 0 to 7 do
  begin
    LCorpus[LCorpusCount] := AGen.Generate;
    Inc(LCorpusCount);
  end;

  LFailCount := 0;
  for I := 1 to AMaxIterations do
  begin
    { Pick random corpus item and mutate }
    EnsureFuzzRng;
    LIdx := GFuzzRng.NextIntRange(0, LCorpusCount - 1);
    LValue := LCorpus[LIdx];

    { Mutate: apply generator shrink to get variants, or generate fresh }
    if GFuzzRng.NextIntRange(0, 3) = 0 then
    begin
      { 25% chance: generate fresh value }
      LValue := AGen.Generate;
    end
    else
    begin
      { 75% chance: shrink existing value to get mutation }
      LShrunk := AGen.Shrink(LValue);
      if Length(LShrunk) > 0 then
        LValue := LShrunk[GFuzzRng.NextIntRange(0, High(LShrunk))];
    end;

    try
      LTracker.ResetNewCoverage;
      ATest(LValue, LTracker);

      { If test passes and triggered new coverage, add to corpus }
      if LTracker.HasNewCoverage then
      begin
        if LCorpusCount >= Length(LCorpus) then
          SetLength(LCorpus, LCorpusCount + 16);
        LCorpus[LCorpusCount] := LValue;
        Inc(LCorpusCount);
      end;
    except
      on E: EAssertionFailed do
      begin
        Inc(LFailCount);
        { Minimize: try shrinking the failing value }
        LMin := LValue;
        LShrunk := AGen.Shrink(LMin);
        LIdx := 0;
        LFailCount := 0;  { reuse as shrink iteration counter }
        while (LIdx <= High(LShrunk)) and (LFailCount < 100) do
        begin
          try
            LTracker.ResetNewCoverage;
            ATest(LShrunk[LIdx], LTracker);
            Inc(LIdx);
          except
            on E2: EAssertionFailed do
            begin
              if LShrunk[LIdx] = LMin then
              begin
                { Fixed point — no further shrinking possible }
                Inc(LFailCount);
                Inc(LIdx);
              end
              else
              begin
                LMin := LShrunk[LIdx];
                LShrunk := AGen.Shrink(LMin);
                LIdx := 0;
              end;
            end;
          end;
        end;
        FailTest('FuzzStructured "' + AName + '" found failure after ' +
          IntToStr(I) + ' iterations, minimal input: ' + IntToStr(LMin) +
          ', coverage: ' + IntToStr(LTracker.CoverageCount) + ' points');
        Exit;
      end;
    end;
  end;
  PassTest('FuzzStructured "' + AName + '" passed ' + IntToStr(AMaxIterations) +
    ' iterations, 0 failures, corpus: ' + IntToStr(LCorpusCount) +
    ' items, coverage: ' + IntToStr(LTracker.CoverageCount) + ' points');
end;

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredStringTest;
  AGen: IStringGenerator; ACorpus: ICoverageTracker;
  AMaxIterations: Integer);
var
  LCorpus: array of string;
  LCorpusCount: Integer;
  I, LIdx, LFailCount: Integer;
  LValue, LMin: string;
  LShrunk: specialize TArray<string>;
  LTracker: ICoverageTracker;
begin
  LTracker := ACorpus;
  if LTracker = nil then
    LTracker := CreateCoverageTracker;

  { Seed corpus with generator values }
  SetLength(LCorpus, 8);
  LCorpusCount := 0;
  for I := 0 to 7 do
  begin
    LCorpus[LCorpusCount] := AGen.Generate;
    Inc(LCorpusCount);
  end;

  LFailCount := 0;
  for I := 1 to AMaxIterations do
  begin
    EnsureFuzzRng;
    LIdx := GFuzzRng.NextIntRange(0, LCorpusCount - 1);
    LValue := LCorpus[LIdx];

    if GFuzzRng.NextIntRange(0, 3) = 0 then
      LValue := AGen.Generate
    else
    begin
      LShrunk := AGen.Shrink(LValue);
      if Length(LShrunk) > 0 then
        LValue := LShrunk[GFuzzRng.NextIntRange(0, High(LShrunk))];
    end;

    try
      LTracker.ResetNewCoverage;
      ATest(LValue, LTracker);

      if LTracker.HasNewCoverage then
      begin
        if LCorpusCount >= Length(LCorpus) then
          SetLength(LCorpus, LCorpusCount + 16);
        LCorpus[LCorpusCount] := LValue;
        Inc(LCorpusCount);
      end;
    except
      on E: EAssertionFailed do
      begin
        LMin := LValue;
        LShrunk := AGen.Shrink(LMin);
        LIdx := 0;
        LFailCount := 0;
        while (LIdx <= High(LShrunk)) and (LFailCount < 100) do
        begin
          try
            LTracker.ResetNewCoverage;
            ATest(LShrunk[LIdx], LTracker);
            Inc(LIdx);
          except
            on E2: EAssertionFailed do
            begin
              if LShrunk[LIdx] = LMin then
              begin
                Inc(LFailCount);
                Inc(LIdx);
              end
              else
              begin
                LMin := LShrunk[LIdx];
                LShrunk := AGen.Shrink(LMin);
                LIdx := 0;
              end;
            end;
          end;
        end;
        FailTest('FuzzStructured "' + AName + '" found failure after ' +
          IntToStr(I) + ' iterations, minimal input: ''' + LMin + '''' +
          ', coverage: ' + IntToStr(LTracker.CoverageCount) + ' points');
        Exit;
      end;
    end;
  end;
  PassTest('FuzzStructured "' + AName + '" passed ' + IntToStr(AMaxIterations) +
    ' iterations, 0 failures, corpus: ' + IntToStr(LCorpusCount) +
    ' items, coverage: ' + IntToStr(LTracker.CoverageCount) + ' points');
end;

{ ── Parallel Fuzzing (v8.0b) ───────────────────────────────────────────────── }

{ Mutate with a specific strategy }
function FuzzMutateStrategy(const AData: TBytes; AStrategy: TFuzzStrategy): TBytes;
var
  LRng: TRandomGen;
  LLen, LPos, LPos2, LBlockLen, I, LTmp: Integer;
begin
  Result := nil;
  EnsureFuzzRng;
  LLen := Length(AData);

  if LLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := Byte(GFuzzRng.NextIntRange(0, 255));
    Exit;
  end;

  case AStrategy of
    fsBitFlip:
    begin
      { Pure bit flips: 1-3 bits }
      Result := Copy(AData);
      LPos := GFuzzRng.NextIntRange(0, LLen - 1);
      Result[LPos] := Result[LPos] xor Byte(1 shl GFuzzRng.NextIntRange(0, 7));
      if GFuzzRng.NextIntRange(0, 2) = 0 then
        Result[LPos] := Result[LPos] xor Byte(1 shl GFuzzRng.NextIntRange(0, 7));
    end;
    fsByteReplace:
    begin
      { Byte replacements: replace 1-4 bytes }
      Result := Copy(AData);
      for I := 1 to 1 + GFuzzRng.NextIntRange(0, 3) do
      begin
        EnsureFuzzRng;
        LPos := GFuzzRng.NextIntRange(0, LLen - 1);
        Result[LPos] := Byte(GFuzzRng.NextIntRange(0, 255));
      end;
    end;
    fsHavoc:
    begin
      { Heavy mutations: insert, delete, dup, swap }
      case GFuzzRng.NextIntRange(0, 3) of
        0: begin { Insert }
          LPos := GFuzzRng.NextIntRange(0, LLen);
          SetLength(Result, LLen + 1);
          if LPos > 0 then
            Move(AData[0], Result[0], LPos);
          Result[LPos] := Byte(GFuzzRng.NextIntRange(0, 255));
          if LPos < LLen then
            Move(AData[LPos], Result[LPos + 1], LLen - LPos);
        end;
        1: begin { Delete }
          if LLen <= 1 then
          begin
            Result := Copy(AData);
            Exit;
          end;
          LPos := GFuzzRng.NextIntRange(0, LLen - 1);
          SetLength(Result, LLen - 1);
          if LPos > 0 then
            Move(AData[0], Result[0], LPos);
          if LPos < LLen - 1 then
            Move(AData[LPos + 1], Result[LPos], LLen - 1 - LPos);
        end;
        2: begin { Block duplicate }
          if 7 < LLen then
            LBlockLen := 1 + GFuzzRng.NextIntRange(0, 7)
          else
            LBlockLen := 1 + GFuzzRng.NextIntRange(0, LLen - 1);
          LPos := GFuzzRng.NextIntRange(0, LLen - 1);
          if LPos + LBlockLen > LLen then
            LBlockLen := LLen - LPos;
          SetLength(Result, LLen + LBlockLen);
          Move(AData[0], Result[0], LLen);
          Move(AData[LPos], Result[LLen], LBlockLen);
        end;
        3: begin { Block swap }
          Result := Copy(AData);
          if 3 < LLen div 2 then
            LBlockLen := 1 + GFuzzRng.NextIntRange(0, 3)
          else
            LBlockLen := 1 + GFuzzRng.NextIntRange(0, LLen div 2);
          if LLen - LBlockLen < 0 then
            LBlockLen := LLen;
          LPos := GFuzzRng.NextIntRange(0, LLen - LBlockLen);
          LPos2 := GFuzzRng.NextIntRange(0, LLen - LBlockLen);
          for I := 0 to LBlockLen - 1 do
          begin
            LTmp := Result[LPos + I];
            Result[LPos + I] := Result[LPos2 + I];
            Result[LPos2 + I] := LTmp;
          end;
        end;
      end;
    end;
    fsStructured:
    begin
      { Structured: use existing FuzzMutate }
      Result := FuzzMutate(AData);
    end;
  end;
end;

{ R4-10: FuzzMultiStrategy runs multiple mutation strategies sequentially.
  Each strategy explores the corpus independently with its own mutation approach.
  Actual thread-level parallelism is not implemented — all workers run in
  the calling thread. }
procedure FuzzMultiStrategy(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer; AIterationsPerWorker: Integer);
var
  LCorpus: array of TBytes;
  LCorpusCount, LLen, I, J, W, LIdx, LFailCount: Integer;
  LInput, LMin: TBytes;
  LHex: string;
  LTracker: ICoverageTracker;
  LStrategy: TFuzzStrategy;
  LStrategies: array of TFuzzStrategy;
begin
  { Clamp workers }
  if AWorkers < 1 then AWorkers := 1;
  if AWorkers > 4 then AWorkers := 4;

  { Build strategy list }
  SetLength(LStrategies, AWorkers);
  case AWorkers of
    1: LStrategies[0] := fsStructured;
    2: begin LStrategies[0] := fsBitFlip; LStrategies[1] := fsHavoc; end;
    3: begin LStrategies[0] := fsBitFlip; LStrategies[1] := fsByteReplace; LStrategies[2] := fsHavoc; end;
    4: begin LStrategies[0] := fsBitFlip; LStrategies[1] := fsByteReplace; LStrategies[2] := fsHavoc; LStrategies[3] := fsStructured; end;
  end;

  { Build shared corpus }
  LLen := Length(ACorpus);
  if LLen = 0 then
  begin
    FailTest('FuzzMultiStrategy "' + AName + '": corpus is empty');
    Exit;
  end;
  SetLength(LCorpus, LLen + 16);
  LCorpusCount := LLen;
  for I := 0 to LLen - 1 do
    LCorpus[I] := Copy(ACorpus[I]);

  LTracker := CreateCoverageTracker;
  LFailCount := 0;

  { Run workers sequentially, each with its strategy }
  for W := 0 to AWorkers - 1 do
  begin
    LStrategy := LStrategies[W];
    for J := 1 to AIterationsPerWorker do
    begin
      { Pick random corpus item and mutate with strategy }
      EnsureFuzzRng;
      LIdx := GFuzzRng.NextIntRange(0, LCorpusCount - 1);
      LInput := FuzzMutateStrategy(LCorpus[LIdx], LStrategy);

      try
        LTracker.ResetNewCoverage;
        ATest(LInput);

        { If triggered new coverage, add to shared corpus }
        if LTracker.HasNewCoverage then
        begin
          if LCorpusCount >= Length(LCorpus) then
            SetLength(LCorpus, LCorpusCount + 16);
          LCorpus[LCorpusCount] := Copy(LInput);
          Inc(LCorpusCount);
        end;
      except
        on E: EAssertionFailed do
        begin
          Inc(LFailCount);
          LMin := FuzzMinimize(LInput, ATest);
          LHex := BytesToHexStr(LMin);
          FailTest('FuzzMultiStrategy "' + AName + '" worker ' + IntToStr(W) +
            ' (' + IntToStr(Ord(LStrategy)) + ') found failure after ' +
            IntToStr(J) + ' iterations, minimal input (' +
            IntToStr(Length(LMin)) + ' bytes): ' + LHex);
          Exit;
        end;
      end;
    end;
  end;

  PassTest('FuzzMultiStrategy "' + AName + '" passed ' +
    IntToStr(AWorkers * AIterationsPerWorker) + ' iterations (' +
    IntToStr(AWorkers) + ' workers), 0 failures, corpus: ' +
    IntToStr(LCorpusCount) + ' items, coverage: ' +
    IntToStr(LTracker.CoverageCount) + ' points');
end;

{ Deprecated alias }
{$PUSH}{$WARNINGS OFF}
procedure FuzzParallel(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer;
  AIterationsPerWorker: Integer);
begin
  FuzzMultiStrategy(AName, ATest, ACorpus, AWorkers, AIterationsPerWorker);
end;
{$POP}


end.
