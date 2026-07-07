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

implementation

uses
  nextpas.core.math.random;

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
  SetLength(Result, 3);
  { Try empty }
  Result[0] := '';
  { Try half }
  Result[1] := Copy(AValue, 1, LLen div 2);
  { Try remove last char }
  Result[2] := Copy(AValue, 1, LLen - 1);
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
begin
  if FMin = FMax then
    Result := FMin
  else
    Result := FMin + Int64(FRng.NextIntRange(0, Integer(FMax - FMin)));
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
      on E: Exception do
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
      on E: Exception do
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
      on E: Exception do
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
      on E: Exception do
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
        LHex := '';
        for J := 0 to High(LMin) do
        begin
          if J > 0 then
            LHex := LHex + ' ';
          LHex := LHex + IntToHex(LMin[J], 2);
        end;
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

finalization
  FreeAndNil(GFuzzRng);

end.
