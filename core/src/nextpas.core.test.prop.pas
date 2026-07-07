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

end.
