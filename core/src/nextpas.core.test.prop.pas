{ nextpas.core.test.prop — Property-based Testing (v8.32)
  =========================================================
  QuickCheck-style property execution with automatic shrinking on failure.
  Split per F-03: generators live in nextpas.core.test.prop.gen; fuzzing
  lives in nextpas.core.test.fuzz. This unit owns Prop registration and
  the shrink-execution loop.

  Usage:
    procedure TestRoundtrip(const S: string);
    begin
      CheckEqual(S, JsonDecode(JsonEncode(S)));
    end;

    Prop('JSON roundtrip', @TestRoundtrip, GenString(1000), 1000, True); }

unit nextpas.core.test.prop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.base,
  nextpas.core.test.prop.gen;

type
  { ── Test procedure types ─────────────────────────────────────────────────── }
  TStringTest = reference to procedure(const V: string);
  TIntTest = reference to procedure(const V: Int64);
  TBoolTest = reference to procedure(const V: Boolean);
  TBytesTest = reference to procedure(const V: TBytes);
  TIntArrayTest = reference to procedure(const V: array of Int64);
  TTupleTest = reference to procedure(AInt: Int64; const AStr: string);

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

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.test.output;

{ ── Shrinking helper ──────────────────────────────────────────────────────── }

{ P2 #7: forward declarations for depth-limited shrink helpers }
function ShrinkStringDepth(AGen: IStringGenerator; const AFailed: string;
  ATest: TStringTest; ADepth: Integer): string; forward;
function ShrinkIntDepth(AGen: IIntGenerator; const AFailed: Int64;
  ATest: TIntTest; ADepth: Integer): Int64; forward;
function ShrinkBoolDepth(AGen: IBoolGenerator; const AFailed: Boolean;
  ATest: TBoolTest; ADepth: Integer): Boolean; forward;
function ShrinkBytesDepth(AGen: IBytesGenerator; const AFailed: TBytes;
  ATest: TBytesTest; ADepth: Integer): TBytes; forward;

function ShrinkString(AGen: IStringGenerator; const AFailed: string;
  ATest: TStringTest): string;
begin
  Result := ShrinkStringDepth(AGen, AFailed, ATest, 0);
end;

function ShrinkStringDepth(AGen: IStringGenerator; const AFailed: string;
  ATest: TStringTest; ADepth: Integer): string;
var
  LShrunk: specialize TArray<string>;
  I: Integer;
begin
  Result := AFailed;
  { P2 #7: guard against infinite shrink loops by capping iteration depth }
  if ADepth > 100 then
    Exit;
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
        Result := ShrinkStringDepth(AGen, LShrunk[I], ATest, ADepth + 1);
        Exit;
      end;
    end;
  end;
end;

function ShrinkInt(AGen: IIntGenerator; const AFailed: Int64;
  ATest: TIntTest): Int64;
begin
  Result := ShrinkIntDepth(AGen, AFailed, ATest, 0);
end;

function ShrinkIntDepth(AGen: IIntGenerator; const AFailed: Int64;
  ATest: TIntTest; ADepth: Integer): Int64;
var
  LShrunk: specialize TArray<Int64>;
  I: Integer;
begin
  Result := AFailed;
  { P2 #7: guard against infinite shrink loops }
  if ADepth > 100 then
    Exit;
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
        Result := ShrinkIntDepth(AGen, LShrunk[I], ATest, ADepth + 1);
        Exit;
      end;
    end;
  end;
end;

function ShrinkBool(AGen: IBoolGenerator; const AFailed: Boolean;
  ATest: TBoolTest): Boolean;
begin
  Result := ShrinkBoolDepth(AGen, AFailed, ATest, 0);
end;

function ShrinkBoolDepth(AGen: IBoolGenerator; const AFailed: Boolean;
  ATest: TBoolTest; ADepth: Integer): Boolean;
var
  LShrunk: specialize TArray<Boolean>;
  I: Integer;
begin
  Result := AFailed;
  { P2 #7: guard against infinite shrink loops }
  if ADepth > 100 then
    Exit;
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
        Result := ShrinkBoolDepth(AGen, LShrunk[I], ATest, ADepth + 1);
        Exit;
      end;
    end;
  end;
end;

function ShrinkBytes(AGen: IBytesGenerator; const AFailed: TBytes;
  ATest: TBytesTest): TBytes;
begin
  Result := ShrinkBytesDepth(AGen, AFailed, ATest, 0);
end;

function ShrinkBytesDepth(AGen: IBytesGenerator; const AFailed: TBytes;
  ATest: TBytesTest; ADepth: Integer): TBytes;
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
  { P2 #7: guard against infinite shrink loops }
  if ADepth > 100 then
    Exit;
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
        Result := ShrinkBytesDepth(AGen, LShrunk[I], ATest, ADepth + 1);
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

end.
