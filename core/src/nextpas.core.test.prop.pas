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

{ ── Generator combinators ──────────────────────────────────────────────────── }

{ Map: transform Int64 generator output to string }
function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;

{ Filter: reject Int64 values not matching predicate }
function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;

{ Filter: reject string values not matching predicate }
function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;

{ Filter: reject TBytes values not matching predicate }
function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;

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
begin
  SetLength(Result, 3);
  { Try zero }
  Result[0] := 0;
  { Try half toward zero }
  Result[1] := AValue div 2;
  { Try one less }
  Result[2] := AValue - 1;
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
    try
      ATest(LShrunk[I]);
    except
      on E: Exception do
      begin
        { This smaller input also fails — recurse }
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
begin
  Result := AFailed;
  LShrunk := AGen.Shrink(AFailed);
  for I := 0 to High(LShrunk) do
  begin
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
      on E: Exception do
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
      on E: Exception do
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
      on E: Exception do
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
      on E: Exception do
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

end.
