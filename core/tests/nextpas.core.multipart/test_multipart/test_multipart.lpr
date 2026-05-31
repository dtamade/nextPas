program test_multipart;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.multipart.base,
  nextpas.core.multipart;

var
  T: TTestRunner;

function MakeBody(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Byte(S[I]);
end;

procedure TestExtractBoundary;
var
  LBoundary: string;
begin
  LBoundary := MultipartExtractBoundary('multipart/form-data; boundary=abc123');
  CheckEqual('abc123', LBoundary, 'simple boundary');
end;

procedure TestExtractBoundaryQuoted;
var
  LBoundary: string;
begin
  LBoundary := MultipartExtractBoundary('multipart/form-data; boundary="my-boundary"');
  CheckEqual('my-boundary', LBoundary, 'quoted boundary');
end;

procedure TestTryExtractBoundaryMissing;
var
  LBoundary: string;
  LOk: Boolean;
begin
  LOk := TryMultipartExtractBoundary('text/plain', LBoundary);
  CheckEqual(False, LOk, 'no boundary');
end;

procedure TestParseSingleTextField;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  LStr: string;
begin
  LBody := MakeBody(
    '--boundary' + #13#10 +
    'Content-Disposition: form-data; name="field1"' + #13#10 +
    #13#10 +
    'value1' + #13#10 +
    '--boundary--' + #13#10);
  LParts := ParseMultipart(LBody, 'boundary');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'count');
  CheckEqual('field1', LParts[0].Name, 'name');
  CheckEqual('', LParts[0].FileName, 'no filename');
  CheckEqual(Int64(6), Int64(Length(LParts[0].Body)), 'body length');
  SetLength(LStr, Length(LParts[0].Body));
  Move(LParts[0].Body[0], LStr[1], Length(LParts[0].Body));
  CheckEqual('value1', LStr, 'body');
end;

procedure TestParseMultipleFields;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
begin
  LBody := MakeBody(
    '--sep' + #13#10 +
    'Content-Disposition: form-data; name="a"' + #13#10 +
    #13#10 +
    'alpha' + #13#10 +
    '--sep' + #13#10 +
    'Content-Disposition: form-data; name="b"' + #13#10 +
    #13#10 +
    'beta' + #13#10 +
    '--sep' + #13#10 +
    'Content-Disposition: form-data; name="c"' + #13#10 +
    #13#10 +
    'gamma' + #13#10 +
    '--sep--' + #13#10);
  LParts := ParseMultipart(LBody, 'sep');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'count');
  CheckEqual('a', LParts[0].Name, 'name 0');
  CheckEqual('b', LParts[1].Name, 'name 1');
  CheckEqual('c', LParts[2].Name, 'name 2');
end;

procedure TestParseFileUpload;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  LExpected: string;
begin
  LBody := MakeBody(
    '--XYZZY' + #13#10 +
    'Content-Disposition: form-data; name="file"; filename="test.txt"' + #13#10 +
    'Content-Type: text/plain' + #13#10 +
    #13#10 +
    'Hello, World!' + #13#10 +
    '--XYZZY--' + #13#10);
  LParts := ParseMultipart(LBody, 'XYZZY');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'count');
  CheckEqual('file', LParts[0].Name, 'name');
  CheckEqual('test.txt', LParts[0].FileName, 'filename');
  CheckEqual('text/plain', LParts[0].ContentType, 'content-type');
  LExpected := 'Hello, World!';
  CheckEqual(Int64(Length(LExpected)), Int64(Length(LParts[0].Body)), 'body length');
end;

procedure TestParseMixed;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
begin
  LBody := MakeBody(
    '--bnd' + #13#10 +
    'Content-Disposition: form-data; name="text"' + #13#10 +
    #13#10 +
    'hello' + #13#10 +
    '--bnd' + #13#10 +
    'Content-Disposition: form-data; name="upload"; filename="data.bin"' + #13#10 +
    'Content-Type: application/octet-stream' + #13#10 +
    #13#10 +
    'BINARY' + #13#10 +
    '--bnd--' + #13#10);
  LParts := ParseMultipart(LBody, 'bnd');
  CheckEqual(Int64(2), Int64(Length(LParts)), 'count');
  CheckEqual('text', LParts[0].Name, 'part 0 name');
  CheckEqual('', LParts[0].FileName, 'part 0 no filename');
  CheckEqual('upload', LParts[1].Name, 'part 1 name');
  CheckEqual('data.bin', LParts[1].FileName, 'part 1 filename');
  CheckEqual('application/octet-stream', LParts[1].ContentType, 'part 1 ct');
end;

procedure TestBinaryBodyPreservation;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  I: Integer;
  LBinData: TBytes;
begin
  { Build body with binary content containing null bytes }
  SetLength(LBinData, 5);
  LBinData[0] := 0; LBinData[1] := 1; LBinData[2] := 0; LBinData[3] := 255; LBinData[4] := 128;

  LBody := MakeBody(
    '--bin' + #13#10 +
    'Content-Disposition: form-data; name="data"' + #13#10 +
    #13#10);
  { Append binary data }
  I := Length(LBody);
  SetLength(LBody, I + Length(LBinData) + Length(MakeBody(#13#10 + '--bin--' + #13#10)));
  Move(LBinData[0], LBody[I], Length(LBinData));
  Move(MakeBody(#13#10 + '--bin--' + #13#10)[0], LBody[I + Length(LBinData)],
    Length(MakeBody(#13#10 + '--bin--' + #13#10)));

  LParts := ParseMultipart(LBody, 'bin');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'count');
  CheckEqual(Int64(5), Int64(Length(LParts[0].Body)), 'binary length');
  Check(LParts[0].Body[0] = 0, 'byte 0');
  Check(LParts[0].Body[1] = 1, 'byte 1');
  Check(LParts[0].Body[2] = 0, 'byte 2');
  Check(LParts[0].Body[3] = 255, 'byte 3');
  Check(LParts[0].Body[4] = 128, 'byte 4');
end;

procedure TestEmptyBody;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  LOk: Boolean;
begin
  SetLength(LBody, 0);
  LOk := TryParseMultipart(LBody, 'boundary', LParts);
  CheckEqual(False, LOk, 'empty body');
end;

procedure TestMissingBoundary;
var
  LBody: TBytes;
  LRaised: Boolean;
begin
  LBody := MakeBody('some data');
  LRaised := False;
  try
    ParseMultipart(LBody, '');
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'empty boundary raises');
end;

procedure TestMalformedNoBoundaryInBody;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  LOk: Boolean;
begin
  LBody := MakeBody('no boundary markers here');
  LOk := TryParseMultipart(LBody, 'missing', LParts);
  CheckEqual(False, LOk, 'no boundary in body');
end;

procedure TestParseMultipartFormData;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
begin
  LBody := MakeBody(
    '--abc' + #13#10 +
    'Content-Disposition: form-data; name="key"' + #13#10 +
    #13#10 +
    'val' + #13#10 +
    '--abc--' + #13#10);
  LParts := ParseMultipartFormData(LBody, 'multipart/form-data; boundary=abc');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'count');
  CheckEqual('key', LParts[0].Name, 'name');
end;

procedure TestBoundaryInBinaryNoFalseSplit;
var
  LBody: TBytes;
  LParts: TMultipartPartArray;
  LBinData: string;
  LStr: string;
begin
  { Binary body contains "--boundary" but NOT at start of line (no preceding CRLF) }
  LBinData := 'prefix--sep' + 'suffix';
  LBody := MakeBody(
    '--sep' + #13#10 +
    'Content-Disposition: form-data; name="data"' + #13#10 +
    #13#10 +
    LBinData + #13#10 +
    '--sep--' + #13#10);
  LParts := ParseMultipart(LBody, 'sep');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'no false split');
  SetLength(LStr, Length(LParts[0].Body));
  Move(LParts[0].Body[0], LStr[1], Length(LParts[0].Body));
  CheckEqual(LBinData, LStr, 'body preserved with embedded boundary text');
end;

begin
  T := TTestRunner.Create('nextpas.core.multipart');
  T.Run('Extract boundary', @TestExtractBoundary);
  T.Run('Extract boundary quoted', @TestExtractBoundaryQuoted);
  T.Run('Try extract boundary missing', @TestTryExtractBoundaryMissing);
  T.Run('Parse single text field', @TestParseSingleTextField);
  T.Run('Parse multiple fields', @TestParseMultipleFields);
  T.Run('Parse file upload', @TestParseFileUpload);
  T.Run('Parse mixed text+file', @TestParseMixed);
  T.Run('Binary body preservation', @TestBinaryBodyPreservation);
  T.Run('Empty body', @TestEmptyBody);
  T.Run('Missing boundary raises', @TestMissingBoundary);
  T.Run('Malformed no boundary in body', @TestMalformedNoBoundaryInBody);
  T.Run('ParseMultipartFormData', @TestParseMultipartFormData);
  T.Run('Boundary in binary no false split', @TestBoundaryInBinaryNoFalseSplit);
  T.Summary;
end.
