{ nextpas.core.test.prop — Property-based Testing (v7.1)
  =========================================================
  QuickCheck-style property testing with structured generators
  and automatic shrinking on failure.

  Usage:
    procedure TestRoundtrip(const S: string);
    begin
      CheckEqual(S, JsonDecode(JsonEncode(S)));
    end;

    Prop('JSON roundtrip', @TestRoundtrip)
      .WithGen(GenString(1..1000))
      .Runs(1000)
      .ShrinkOnFail; }

unit nextpas.core.test.prop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.output;

type
  { ── Test procedure types ─────────────────────────────────────────────────── }
  TStringTest = reference to procedure(const V: string);
  TIntTest = reference to procedure(const V: Int64);
  TBoolTest = reference to procedure(const V: Boolean);
  TBytesTest = reference to procedure(const V: TBytes);

  { ── String Generator ────────────────────────────────────────────────────── }
  IStringGenerator = interface
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

  { ── Int64 Generator ─────────────────────────────────────────────────────── }
  IIntGenerator = interface
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

  { ── Boolean Generator ───────────────────────────────────────────────────── }
  IBoolGenerator = interface
    function Generate: Boolean;
    function Shrink(const AValue: Boolean): specialize TArray<Boolean>;
    function Name: string;
  end;

  { ── TBytes Generator ────────────────────────────────────────────────────── }
  IBytesGenerator = interface
    function Generate: TBytes;
    function Shrink(const AValue: TBytes): specialize TArray<TBytes>;
    function Name: string;
  end;

  { ── Combinator function types ─────────────────────────────────────────────── }
  TIntToString = reference to function(V: Int64): string;
  TIntPred     = reference to function(V: Int64): Boolean;
  TStringPred  = reference to function(const V: string): Boolean;
  TBytesPred   = reference to function(const V: TBytes): Boolean;

{ ── Generator factories ───────────────────────────────────────────────────── }

function GenString(AMinLen, AMaxLen: Integer): IStringGenerator; overload;
function GenString(AMaxLen: Integer = 256): IStringGenerator; overload;
function GenInt(AMin, AMax: Int64): IIntGenerator; overload;
function GenInt(AMax: Int64 = MaxInt): IIntGenerator; overload;
function GenBytes(AMinLen, AMaxLen: Integer): IBytesGenerator; overload;
function GenBytes(AMaxLen: Integer = 256): IBytesGenerator; overload;
function GenBool: IBoolGenerator;

{ Pick random values from a predefined array }
function GenChoiceInt(const AValues: array of Int64): IIntGenerator;
function GenChoiceString(const AValues: array of string): IStringGenerator;
function GenChoiceBool(const AValues: array of Boolean): IBoolGenerator;

{ Combine multiple generators of the same type (randomly pick one per Generate) }
function GenOneOfInt(const AGens: array of IIntGenerator): IIntGenerator;
function GenOneOfString(const AGens: array of IStringGenerator): IStringGenerator;

{ ── Generator combinators ──────────────────────────────────────────────────── }

{ Map: transform Int64 generator output to string }
function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;

{ Filter: reject Int64 values not matching predicate }
function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;

{ Filter: reject string values not matching predicate }
function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;

{ Filter: reject TBytes values not matching predicate }
function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;

{ ── Structured Generators (v8.0a) ─────────────────────────────────────────── }

type
  { Array of Int64 generator }
  TIntArrayTest = reference to procedure(const V: array of Int64);

  IArrayGenerator = interface
    function Generate: specialize TArray<Int64>;
    function Shrink(const AValue: specialize TArray<Int64>): specialize TArray<specialize TArray<Int64>>;
    function Name: string;
  end;

  { Tuple (Int64, String) generator }
  TTupleTest = reference to procedure(AInt: Int64; const AStr: string);

  ITupleGenerator = interface
    function GenerateInt: Int64;
    function GenerateString: string;
    function Name: string;
  end;

{ Generate random-length array of Int64 values }
function GenArray(AGen: IIntGenerator; AMaxLen: Integer = 100): IArrayGenerator; overload;
function GenArray(AGen: IIntGenerator; AMinLen, AMaxLen: Integer): IArrayGenerator; overload;

{ Generate (Int64, String) tuple }
function GenTuple(AGen1: IIntGenerator; AGen2: IStringGenerator): ITupleGenerator;

{ Bind/FlatMap: chain generators based on first output }
type
  TIntToGenerator = reference to function(V: Int64): IIntGenerator;

function BindInt(AGen: IIntGenerator; AFn: TIntToGenerator): IIntGenerator;

{ ── Property test helpers ──────────────────────────────────────────────────── }

{ Raise EAssertionFailed — use inside Prop test bodies instead of FailTest }
procedure PropFail(const AMsg: string);

{ ── Property test registration ─────────────────────────────────────────────── }

{ Register a property test with a string generator }
procedure Prop(const AName: string; ATest: TStringTest;
  AGen: IStringGenerator; ARuns: Integer = 100; AShrink: Boolean = True); overload;

{ Register a property test with an Int64 generator }
procedure Prop(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer = 100; AShrink: Boolean = True); overload;

{ Register a property test with a Boolean generator }
procedure Prop(const AName: string; ATest: TBoolTest;
  AGen: IBoolGenerator; ARuns: Integer = 100; AShrink: Boolean = True); overload;

{ Register a property test with a TBytes generator }
procedure Prop(const AName: string; ATest: TBytesTest;
  AGen: IBytesGenerator; ARuns: Integer = 100; AShrink: Boolean = True); overload;

{ Register a property test with an array generator (v8.0a) }
procedure PropArray(const AName: string; ATest: TIntArrayTest;
  AGen: IArrayGenerator; ARuns: Integer = 100; AShrink: Boolean = True);

{ Register a property test with a tuple generator (v8.0a) }
procedure PropTuple(const AName: string; ATest: TTupleTest;
  AGen: ITupleGenerator; ARuns: Integer = 100);

{ Like Prop, but returns the shrunk value as string instead of calling FailTest.
  Returns '' if all runs pass. Raises EAssertionFailed on unexpected errors. }
function PropWithResult(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer = 100; AShrink: Boolean = True): string;

{ ── Mutation-based Fuzzing (v7.2a) ───────────────────────────────────────── }

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
procedure FuzzParallel(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer = 4;
  AIterationsPerWorker: Integer = 2500);

implementation

uses
  nextpas.core.math.random,
  nextpas.core.fs;

{ ── String Generator ──────────────────────────────────────────────────────── }

type
  TStringGenerator = class(TInterfacedObject, IStringGenerator)
  private
    FMinLen, FMaxLen: Integer;
    FRng: TRandomGen;
  public
    constructor Create(AMinLen, AMaxLen: Integer);
    destructor Destroy; override;
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

constructor TStringGenerator.Create(AMinLen, AMaxLen: Integer);
begin
  inherited Create;
  if AMinLen > AMaxLen then
    raise EAssertionFailed.Create('GenString: AMinLen must be <= AMaxLen');
  FMinLen := AMinLen;
  FMaxLen := AMaxLen;
  FRng := TRandomGen.Create(0);
end;

destructor TStringGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TStringGenerator.Generate: string;
var
  LLen, I: Integer;
begin
  LLen := FMinLen + FRng.NextIntRange(0, FMaxLen - FMinLen);
  SetLength(Result, LLen);
  for I := 1 to LLen do
    Result[I] := Char(32 + FRng.NextIntRange(0, 95)); { printable ASCII }
end;

function TStringGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  LLen: Integer;
begin
  LLen := Length(AValue);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, 8);
  { Try empty }
  Result[0] := '';
  { Try half }
  Result[1] := Copy(AValue, 1, LLen div 2);
  { Try remove last char }
  Result[2] := Copy(AValue, 1, LLen - 1);
  { Try replace all chars with 'a' }
  Result[3] := StringOfChar('a', LLen);
  { Try remove first char }
  if LLen > 1 then
    Result[4] := Copy(AValue, 2, LLen - 1)
  else
    Result[4] := '';
  { Try remove middle char }
  if LLen > 2 then
    Result[5] := Copy(AValue, 1, LLen div 2) + Copy(AValue, LLen div 2 + 2, LLen)
  else
    Result[5] := '';
  { Try shorter lengths }
  if LLen > 3 then
    Result[6] := StringOfChar('a', LLen - 1)
  else
    Result[6] := '';
  if LLen > 5 then
    Result[7] := StringOfChar('a', LLen div 2)
  else
    Result[7] := '';
end;

function TStringGenerator.Name: string;
begin
  Result := 'GenString(' + IntToStr(FMinLen) + '..' + IntToStr(FMaxLen) + ')';
end;

{ ── Int64 Generator ───────────────────────────────────────────────────────── }

type
  TIntGenerator = class(TInterfacedObject, IIntGenerator)
  private
    FMin, FMax: Int64;
    FRng: TRandomGen;
  public
    constructor Create(AMin, AMax: Int64);
    destructor Destroy; override;
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

constructor TIntGenerator.Create(AMin, AMax: Int64);
begin
  inherited Create;
  if AMin > AMax then
    raise EAssertionFailed.Create('GenInt: AMin must be <= AMax');
  FMin := AMin;
  FMax := AMax;
  FRng := TRandomGen.Create(0);
end;

destructor TIntGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TIntGenerator.Generate: Int64;
var
  LRange: UInt64;
  LHi, LLo: UInt64;
begin
  if FMin = FMax then
    Result := FMin
  else
  begin
    LRange := UInt64(FMax - FMin) + 1;
    { Build 64-bit random from two 32-bit halves }
    LHi := UInt64(FRng.NextIntRange(0, MaxInt));
    LLo := UInt64(FRng.NextIntRange(0, MaxInt));
    Result := FMin + Int64(((LHi shl 32) or LLo) mod LRange);
  end;
end;

function TIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  LTarget: Int64;
begin
  { Shrink toward the "simplest" value: FMin if positive, 0 otherwise }
  if FMin > 0 then
    LTarget := FMin
  else
    LTarget := 0;
  SetLength(Result, 4);
  { Try simplest value }
  Result[0] := LTarget;
  { Try halfway between current and simplest }
  Result[1] := LTarget + (AValue - LTarget) div 2;
  { Try one step toward simplest }
  if AValue > LTarget then
    Result[2] := AValue - 1
  else
    Result[2] := AValue + 1;
  { Try halfway between simplest and midpoint (faster convergence) }
  Result[3] := LTarget + (AValue - LTarget) div 4;
end;

function TIntGenerator.Name: string;
begin
  Result := 'GenInt(' + IntToStr(FMin) + '..' + IntToStr(FMax) + ')';
end;

{ ── Boolean Generator ─────────────────────────────────────────────────────── }

type
  TBoolGenerator = class(TInterfacedObject, IBoolGenerator)
  private
    FRng: TRandomGen;
  public
    constructor Create;
    destructor Destroy; override;
    function Generate: Boolean;
    function Shrink(const AValue: Boolean): specialize TArray<Boolean>;
    function Name: string;
  end;

constructor TBoolGenerator.Create;
begin
  inherited Create;
  FRng := TRandomGen.Create(0);
end;

destructor TBoolGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TBoolGenerator.Generate: Boolean;
begin
  Result := FRng.NextBool;
end;

function TBoolGenerator.Shrink(const AValue: Boolean): specialize TArray<Boolean>;
begin
  SetLength(Result, 1);
  { Shrink toward False }
  Result[0] := False;
end;

function TBoolGenerator.Name: string;
begin
  Result := 'GenBool';
end;

{ ── TBytes Generator ──────────────────────────────────────────────────────── }

type
  TBytesGenerator = class(TInterfacedObject, IBytesGenerator)
  private
    FMinLen, FMaxLen: Integer;
    FRng: TRandomGen;
  public
    constructor Create(AMinLen, AMaxLen: Integer);
    destructor Destroy; override;
    function Generate: TBytes;
    function Shrink(const AValue: TBytes): specialize TArray<TBytes>;
    function Name: string;
  end;

constructor TBytesGenerator.Create(AMinLen, AMaxLen: Integer);
begin
  inherited Create;
  if AMinLen > AMaxLen then
    raise EAssertionFailed.Create('GenBytes: AMinLen must be <= AMaxLen');
  FMinLen := AMinLen;
  FMaxLen := AMaxLen;
  FRng := TRandomGen.Create(0);
end;

destructor TBytesGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TBytesGenerator.Generate: TBytes;
var
  LLen, I: Integer;
begin
  LLen := FMinLen + FRng.NextIntRange(0, FMaxLen - FMinLen);
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I] := Byte(FRng.NextIntRange(0, 255));
end;

function TBytesGenerator.Shrink(const AValue: TBytes): specialize TArray<TBytes>;
var
  LLen: Integer;
begin
  LLen := Length(AValue);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, 3);
  { Try empty }
  SetLength(Result[0], 0);
  { Try half }
  SetLength(Result[1], LLen div 2);
  Move(AValue[0], Result[1][0], LLen div 2);
  { Try remove last byte }
  SetLength(Result[2], LLen - 1);
  if LLen > 1 then
    Move(AValue[0], Result[2][0], LLen - 1);
end;

function TBytesGenerator.Name: string;
begin
  Result := 'GenBytes(' + IntToStr(FMinLen) + '..' + IntToStr(FMaxLen) + ')';
end;

{ ── Generator factories ───────────────────────────────────────────────────── }

function GenString(AMinLen, AMaxLen: Integer): IStringGenerator;
begin
  Result := TStringGenerator.Create(AMinLen, AMaxLen);
end;

function GenString(AMaxLen: Integer): IStringGenerator;
begin
  Result := TStringGenerator.Create(0, AMaxLen);
end;

function GenInt(AMin, AMax: Int64): IIntGenerator;
begin
  Result := TIntGenerator.Create(AMin, AMax);
end;

function GenInt(AMax: Int64): IIntGenerator;
begin
  Result := TIntGenerator.Create(0, AMax);
end;

function GenBytes(AMinLen, AMaxLen: Integer): IBytesGenerator;
begin
  Result := TBytesGenerator.Create(AMinLen, AMaxLen);
end;

function GenBytes(AMaxLen: Integer): IBytesGenerator;
begin
  Result := TBytesGenerator.Create(0, AMaxLen);
end;

function GenBool: IBoolGenerator;
begin
  Result := TBoolGenerator.Create;
end;

{ ── MapIntToStr combinator ─────────────────────────────────────────────────── }

type
  TMapIntToStrGenerator = class(TInterfacedObject, IStringGenerator)
  private
    FSource: IIntGenerator;
    FMap: TIntToString;
  public
    constructor Create(ASource: IIntGenerator; AMap: TIntToString);
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

constructor TMapIntToStrGenerator.Create(ASource: IIntGenerator; AMap: TIntToString);
begin
  inherited Create;
  FSource := ASource;
  FMap := AMap;
end;

function TMapIntToStrGenerator.Generate: string;
begin
  Result := FMap(FSource.Generate);
end;

function TMapIntToStrGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  LParsed: Int64;
  LShrunk: specialize TArray<Int64>;
  I, N: Integer;
begin
  { Try to reverse-map to Int64, shrink, then map forward }
  Val(AValue, LParsed);
  LShrunk := FSource.Shrink(LParsed);
  N := 0;
  SetLength(Result, Length(LShrunk));
  for I := 0 to High(LShrunk) do
  begin
    Result[N] := FMap(LShrunk[I]);
    if Result[N] <> AValue then
      Inc(N);
  end;
  SetLength(Result, N);
end;

function TMapIntToStrGenerator.Name: string;
begin
  Result := 'MapIntToStr(' + FSource.Name + ')';
end;

function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;
begin
  Result := TMapIntToStrGenerator.Create(AGen, AMap);
end;

{ ── FilterInt combinator ───────────────────────────────────────────────────── }

type
  TFilterIntGenerator = class(TInterfacedObject, IIntGenerator)
  private
    FSource: IIntGenerator;
    FPred: TIntPred;
    FMaxRetries: Integer;
  public
    constructor Create(ASource: IIntGenerator; APred: TIntPred);
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

constructor TFilterIntGenerator.Create(ASource: IIntGenerator; APred: TIntPred);
begin
  inherited Create;
  FSource := ASource;
  FPred := APred;
  FMaxRetries := 100;
end;

function TFilterIntGenerator.Generate: Int64;
var
  I: Integer;
begin
  for I := 1 to FMaxRetries do
  begin
    Result := FSource.Generate;
    if FPred(Result) then
      Exit;
  end;
  { Fallback: return last generated value even if it doesn't match }
  Result := FSource.Generate;
end;

function TFilterIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  LShrunk: specialize TArray<Int64>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  SetLength(Result, Length(LShrunk));
  for I := 0 to High(LShrunk) do
  begin
    if FPred(LShrunk[I]) then
    begin
      Result[N] := LShrunk[I];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TFilterIntGenerator.Name: string;
begin
  Result := 'FilterInt(' + FSource.Name + ')';
end;

function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;
begin
  Result := TFilterIntGenerator.Create(AGen, APred);
end;

{ ── FilterString combinator ────────────────────────────────────────────────── }

type
  TFilterStringGenerator = class(TInterfacedObject, IStringGenerator)
  private
    FSource: IStringGenerator;
    FPred: TStringPred;
    FMaxRetries: Integer;
  public
    constructor Create(ASource: IStringGenerator; APred: TStringPred);
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

constructor TFilterStringGenerator.Create(ASource: IStringGenerator; APred: TStringPred);
begin
  inherited Create;
  FSource := ASource;
  FPred := APred;
  FMaxRetries := 100;
end;

function TFilterStringGenerator.Generate: string;
var
  I: Integer;
begin
  for I := 1 to FMaxRetries do
  begin
    Result := FSource.Generate;
    if FPred(Result) then
      Exit;
  end;
  Result := FSource.Generate;
end;

function TFilterStringGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  LShrunk: specialize TArray<string>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  SetLength(Result, Length(LShrunk));
  for I := 0 to High(LShrunk) do
  begin
    if FPred(LShrunk[I]) then
    begin
      Result[N] := LShrunk[I];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TFilterStringGenerator.Name: string;
begin
  Result := 'FilterString(' + FSource.Name + ')';
end;

function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;
begin
  Result := TFilterStringGenerator.Create(AGen, APred);
end;

{ ── FilterBytes combinator ─────────────────────────────────────────────────── }

type
  TFilterBytesGenerator = class(TInterfacedObject, IBytesGenerator)
  private
    FSource: IBytesGenerator;
    FPred: TBytesPred;
    FMaxRetries: Integer;
  public
    constructor Create(ASource: IBytesGenerator; APred: TBytesPred);
    function Generate: TBytes;
    function Shrink(const AValue: TBytes): specialize TArray<TBytes>;
    function Name: string;
  end;

constructor TFilterBytesGenerator.Create(ASource: IBytesGenerator; APred: TBytesPred);
begin
  inherited Create;
  FSource := ASource;
  FPred := APred;
  FMaxRetries := 100;
end;

function TFilterBytesGenerator.Generate: TBytes;
var
  I: Integer;
begin
  for I := 1 to FMaxRetries do
  begin
    Result := FSource.Generate;
    if FPred(Result) then
      Exit;
  end;
  Result := FSource.Generate;
end;

function TFilterBytesGenerator.Shrink(const AValue: TBytes): specialize TArray<TBytes>;
var
  LShrunk: specialize TArray<TBytes>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  SetLength(Result, Length(LShrunk));
  for I := 0 to High(LShrunk) do
  begin
    if FPred(LShrunk[I]) then
    begin
      Result[N] := LShrunk[I];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TFilterBytesGenerator.Name: string;
begin
  Result := 'FilterBytes(' + FSource.Name + ')';
end;

function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;
begin
  Result := TFilterBytesGenerator.Create(AGen, APred);
end;

{ ── GenChoiceInt ──────────────────────────────────────────────────────────── }

type
  TChoiceIntGenerator = class(TInterfacedObject, IIntGenerator)
  private
    FValues: specialize TArray<Int64>;
    FRng: TRandomGen;
  public
    constructor Create(const AValues: array of Int64);
    destructor Destroy; override;
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

constructor TChoiceIntGenerator.Create(const AValues: array of Int64);
var
  I: Integer;
begin
  inherited Create;
  if Length(AValues) = 0 then
    raise EAssertionFailed.Create('GenChoiceInt: empty values array');
  SetLength(FValues, Length(AValues));
  for I := 0 to High(AValues) do
    FValues[I] := AValues[I];
  FRng := TRandomGen.Create(0);
end;

destructor TChoiceIntGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TChoiceIntGenerator.Generate: Int64;
begin
  Result := FValues[FRng.NextIntRange(0, Length(FValues) - 1)];
end;

function TChoiceIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  I, N: Integer;
begin
  { Try values that are "simpler" (earlier in the array) }
  N := 0;
  SetLength(Result, Length(FValues));
  for I := 0 to High(FValues) do
  begin
    if FValues[I] < AValue then
    begin
      Result[N] := FValues[I];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TChoiceIntGenerator.Name: string;
begin
  Result := 'GenChoiceInt(' + IntToStr(Length(FValues)) + ' values)';
end;

function GenChoiceInt(const AValues: array of Int64): IIntGenerator;
begin
  Result := TChoiceIntGenerator.Create(AValues);
end;

{ ── GenChoiceString ───────────────────────────────────────────────────────── }

type
  TChoiceStringGenerator = class(TInterfacedObject, IStringGenerator)
  private
    FValues: specialize TArray<string>;
    FRng: TRandomGen;
  public
    constructor Create(const AValues: array of string);
    destructor Destroy; override;
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

constructor TChoiceStringGenerator.Create(const AValues: array of string);
var
  I: Integer;
begin
  inherited Create;
  if Length(AValues) = 0 then
    raise EAssertionFailed.Create('GenChoiceString: empty values array');
  SetLength(FValues, Length(AValues));
  for I := 0 to High(AValues) do
    FValues[I] := AValues[I];
  FRng := TRandomGen.Create(0);
end;

destructor TChoiceStringGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TChoiceStringGenerator.Generate: string;
begin
  Result := FValues[FRng.NextIntRange(0, Length(FValues) - 1)];
end;

function TChoiceStringGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  I, N: Integer;
begin
  { Try shorter strings first }
  N := 0;
  SetLength(Result, Length(FValues));
  for I := 0 to High(FValues) do
  begin
    if (Length(FValues[I]) < Length(AValue)) or
       ((Length(FValues[I]) = Length(AValue)) and (FValues[I] < AValue)) then
    begin
      Result[N] := FValues[I];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TChoiceStringGenerator.Name: string;
begin
  Result := 'GenChoiceString(' + IntToStr(Length(FValues)) + ' values)';
end;

function GenChoiceString(const AValues: array of string): IStringGenerator;
begin
  Result := TChoiceStringGenerator.Create(AValues);
end;

{ ── GenChoiceBool ─────────────────────────────────────────────────────────── }

type
  TChoiceBoolGenerator = class(TInterfacedObject, IBoolGenerator)
  private
    FValues: specialize TArray<Boolean>;
    FRng: TRandomGen;
  public
    constructor Create(const AValues: array of Boolean);
    destructor Destroy; override;
    function Generate: Boolean;
    function Shrink(const AValue: Boolean): specialize TArray<Boolean>;
    function Name: string;
  end;

constructor TChoiceBoolGenerator.Create(const AValues: array of Boolean);
var
  I: Integer;
begin
  inherited Create;
  if Length(AValues) = 0 then
    raise EAssertionFailed.Create('GenChoiceBool: empty values array');
  SetLength(FValues, Length(AValues));
  for I := 0 to High(AValues) do
    FValues[I] := AValues[I];
  FRng := TRandomGen.Create(0);
end;

destructor TChoiceBoolGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TChoiceBoolGenerator.Generate: Boolean;
begin
  Result := FValues[FRng.NextIntRange(0, Length(FValues) - 1)];
end;

function TChoiceBoolGenerator.Shrink(const AValue: Boolean): specialize TArray<Boolean>;
begin
  SetLength(Result, 1);
  Result[0] := False;
end;

function TChoiceBoolGenerator.Name: string;
begin
  Result := 'GenChoiceBool';
end;

function GenChoiceBool(const AValues: array of Boolean): IBoolGenerator;
begin
  Result := TChoiceBoolGenerator.Create(AValues);
end;

{ ── GenOneOfInt ───────────────────────────────────────────────────────────── }

type
  TOneOfIntGenerator = class(TInterfacedObject, IIntGenerator)
  private
    FGens: specialize TArray<IIntGenerator>;
    FRng: TRandomGen;
  public
    constructor Create(const AGens: array of IIntGenerator);
    destructor Destroy; override;
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

constructor TOneOfIntGenerator.Create(const AGens: array of IIntGenerator);
var
  I: Integer;
begin
  inherited Create;
  if Length(AGens) = 0 then
    raise EAssertionFailed.Create('GenOneOfInt: empty generator array');
  SetLength(FGens, Length(AGens));
  for I := 0 to High(AGens) do
    FGens[I] := AGens[I];
  FRng := TRandomGen.Create(0);
end;

destructor TOneOfIntGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TOneOfIntGenerator.Generate: Int64;
begin
  Result := FGens[FRng.NextIntRange(0, Length(FGens) - 1)].Generate;
end;

function TOneOfIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  LAll: specialize TArray<Int64>;
  I, J, N: Integer;
  LPart: specialize TArray<Int64>;
begin
  { Collect shrink candidates from all sub-generators }
  N := 0;
  SetLength(LAll, Length(FGens) * 4);
  for I := 0 to High(FGens) do
  begin
    LPart := FGens[I].Shrink(AValue);
    for J := 0 to High(LPart) do
    begin
      if N < Length(LAll) then
      begin
        LAll[N] := LPart[J];
        Inc(N);
      end;
    end;
  end;
  SetLength(LAll, N);
  Result := LAll;
end;

function TOneOfIntGenerator.Name: string;
begin
  Result := 'GenOneOfInt(' + IntToStr(Length(FGens)) + ' generators)';
end;

function GenOneOfInt(const AGens: array of IIntGenerator): IIntGenerator;
begin
  Result := TOneOfIntGenerator.Create(AGens);
end;

{ ── GenOneOfString ────────────────────────────────────────────────────────── }

type
  TOneOfStringGenerator = class(TInterfacedObject, IStringGenerator)
  private
    FGens: specialize TArray<IStringGenerator>;
    FRng: TRandomGen;
  public
    constructor Create(const AGens: array of IStringGenerator);
    destructor Destroy; override;
    function Generate: string;
    function Shrink(const AValue: string): specialize TArray<string>;
    function Name: string;
  end;

constructor TOneOfStringGenerator.Create(const AGens: array of IStringGenerator);
var
  I: Integer;
begin
  inherited Create;
  if Length(AGens) = 0 then
    raise EAssertionFailed.Create('GenOneOfString: empty generator array');
  SetLength(FGens, Length(AGens));
  for I := 0 to High(AGens) do
    FGens[I] := AGens[I];
  FRng := TRandomGen.Create(0);
end;

destructor TOneOfStringGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TOneOfStringGenerator.Generate: string;
begin
  Result := FGens[FRng.NextIntRange(0, Length(FGens) - 1)].Generate;
end;

function TOneOfStringGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  LAll: specialize TArray<string>;
  I, J, N: Integer;
  LPart: specialize TArray<string>;
begin
  N := 0;
  SetLength(LAll, Length(FGens) * 4);
  for I := 0 to High(FGens) do
  begin
    LPart := FGens[I].Shrink(AValue);
    for J := 0 to High(LPart) do
    begin
      if N < Length(LAll) then
      begin
        LAll[N] := LPart[J];
        Inc(N);
      end;
    end;
  end;
  SetLength(LAll, N);
  Result := LAll;
end;

function TOneOfStringGenerator.Name: string;
begin
  Result := 'GenOneOfString(' + IntToStr(Length(FGens)) + ' generators)';
end;

function GenOneOfString(const AGens: array of IStringGenerator): IStringGenerator;
begin
  Result := TOneOfStringGenerator.Create(AGens);
end;

{ ── Array Generator (v8.0a) ──────────────────────────────────────────────── }

type
  TArrayGenerator = class(TInterfacedObject, IArrayGenerator)
  private
    FGen: IIntGenerator;
    FMinLen, FMaxLen: Integer;
    FRng: TRandomGen;
  public
    constructor Create(AGen: IIntGenerator; AMinLen, AMaxLen: Integer);
    destructor Destroy; override;
    function Generate: specialize TArray<Int64>;
    function Shrink(const AValue: specialize TArray<Int64>): specialize TArray<specialize TArray<Int64>>;
    function Name: string;
  end;

constructor TArrayGenerator.Create(AGen: IIntGenerator; AMinLen, AMaxLen: Integer);
begin
  inherited Create;
  if AMinLen > AMaxLen then
    raise EAssertionFailed.Create('GenArray: AMinLen must be <= AMaxLen');
  FGen := AGen;
  FMinLen := AMinLen;
  FMaxLen := AMaxLen;
  FRng := TRandomGen.Create(0);
end;

destructor TArrayGenerator.Destroy;
begin
  FRng.Free;
  inherited;
end;

function TArrayGenerator.Generate: specialize TArray<Int64>;
var
  LLen, I: Integer;
begin
  LLen := FMinLen + FRng.NextIntRange(0, FMaxLen - FMinLen);
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I] := FGen.Generate;
end;

function TArrayGenerator.Shrink(const AValue: specialize TArray<Int64>): specialize TArray<specialize TArray<Int64>>;
var
  LLen, LHalf, I: Integer;
begin
  LLen := Length(AValue);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, 4);
  { Try empty array }
  SetLength(Result[0], 0);
  { Try half length }
  LHalf := LLen div 2;
  SetLength(Result[1], LHalf);
  for I := 0 to LHalf - 1 do
    Result[1][I] := AValue[I];
  { Try remove last element }
  SetLength(Result[2], LLen - 1);
  for I := 0 to LLen - 2 do
    Result[2][I] := AValue[I];
  { Try shrink each element }
  SetLength(Result[3], LLen);
  for I := 0 to LLen - 1 do
    Result[3][I] := AValue[I] div 2;
end;

function TArrayGenerator.Name: string;
begin
  Result := 'GenArray(' + FGen.Name + ', ' + IntToStr(FMinLen) + '..' + IntToStr(FMaxLen) + ')';
end;

function GenArray(AGen: IIntGenerator; AMaxLen: Integer): IArrayGenerator;
begin
  Result := TArrayGenerator.Create(AGen, 0, AMaxLen);
end;

function GenArray(AGen: IIntGenerator; AMinLen, AMaxLen: Integer): IArrayGenerator;
begin
  Result := TArrayGenerator.Create(AGen, AMinLen, AMaxLen);
end;

{ ── Tuple Generator (v8.0a) ──────────────────────────────────────────────── }

type
  TTupleGenerator = class(TInterfacedObject, ITupleGenerator)
  private
    FGen1: IIntGenerator;
    FGen2: IStringGenerator;
  public
    constructor Create(AGen1: IIntGenerator; AGen2: IStringGenerator);
    function GenerateInt: Int64;
    function GenerateString: string;
    function Name: string;
  end;

constructor TTupleGenerator.Create(AGen1: IIntGenerator; AGen2: IStringGenerator);
begin
  inherited Create;
  FGen1 := AGen1;
  FGen2 := AGen2;
end;

function TTupleGenerator.GenerateInt: Int64;
begin
  Result := FGen1.Generate;
end;

function TTupleGenerator.GenerateString: string;
begin
  Result := FGen2.Generate;
end;

function TTupleGenerator.Name: string;
begin
  Result := 'GenTuple(' + FGen1.Name + ', ' + FGen2.Name + ')';
end;

function GenTuple(AGen1: IIntGenerator; AGen2: IStringGenerator): ITupleGenerator;
begin
  Result := TTupleGenerator.Create(AGen1, AGen2);
end;

{ ── Bind/FlatMap Generator (v8.0a) ───────────────────────────────────────── }

type
  TBindIntGenerator = class(TInterfacedObject, IIntGenerator)
  private
    FGen: IIntGenerator;
    FFn: TIntToGenerator;
  public
    constructor Create(AGen: IIntGenerator; AFn: TIntToGenerator);
    function Generate: Int64;
    function Shrink(const AValue: Int64): specialize TArray<Int64>;
    function Name: string;
  end;

constructor TBindIntGenerator.Create(AGen: IIntGenerator; AFn: TIntToGenerator);
begin
  inherited Create;
  FGen := AGen;
  FFn := AFn;
end;

function TBindIntGenerator.Generate: Int64;
var
  LFirst: Int64;
  LSecond: IIntGenerator;
begin
  LFirst := FGen.Generate;
  LSecond := FFn(LFirst);
  Result := LSecond.Generate;
end;

function TBindIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
begin
  { Bind generators don't shrink directly — shrink the inner generator }
  SetLength(Result, 3);
  Result[0] := 0;
  Result[1] := AValue div 2;
  { Guard against Low(Int64) overflow }
  if AValue > Low(Int64) then
    Result[2] := AValue - 1
  else
    Result[2] := AValue + 1;
end;

function TBindIntGenerator.Name: string;
begin
  Result := 'BindInt(' + FGen.Name + ')';
end;

function BindInt(AGen: IIntGenerator; AFn: TIntToGenerator): IIntGenerator;
begin
  Result := TBindIntGenerator.Create(AGen, AFn);
end;

{ ── Shrinking helper ──────────────────────────────────────────────────────── }

function ShrinkString(AGen: IStringGenerator; const AFailed: string;
  ATest: TStringTest): string;
var
  LShrunk: specialize TArray<string>;
  I: Integer;
begin
  Result := AFailed;
  LShrunk := AGen.Shrink(AFailed);
  for I := 0 to High(LShrunk) do
  begin
    if LShrunk[I] = AFailed then
      Continue;
    try
      ATest(LShrunk[I]);
    except
      on E: EAssertionFailed do
      begin
        Result := ShrinkString(AGen, LShrunk[I], ATest);
        Exit;
      end;
    end;
  end;
end;

function ShrinkInt(AGen: IIntGenerator; const AFailed: Int64;
  ATest: TIntTest): Int64;
var
  LShrunk: specialize TArray<Int64>;
  I: Integer;
begin
  Result := AFailed;
  LShrunk := AGen.Shrink(AFailed);
  for I := 0 to High(LShrunk) do
  begin
    { Skip candidates equal to current value to prevent infinite recursion }
    if LShrunk[I] = AFailed then
      Continue;
    try
      ATest(LShrunk[I]);
    except
      on E: EAssertionFailed do
      begin
        Result := ShrinkInt(AGen, LShrunk[I], ATest);
        Exit;
      end;
    end;
  end;
end;

function ShrinkBool(AGen: IBoolGenerator; const AFailed: Boolean;
  ATest: TBoolTest): Boolean;
var
  LShrunk: specialize TArray<Boolean>;
  I: Integer;
begin
  Result := AFailed;
  LShrunk := AGen.Shrink(AFailed);
  for I := 0 to High(LShrunk) do
  begin
    if LShrunk[I] = AFailed then
      Continue;
    try
      ATest(LShrunk[I]);
    except
      on E: EAssertionFailed do
      begin
        Result := ShrinkBool(AGen, LShrunk[I], ATest);
        Exit;
      end;
    end;
  end;
end;

function ShrinkBytes(AGen: IBytesGenerator; const AFailed: TBytes;
  ATest: TBytesTest): TBytes;
var
  LShrunk: specialize TArray<TBytes>;
  I: Integer;

  function BytesEqual(const A, B: TBytes): Boolean;
  var J: Integer;
  begin
    if Length(A) <> Length(B) then Exit(False);
    for J := 0 to High(A) do
      if A[J] <> B[J] then Exit(False);
    Result := True;
  end;

begin
  Result := AFailed;
  LShrunk := AGen.Shrink(AFailed);
  for I := 0 to High(LShrunk) do
  begin
    if BytesEqual(LShrunk[I], AFailed) then
      Continue;
    try
      ATest(LShrunk[I]);
    except
      on E: EAssertionFailed do
      begin
        Result := ShrinkBytes(AGen, LShrunk[I], ATest);
        Exit;
      end;
    end;
  end;
end;

{ ── Internal raise helper ──────────────────────────────────────────────────── }

procedure PropFail(const AMsg: string);
begin
  raise EAssertionFailed.Create(AMsg);
end;

{ ── Property test execution ───────────────────────────────────────────────── }

procedure Prop(const AName: string; ATest: TStringTest;
  AGen: IStringGenerator; ARuns: Integer; AShrink: Boolean);
var
  I: Integer;
  LValue: string;
begin
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
          LValue := ShrinkString(AGen, LValue, ATest);
        FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
          ' runs with input: "' + LValue + '" (' + AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

procedure Prop(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer; AShrink: Boolean);
var
  I: Integer;
  LValue: Int64;
begin
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
          LValue := ShrinkInt(AGen, LValue, ATest);
        FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
          ' runs with input: ' + IntToStr(LValue) + ' (' + AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

procedure Prop(const AName: string; ATest: TBoolTest;
  AGen: IBoolGenerator; ARuns: Integer; AShrink: Boolean);
var
  I: Integer;
  LValue: Boolean;
begin
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
          LValue := ShrinkBool(AGen, LValue, ATest);
        if LValue then
          FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
            ' runs with input: True (' + AGen.Name + ')')
        else
          FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
            ' runs with input: False (' + AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

procedure Prop(const AName: string; ATest: TBytesTest;
  AGen: IBytesGenerator; ARuns: Integer; AShrink: Boolean);
var
  I: Integer;
  LValue: TBytes;
begin
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
          LValue := ShrinkBytes(AGen, LValue, ATest);
        FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
          ' runs with input: <' + IntToStr(Length(LValue)) + ' bytes> (' +
          AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

{ ── PropArray (v8.0a) ─────────────────────────────────────────────────────── }

procedure PropArray(const AName: string; ATest: TIntArrayTest;
  AGen: IArrayGenerator; ARuns: Integer; AShrink: Boolean);
var
  I, J: Integer;
  LValue: specialize TArray<Int64>;
  LShrunk: specialize TArray<specialize TArray<Int64>>;
  LFailed: Boolean;
begin
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
        begin
          { Try shrinking: first shorten array, then shrink elements }
          repeat
            LFailed := False;
            LShrunk := AGen.Shrink(LValue);
            for J := 0 to High(LShrunk) do
            begin
              { Skip if candidate is identical to current value }
              if Length(LShrunk[J]) = Length(LValue) then
              begin
                if (Length(LValue) = 0) or CompareMem(@LShrunk[J][0], @LValue[0], Length(LValue) * SizeOf(Int64)) then
                  Continue;
              end;
              try
                ATest(LShrunk[J]);
              except
                on E2: EAssertionFailed do
                begin
                  LValue := LShrunk[J];
                  LFailed := True;
                  Break;
                end;
              end;
            end;
          until not LFailed or (Length(LValue) = 0);
        end;
        FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
          ' runs with input: [' + IntToStr(Length(LValue)) + ' elements] (' +
          AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

{ ── PropTuple (v8.0a) ─────────────────────────────────────────────────────── }

procedure PropTuple(const AName: string; ATest: TTupleTest;
  AGen: ITupleGenerator; ARuns: Integer);
var
  I: Integer;
  LInt: Int64;
  LStr: string;
begin
  for I := 1 to ARuns do
  begin
    LInt := AGen.GenerateInt;
    LStr := AGen.GenerateString;
    try
      ATest(LInt, LStr);
    except
      on E: EAssertionFailed do
      begin
        FailTest('Property "' + AName + '" failed after ' + IntToStr(I) +
          ' runs with input: (' + IntToStr(LInt) + ', "' + LStr + '") (' +
          AGen.Name + ')');
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

{ ── PropWithResult ────────────────────────────────────────────────────────── }

function PropWithResult(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer; AShrink: Boolean): string;
var
  I: Integer;
  LValue: Int64;
begin
  Result := '';
  for I := 1 to ARuns do
  begin
    LValue := AGen.Generate;
    try
      ATest(LValue);
    except
      on E: EAssertionFailed do
      begin
        if AShrink then
          LValue := ShrinkInt(AGen, LValue, ATest);
        Result := IntToStr(LValue);
        Exit;
      end;
    end;
  end;
  PassTest('Property "' + AName + '" passed ' + IntToStr(ARuns) + ' runs');
end;

{ ── Mutation-based Fuzzing (v7.2a) ───────────────────────────────────────── }

var
  GFuzzRng: TRandomGen = nil;

function GetFuzzRng: TRandomGen;
begin
  if GFuzzRng = nil then
    GFuzzRng := TRandomGen.Create(0);
  Result := GFuzzRng;
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
  LRng := GetFuzzRng;
  LLen := Length(AData);

  { Empty input → insert a random byte }
  if LLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := Byte(LRng.NextIntRange(0, 255));
    Exit;
  end;

  LStrategy := LRng.NextIntRange(0, 99);
  LPos := LRng.NextIntRange(0, LLen - 1);

  if LStrategy < 40 then
  begin
    { Bit flip: flip 1-3 random bits in one byte }
    Result := Copy(AData);
    Result[LPos] := Result[LPos] xor Byte(1 shl LRng.NextIntRange(0, 7));
    if LRng.NextIntRange(0, 2) = 0 then
      Result[LPos] := Result[LPos] xor Byte(1 shl LRng.NextIntRange(0, 7));
  end
  else if LStrategy < 65 then
  begin
    { Byte replace: replace with random byte }
    Result := Copy(AData);
    Result[LPos] := Byte(LRng.NextIntRange(0, 255));
  end
  else if LStrategy < 80 then
  begin
    { Byte insert: insert random byte at position }
    SetLength(Result, LLen + 1);
    if LPos > 0 then
      Move(AData[0], Result[0], LPos);
    Result[LPos] := Byte(LRng.NextIntRange(0, 255));
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
      LBlockLen := 1 + LRng.NextIntRange(0, 15)
    else
      LBlockLen := 1 + LRng.NextIntRange(0, LLen - 1);
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
      LBlockLen := 1 + LRng.NextIntRange(0, 7)
    else
      LBlockLen := 1 + LRng.NextIntRange(0, LLen div 2);
    LPos2 := LRng.NextIntRange(0, LLen - LBlockLen);
    if LPos + LBlockLen <= LLen then
    begin
      { Swap bytes at LPos and LPos2 }
      for I := 0 to LBlockLen - 1 do
      begin
        LTmp := Result[LPos + I];
        Result[LPos + I] := Result[LPos2 + I];
        Result[LPos2 + I] := LTmp;
      end;
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
    LIdx := GetFuzzRng.NextIntRange(0, High(LCorpus));
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
  LRng: TRandomGen;
  I: Integer;
begin
  LRng := TRandomGen.Create(0);
  try
    SetLength(Result, ALen);
    for I := 0 to ALen - 1 do
      Result[I] := Byte(LRng.NextIntRange(0, 255));
  finally
    LRng.Free;
  end;
end;

function FuzzGenString(ALen: Integer): string;
var
  LRng: TRandomGen;
  I: Integer;
begin
  LRng := TRandomGen.Create(0);
  try
    SetLength(Result, ALen);
    for I := 1 to ALen do
      Result[I] := Char(32 + LRng.NextIntRange(0, 95));
  finally
    LRng.Free;
  end;
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
      LIdx := GetFuzzRng.NextIntRange(0, LCorpus.Count - 1);
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
    { Bitset for coverage points — supports up to 4096 coverage IDs }
    FCoverage: array[0..511] of Byte;  { 4096 bits }
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
  if (AId < 0) or (AId > 4095) then
    Exit;
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
    LIdx := GetFuzzRng.NextIntRange(0, LCorpusCount - 1);
    LValue := LCorpus[LIdx];

    { Mutate: apply generator shrink to get variants, or generate fresh }
    if GetFuzzRng.NextIntRange(0, 3) = 0 then
    begin
      { 25% chance: generate fresh value }
      LValue := AGen.Generate;
    end
    else
    begin
      { 75% chance: shrink existing value to get mutation }
      LShrunk := AGen.Shrink(LValue);
      if Length(LShrunk) > 0 then
        LValue := LShrunk[GetFuzzRng.NextIntRange(0, High(LShrunk))];
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
    LIdx := GetFuzzRng.NextIntRange(0, LCorpusCount - 1);
    LValue := LCorpus[LIdx];

    if GetFuzzRng.NextIntRange(0, 3) = 0 then
      LValue := AGen.Generate
    else
    begin
      LShrunk := AGen.Shrink(LValue);
      if Length(LShrunk) > 0 then
        LValue := LShrunk[GetFuzzRng.NextIntRange(0, High(LShrunk))];
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
  LRng := GetFuzzRng;
  LLen := Length(AData);

  if LLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := Byte(LRng.NextIntRange(0, 255));
    Exit;
  end;

  case AStrategy of
    fsBitFlip:
    begin
      { Pure bit flips: 1-3 bits }
      Result := Copy(AData);
      LPos := LRng.NextIntRange(0, LLen - 1);
      Result[LPos] := Result[LPos] xor Byte(1 shl LRng.NextIntRange(0, 7));
      if LRng.NextIntRange(0, 2) = 0 then
        Result[LPos] := Result[LPos] xor Byte(1 shl LRng.NextIntRange(0, 7));
    end;
    fsByteReplace:
    begin
      { Byte replacements: replace 1-4 bytes }
      Result := Copy(AData);
      for I := 1 to 1 + LRng.NextIntRange(0, 3) do
      begin
        LPos := LRng.NextIntRange(0, LLen - 1);
        Result[LPos] := Byte(LRng.NextIntRange(0, 255));
      end;
    end;
    fsHavoc:
    begin
      { Heavy mutations: insert, delete, dup, swap }
      case LRng.NextIntRange(0, 3) of
        0: begin { Insert }
          LPos := LRng.NextIntRange(0, LLen);
          SetLength(Result, LLen + 1);
          if LPos > 0 then
            Move(AData[0], Result[0], LPos);
          Result[LPos] := Byte(LRng.NextIntRange(0, 255));
          if LPos < LLen then
            Move(AData[LPos], Result[LPos + 1], LLen - LPos);
        end;
        1: begin { Delete }
          if LLen <= 1 then
          begin
            Result := Copy(AData);
            Exit;
          end;
          LPos := LRng.NextIntRange(0, LLen - 1);
          SetLength(Result, LLen - 1);
          if LPos > 0 then
            Move(AData[0], Result[0], LPos);
          if LPos < LLen - 1 then
            Move(AData[LPos + 1], Result[LPos], LLen - 1 - LPos);
        end;
        2: begin { Block duplicate }
          if 7 < LLen then
            LBlockLen := 1 + LRng.NextIntRange(0, 7)
          else
            LBlockLen := 1 + LRng.NextIntRange(0, LLen - 1);
          LPos := LRng.NextIntRange(0, LLen - 1);
          if LPos + LBlockLen > LLen then
            LBlockLen := LLen - LPos;
          SetLength(Result, LLen + LBlockLen);
          Move(AData[0], Result[0], LLen);
          Move(AData[LPos], Result[LLen], LBlockLen);
        end;
        3: begin { Block swap }
          Result := Copy(AData);
          if 3 < LLen div 2 then
            LBlockLen := 1 + LRng.NextIntRange(0, 3)
          else
            LBlockLen := 1 + LRng.NextIntRange(0, LLen div 2);
          if LLen - LBlockLen < 0 then
            LBlockLen := LLen;
          LPos := LRng.NextIntRange(0, LLen - LBlockLen);
          LPos2 := LRng.NextIntRange(0, LLen - LBlockLen);
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

procedure FuzzParallel(const AName: string; ATest: TFuzzBytesTest;
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
    FailTest('FuzzParallel "' + AName + '": corpus is empty');
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
      LIdx := GetFuzzRng.NextIntRange(0, LCorpusCount - 1);
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
          FailTest('FuzzParallel "' + AName + '" worker ' + IntToStr(W) +
            ' (' + IntToStr(Ord(LStrategy)) + ') found failure after ' +
            IntToStr(J) + ' iterations, minimal input (' +
            IntToStr(Length(LMin)) + ' bytes): ' + LHex);
          Exit;
        end;
      end;
    end;
  end;

  PassTest('FuzzParallel "' + AName + '" passed ' +
    IntToStr(AWorkers * AIterationsPerWorker) + ' iterations (' +
    IntToStr(AWorkers) + ' workers), 0 failures, corpus: ' +
    IntToStr(LCorpusCount) + ' items, coverage: ' +
    IntToStr(LTracker.CoverageCount) + ' points');
end;

finalization
  FreeAndNil(GFuzzRng);

end.
