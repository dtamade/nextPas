program test_toml_parser;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  TOML_PARSER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.toml.parser.pas';
  TOML_PARSER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.toml.parser.pas';

type
  TFailingReallocateAllocator = class(TInterfacedObject, IAllocator)
  private
    FFailOnReallocateCall: SizeUInt;
    FReallocateCalls: SizeUInt;
  public
    constructor Create(const AFailOnReallocateCall: SizeUInt);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

  TFailingAllocateAllocator = class(TInterfacedObject, IAllocator)
  private
    FFailOnAllocateCall: SizeUInt;
    FAllocateCalls: SizeUInt;
  public
    constructor Create(const AFailOnAllocateCall: SizeUInt);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

constructor TFailingReallocateAllocator.Create(
  const AFailOnReallocateCall: SizeUInt);
begin
  inherited Create;
  FFailOnReallocateCall := AFailOnReallocateCall;
  FReallocateCalls := 0;
end;

function TFailingReallocateAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.GetMem(aSize);
end;

function TFailingReallocateAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.AllocMem(aSize);
end;

function TFailingReallocateAllocator.ReallocMem(aDst: Pointer;
  aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Inc(FReallocateCalls);
  if (FFailOnReallocateCall > 0) and
    (FReallocateCalls = FFailOnReallocateCall) then
    Exit(nil);
  Result := System.ReallocMem(aDst, aSize);
end;

procedure TFailingReallocateAllocator.FreeMem(aDst: Pointer);
begin
  if aDst <> nil then
    System.FreeMem(aDst);
end;

function TFailingReallocateAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFailingReallocateAllocator.AllocAligned(aSize,
  aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TFailingReallocateAllocator.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TFailingReallocateAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

constructor TFailingAllocateAllocator.Create(
  const AFailOnAllocateCall: SizeUInt);
begin
  inherited Create;
  FFailOnAllocateCall := AFailOnAllocateCall;
  FAllocateCalls := 0;
end;

function TFailingAllocateAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Inc(FAllocateCalls);
  if (FFailOnAllocateCall > 0) and (FAllocateCalls = FFailOnAllocateCall) then
    Exit(nil);
  Result := System.GetMem(aSize);
end;

function TFailingAllocateAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Inc(FAllocateCalls);
  if (FFailOnAllocateCall > 0) and (FAllocateCalls = FFailOnAllocateCall) then
    Exit(nil);
  Result := System.AllocMem(aSize);
end;

function TFailingAllocateAllocator.ReallocMem(aDst: Pointer;
  aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Result := System.ReallocMem(aDst, aSize);
end;

procedure TFailingAllocateAllocator.FreeMem(aDst: Pointer);
begin
  if aDst <> nil then
    System.FreeMem(aDst);
end;

function TFailingAllocateAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFailingAllocateAllocator.AllocAligned(aSize,
  aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TFailingAllocateAllocator.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TFailingAllocateAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

function ReadSourceFile(const APath: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(APath);
    Result := LowerCase(LText.Text);
  finally
    LText.Free;
  end;
end;

function ResolveSourcePath(const APathFromTest: string;
  const APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(LowerCase(ANeedle), ASource) > 0, AMessage);
end;

function MustParse(const AToml: string): TTomlDocument;
begin
  Result.Init(DefaultAllocator);
  if not Result.Parse(TStringView.FromStr(AToml)) then
  begin
    WriteLn('  Parse error: ', Result.Error.Message.ToString,
      ' at line ', Result.Error.Line, ' col ', Result.Error.Col);
    Result.Done;
    Fail('parse failed');
  end;
end;

function MustReject(const AToml: string): Boolean;
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  Result := not LDoc.Parse(TStringView.FromStr(AToml));
  LDoc.Done;
end;

function DottedPath(const ACount: Int32): string;
var
  LI: Int32;
begin
  Result := '';
  for LI := 1 to ACount do
  begin
    if LI > 1 then
      Result := Result + '.';
    Result := Result + 'k' + IntToStr(LI);
  end;
end;

procedure CheckRejectsWithMessage(const AToml, AExpectedMessage,
  ACaseName: string);
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  try
    Check(not LDoc.Parse(TStringView.FromStr(AToml)),
      ACaseName + ' rejected');
    CheckEqual(AExpectedMessage, LDoc.Error.Message.ToString,
      ACaseName + ' diagnostic');
  finally
    LDoc.Done;
  end;
end;

procedure CheckRejectsAt(const AToml, AExpectedMessage, ACaseName: string;
  AExpectedOffset, AExpectedLine, AExpectedCol: Int64);
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  try
    Check(not LDoc.Parse(TStringView.FromStr(AToml)),
      ACaseName + ' rejected');
    CheckEqual(AExpectedMessage, LDoc.Error.Message.ToString,
      ACaseName + ' diagnostic');
    CheckEqual(AExpectedOffset, Int64(LDoc.Error.Offset),
      ACaseName + ' error offset');
    CheckEqual(AExpectedLine, Int64(LDoc.Error.Line),
      ACaseName + ' error line');
    CheckEqual(AExpectedCol, Int64(LDoc.Error.Col),
      ACaseName + ' error column');
  finally
    LDoc.Done;
  end;
end;

procedure TestEmptyInput;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('');
  Check(LDoc.Root <> TOML_NODE_NONE, 'root exists');
  Check(LDoc.Node(LDoc.Root)^.Kind = tnkTable, 'root is table');
  CheckEqual(Int64(0), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'empty');
  LDoc.Done;
end;

procedure TestCommentsOnly;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('# this is a comment' + #10 + '# another comment' + #10);
  CheckEqual(Int64(0), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'empty');
  LDoc.Done;
end;

procedure TestCommentControlCharacters;
var
  LDoc: TTomlDocument;
begin
  CheckRejectsAt('key = 1 # bad ' + #1 + #10,
    'control char in comment', 'inline comment raw C0', 14, 1, 15);
  CheckRejectsAt('# bad ' + #27 + #10,
    'control char in comment', 'standalone comment raw C0', 6, 1, 7);

  LDoc := MustParse('# tab' + #9 + 'comment' + #13#10 + 'key = 1 # ok');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count),
    'tab and CRLF comments accepted');
  LDoc.Done;
end;

procedure TestSimpleString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('name = "Alice"');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'one entry');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LChild <> TOML_NODE_NONE, 'child exists');
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Key.Equals(TStringView.Create(PAnsiChar('name'), 4)), 'key = name');
  Check(LDoc.Node(LChild)^.Str.Equals(TStringView.Create(PAnsiChar('Alice'), 5)), 'val = Alice');
  LDoc.Done;
end;

procedure TestSimpleInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('port = 8080');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(8080), LDoc.Node(LChild)^.IntVal, 'val = 8080');
  LDoc.Done;
end;

procedure TestNegativeInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('offset = -7');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(-7), LDoc.Node(LChild)^.IntVal, 'val = -7');
  LDoc.Done;
end;

procedure TestHexInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('color = 0xff0000');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64($FF0000), LDoc.Node(LChild)^.IntVal, 'val = 0xff0000');
  LDoc.Done;
end;

procedure TestOctInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('perm = 0o755');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(493), LDoc.Node(LChild)^.IntVal, 'val = 0o755 = 493');
  LDoc.Done;
end;

procedure TestBinInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('flags = 0b11010110');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(214), LDoc.Node(LChild)^.IntVal, 'val = 0b11010110 = 214');
  LDoc.Done;
end;

procedure TestIntegerWithUnderscores;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('big = 1_000_000');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(1000000), LDoc.Node(LChild)^.IntVal, 'val = 1000000');
  LDoc.Done;
end;

procedure TestFloat;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('pi = 3.14159');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(Abs(LDoc.Node(LChild)^.FloatVal - 3.14159) < 1e-10, 'val ~ 3.14159');
  LDoc.Done;
end;

procedure TestFloatExponent;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('sci = 5e+22');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal > 4.9e22, 'val ~ 5e22');
  LDoc.Done;
end;

procedure TestFloatInf;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('x = inf');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal = 1.0/0.0, 'val = +inf');
  LDoc.Done;
end;

procedure TestFloatNegInf;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('x = -inf');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal = -1.0/0.0, 'val = -inf');
  LDoc.Done;
end;

procedure TestFloatNan;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LBits: QWord;
begin
  LDoc := MustParse('x = nan');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Move(LDoc.Node(LChild)^.FloatVal, LBits, 8);
  Check((LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000), 'exponent all 1s');
  Check((LBits and QWord($000FFFFFFFFFFFFF)) <> 0, 'mantissa non-zero (NaN)');
  LDoc.Done;
end;

procedure TestBoolTrue;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('enabled = true');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkBool, 'is bool');
  Check(LDoc.Node(LChild)^.BoolVal = True, 'val = true');
  LDoc.Done;
end;

procedure TestBoolFalse;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('debug = false');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkBool, 'is bool');
  Check(LDoc.Node(LChild)^.BoolVal = False, 'val = false');
  LDoc.Done;
end;

procedure TestMultipleKeys;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('a = 1' + #10 + 'b = 2' + #10 + 'c = 3');
  CheckEqual(Int64(3), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '3 entries');
  LDoc.Done;
end;

procedure TestTable;
var
  LDoc: TTomlDocument;
  LChild, LSubChild: UInt32;
begin
  LDoc := MustParse('[server]' + #10 + 'host = "localhost"' + #10 + 'port = 8080');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 table');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkTable, 'is table');
  Check(LDoc.Node(LChild)^.Key.Equals(TStringView.Create(PAnsiChar('server'), 6)), 'key = server');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 entries in table');
  LSubChild := LDoc.Node(LChild)^.Container.FirstChild;
  Check(LDoc.Node(LSubChild)^.Kind = tnkString, 'host is string');
  LDoc.Done;
end;

procedure TestNestedTable;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('[a.b.c]' + #10 + 'key = "deep"');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 top-level');
  LDoc.Done;
end;

procedure TestDottedKey;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('a.b.c = "value"');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 top-level (a)');
  LDoc.Done;
end;

procedure TestDottedKeyPathDepthBoundary;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse(DottedPath(128) + ' = 1');
  Check(not LDoc.HasError, '128-segment dotted key accepted');
  LDoc.Done;

  CheckRejectsWithMessage(DottedPath(129) + ' = 1',
    'key too deeply nested', '129-segment dotted key');
end;

procedure TestTablePathDepthBoundary;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('[' + DottedPath(128) + ']' + #10 + 'value = 1');
  Check(not LDoc.HasError, '128-segment table path accepted');
  LDoc.Done;

  CheckRejectsWithMessage('[' + DottedPath(129) + ']' + #10 + 'value = 1',
    'key too deeply nested', '129-segment table path');
end;

procedure TestArrayTablePathDepthBoundary;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('[[' + DottedPath(128) + ']]' + #10 + 'value = 1');
  Check(not LDoc.HasError, '128-segment array-table path accepted');
  LDoc.Done;

  CheckRejectsWithMessage('[[' + DottedPath(129) + ']]' + #10 + 'value = 1',
    'key too deeply nested', '129-segment array-table path');
end;

procedure TestArray;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('nums = [1, 2, 3]');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(3), Int64(LDoc.Node(LChild)^.Container.Count), '3 elements');
  LDoc.Done;
end;

procedure TestInlineTable;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('point = {x = 1, y = 2}');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkTable, 'is table');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 entries');
  LDoc.Done;
end;

procedure TestInlineTableDottedKeyPathDepthBoundary;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('root = { ' + DottedPath(128) + ' = 1 }');
  Check(not LDoc.HasError, '128-segment inline table dotted key accepted');
  LDoc.Done;

  CheckRejectsWithMessage('root = { ' + DottedPath(129) + ' = 1 }',
    'key too deeply nested', '129-segment inline table dotted key');
end;

procedure TestLiteralString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('path = ''C:\Users\admin''');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Str.Equals(
    TStringView.Create(PAnsiChar('C:\Users\admin'), 14)), 'literal no escape');
  LDoc.Done;
end;

procedure TestEscapedString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('msg = "hello\nworld"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Str.Equals(
    TStringView.Create(PAnsiChar('hello' + #10 + 'world'), 11)), 'escaped newline');
  LDoc.Done;
end;

procedure TestRawDelControlCharInStrings;
var
  LDoc: TTomlDocument;
begin
  CheckRejectsAt('msg = "a' + #127 + 'b"', 'control char in string',
    'basic string raw DEL', 8, 1, 9);
  CheckRejectsAt('msg = ''a' + #127 + 'b''', 'control char in string',
    'literal string raw DEL', 8, 1, 9);
  CheckRejectsAt('msg = """a' + #127 + 'b"""', 'control char in multi-line string',
    'multi-line basic string raw DEL', 10, 1, 11);
  CheckRejectsAt('msg = ''''''a' + #127 + 'b''''''',
    'control char in multi-line literal string',
    'multi-line literal string raw DEL', 10, 1, 11);

  LDoc := MustParse('tab = "a' + #9 + 'b"' + #10 + 'lit = ''a' + #9 + 'b''');
  LDoc.Done;
end;

procedure TestQuotedKey;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('"key with spaces" = "value"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Key.Equals(
    TStringView.Create(PAnsiChar('key with spaces'), 15)), 'quoted key');
  LDoc.Done;
end;

procedure TestDateTimeOffset;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('dt = 1979-05-27T07:32:00Z');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  CheckEqual(Int64(1979), Int64(LDT.Year), 'year');
  CheckEqual(Int64(5), Int64(LDT.Month), 'month');
  CheckEqual(Int64(27), Int64(LDT.Day), 'day');
  CheckEqual(Int64(7), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(32), Int64(LDT.Minute), 'minute');
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(0), Int64(LDT.OffsetMinutes), 'offset = 0 (Z)');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset');
  LDoc.Done;
end;

procedure TestLocalDate;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('d = 2024-01-15');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  Check(LDT.HasDate, 'has date');
  Check(not LDT.HasTime, 'no time');
  Check(LDT.Kind = tdkLocalDate, 'kind = local date');
  LDoc.Done;
end;

procedure TestLocalTime;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('t = 07:32:00');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  Check(not LDT.HasDate, 'no date');
  Check(LDT.HasTime, 'has time');
  Check(LDT.Kind = tdkLocalTime, 'kind = local time');
  LDoc.Done;
end;

procedure TestArrayTable;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('[[products]]' + #10 + 'name = "Hammer"' + #10 +
    '[[products]]' + #10 + 'name = "Nail"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 elements');
  LDoc.Done;
end;

procedure TestDuplicateKeyReject;
begin
  Check(MustReject('a = 1' + #10 + 'a = 2'), 'duplicate key rejected');
end;

procedure TestTrailingCommaArray;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('a = [1, 2, 3,]');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(3), Int64(LDoc.Node(LChild)^.Container.Count), '3 elements');
  LDoc.Done;
end;

procedure TestCommentAfterValue;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('key = "value" # this is a comment');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 entry');
  LDoc.Done;
end;

function BuildTomlKeyValuePairs(const ACount: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to ACount - 1 do
    Result := Result + 'k' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
end;

function BuildTomlEscapedStrings(const ACount: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to ACount - 1 do
    Result := Result + 'k' + IntToStr(LI) + ' = "\n"' + #10;
end;

procedure TestNodeGrowthOOMFailsClosed;
var
  LAllocatorObj: TFailingReallocateAllocator;
  LAllocator: IAllocator;
  LDoc: TTomlDocument;
begin
  LAllocatorObj := TFailingReallocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  LDoc.Init(LAllocator);
  try
    Check(not LDoc.Parse(TStringView.FromStr(BuildTomlKeyValuePairs(80))),
      'node growth OOM rejects parse');
    Check(LDoc.HasError, 'node growth OOM sets error');
    CheckEqual('out of memory', LDoc.Error.Message.ToString,
      'node growth OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestOwnedBufferGrowthOOMFailsClosed;
var
  LAllocatorObj: TFailingReallocateAllocator;
  LAllocator: IAllocator;
  LDoc: TTomlDocument;
begin
  LAllocatorObj := TFailingReallocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  LDoc.Init(LAllocator);
  try
    Check(not LDoc.Parse(TStringView.FromStr(BuildTomlEscapedStrings(17))),
      'owned buffer growth OOM rejects parse');
    Check(LDoc.HasError, 'owned buffer growth OOM sets error');
    CheckEqual('out of memory', LDoc.Error.Message.ToString,
      'owned buffer growth OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestInitAllocateOOMSetsError;
var
  LAllocatorObj: TFailingAllocateAllocator;
  LAllocator: IAllocator;
  LDoc: TTomlDocument;
begin
  LAllocatorObj := TFailingAllocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  LDoc.Init(LAllocator);
  try
    Check(LDoc.HasError, 'init allocate OOM sets error');
    CheckEqual('out of memory', LDoc.Error.Message.ToString,
      'init allocate OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestParserSourceTracksOOMAndInitGuards;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(
    TOML_PARSER_SOURCE_PATH_FROM_TEST,
    TOML_PARSER_SOURCE_PATH_FROM_ROOT));
  CheckSourceContains(LSource, 'finited: boolean;',
    'document tracks initialized state');
  CheckSourceContains(LSource, 'if not finited then',
    'done must guard uninited records');
  CheckSourceContains(LSource, 'lptr := fallocator.getmem(fnodecap * sizeof(ttomlnode));',
    'init must stage node allocation');
  CheckSourceContains(LSource, 'if lptr = nil then',
    'init must guard node allocation');
  CheckSourceContains(LSource, 'lnewbufs := ppointer(fallocator.reallocmem(pointer(fownedbufs), lnewcap * sizeof(pointer)));',
    'owned buffer growth must stage reallocate');
  CheckSourceContains(LSource, 'lnewnodes := fallocator.reallocmem(fnodes, lnewcap * sizeof(ttomlnode));',
    'node growth must stage reallocate');
  CheckSourceContains(LSource, 'lhashbuckets := fallocator.getmem(lcap * sizeof(uint32));',
    'hash index buckets must stage allocation');
  CheckSourceContains(LSource, 'lbuf := doc^.fallocator.getmem(lbuflen);',
    'basic string unescape buffer must stage allocation');
  CheckSourceContains(LSource, 'lbuf := doc^.fallocator.getmem(lbuflen + 1);',
    'multi-line string buffers must stage allocation');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.parser');
  T.Run('empty input', @TestEmptyInput);
  T.Run('comments only', @TestCommentsOnly);
  T.Run('comment control characters', @TestCommentControlCharacters);
  T.Run('simple string', @TestSimpleString);
  T.Run('simple integer', @TestSimpleInteger);
  T.Run('negative integer', @TestNegativeInteger);
  T.Run('hex integer', @TestHexInteger);
  T.Run('oct integer', @TestOctInteger);
  T.Run('bin integer', @TestBinInteger);
  T.Run('integer underscores', @TestIntegerWithUnderscores);
  T.Run('float', @TestFloat);
  T.Run('float exponent', @TestFloatExponent);
  T.Run('float inf', @TestFloatInf);
  T.Run('float -inf', @TestFloatNegInf);
  T.Run('float nan', @TestFloatNan);
  T.Run('bool true', @TestBoolTrue);
  T.Run('bool false', @TestBoolFalse);
  T.Run('multiple keys', @TestMultipleKeys);
  T.Run('table', @TestTable);
  T.Run('nested table', @TestNestedTable);
  T.Run('dotted key', @TestDottedKey);
  T.Run('dotted key path depth boundary',
    @TestDottedKeyPathDepthBoundary);
  T.Run('table path depth boundary',
    @TestTablePathDepthBoundary);
  T.Run('array table path depth boundary',
    @TestArrayTablePathDepthBoundary);
  T.Run('array', @TestArray);
  T.Run('inline table', @TestInlineTable);
  T.Run('inline table dotted key path depth boundary',
    @TestInlineTableDottedKeyPathDepthBoundary);
  T.Run('literal string', @TestLiteralString);
  T.Run('escaped string', @TestEscapedString);
  T.Run('raw DEL control char in strings', @TestRawDelControlCharInStrings);
  T.Run('quoted key', @TestQuotedKey);
  T.Run('datetime offset', @TestDateTimeOffset);
  T.Run('local date', @TestLocalDate);
  T.Run('local time', @TestLocalTime);
  T.Run('array table', @TestArrayTable);
  T.Run('duplicate key reject', @TestDuplicateKeyReject);
  T.Run('trailing comma array', @TestTrailingCommaArray);
  T.Run('comment after value', @TestCommentAfterValue);
  T.Run('node growth OOM fails closed', @TestNodeGrowthOOMFailsClosed);
  T.Run('owned buffer growth OOM fails closed',
    @TestOwnedBufferGrowthOOMFailsClosed);
  T.Run('init allocate OOM sets error', @TestInitAllocateOOMSetsError);
  T.Run('parser source tracks OOM and init guards',
    @TestParserSourceTracksOOMAndInitGuards);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
