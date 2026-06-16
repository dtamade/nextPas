program test_ini_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.ini,
  nextpas.core.mem.default,
  nextpas.core.testing;

var
  T: TTestRunner;

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

procedure TestFacadeExposesAllocatorSurface;
var
  Ini: TIniFile;
  LContent: string;
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
    { IniStringify surface }
    LContent := IniStringify(Ini);
    Check(Pos('port=8080', LContent) > 0, 'IniStringify surface visible');
  finally
    Ini.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.ini (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Run('facade exposes write surface', @TestFacadeExposesWriteSurface);
  T.Run('facade exposes delete surface', @TestFacadeExposesDeleteSurface);
  T.Run('facade exposes allocator surface',
    @TestFacadeExposesAllocatorSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
