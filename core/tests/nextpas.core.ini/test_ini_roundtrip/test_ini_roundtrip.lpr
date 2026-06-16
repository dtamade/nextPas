program test_ini_roundtrip;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.ini,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== Load → ToString → Re-load → Verify ===== }

procedure TestBasicRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.LoadFromString('[server]' + #10 + 'host=localhost' + #10 + 'port=8080');
    LOutput := Ini1.ToString;
    Check(Pos('[server]', LOutput) > 0, 'basic rt: section header');
    Check(Pos('host=localhost', LOutput) > 0, 'basic rt: host line');
    Check(Pos('port=8080', LOutput) > 0, 'basic rt: port line');

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      CheckEqual('localhost', Ini2.ReadString('server', 'host', ''),
        'basic rt: host roundtripped');
      CheckEqual(Int64(8080), Ini2.ReadInteger('server', 'port', 0),
        'basic rt: port roundtripped');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestMultiSectionRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.LoadFromString(
      '[server]' + #10 +
      'host=localhost' + #10 +
      'port=8080' + #10 +
      #10 +
      '[database]' + #10 +
      'name=mydb' + #10 +
      'user=admin');
    LOutput := Ini1.ToString;

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      Check(Ini2.SectionExists('server'), 'multi rt: server exists');
      Check(Ini2.SectionExists('database'), 'multi rt: database exists');
      CheckEqual('localhost', Ini2.ReadString('server', 'host', ''),
        'multi rt: host');
      CheckEqual('mydb', Ini2.ReadString('database', 'name', ''),
        'multi rt: db name');
      CheckEqual(Int64(2), Int64(Length(Ini2.GetSections)),
        'multi rt: 2 sections');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestWriteThenRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.WriteString('app', 'name', 'nextpas');
    Ini1.WriteInteger('app', 'version', 1);
    Ini1.WriteBool('app', 'debug', True);
    Ini1.WriteString('db', 'host', 'localhost');
    LOutput := Ini1.ToString;

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      CheckEqual('nextpas', Ini2.ReadString('app', 'name', ''),
        'write rt: name');
      CheckEqual(Int64(1), Ini2.ReadInteger('app', 'version', 0),
        'write rt: version');
      Check(Ini2.ReadBool('app', 'debug', False), 'write rt: debug');
      CheckEqual('localhost', Ini2.ReadString('db', 'host', ''),
        'write rt: db host');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestDeleteThenRoundtrip;
var
  Ini: TIniFile;
  LOutput: string;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(
      '[keep]' + #10 +
      'a=1' + #10 +
      'b=2' + #10 +
      '[remove]' + #10 +
      'x=9');
    Ini.DeleteKey('keep', 'b');
    Ini.DeleteSection('remove');
    LOutput := Ini.ToString;

    Ini.Free;
    Ini := TIniFile.Create;
    Ini.LoadFromString(LOutput);
    Check(Ini.SectionExists('keep'), 'delete rt: keep exists');
    Check(not Ini.SectionExists('remove'), 'delete rt: remove gone');
    CheckEqual('1', Ini.ReadString('keep', 'a', ''), 'delete rt: a preserved');
    CheckEqual('NOPE', Ini.ReadString('keep', 'b', 'NOPE'),
      'delete rt: b removed (returns default)');
  finally
    Ini.Free;
  end;
end;

procedure TestEmptyRoundtrip;
var
  Ini: TIniFile;
  LOutput: string;
begin
  Ini := TIniFile.Create;
  try
    LOutput := Ini.ToString;
    CheckEqual('', LOutput, 'empty rt: empty string');
    Ini.LoadFromString(LOutput);
    CheckEqual(Int64(0), Int64(Length(Ini.GetSections)),
      'empty rt: 0 sections');
  finally
    Ini.Free;
  end;
end;

procedure TestGlobalSectionRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.LoadFromString('key=value' + #10 + 'other=data');
    LOutput := Ini1.ToString;

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      CheckEqual('value', Ini2.ReadString('', 'key', ''), 'global rt: key');
      CheckEqual('data', Ini2.ReadString('', 'other', ''), 'global rt: other');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestReadBoolRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.WriteBool('flags', 'active', True);
    Ini1.WriteBool('flags', 'verbose', False);
    LOutput := Ini1.ToString;

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      Check(Ini2.ReadBool('flags', 'active', False), 'bool rt: active');
      Check(not Ini2.ReadBool('flags', 'verbose', True), 'bool rt: verbose');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestReadIntegerRoundtrip;
var
  Ini1, Ini2: TIniFile;
  LOutput: string;
begin
  Ini1 := TIniFile.Create;
  try
    Ini1.WriteInteger('numbers', 'small', 0);
    Ini1.WriteInteger('numbers', 'medium', 1000);
    Ini1.WriteInteger('numbers', 'large', 9999999999);
    Ini1.WriteInteger('numbers', 'negative', -42);
    LOutput := Ini1.ToString;

    Ini2 := TIniFile.Create;
    try
      Ini2.LoadFromString(LOutput);
      CheckEqual(Int64(0), Ini2.ReadInteger('numbers', 'small', -1), 'int rt: 0');
      CheckEqual(Int64(1000), Ini2.ReadInteger('numbers', 'medium', -1), 'int rt: 1000');
      CheckEqual(Int64(9999999999), Ini2.ReadInteger('numbers', 'large', -1), 'int rt: large');
      CheckEqual(Int64(-42), Ini2.ReadInteger('numbers', 'negative', 0), 'int rt: negative');
    finally
      Ini2.Free;
    end;
  finally
    Ini1.Free;
  end;
end;

procedure TestIniParseRoundtrip;
var
  Ini: TIniFile;
  LOutput: string;
begin
  Ini := IniParse(
    '[project]' + #10 +
    'name=nextpas' + #10 +
    'language=pascal');
  try
    LOutput := IniStringify(Ini);
    Ini.Free;

    Ini := IniParse(LOutput);
    CheckEqual('nextpas', Ini.ReadString('project', 'name', ''),
      'IniParse rt: name');
    CheckEqual('pascal', Ini.ReadString('project', 'language', ''),
      'IniParse rt: language');
  finally
    Ini.Free;
  end;
end;

begin
  T := TTestRunner.Create('ini roundtrip');
  T.Run('basic roundtrip', @TestBasicRoundtrip);
  T.Run('multi section roundtrip', @TestMultiSectionRoundtrip);
  T.Run('write then roundtrip', @TestWriteThenRoundtrip);
  T.Run('delete then roundtrip', @TestDeleteThenRoundtrip);
  T.Run('empty roundtrip', @TestEmptyRoundtrip);
  T.Run('global section roundtrip', @TestGlobalSectionRoundtrip);
  T.Run('ReadBool roundtrip', @TestReadBoolRoundtrip);
  T.Run('ReadInteger roundtrip', @TestReadIntegerRoundtrip);
  T.Run('IniParse roundtrip', @TestIniParseRoundtrip);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
