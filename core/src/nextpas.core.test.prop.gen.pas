{ nextpas.core.test.prop.gen — Property-test Generators (v8.32)
  =============================================================
  Generator interfaces, factories, and combinators for property-based
  testing. Split from nextpas.core.test.prop (F-03): this unit owns the
  value-generation vocabulary; nextpas.core.test.prop owns Prop execution;
  nextpas.core.test.fuzz owns mutation-based fuzzing.

  Each generator holds its own deterministic TRandomGen (Init(0)) — no
  global RNG state, safe to construct per test. }

unit nextpas.core.test.prop.gen;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.base;

type
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
  IArrayGenerator = interface
    function Generate: specialize TArray<Int64>;
    function Shrink(const AValue: specialize TArray<Int64>): specialize TArray<specialize TArray<Int64>>;
    function Name: string;
  end;

  { Tuple (Int64, String) generator }
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

implementation

uses
  nextpas.core.text.conv,
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
  { P2 fix: reject negative lengths — allocation APIs don't accept negative sizes }
  if AMinLen < 0 then
    raise EAssertionFailed.Create('GenString: AMinLen must be >= 0');
  if AMaxLen < 0 then
    raise EAssertionFailed.Create('GenString: AMaxLen must be >= 0');
  if AMinLen > AMaxLen then
    raise EAssertionFailed.Create('GenString: AMinLen must be <= AMaxLen');
  FMinLen := AMinLen;
  FMaxLen := AMaxLen;
  FRng := TRandomGen.Init(0);
end;

destructor TStringGenerator.Destroy;
begin
  { TRandomGen is a pure stack-only record (2x UInt64) — no heap resources to free }
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
  LLen, LCount: Integer;
begin
  LLen := Length(AValue);

  { P2 #13 fix: domain check — if length out of [FMinLen, FMaxLen], shrink toward range }
  if (LLen < FMinLen) or (LLen > FMaxLen) then
  begin
    Result := nil;
    SetLength(Result, 1);
    if LLen < FMinLen then
      Result[0] := StringOfChar('a', FMinLen)
    else
      Result[0] := Copy(AValue, 1, FMaxLen);
    Exit;
  end;

  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LCount := 0;
  SetLength(Result, 8);

  { Try empty (only if FMinLen = 0) }
  if FMinLen = 0 then
  begin
    Result[LCount] := '';
    Inc(LCount);
  end;

  { Try half (check min length) }
  if LLen div 2 >= FMinLen then
  begin
    Result[LCount] := Copy(AValue, 1, LLen div 2);
    Inc(LCount);
  end;

  { Try remove last char (check min length) }
  if (LLen - 1 >= FMinLen) then
  begin
    Result[LCount] := Copy(AValue, 1, LLen - 1);
    Inc(LCount);
  end;

  { Try replace all chars with 'a' (same length, always in domain) }
  Result[LCount] := StringOfChar('a', LLen);
  Inc(LCount);

  { Try remove first char (check min length) }
  if (LLen > 1) and (LLen - 1 >= FMinLen) then
  begin
    Result[LCount] := Copy(AValue, 2, LLen - 1);
    Inc(LCount);
  end;

  { Try remove middle char (check min length) }
  if (LLen > 2) and (LLen - 1 >= FMinLen) then
  begin
    Result[LCount] := Copy(AValue, 1, LLen div 2) + Copy(AValue, LLen div 2 + 2, LLen);
    Inc(LCount);
  end;

  { Try shorter lengths (check min length) }
  if (LLen > 3) and (LLen - 1 >= FMinLen) then
  begin
    Result[LCount] := StringOfChar('a', LLen - 1);
    Inc(LCount);
  end;

  if (LLen > 5) and (LLen div 2 >= FMinLen) then
  begin
    Result[LCount] := StringOfChar('a', LLen div 2);
    Inc(LCount);
  end;

  SetLength(Result, LCount);
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
  FRng := TRandomGen.Init(0);
end;

destructor TIntGenerator.Destroy;
begin
  { TRandomGen is a pure stack-only record (2x UInt64) — no heap resources to free }
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
    { P2 fix: handle full Int64 range without overflow.
      When FMin=Low(Int64) and FMax=High(Int64), FMax-FMin overflows.
      Use modular arithmetic on the full 64-bit random value. }
    if (FMin = Low(Int64)) and (FMax = High(Int64)) then
    begin
      LHi := UInt64(FRng.NextIntRange(0, MaxInt));
      LLo := UInt64(FRng.NextIntRange(0, MaxInt));
      Result := Int64((LHi shl 32) or LLo);
    end
    else
    begin
      LRange := UInt64(FMax - FMin) + 1;
      { Build 64-bit random from two 32-bit halves }
      LHi := UInt64(FRng.NextIntRange(0, MaxInt));
      LLo := UInt64(FRng.NextIntRange(0, MaxInt));
      Result := FMin + Int64(((LHi shl 32) or LLo) mod LRange);
    end;
  end;
end;

function TIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  LTarget, LMid, LQuarter: Int64;
  LCount: Integer;
begin
  { P2 #13 fix: domain check — if AValue is out of [FMin, FMax], shrink toward range }
  if (AValue < FMin) or (AValue > FMax) then
  begin
    Result := nil;
    SetLength(Result, 1);
    if AValue < FMin then
      Result[0] := FMin
    else
      Result[0] := FMax;
    Exit;
  end;

  { Shrink toward the "simplest" value: FMin if positive, 0 otherwise }
  if FMin > 0 then
    LTarget := FMin
  else if FMax < 0 then
    LTarget := FMax
  else
    LTarget := 0;

  { P2 #13 fix: clamp target to [FMin, FMax] }
  if LTarget < FMin then LTarget := FMin;
  if LTarget > FMax then LTarget := FMax;

  { P2 #13 fix: avoid cycle — if AValue already equals target, no useful shrink }
  if AValue = LTarget then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LCount := 0;
  SetLength(Result, 4);

  { Try simplest value (in domain) }
  Result[LCount] := LTarget;
  Inc(LCount);

  { Try halfway between current and simplest }
  LMid := LTarget + (AValue - LTarget) div 2;
  if (LMid >= FMin) and (LMid <= FMax) and (LMid <> AValue) then
  begin
    Result[LCount] := LMid;
    Inc(LCount);
  end;

  { Try one step toward simplest (in domain) }
  if AValue > LTarget then
  begin
    if AValue - 1 >= FMin then
    begin
      Result[LCount] := AValue - 1;
      Inc(LCount);
    end;
  end
  else
  begin
    if AValue + 1 <= FMax then
    begin
      Result[LCount] := AValue + 1;
      Inc(LCount);
    end;
  end;

  { Try halfway between simplest and midpoint (faster convergence) }
  LQuarter := LTarget + (AValue - LTarget) div 4;
  if (LQuarter >= FMin) and (LQuarter <= FMax) and (LQuarter <> AValue) and
     (LQuarter <> LMid) then
  begin
    Result[LCount] := LQuarter;
    Inc(LCount);
  end;

  SetLength(Result, LCount);
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
  FRng := TRandomGen.Init(0);
end;

destructor TBoolGenerator.Destroy;
begin
  { TRandomGen is a pure stack-only record (2x UInt64) — no heap resources to free }
  inherited;
end;

function TBoolGenerator.Generate: Boolean;
begin
  Result := FRng.NextBool;
end;

function TBoolGenerator.Shrink(const AValue: Boolean): specialize TArray<Boolean>;
begin
  Result := nil;
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
  { P2 fix: reject negative lengths — allocation APIs don't accept negative sizes }
  if AMinLen < 0 then
    raise EAssertionFailed.Create('GenBytes: AMinLen must be >= 0');
  if AMaxLen < 0 then
    raise EAssertionFailed.Create('GenBytes: AMaxLen must be >= 0');
  if AMinLen > AMaxLen then
    raise EAssertionFailed.Create('GenBytes: AMinLen must be <= AMaxLen');
  FMinLen := AMinLen;
  FMaxLen := AMaxLen;
  FRng := TRandomGen.Init(0);
end;

destructor TBytesGenerator.Destroy;
begin
  { TRandomGen is a pure stack-only record (2x UInt64) — no heap resources to free }
  inherited;
end;

function TBytesGenerator.Generate: TBytes;
var
  LLen, I: Integer;
begin
  LLen := FMinLen + FRng.NextIntRange(0, FMaxLen - FMinLen);
  Result := nil;
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I] := Byte(FRng.NextIntRange(0, 255));
end;

function TBytesGenerator.Shrink(const AValue: TBytes): specialize TArray<TBytes>;
var
  LLen, LCount: Integer;
begin
  LLen := Length(AValue);

  { P2 #13 fix: domain check — if length out of [FMinLen, FMaxLen], shrink toward range }
  if (LLen < FMinLen) or (LLen > FMaxLen) then
  begin
    Result := nil;
    SetLength(Result, 1);
    if LLen < FMinLen then
    begin
      SetLength(Result[0], FMinLen);
      FillChar(Result[0][0], FMinLen, 0);
    end
    else
    begin
      SetLength(Result[0], FMaxLen);
      Move(AValue[0], Result[0][0], FMaxLen);
    end;
    Exit;
  end;

  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LCount := 0;
  SetLength(Result, 3);

  { Try empty (only if FMinLen = 0) }
  if FMinLen = 0 then
  begin
    SetLength(Result[LCount], 0);
    Inc(LCount);
  end;

  { Try half (check min length) }
  if LLen div 2 >= FMinLen then
  begin
    SetLength(Result[LCount], LLen div 2);
    Move(AValue[0], Result[LCount][0], LLen div 2);
    Inc(LCount);
  end;

  { Try remove last byte (check min length) }
  if (LLen > 1) and (LLen - 1 >= FMinLen) then
  begin
    SetLength(Result[LCount], LLen - 1);
    Move(AValue[0], Result[LCount][0], LLen - 1);
    Inc(LCount);
  end;

  SetLength(Result, LCount);
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
  LCode: Integer;
  I, N: Integer;
begin
  { R4-09: reverse-map via Val; if the string isn't numeric, Shrink is a no-op.
    This is an inherent limitation of MapIntToStr — the mapping is one-way.
    Only numeric string mappings (IntToStr-compatible) support shrinking. }
  Val(AValue, LParsed, LCode);
  if LCode <> 0 then
  begin
    Result := nil;
    SetLength(Result, 0);
    Exit;
  end;
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
  { R4-07: fail explicitly instead of returning a value that violates the predicate }
  raise EAssertionFailed.Create(
    'FilterInt: no matching value after ' + IntToStr(FMaxRetries) + ' retries');
end;

function TFilterIntGenerator.Shrink(const AValue: Int64): specialize TArray<Int64>;
var
  LShrunk: specialize TArray<Int64>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  Result := nil;
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
  { R4-07: fail explicitly instead of returning a value that violates the predicate }
  raise EAssertionFailed.Create(
    'FilterString: no matching value after ' + IntToStr(FMaxRetries) + ' retries');
end;

function TFilterStringGenerator.Shrink(const AValue: string): specialize TArray<string>;
var
  LShrunk: specialize TArray<string>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  Result := nil;
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
  { R4-07: fail explicitly instead of returning a value that violates the predicate }
  raise EAssertionFailed.Create(
    'FilterBytes: no matching value after ' + IntToStr(FMaxRetries) + ' retries');
end;

function TFilterBytesGenerator.Shrink(const AValue: TBytes): specialize TArray<TBytes>;
var
  LShrunk: specialize TArray<TBytes>;
  I, N: Integer;
begin
  LShrunk := FSource.Shrink(AValue);
  N := 0;
  Result := nil;
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
  FRng := TRandomGen.Init(0);
end;

destructor TChoiceIntGenerator.Destroy;
begin
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
  Result := nil;
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
  FRng := TRandomGen.Init(0);
end;

destructor TChoiceStringGenerator.Destroy;
begin
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
  Result := nil;
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
  FRng := TRandomGen.Init(0);
end;

destructor TChoiceBoolGenerator.Destroy;
begin
  inherited;
end;

function TChoiceBoolGenerator.Generate: Boolean;
begin
  Result := FValues[FRng.NextIntRange(0, Length(FValues) - 1)];
end;

function TChoiceBoolGenerator.Shrink(const AValue: Boolean): specialize TArray<Boolean>;
begin
  Result := nil;
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
  FRng := TRandomGen.Init(0);
end;

destructor TOneOfIntGenerator.Destroy;
begin
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
  FRng := TRandomGen.Init(0);
end;

destructor TOneOfStringGenerator.Destroy;
begin
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
  FRng := TRandomGen.Init(0);
end;

destructor TArrayGenerator.Destroy;
begin
  inherited;
end;

function TArrayGenerator.Generate: specialize TArray<Int64>;
var
  LLen, I: Integer;
begin
  LLen := FMinLen + FRng.NextIntRange(0, FMaxLen - FMinLen);
  Result := nil;
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
    Result := nil;
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
  Result := nil;
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

end.
