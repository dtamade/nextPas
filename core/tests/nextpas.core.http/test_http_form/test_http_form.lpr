program test_http_form;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.http.form.base,
  nextpas.core.http.form;

procedure TestParseUrlEncodedBasic;
var
  LFields: TFormFieldArray;
begin
  LFields := ParseUrlEncodedForm('name=Alice&age=30&city=NYC');
  CheckEqual(3, Length(LFields), 'field count');
  CheckEqual('name', LFields[0].Name, 'field 0 name');
  CheckEqual('Alice', LFields[0].Value, 'field 0 value');
  CheckEqual('age', LFields[1].Name, 'field 1 name');
  CheckEqual('30', LFields[1].Value, 'field 1 value');
  CheckEqual('city', LFields[2].Name, 'field 2 name');
  CheckEqual('NYC', LFields[2].Value, 'field 2 value');
end;

procedure TestParseUrlEncodedEmpty;
var
  LFields: TFormFieldArray;
begin
  LFields := ParseUrlEncodedForm('');
  CheckEqual(0, Length(LFields), 'empty body');
end;

procedure TestParseUrlEncodedPlusSpace;
var
  LFields: TFormFieldArray;
begin
  LFields := ParseUrlEncodedForm('msg=hello+world');
  CheckEqual(1, Length(LFields), 'field count');
  CheckEqual('hello world', LFields[0].Value, '+ decoded as space');
end;

procedure TestParseUrlEncodedPercentEncoding;
var
  LFields: TFormFieldArray;
begin
  LFields := ParseUrlEncodedForm('q=hello%26world%3Dtest');
  CheckEqual(1, Length(LFields), 'field count');
  CheckEqual('hello&world=test', LFields[0].Value, 'percent encoding');
end;

procedure TestParseUrlEncodedNoValue;
var
  LFields: TFormFieldArray;
begin
  LFields := ParseUrlEncodedForm('key&other=val');
  CheckEqual(2, Length(LFields), 'field count');
  CheckEqual('key', LFields[0].Name, 'field 0 name');
  CheckEqual('', LFields[0].Value, 'field 0 empty value');
  CheckEqual('other', LFields[1].Name, 'field 1 name');
  CheckEqual('val', LFields[1].Value, 'field 1 value');
end;

procedure TestParseMultipartBasic;
var
  LBody, LBoundary: string;
  LData: TMultipartFormData;
begin
  LBoundary := 'boundary';
  LBody :=
    '--boundary' + #13#10 +
    'Content-Disposition: form-data; name="username"' + #13#10 +
    #13#10 +
    'alice' + #13#10 +
    '--boundary' + #13#10 +
    'Content-Disposition: form-data; name="email"' + #13#10 +
    #13#10 +
    'alice@example.com' + #13#10 +
    '--boundary--' + #13#10;

  LData := ParseMultipartFormData(LBody, LBoundary);
  CheckEqual(2, LData.FieldCount, 'field count');
  CheckEqual('username', LData.Fields[0].Name, 'field 0 name');
  CheckEqual('alice', LData.Fields[0].Value, 'field 0 value');
  CheckEqual('email', LData.Fields[1].Name, 'field 1 name');
  CheckEqual('alice@example.com', LData.Fields[1].Value, 'field 1 value');
  CheckEqual(0, LData.FileCount, 'no files');
end;

procedure TestParseMultipartFile;
var
  LBody, LBoundary: string;
  LData: TMultipartFormData;
begin
  LBoundary := 'boundary123';
  LBody :=
    '--boundary123' + #13#10 +
    'Content-Disposition: form-data; name="file"; filename="test.txt"' + #13#10 +
    'Content-Type: text/plain' + #13#10 +
    #13#10 +
    'file content here' + #13#10 +
    '--boundary123--' + #13#10;

  LData := ParseMultipartFormData(LBody, LBoundary);
  CheckEqual(0, LData.FieldCount, 'no fields');
  CheckEqual(1, LData.FileCount, 'file count');
  CheckEqual('file', LData.Files[0].FieldName, 'file field name');
  CheckEqual('test.txt', LData.Files[0].FileName, 'file name');
  CheckEqual('text/plain', LData.Files[0].ContentType, 'file content type');
  CheckEqual('file content here', LData.Files[0].Content, 'file content');
end;

procedure TestParseMultipartMixed;
var
  LBody, LBoundary: string;
  LData: TMultipartFormData;
begin
  LBoundary := '----boundary';
  LBody :=
    '------boundary' + #13#10 +
    'Content-Disposition: form-data; name="description"' + #13#10 +
    #13#10 +
    'A test file' + #13#10 +
    '------boundary' + #13#10 +
    'Content-Disposition: form-data; name="avatar"; filename="pic.png"' + #13#10 +
    'Content-Type: image/png' + #13#10 +
    #13#10 +
    #13#10 +
    '------boundary--' + #13#10;

  LData := ParseMultipartFormData(LBody, LBoundary);
  CheckEqual(1, LData.FieldCount, 'field count');
  CheckEqual('description', LData.Fields[0].Name, 'field name');
  CheckEqual('A test file', LData.Fields[0].Value, 'field value');
  CheckEqual(1, LData.FileCount, 'file count');
  CheckEqual('avatar', LData.Files[0].FieldName, 'file field name');
  CheckEqual('pic.png', LData.Files[0].FileName, 'file name');
end;

procedure TestMultipartFormDataHelpers;
var
  LData: TMultipartFormData;
  LFile: THttpFile;
begin
  SetLength(LData.Fields, 2);
  LData.Fields[0].Name := 'key1';
  LData.Fields[0].Value := 'val1';
  LData.Fields[1].Name := 'key2';
  LData.Fields[1].Value := 'val2';
  SetLength(LData.Files, 1);
  LData.Files[0].FieldName := 'upload';
  LData.Files[0].FileName := 'doc.pdf';

  CheckEqual(2, LData.FieldCount, 'FieldCount');
  CheckEqual(1, LData.FileCount, 'FileCount');
  Check(LData.HasField('key1'), 'HasField key1');
  Check(not LData.HasField('missing'), 'not HasField missing');
  CheckEqual('val1', LData.GetField('key1'), 'GetField key1');
  CheckEqual('', LData.GetField('missing'), 'GetField missing returns empty');
  Check(LData.HasFile('upload'), 'HasFile upload');
  Check(not LData.HasFile('missing'), 'not HasFile missing');
  LFile := LData.GetFile('upload');
  CheckEqual('doc.pdf', LFile.FileName, 'GetFile filename');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.form');
  T.Test('URL-encoded: basic key=value', @TestParseUrlEncodedBasic);
  T.Test('URL-encoded: empty body', @TestParseUrlEncodedEmpty);
  T.Test('URL-encoded: + as space', @TestParseUrlEncodedPlusSpace);
  T.Test('URL-encoded: percent encoding', @TestParseUrlEncodedPercentEncoding);
  T.Test('URL-encoded: no value (key only)', @TestParseUrlEncodedNoValue);
  T.Test('Multipart: basic fields', @TestParseMultipartBasic);
  T.Test('Multipart: file upload', @TestParseMultipartFile);
  T.Test('Multipart: mixed fields + files', @TestParseMultipartMixed);
  T.Test('TMultipartFormData helpers', @TestMultipartFormDataHelpers);
  if not T.Run then Halt(1);
end.
