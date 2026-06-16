program test_ini;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.ini,
  nextpas.core.testing;

var
  T: TTestRunner;

type
  TFailingReallocateAllocator = class(TInterfacedObject, IAllocator)
  private
    FFailOnReallocateCall: SizeUInt;
    FReallocateCalls: SizeUInt;
  public
    constructor Create(const AFailOnReallocateCall: SizeUInt);
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
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

function TFailingReallocateAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TFailingReallocateAllocator.Reallocate(const APtr: Pointer;
  const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TFailingReallocateAllocator.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
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

{ === Basic Read/Write Tests === }

procedure TestReadStringBasic;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[database]' + #10 + 'host=localhost' + #10 + 'port=5432' + #10);
    CheckEqual('localhost', Ini.ReadString('database', 'host', ''), 'host');
    CheckEqual('5432', Ini.ReadString('database', 'port', ''), 'port');
    CheckEqual('default', Ini.ReadString('database', 'missing', 'default'), 'missing key');
    CheckEqual('fallback', Ini.ReadString('nosection', 'key', 'fallback'), 'missing section');
  finally
    Ini.Free;
  end;
end;

procedure TestReadInteger;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[server]' + #10 + 'port=8080' + #10 + 'timeout=30' + #10 + 'bad=abc' + #10);
    CheckEqual(Int64(8080), Ini.ReadInteger('server', 'port', 0), 'port');
    CheckEqual(Int64(30), Ini.ReadInteger('server', 'timeout', 0), 'timeout');
    CheckEqual(Int64(-1), Ini.ReadInteger('server', 'bad', -1), 'bad int');
    CheckEqual(Int64(99), Ini.ReadInteger('server', 'missing', 99), 'missing');
  finally
    Ini.Free;
  end;
end;

procedure TestReadBool;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[flags]' + #10 +
      'a=true' + #10 + 'b=false' + #10 +
      'c=1' + #10 + 'd=0' + #10 +
      'e=yes' + #10 + 'f=no' + #10 +
      'g=on' + #10 + 'h=off' + #10 +
      'i=maybe' + #10);
    CheckEqual(True, Ini.ReadBool('flags', 'a', False), 'true');
    CheckEqual(False, Ini.ReadBool('flags', 'b', True), 'false');
    CheckEqual(True, Ini.ReadBool('flags', 'c', False), '1');
    CheckEqual(False, Ini.ReadBool('flags', 'd', True), '0');
    CheckEqual(True, Ini.ReadBool('flags', 'e', False), 'yes');
    CheckEqual(False, Ini.ReadBool('flags', 'f', True), 'no');
    CheckEqual(True, Ini.ReadBool('flags', 'g', False), 'on');
    CheckEqual(False, Ini.ReadBool('flags', 'h', True), 'off');
    CheckEqual(True, Ini.ReadBool('flags', 'i', True), 'invalid defaults true');
    CheckEqual(False, Ini.ReadBool('flags', 'i', False), 'invalid defaults false');
  finally
    Ini.Free;
  end;
end;

procedure TestWriteString;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('app', 'name', 'MyApp');
    Ini.WriteString('app', 'version', '1.0');
    CheckEqual('MyApp', Ini.ReadString('app', 'name', ''), 'write name');
    CheckEqual('1.0', Ini.ReadString('app', 'version', ''), 'write version');
    { Overwrite }
    Ini.WriteString('app', 'name', 'NewApp');
    CheckEqual('NewApp', Ini.ReadString('app', 'name', ''), 'overwrite');
  finally
    Ini.Free;
  end;
end;

procedure TestDuplicateParsedKeyUpdatesValue;
var
  Ini: TIniFile;
  Keys: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[app]' + #10 +
      'name=first' + #10 +
      'Name=second' + #10);
    CheckEqual('second', Ini.ReadString('app', 'name', ''), 'last parsed value wins');
    Keys := Ini.GetKeys('app');
    CheckEqual(Int64(1), Int64(Length(Keys)), 'duplicate parsed key is not appended');
    CheckEqual('name', LowerCase(Keys[0]), 'original key slot reused');
  finally
    Ini.Free;
  end;
end;

procedure TestWriteInteger;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteInteger('nums', 'count', 42);
    Ini.WriteInteger('nums', 'negative', -100);
    CheckEqual(Int64(42), Ini.ReadInteger('nums', 'count', 0), 'write int');
    CheckEqual(Int64(-100), Ini.ReadInteger('nums', 'negative', 0), 'write neg');
  finally
    Ini.Free;
  end;
end;

procedure TestWriteBool;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteBool('opts', 'enabled', True);
    Ini.WriteBool('opts', 'debug', False);
    CheckEqual(True, Ini.ReadBool('opts', 'enabled', False), 'write true');
    CheckEqual(False, Ini.ReadBool('opts', 'debug', True), 'write false');
  finally
    Ini.Free;
  end;
end;

{ === Section Operations === }

procedure TestSectionExists;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[alpha]' + #10 + 'x=1' + #10 + '[beta]' + #10 + 'y=2' + #10);
    Check(Ini.SectionExists('alpha'), 'alpha exists');
    Check(Ini.SectionExists('beta'), 'beta exists');
    Check(not Ini.SectionExists('gamma'), 'gamma not exists');
  finally
    Ini.Free;
  end;
end;

procedure TestSectionCaseInsensitive;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[Database]' + #10 + 'Host=localhost' + #10);
    CheckEqual('localhost', Ini.ReadString('database', 'host', ''), 'case insensitive');
    CheckEqual('localhost', Ini.ReadString('DATABASE', 'HOST', ''), 'upper case');
  finally
    Ini.Free;
  end;
end;

procedure TestDeleteSection;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('sec1', 'a', '1');
    Ini.WriteString('sec2', 'b', '2');
    Check(Ini.SectionExists('sec1'), 'sec1 before delete');
    Ini.DeleteSection('sec1');
    Check(not Ini.SectionExists('sec1'), 'sec1 after delete');
    Check(Ini.SectionExists('sec2'), 'sec2 still exists');
  finally
    Ini.Free;
  end;
end;

procedure TestGetSections;
var
  Ini: TIniFile;
  Secs: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[first]' + #10 + 'a=1' + #10 + '[second]' + #10 + 'b=2' + #10 + '[third]' + #10 + 'c=3' + #10);
    Secs := Ini.GetSections;
    CheckEqual(Int64(3), Int64(Length(Secs)), 'section count');
    CheckEqual('first', Secs[0], 'sec 0');
    CheckEqual('second', Secs[1], 'sec 1');
    CheckEqual('third', Secs[2], 'sec 2');
  finally
    Ini.Free;
  end;
end;

{ === Key Operations === }

procedure TestKeyExists;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[db]' + #10 + 'host=localhost' + #10 + 'port=5432' + #10);
    Check(Ini.KeyExists('db', 'host'), 'host exists');
    Check(Ini.KeyExists('db', 'port'), 'port exists');
    Check(not Ini.KeyExists('db', 'user'), 'user not exists');
    Check(not Ini.KeyExists('other', 'host'), 'wrong section');
  finally
    Ini.Free;
  end;
end;

procedure TestDeleteKey;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('sec', 'a', '1');
    Ini.WriteString('sec', 'b', '2');
    Ini.WriteString('sec', 'c', '3');
    Check(Ini.KeyExists('sec', 'b'), 'b before delete');
    Ini.DeleteKey('sec', 'b');
    Check(not Ini.KeyExists('sec', 'b'), 'b after delete');
    CheckEqual('1', Ini.ReadString('sec', 'a', ''), 'a intact');
    CheckEqual('3', Ini.ReadString('sec', 'c', ''), 'c intact');
  finally
    Ini.Free;
  end;
end;

procedure TestGetKeys;
var
  Ini: TIniFile;
  Keys: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[cfg]' + #10 + 'alpha=1' + #10 + 'beta=2' + #10 + 'gamma=3' + #10);
    Keys := Ini.GetKeys('cfg');
    CheckEqual(Int64(3), Int64(Length(Keys)), 'key count');
    CheckEqual('alpha', Keys[0], 'key 0');
    CheckEqual('beta', Keys[1], 'key 1');
    CheckEqual('gamma', Keys[2], 'key 2');
  finally
    Ini.Free;
  end;
end;

{ === Comments === }

procedure TestCommentsSkipped;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(
      '; This is a comment' + #10 +
      '# This is also a comment' + #10 +
      '[section]' + #10 +
      '; inline section comment' + #10 +
      'key=value' + #10 +
      '# another comment' + #10 +
      'key2=value2' + #10);
    CheckEqual('value', Ini.ReadString('section', 'key', ''), 'key after comment');
    CheckEqual('value2', Ini.ReadString('section', 'key2', ''), 'key2 after comment');
    { Comments should not appear as keys }
    Check(not Ini.KeyExists('section', '; inline section comment'), 'comment not a key');
  finally
    Ini.Free;
  end;
end;

{ === Value with spaces === }

procedure TestValueWithSpaces;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[paths]' + #10 +
      'dir = /usr/local/bin' + #10 +
      'name = hello world' + #10 +
      'spaced =   leading preserved trailing  ' + #10);
    CheckEqual('/usr/local/bin', Ini.ReadString('paths', 'dir', ''), 'path value');
    CheckEqual('hello world', Ini.ReadString('paths', 'name', ''), 'space in value');
    { Leading whitespace after = is trimmed, trailing preserved }
    CheckEqual('leading preserved trailing  ', Ini.ReadString('paths', 'spaced', ''), 'leading trimmed trailing kept');
  finally
    Ini.Free;
  end;
end;

{ === LoadFromString + ToString roundtrip === }

procedure TestRoundtrip;
var
  Ini: TIniFile;
  LOutput: string;
  Ini2: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('server', 'host', 'localhost');
    Ini.WriteString('server', 'port', '8080');
    Ini.WriteString('database', 'name', 'mydb');
    LOutput := Ini.ToString;
  finally
    Ini.Free;
  end;

  Ini2 := TIniFile.Create;
  try
    Ini2.LoadFromString(LOutput);
    CheckEqual('localhost', Ini2.ReadString('server', 'host', ''), 'roundtrip host');
    CheckEqual('8080', Ini2.ReadString('server', 'port', ''), 'roundtrip port');
    CheckEqual('mydb', Ini2.ReadString('database', 'name', ''), 'roundtrip name');
  finally
    Ini2.Free;
  end;
end;

{ === Edge Cases === }

procedure TestEmptyFile;
var
  Ini: TIniFile;
  Secs: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('');
    Secs := Ini.GetSections;
    CheckEqual(Int64(0), Int64(Length(Secs)), 'no sections in empty');
  finally
    Ini.Free;
  end;
end;

procedure TestOnlyComments;
var
  Ini: TIniFile;
  Secs: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('; comment 1' + #10 + '# comment 2' + #10 + '; comment 3' + #10);
    Secs := Ini.GetSections;
    CheckEqual(Int64(0), Int64(Length(Secs)), 'no sections in comments-only');
  finally
    Ini.Free;
  end;
end;

procedure TestKeysWithoutSection;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('global_key=global_value' + #10 + '[section]' + #10 + 'key=value' + #10);
    { Keys before any section go to the empty-name global section }
    CheckEqual('global_value', Ini.ReadString('', 'global_key', ''), 'global key');
    CheckEqual('value', Ini.ReadString('section', 'key', ''), 'section key');
  finally
    Ini.Free;
  end;
end;

procedure TestEmptySection;
var
  Ini: TIniFile;
  Keys: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[empty]' + #10 + '[notempty]' + #10 + 'k=v' + #10);
    Check(Ini.SectionExists('empty'), 'empty section exists');
    Keys := Ini.GetKeys('empty');
    CheckEqual(Int64(0), Int64(Length(Keys)), 'empty section has no keys');
    CheckEqual('v', Ini.ReadString('notempty', 'k', ''), 'notempty has key');
  finally
    Ini.Free;
  end;
end;

procedure TestEmptyValue;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[sec]' + #10 + 'empty=' + #10 + 'normal=hello' + #10);
    CheckEqual('', Ini.ReadString('sec', 'empty', 'X'), 'empty value');
    CheckEqual('hello', Ini.ReadString('sec', 'normal', ''), 'normal value');
  finally
    Ini.Free;
  end;
end;

procedure TestCRLFLineEndings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[sec]' + #13#10 + 'key=value' + #13#10 + 'key2=val2' + #13#10);
    CheckEqual('value', Ini.ReadString('sec', 'key', ''), 'CRLF key');
    CheckEqual('val2', Ini.ReadString('sec', 'key2', ''), 'CRLF key2');
  finally
    Ini.Free;
  end;
end;

procedure TestValueWithEquals;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[sec]' + #10 + 'expr=a=b' + #10 + 'url=http://x?a=1&b=2' + #10);
    { Only first = is the delimiter }
    CheckEqual('a=b', Ini.ReadString('sec', 'expr', ''), 'value with =');
    CheckEqual('http://x?a=1&b=2', Ini.ReadString('sec', 'url', ''), 'url with =');
  finally
    Ini.Free;
  end;
end;

procedure TestTryLoadFromStringValid;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    CheckEqual(True, Ini.TryLoadFromString('[service]' + #10 + 'host=localhost' + #10, LError),
      'TryLoadFromString valid');
    CheckEqual('', LError, 'valid load clears error');
    CheckEqual('localhost', Ini.ReadString('service', 'host', ''), 'valid load keeps parsed value');
  finally
    Ini.Free;
  end;
end;

procedure TestTryLoadFromStringInvalidSection;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    CheckEqual(False, Ini.TryLoadFromString('[section' + #10 + 'key=value' + #10, LError),
      'TryLoadFromString invalid section');
    Check(LError <> '', 'invalid section returns error');
  finally
    Ini.Free;
  end;
end;

procedure TestTryLoadFromFileMissing;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    CheckEqual(False, Ini.TryLoadFromFile('/tmp/nextpas_missing_try_load.ini', LError),
      'TryLoadFromFile missing');
    Check(LError <> '', 'missing file returns error');
  finally
    Ini.Free;
  end;
end;

procedure TestDeleteNonExistent;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('sec', 'key', 'val');
    { Should not crash }
    Ini.DeleteKey('sec', 'nonexist');
    Ini.DeleteKey('nosec', 'key');
    Ini.DeleteSection('nosec');
    CheckEqual('val', Ini.ReadString('sec', 'key', ''), 'original intact');
  finally
    Ini.Free;
  end;
end;


{ === File I/O Tests === }

procedure TestSaveAndLoadFromFile;
var
  Ini, Ini2: TIniFile;
  LPath: string;
begin
  LPath := '/tmp/test_ini_roundtrip.ini';
  Ini := TIniFile.Create;
  try
    Ini.WriteString('server', 'host', 'localhost');
    Ini.WriteString('server', 'port', '3000');
    Ini.WriteString('db', 'name', 'testdb');
    Ini.WriteBool('flags', 'debug', True);
    Ini.SaveToFile(LPath);
  finally
    Ini.Free;
  end;

  Ini2 := TIniFile.Create;
  try
    Ini2.LoadFromFile(LPath);
    CheckEqual('localhost', Ini2.ReadString('server', 'host', ''), 'file roundtrip host');
    CheckEqual('3000', Ini2.ReadString('server', 'port', ''), 'file roundtrip port');
    CheckEqual('testdb', Ini2.ReadString('db', 'name', ''), 'file roundtrip db');
    CheckEqual(True, Ini2.ReadBool('flags', 'debug', False), 'file roundtrip bool');
  finally
    Ini2.Free;
  end;
  DeleteFile(LPath);
end;

procedure TestSaveToFileFormat;
var
  Ini: TIniFile;
  LPath: string;
  LFile: TextFile;
  LLine, LContent: string;
begin
  LPath := '/tmp/test_ini_format.ini';
  Ini := TIniFile.Create;
  try
    Ini.WriteString('section1', 'key1', 'value1');
    Ini.WriteString('section1', 'key2', 'value2');
    Ini.WriteString('section2', 'alpha', 'beta');
    Ini.SaveToFile(LPath);
  finally
    Ini.Free;
  end;

  { Read raw file content }
  LContent := '';
  AssignFile(LFile, LPath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LContent := LContent + LLine + #10;
    end;
  finally
    CloseFile(LFile);
  end;

  { Verify format: [section] header + key=value lines }
  Check(Pos('[section1]', LContent) > 0, 'has [section1] header');
  Check(Pos('[section2]', LContent) > 0, 'has [section2] header');
  Check(Pos('key1=value1', LContent) > 0, 'has key1=value1');
  Check(Pos('key2=value2', LContent) > 0, 'has key2=value2');
  Check(Pos('alpha=beta', LContent) > 0, 'has alpha=beta');
  { section1 should appear before section2 }
  Check(Pos('[section1]', LContent) < Pos('[section2]', LContent), 'section order');
  DeleteFile(LPath);
end;

procedure TestCreateNilAllocatorUsesDefault;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(nil);
  try
    Check(Ini.Allocator <> nil, 'nil allocator falls back to default');
    Ini.LoadFromString('[app]' + #10 + 'name=nextpas');
    CheckEqual('nextpas', Ini.ReadString('app', 'name', ''),
      'load with default allocator works');
  finally
    Ini.Free;
  end;
end;

procedure TestLoadFromStringReallocateFailureRaises;
var
  Ini: TIniFile;
  LRaised: Boolean;
  LAllocatorObj: TFailingReallocateAllocator;
  LAllocator: IAllocator;
begin
  LAllocatorObj := TFailingReallocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  Ini := TIniFile.Create(LAllocator);
  try
    LRaised := False;
    try
      Ini.LoadFromString('[s1]' + #10 + 'k=v' + #10 +
        '[s2]' + #10 + 'k=v' + #10 +
        '[s3]' + #10 + 'k=v' + #10 +
        '[s4]' + #10 + 'k=v' + #10 +
        '[s5]' + #10 + 'k=v' + #10 +
        '[s6]' + #10 + 'k=v' + #10 +
        '[s7]' + #10 + 'k=v' + #10 +
        '[s8]' + #10 + 'k=v' + #10 +
        '[s9]' + #10 + 'k=v');
    except
      on E: EResourceExhaustedError do
        LRaised := True;
    end;
    Check(LRaised, 'section reallocate failure raises resource exhausted');
  finally
    Ini.Free;
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.ini');
  T.Run('ReadString basic', @TestReadStringBasic);
  T.Run('ReadInteger', @TestReadInteger);
  T.Run('ReadBool', @TestReadBool);
  T.Run('WriteString', @TestWriteString);
  T.Run('Duplicate parsed key updates value', @TestDuplicateParsedKeyUpdatesValue);
  T.Run('WriteInteger', @TestWriteInteger);
  T.Run('WriteBool', @TestWriteBool);
  T.Run('SectionExists', @TestSectionExists);
  T.Run('Section case insensitive', @TestSectionCaseInsensitive);
  T.Run('DeleteSection', @TestDeleteSection);
  T.Run('GetSections', @TestGetSections);
  T.Run('KeyExists', @TestKeyExists);
  T.Run('DeleteKey', @TestDeleteKey);
  T.Run('GetKeys', @TestGetKeys);
  T.Run('Comments skipped', @TestCommentsSkipped);
  T.Run('Value with spaces', @TestValueWithSpaces);
  T.Run('Roundtrip', @TestRoundtrip);
  T.Run('Empty file', @TestEmptyFile);
  T.Run('Only comments', @TestOnlyComments);
  T.Run('Keys without section', @TestKeysWithoutSection);
  T.Run('Empty section', @TestEmptySection);
  T.Run('Empty value', @TestEmptyValue);
  T.Run('CRLF line endings', @TestCRLFLineEndings);
  T.Run('Value with equals sign', @TestValueWithEquals);
  T.Run('TryLoadFromString valid', @TestTryLoadFromStringValid);
  T.Run('TryLoadFromString invalid section', @TestTryLoadFromStringInvalidSection);
  T.Run('TryLoadFromFile missing', @TestTryLoadFromFileMissing);
  T.Run('Delete non-existent', @TestDeleteNonExistent);
  T.Run('SaveToFile + LoadFromFile roundtrip', @TestSaveAndLoadFromFile);
  T.Run('SaveToFile format', @TestSaveToFileFormat);
  T.Run('Allocator nil falls back to default',
    @TestCreateNilAllocatorUsesDefault);
  T.Run('LoadFromString reallocate failure raises',
    @TestLoadFromStringReallocateFailureRaises);
  T.Summary;
end.
