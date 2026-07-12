unit nextpas.core.http.form;
{**
 * @desc HTTP form data parsing and encoding for application/x-www-form-urlencoded and multipart/form-data.
 *       Provides ParseUrlEncodedForm, ParseMultipartFormData, EncodeUrlEncodedForm, and EncodeMultipartFormData.
 *}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.form.base;

type
  TFormField = nextpas.core.http.form.base.TFormField;
  TFormFieldArray = nextpas.core.http.form.base.TFormFieldArray;
  THttpFile = nextpas.core.http.form.base.THttpFile;
  THttpFileArray = nextpas.core.http.form.base.THttpFileArray;
  TMultipartFormData = nextpas.core.http.form.base.TMultipartFormData;

{ Parse application/x-www-form-urlencoded body }
function ParseUrlEncodedForm(const ABody: string): TFormFieldArray;
function TryParseUrlEncodedForm(const ABody: string; out AFields: TFormFieldArray): Boolean;

{ Encode application/x-www-form-urlencoded body (space as +) }
function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string;

{ Parse multipart/form-data body with given boundary }
function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData;
function TryParseMultipartFormData(const ABody, ABoundary: string;
  out AData: TMultipartFormData): Boolean;

{ Encode multipart/form-data body. ABoundary is generated if empty. }
function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string = ''): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.http.url;

{ URL-decode a string, converting + to space }
function UrlDecodeForm(const S: string): string;
var
  I, Len: Integer;
  C: Char;
  H1, H2: Integer;
begin
  Result := '';
  Len := Length(S);
  I := 1;
  while I <= Len do
  begin
    C := S[I];
    if C = '+' then
    begin
      Result := Result + ' ';
      Inc(I);
    end
    else if (C = '%') and (I + 2 <= Len) then
    begin
      H1 := Pos(S[I + 1], '0123456789ABCDEFabcdef') - 1;
      H2 := Pos(S[I + 2], '0123456789ABCDEFabcdef') - 1;
      if (H1 >= 0) and (H2 >= 0) then
      begin
        if H1 > 15 then Dec(H1, 6);
        if H2 > 15 then Dec(H2, 6);
        Result := Result + Chr(H1 * 16 + H2);
        Inc(I, 3);
      end
      else
      begin
        Result := Result + C;
        Inc(I);
      end;
    end
    else
    begin
      Result := Result + C;
      Inc(I);
    end;
  end;
end;

{ Parse application/x-www-form-urlencoded }
function ParseUrlEncodedForm(const ABody: string): TFormFieldArray;
var
  LPos, LStart, LLen, LEq, LCount, LCap: Integer;
begin
  Result := nil;
  LLen := Length(ABody);
  if LLen = 0 then
    Exit;

  LCap := 4;
  SetLength(Result, LCap);
  LCount := 0;
  LStart := 1;
  LPos := 1;

  while LPos <= LLen + 1 do
  begin
    if (LPos > LLen) or (ABody[LPos] = '&') then
    begin
      if LPos > LStart then
      begin
        LEq := LStart;
        while (LEq < LPos) and (ABody[LEq] <> '=') do
          Inc(LEq);

        if LCount >= LCap then
        begin
          LCap := LCap * 2;
          SetLength(Result, LCap);
        end;

        if ABody[LEq] = '=' then
        begin
          Result[LCount].Name := UrlDecodeForm(Copy(ABody, LStart, LEq - LStart));
          Result[LCount].Value := UrlDecodeForm(Copy(ABody, LEq + 1, LPos - LEq - 1));
        end
        else
        begin
          Result[LCount].Name := UrlDecodeForm(Copy(ABody, LStart, LPos - LStart));
          Result[LCount].Value := '';
        end;
        Inc(LCount);
      end;
      if LPos > LLen then
        Break;
      LStart := LPos + 1;
    end;
    Inc(LPos);
  end;
  SetLength(Result, LCount);
end;

function TryParseUrlEncodedForm(const ABody: string; out AFields: TFormFieldArray): Boolean;
begin
  AFields := ParseUrlEncodedForm(ABody);
  Result := Length(AFields) > 0;
end;

{ Find boundary in multipart body. Returns position of '--' prefix, or 0 if not found.
  RFC 2046: boundary must be at start of line (preceded by CRLF) or at body start. }
function FindBoundary(const ABody, ABoundary: string; AStart: Integer): Integer;
var
  LBoundaryLen, LBodyLen: Integer;
begin
  LBoundaryLen := Length(ABoundary);
  LBodyLen := Length(ABody);
  Result := AStart;
  while Result <= LBodyLen - LBoundaryLen - 1 do
  begin
    if (ABody[Result] = '-') and (ABody[Result + 1] = '-') and
       (Copy(ABody, Result + 2, LBoundaryLen) = ABoundary) then
    begin
      { Boundary must be at start of line: body start or preceded by CRLF }
      if (Result = 1) or
         ((Result >= 3) and (ABody[Result - 2] = #13) and (ABody[Result - 1] = #10)) then
        Exit;
    end;
    Inc(Result);
  end;
  Result := 0;
end;

{ Parse Content-Disposition header to extract field name and filename }
procedure ParseContentDisposition(const AHeader: string;
  out AFieldName: string; out AFileName: string);
var
  LPos, LEnd: Integer;
  LKey, LVal: string;
begin
  AFieldName := '';
  AFileName := '';
  LPos := 1;
  while LPos <= Length(AHeader) do
  begin
    { Skip to next ';' or end }
    LEnd := LPos;
    while (LEnd <= Length(AHeader)) and (AHeader[LEnd] <> ';') do
      Inc(LEnd);

    LKey := Copy(AHeader, LPos, LEnd - LPos);
    { Trim leading spaces }
    while (Length(LKey) > 0) and (LKey[1] = ' ') do
      LKey := Copy(LKey, 2, Length(LKey) - 1);

    { Check for name="..." }
    if Copy(LKey, 1, 5) = 'name=' then
    begin
      LVal := Copy(LKey, 6, Length(LKey) - 5);
      if (Length(LVal) >= 2) and (LVal[1] = '"') and (LVal[Length(LVal)] = '"') then
        LVal := Copy(LVal, 2, Length(LVal) - 2);
      AFieldName := LVal;
    end
    { Check for filename="..." }
    else if Copy(LKey, 1, 9) = 'filename=' then
    begin
      LVal := Copy(LKey, 10, Length(LKey) - 9);
      if (Length(LVal) >= 2) and (LVal[1] = '"') and (LVal[Length(LVal)] = '"') then
        LVal := Copy(LVal, 2, Length(LVal) - 2);
      AFileName := LVal;
    end;

    LPos := LEnd + 1;
  end;
end;

{ Parse Content-Type header }
function ParseContentType(const AHeader: string): string;
var
  LPos: Integer;
begin
  LPos := 1;
  while (LPos <= Length(AHeader)) and (AHeader[LPos] <> ';') do
    Inc(LPos);
  Result := Copy(AHeader, 1, LPos - 1);
  { Trim trailing spaces }
  while (Length(Result) > 0) and (Result[Length(Result)] = ' ') do
    Result := Copy(Result, 1, Length(Result) - 1);
end;

{ Parse a single multipart part }
procedure ParsePart(const APart: string;
  var AFields: TFormFieldArray; var AFieldCount: Int32;
  var AFiles: THttpFileArray; var AFileCount: Int32);
var
  LHeaderEnd, LLineStart, LLineEnd: Integer;
  LLine, LDisposition, LContentType: string;
  LFieldName, LFileName: string;
  LBody: string;
begin
  LHeaderEnd := Pos(#13#10#13#10, APart);
  if LHeaderEnd = 0 then
    Exit;

  { Parse headers }
  LDisposition := '';
  LContentType := '';
  LLineStart := 1;
  while LLineStart < LHeaderEnd do
  begin
    LLineEnd := LLineStart;
    while (LLineEnd < LHeaderEnd) and
          not ((APart[LLineEnd] = #13) and (LLineEnd + 1 <= Length(APart)) and (APart[LLineEnd + 1] = #10)) do
      Inc(LLineEnd);
    LLine := Copy(APart, LLineStart, LLineEnd - LLineStart);

    if (Length(LLine) >= 21) and (Copy(LLine, 1, 21) = 'Content-Disposition: ') then
      LDisposition := Copy(LLine, 22, Length(LLine) - 21)
    else if (Length(LLine) >= 14) and (Copy(LLine, 1, 14) = 'Content-Type: ') then
      LContentType := Copy(LLine, 15, Length(LLine) - 14);

    LLineStart := LLineEnd + 2;
  end;

  { Extract body (after blank line) }
  LBody := Copy(APart, LHeaderEnd + 4, Length(APart) - LHeaderEnd - 3);
  { Remove trailing CRLF }
  if (Length(LBody) >= 2) and (LBody[Length(LBody) - 1] = #13) and
     (LBody[Length(LBody)] = #10) then
    LBody := Copy(LBody, 1, Length(LBody) - 2);

  ParseContentDisposition(LDisposition, LFieldName, LFileName);

  if LFileName <> '' then
  begin
    { It's a file upload }
    if AFileCount >= Length(AFiles) then
      SetLength(AFiles, AFileCount + 4);
    AFiles[AFileCount].FieldName := LFieldName;
    AFiles[AFileCount].FileName := LFileName;
    AFiles[AFileCount].ContentType := ParseContentType(LContentType);
    AFiles[AFileCount].Content := LBody;
    Inc(AFileCount);
  end
  else
  begin
    { It's a regular field }
    if AFieldCount >= Length(AFields) then
      SetLength(AFields, AFieldCount + 4);
    AFields[AFieldCount].Name := LFieldName;
    AFields[AFieldCount].Value := LBody;
    Inc(AFieldCount);
  end;
end;

{ Parse multipart/form-data body }
function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData;
var
  LPos, LNextPos, LBoundaryLen: Integer;
  LPart: string;
  LFieldCount, LFileCount: Int32;
begin
  Result := Default(TMultipartFormData);
  LFieldCount := 0;
  LFileCount := 0;
  SetLength(Result.Fields, 4);
  SetLength(Result.Files, 4);
  LBoundaryLen := Length(ABoundary);

  LPos := FindBoundary(ABody, ABoundary, 1);
  if LPos = 0 then
  begin
    SetLength(Result.Fields, 0);
    SetLength(Result.Files, 0);
    Exit;
  end;

  { Skip --boundary + CRLF }
  LPos := LPos + 2 + LBoundaryLen;
  if (LPos <= Length(ABody)) and (ABody[LPos] = #13) then
    Inc(LPos);
  if (LPos <= Length(ABody)) and (ABody[LPos] = #10) then
    Inc(LPos);

  while LPos <= Length(ABody) do
  begin
    LNextPos := FindBoundary(ABody, ABoundary, LPos);
    if LNextPos = 0 then
      Break;

    { Extract part: from LPos to just before CRLF+--boundary }
    if LNextPos >= LPos + 2 then
      LPart := Copy(ABody, LPos, LNextPos - LPos - 2)
    else
      LPart := '';
    ParsePart(LPart, Result.Fields, LFieldCount, Result.Files, LFileCount);

    { Skip --boundary + CRLF }
    LPos := LNextPos + 2 + LBoundaryLen;
    if (LPos <= Length(ABody)) and (ABody[LPos] = #13) then
      Inc(LPos);
    if (LPos <= Length(ABody)) and (ABody[LPos] = #10) then
      Inc(LPos);
  end;

  SetLength(Result.Fields, LFieldCount);
  SetLength(Result.Files, LFileCount);
end;

{ URL-encode for form data: space as +, unreserved chars pass through }
function FormUrlEncode(const S: string): string;
var
  I, Len, J: Integer;
  B: Byte;
const
  HEX: array[0..15] of Char = '0123456789ABCDEF';
begin
  Len := Length(S);
  if Len = 0 then
    Exit('');
  SetLength(Result, Len * 3);
  J := 1;
  for I := 1 to Len do
  begin
    B := Ord(S[I]);
    case Chr(B) of
      'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~':
        begin
          Result[J] := Chr(B);
          Inc(J);
        end;
      ' ':
        begin
          Result[J] := '+';
          Inc(J);
        end;
    else
      begin
        Result[J]     := '%';
        Result[J + 1] := HEX[B shr 4];
        Result[J + 2] := HEX[B and $0F];
        Inc(J, 3);
      end;
    end;
  end;
  SetLength(Result, J - 1);
end;

{ Encode application/x-www-form-urlencoded body }
function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string;
var
  LI, LLen: Integer;
  LParts: array of string;
begin
  LLen := Length(AFields);
  if LLen = 0 then
    Exit('');
  SetLength(LParts, LLen);
  for LI := 0 to LLen - 1 do
    LParts[LI] := FormUrlEncode(AFields[LI].Name) + '=' + FormUrlEncode(AFields[LI].Value);
  Result := LParts[0];
  for LI := 1 to LLen - 1 do
    Result := Result + '&' + LParts[LI];
end;

{ Generate a random boundary string }
function GenerateBoundary: string;
const
  CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  LI: Integer;
begin
  SetLength(Result, 36);
  for LI := 1 to 36 do
    Result[LI] := CHARS[1 + Random(Length(CHARS))];
end;

{ Validate that a string contains no CR/LF/NUL characters (injection prevention) }
function RejectCRLF(const AValue, AFieldName: string): string;
var
  LI: Integer;
begin
  for LI := 1 to Length(AValue) do
    if AValue[LI] in [#13, #10, #0] then
      raise EArgumentError.Create(
        AFieldName + ' must not contain CR/LF/NUL characters');
  Result := AValue;
end;

{ Encode multipart/form-data body }
function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string): string;
var
  LBoundary: string;
  LParts: array of string;
  LCount, LI: Integer;
  LEscapedName, LEscapedFieldName, LEscapedFileName: string;

  procedure AddPart(const S: string);
  begin
    if LCount >= Length(LParts) then
      SetLength(LParts, LCount + 8);
    LParts[LCount] := S;
    Inc(LCount);
  end;

begin
  if ABoundary <> '' then
    LBoundary := RejectCRLF(ABoundary, 'boundary')
  else
    LBoundary := GenerateBoundary;

  LCount := 0;
  SetLength(LParts, Length(AFields) + Length(AFiles) + 2);

  for LI := 0 to High(AFields) do
  begin
    { RFC 6266: Content-Disposition name needs quoted-string escaping }
    LEscapedName := RejectCRLF(AFields[LI].Name, 'field name');
    LEscapedName := StringReplace(LEscapedName, '\', '\\', True);
    LEscapedName := StringReplace(LEscapedName, '"', '\"', True);
    AddPart('--' + LBoundary + #13#10 +
            'Content-Disposition: form-data; name="' + LEscapedName + '"' + #13#10 +
            #13#10 + AFields[LI].Value + #13#10);
  end;

  for LI := 0 to High(AFiles) do
  begin
    { RFC 6266: Content-Disposition filename needs quoted-string escaping }
    LEscapedFieldName := RejectCRLF(AFiles[LI].FieldName, 'file field name');
    LEscapedFieldName := StringReplace(LEscapedFieldName, '\', '\\', True);
    LEscapedFieldName := StringReplace(LEscapedFieldName, '"', '\"', True);
    LEscapedFileName := RejectCRLF(AFiles[LI].FileName, 'file name');
    LEscapedFileName := StringReplace(LEscapedFileName, '\', '\\', True);
    LEscapedFileName := StringReplace(LEscapedFileName, '"', '\"', True);
    AddPart('--' + LBoundary + #13#10 +
            'Content-Disposition: form-data; name="' + LEscapedFieldName + '"; filename="' + LEscapedFileName + '"' + #13#10 +
            'Content-Type: ' + RejectCRLF(AFiles[LI].ContentType, 'content type') + #13#10 +
            #13#10 + AFiles[LI].Content + #13#10);
  end;

  AddPart('--' + LBoundary + '--');

  Result := LParts[0];
  for LI := 1 to LCount - 1 do
    Result := Result + LParts[LI];
end;

function TryParseMultipartFormData(const ABody, ABoundary: string;
  out AData: TMultipartFormData): Boolean;
begin
  AData := ParseMultipartFormData(ABody, ABoundary);
  Result := (AData.FieldCount > 0) or (AData.FileCount > 0);
end;

end.
