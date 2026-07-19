program test_http_form;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.http.base,
  nextpas.core.http.form.base,
  nextpas.core.http.form;

function StringToBytes(const AStr: string): TBytes;
begin
  SetLength(Result, Length(AStr));
  if Length(AStr) > 0 then
    Move(AStr[1], Result[0], Length(AStr));
end;

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

{ === Encoding tests === }

procedure TestEncodeUrlEncodedBasic;
var
  LFields: TFormFieldArray;
  LEncoded: string;
begin
  SetLength(LFields, 3);
  LFields[0].Name := 'name';
  LFields[0].Value := 'Alice';
  LFields[1].Name := 'age';
  LFields[1].Value := '30';
  LFields[2].Name := 'city';
  LFields[2].Value := 'NYC';
  LEncoded := EncodeUrlEncodedForm(LFields);
  CheckEqual('name=Alice&age=30&city=NYC', LEncoded, 'basic encode');
end;

procedure TestEncodeUrlEncodedEmpty;
var
  LFields: TFormFieldArray;
begin
  SetLength(LFields, 0);
  CheckEqual('', EncodeUrlEncodedForm(LFields), 'empty fields');
end;

procedure TestEncodeUrlEncodedSpecialChars;
var
  LFields: TFormFieldArray;
  LEncoded: string;
begin
  SetLength(LFields, 1);
  LFields[0].Name := 'q';
  LFields[0].Value := 'hello world&test=1';
  LEncoded := EncodeUrlEncodedForm(LFields);
  Check(LEncoded = 'q=hello+world%26test%3D1', 'special chars encoded: ' + LEncoded);
end;

procedure TestEncodeUrlEncodedRoundtrip;
var
  LOriginal: TFormFieldArray;
  LEncoded: string;
  LDecoded: TFormFieldArray;
begin
  SetLength(LOriginal, 2);
  LOriginal[0].Name := 'key';
  LOriginal[0].Value := 'value with spaces & special=chars';
  LOriginal[1].Name := 'num';
  LOriginal[1].Value := '42';
  LEncoded := EncodeUrlEncodedForm(LOriginal);
  LDecoded := ParseUrlEncodedForm(LEncoded);
  CheckEqual(2, Length(LDecoded), 'roundtrip field count');
  CheckEqual(LOriginal[0].Name, LDecoded[0].Name, 'roundtrip name 0');
  CheckEqual(LOriginal[0].Value, LDecoded[0].Value, 'roundtrip value 0');
  CheckEqual(LOriginal[1].Name, LDecoded[1].Name, 'roundtrip name 1');
  CheckEqual(LOriginal[1].Value, LDecoded[1].Value, 'roundtrip value 1');
end;

procedure TestEncodeMultipartBasic;
var
  LFields: TFormFieldArray;
  LEncoded: string;
begin
  SetLength(LFields, 2);
  LFields[0].Name := 'username';
  LFields[0].Value := 'alice';
  LFields[1].Name := 'email';
  LFields[1].Value := 'alice@example.com';
  LEncoded := EncodeMultipartFormData(LFields, nil, 'testboundary');
  Check(Pos('--testboundary' + #13#10, LEncoded) > 0, 'has boundary start');
  Check(Pos('Content-Disposition: form-data; name="username"' + #13#10, LEncoded) > 0, 'has username disposition');
  Check(Pos(#13#10 + 'alice' + #13#10, LEncoded) > 0, 'has username value');
  Check(Pos('Content-Disposition: form-data; name="email"' + #13#10, LEncoded) > 0, 'has email disposition');
  Check(Pos('--testboundary--', LEncoded) > 0, 'has boundary end');
end;

procedure TestEncodeMultipartWithFile;
var
  LFields: TFormFieldArray;
  LFiles: THttpFileArray;
  LEncoded: string;
begin
  SetLength(LFields, 1);
  LFields[0].Name := 'desc';
  LFields[0].Value := 'My file';
  SetLength(LFiles, 1);
  LFiles[0].FieldName := 'upload';
  LFiles[0].FileName := 'test.txt';
  LFiles[0].ContentType := 'text/plain';
  LFiles[0].Content := 'file content';
  LEncoded := EncodeMultipartFormData(LFields, LFiles, 'myboundary');
  Check(Pos('name="desc"', LEncoded) > 0, 'has field disposition');
  Check(Pos('name="upload"; filename="test.txt"', LEncoded) > 0, 'has file disposition');
  Check(Pos('Content-Type: text/plain' + #13#10, LEncoded) > 0, 'has file content type');
  Check(Pos('file content', LEncoded) > 0, 'has file content');
end;

procedure TestEncodeMultipartRoundtrip;
var
  LFields: TFormFieldArray;
  LFiles: THttpFileArray;
  LEncoded: string;
  LDecoded: TMultipartFormData;
begin
  SetLength(LFields, 1);
  LFields[0].Name := 'name';
  LFields[0].Value := 'test value';
  SetLength(LFiles, 1);
  LFiles[0].FieldName := 'doc';
  LFiles[0].FileName := 'readme.txt';
  LFiles[0].ContentType := 'text/plain';
  LFiles[0].Content := 'hello world';
  LEncoded := EncodeMultipartFormData(LFields, LFiles, 'roundtrip');
  LDecoded := ParseMultipartFormData(LEncoded, 'roundtrip');
  CheckEqual(1, LDecoded.FieldCount, 'roundtrip field count');
  CheckEqual('name', LDecoded.Fields[0].Name, 'roundtrip field name');
  CheckEqual('test value', LDecoded.Fields[0].Value, 'roundtrip field value');
  CheckEqual(1, LDecoded.FileCount, 'roundtrip file count');
  CheckEqual('doc', LDecoded.Files[0].FieldName, 'roundtrip file field name');
  CheckEqual('readme.txt', LDecoded.Files[0].FileName, 'roundtrip file name');
  CheckEqual('text/plain', LDecoded.Files[0].ContentType, 'roundtrip file content type');
  CheckEqual('hello world', LDecoded.Files[0].Content, 'roundtrip file content');
end;

procedure TestParseMultipartFromReaderRoundtrip;
var
  LBody, LBoundary: string;
  LBytes: TBytes;
  LStream: IStream;
  LOpts: TMultipartParseOptions;
  LData: TMultipartFormData;
  LPos: Int64;
begin
  LBoundary := 'boundary';
  LBody :=
    '--boundary' + #13#10 +
    'Content-Disposition: form-data; name="username"' + #13#10 +
    #13#10 +
    'alice' + #13#10 +
    '--boundary--' + #13#10;
  LBytes := StringToBytes(LBody);
  LStream := CreateBytesStreamFrom(LBytes);
  LOpts := MultipartParseOptionsDefault;
  LData := ParseMultipartFormDataFromReader(LStream as IReader, LBoundary, LOpts);
  CheckEqual(1, LData.FieldCount, 'from-reader field count');
  CheckEqual('alice', LData.GetField('username'), 'from-reader field value');
  { Caller still owns the stream: position is at EOF after full read, stream usable. }
  LPos := LStream.GetPosition;
  CheckEqual(Int64(Length(LBytes)), LPos, 'reader fully consumed but not closed by parse');
end;

procedure TestParseMultipartFromReaderMaxBytes;
var
  LBody: string;
  LBytes: TBytes;
  LStream: IStream;
  LOpts: TMultipartParseOptions;
  LCaught: Boolean;
begin
  LBody :=
    '--boundary' + #13#10 +
    'Content-Disposition: form-data; name="x"' + #13#10 +
    #13#10 +
    'hello-world-payload' + #13#10 +
    '--boundary--' + #13#10;
  LBytes := StringToBytes(LBody);
  LStream := CreateBytesStreamFrom(LBytes);
  LOpts.MaxBytes := 8;
  LCaught := False;
  try
    ParseMultipartFormDataFromReader(LStream as IReader, 'boundary', LOpts);
    Check(False, 'oversize body must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekBody) and (E.Op = 'multipart');
  end;
  Check(LCaught, 'MaxBytes exceed is hekBody Op=multipart');
end;

procedure TestParseMultipartFromReaderNilAndBoundary;
var
  LOpts: TMultipartParseOptions;
  LCaught: Boolean;
  LStream: IStream;
  LBytes: TBytes;
begin
  LOpts := MultipartParseOptionsDefault;
  LCaught := False;
  try
    ParseMultipartFormDataFromReader(nil, 'b', LOpts);
    Check(False, 'nil reader must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (E.Op = 'multipart');
  end;
  Check(LCaught, 'nil reader is hekArgument Op=multipart');

  SetLength(LBytes, 0);
  LStream := CreateBytesStreamFrom(LBytes);
  LCaught := False;
  try
    ParseMultipartFormDataFromReader(LStream as IReader, '', LOpts);
    Check(False, 'empty boundary must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (E.Op = 'multipart');
  end;
  Check(LCaught, 'empty boundary is hekArgument Op=multipart');

  LOpts.MaxBytes := 0;
  LCaught := False;
  try
    ParseMultipartFormDataFromReader(LStream as IReader, 'b', LOpts);
    Check(False, 'MaxBytes<=0 must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (E.Op = 'multipart');
  end;
  Check(LCaught, 'MaxBytes<=0 is hekArgument Op=multipart');
end;

procedure TestMultipartParseOptionsDefaultValue;
var
  LOpts: TMultipartParseOptions;
begin
  LOpts := MultipartParseOptionsDefault;
  CheckEqual(HTTP_DEFAULT_MULTIPART_MAX_BYTES, LOpts.MaxBytes,
    'default MaxBytes is 4 MiB');
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
  T.Test('Encode URL-encoded: basic', @TestEncodeUrlEncodedBasic);
  T.Test('Encode URL-encoded: empty', @TestEncodeUrlEncodedEmpty);
  T.Test('Encode URL-encoded: special chars', @TestEncodeUrlEncodedSpecialChars);
  T.Test('Encode URL-encoded: roundtrip', @TestEncodeUrlEncodedRoundtrip);
  T.Test('Encode Multipart: basic', @TestEncodeMultipartBasic);
  T.Test('Encode Multipart: with file', @TestEncodeMultipartWithFile);
  T.Test('Encode Multipart: roundtrip', @TestEncodeMultipartRoundtrip);
  T.Test('Multipart FromReader: roundtrip + caller owns stream', @TestParseMultipartFromReaderRoundtrip);
  T.Test('Multipart FromReader: MaxBytes hekBody Op=multipart', @TestParseMultipartFromReaderMaxBytes);
  T.Test('Multipart FromReader: nil/boundary/MaxBytes args', @TestParseMultipartFromReaderNilAndBoundary);
  T.Test('MultipartParseOptionsDefault MaxBytes', @TestMultipartParseOptionsDefaultValue);
  if not T.Run then Halt(1);
end.
