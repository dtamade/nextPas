program test_ini_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.ini,
  nextpas.core.mem.default,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFacadeExposesCoreSurface;
var
  Ini: TIniFile;
  Sections: TStringArray;
  Keys: TStringArray;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[server]' + #10 + 'host=localhost' + #10 + 'port=8080' + #10 + #10 + '[database]' + #10 + 'name=mydb');
    CheckEqual('localhost', Ini.ReadString('server', 'host', ''), 'ReadString');
    CheckEqual(Int64(8080), Ini.ReadInteger('server', 'port', 0), 'ReadInteger');
    Check(Ini.SectionExists('server'), 'SectionExists');
    Check(Ini.KeyExists('server', 'host'), 'KeyExists');

    Sections := Ini.GetSections;
    CheckEqual(Int64(2), Int64(Length(Sections)), 'GetSections count');
    CheckEqual('database', Sections[1], 'GetSections second');

    Keys := Ini.GetKeys('server');
    CheckEqual(Int64(2), Int64(Length(Keys)), 'GetKeys count');
  finally
    Ini.Free;
  end;
end;

procedure TestFacadeExposesWriteSurface;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('app', 'name', 'test-app');
    Ini.WriteInteger('app', 'port', 3000);
    Ini.WriteBool('app', 'debug', True);

    CheckEqual('test-app', Ini.ReadString('app', 'name', ''), 'WriteString');
    CheckEqual(Int64(3000), Ini.ReadInteger('app', 'port', 0), 'WriteInteger');
    CheckEqual(True, Ini.ReadBool('app', 'debug', False), 'WriteBool');
  finally
    Ini.Free;
  end;
end;

procedure TestFacadeExposesDeleteSurface;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[server]' + #10 + 'host=localhost' + #10 + 'port=8080');
    Check(Ini.KeyExists('server', 'host'), 'key exists before delete');
    Ini.DeleteKey('server', 'host');
    Check(not Ini.KeyExists('server', 'host'), 'key deleted');

    Check(Ini.SectionExists('server'), 'section exists before delete');
    Ini.DeleteSection('server');
    Check(not Ini.SectionExists('server'), 'section deleted');
  finally
    Ini.Free;
  end;
end;

procedure TestFacadeExposesStructuredErrorSurface;
var
  Ini: TIniFile;
  LErr: TIniError;
  LMsg: string;
begin
  Ini := TIniFile.Create;
  try
    CheckEqual(False,
      Ini.TryLoadFromString('[unclosed' + #10 + 'key=value' + #10, LErr),
      'structured TryLoadFromString fails on unclosed section');
    CheckEqual('missing closing ] in section header', LErr.Message,
      'structured error message');
    CheckEqual(UInt32(1), LErr.Line, 'structured error line');
    CheckEqual(UInt32(1), LErr.Column, 'structured error column');
    CheckEqual(False,
      Ini.TryLoadFromString('[unclosed' + #10 + 'key=value' + #10, LMsg),
      'string TryLoadFromString still fails');
    Check(Pos('line 1', LMsg) > 0, 'string error keeps line prefix');
    Check(Pos('missing closing', LMsg) > 0, 'string error keeps message');

    CheckEqual(True,
      Ini.TryLoadFromString('[ok]' + #10 + 'a=1' + #10, LErr),
      'structured TryLoadFromString success');
    CheckEqual('', LErr.Message, 'success clears structured message');
    CheckEqual(UInt32(0), LErr.Line, 'success clears line');
  finally
    Ini.Free;
  end;
end;

procedure TestFacadeExposesAllocatorSurface;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(nil);
  try
    Check(Ini.Allocator <> nil, 'allocator accessor visible');
  finally
    Ini.Free;
  end;

  Ini := IniParse('[app]' + #10 + 'name=nextpas');
  try
    CheckEqual('nextpas', Ini.ReadString('app', 'name', ''),
      'IniParse surface visible');
  finally
    Ini.Free;
  end;

  Ini := IniParseWith('[server]' + #10 + 'port=8080', DefaultAllocator);
  try
    CheckEqual(Int64(8080), Ini.ReadInteger('server', 'port', 0),
      'IniParseWith surface visible');
  finally
    Ini.Free;
  end;
end;

function IniBytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesReaderParse;
var
  LStream: IStream;
  Ini: TIniFile;
  LRaised: Boolean;
begin
  LStream := CreateBytesStreamFrom(IniBytesFromString(
    '[app]' + #10 + 'name=from-reader' + #10));
  Ini := IniParse(LStream as IReader);
  try
    CheckEqual('from-reader', Ini.ReadString('app', 'name', ''),
      'IniParse IReader');
  finally
    Ini.Free;
  end;
  LRaised := False;
  try
    IniParse(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises');
end;

procedure TestFacadeExposesStrictAndColAlias;
var
  Ini: TIniFile;
  LErr: TIniError;
begin
  Ini := TIniFile.Create;
  try
    CheckEqual(False, Ini.Strict, 'Strict default false');
    CheckEqual(True,
      Ini.TryLoadFromString('[s]' + #10 + 'bareline' + #10 + 'k=v' + #10, LErr),
      'permissive accepts bare line');
    CheckEqual('v', Ini.ReadString('s', 'k', ''), 'permissive still loads keys');

    Ini.Strict := True;
    CheckEqual(False,
      Ini.TryLoadFromString('[s]' + #10 + 'bareline' + #10 + 'k=v' + #10, LErr),
      'strict rejects bare line');
    Check(Pos('strict', LErr.Message) > 0, 'strict error message');
    CheckEqual(UInt32(2), LErr.Line, 'strict error line');
    CheckEqual(LErr.Column, LErr.Col, 'Column/Col aliases match');
  finally
    Ini.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.ini (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade exposes write surface', @TestFacadeExposesWriteSurface);
  T.Test('facade exposes delete surface', @TestFacadeExposesDeleteSurface);
  T.Test('facade exposes structured error surface',
    @TestFacadeExposesStructuredErrorSurface);
  T.Test('facade exposes allocator surface',
    @TestFacadeExposesAllocatorSurface);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  T.Test('facade exposes strict and Col alias',
    @TestFacadeExposesStrictAndColAlias);
  if not T.Run then Halt(1);
end.
