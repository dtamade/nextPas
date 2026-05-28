program test_fpc_classes;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fpc.classes,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCreateFree;
var SL: TStringList;
begin
  SL := TStringList.Create;
  Check(SL.Count = 0, 'empty on create');
  SL.Free;
end;

procedure TestAddAndAccess;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Add('first');
  SL.Add('second');
  SL.Add('third');
  Check(SL.Count = 3, 'count = 3');
  Check(SL[0] = 'first', '[0]');
  Check(SL[1] = 'second', '[1]');
  Check(SL[2] = 'third', '[2]');
  SL.Free;
end;

procedure TestDelete;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Add('a');
  SL.Add('b');
  SL.Add('c');
  SL.Delete(1);
  Check(SL.Count = 2, 'count after delete');
  Check(SL[0] = 'a', '[0] = a');
  Check(SL[1] = 'c', '[1] = c');
  SL.Free;
end;

procedure TestIndexOf;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Add('alpha');
  SL.Add('beta');
  SL.Add('gamma');
  Check(SL.IndexOf('beta') = 1, 'found beta');
  Check(SL.IndexOf('delta') = -1, 'not found');
  SL.Free;
end;

procedure TestText;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Text := 'line1' + #10 + 'line2' + #10 + 'line3';
  Check(SL.Count = 3, 'count = 3');
  Check(SL[0] = 'line1', 'line1');
  Check(SL[1] = 'line2', 'line2');
  Check(SL[2] = 'line3', 'line3');
  SL.Free;
end;

procedure TestCRLF;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Text := 'a' + #13#10 + 'b' + #13#10 + 'c';
  Check(SL.Count = 3, 'count = 3');
  Check(SL[0] = 'a', 'a');
  Check(SL[1] = 'b', 'b');
  Check(SL[2] = 'c', 'c');
  SL.Free;
end;

procedure TestLoadSaveFile;
var
  SL: TStringList;
  H: TPlatformFileHandle;
  W: PtrUInt;
const
  PATH = '/tmp/nextpas_sl_test.txt';
  CONTENT = 'hello' + #10 + 'world' + #10;
begin
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, @CONTENT[1], Length(CONTENT), W);
  platform_file_close(H);

  SL := TStringList.Create;
  SL.LoadFromFile(PATH);
  Check(SL.Count = 2, 'loaded 2 lines');
  Check(SL[0] = 'hello', 'line 0');
  Check(SL[1] = 'world', 'line 1');

  SL.Add('extra');
  SL.SaveToFile(PATH + '.out');
  SL.Free;

  SL := TStringList.Create;
  SL.LoadFromFile(PATH + '.out');
  Check(SL.Count = 3, 'saved 3 lines');
  Check(SL[2] = 'extra', 'extra line');
  SL.Free;

  platform_file_unlink(PATH);
  platform_file_unlink(PAnsiChar(PATH + '.out'));
end;

procedure TestClear;
var SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Add('x');
  SL.Add('y');
  SL.Clear;
  Check(SL.Count = 0, 'cleared');
  SL.Add('z');
  Check(SL.Count = 1, 'add after clear');
  Check(SL[0] = 'z', 'value after clear');
  SL.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.fpc.classes');
  T.Run('Create/Free', @TestCreateFree);
  T.Run('Add and access', @TestAddAndAccess);
  T.Run('Delete', @TestDelete);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('Text property', @TestText);
  T.Run('CRLF handling', @TestCRLF);
  T.Run('LoadFromFile/SaveToFile', @TestLoadSaveFile);
  T.Run('Clear', @TestClear);
  T.Summary;
end.
