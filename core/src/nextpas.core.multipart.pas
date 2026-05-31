unit nextpas.core.multipart;
{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.multipart.base;

type
  TMultipartHeader = nextpas.core.multipart.base.TMultipartHeader;
  TMultipartHeaderArray = nextpas.core.multipart.base.TMultipartHeaderArray;
  TMultipartPart = nextpas.core.multipart.base.TMultipartPart;
  TMultipartPartArray = nextpas.core.multipart.base.TMultipartPartArray;

function MultipartExtractBoundary(const AContentType: string): string;
function TryMultipartExtractBoundary(const AContentType: string; out ABoundary: string): Boolean;
function ParseMultipart(const ABody: TBytes; const ABoundary: string): TMultipartPartArray;
function TryParseMultipart(const ABody: TBytes; const ABoundary: string; out AParts: TMultipartPartArray): Boolean;
function ParseMultipartFormData(const ABody: TBytes; const AContentType: string): TMultipartPartArray;

implementation

{ --- Internal helpers --- }

function TrimStr(const S: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] <= ' ') do
    Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] <= ' ') do
    Dec(LEnd);
  Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function LowerChar(C: Char): Char; inline;
begin
  if (C >= 'A') and (C <= 'Z') then
    Result := Char(Ord(C) + 32)
  else
    Result := C;
end;

function CaseInsensitiveEqual(const A, B: string): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  for I := 1 to Length(A) do
    if LowerChar(A[I]) <> LowerChar(B[I]) then
      Exit(False);
  Result := True;
end;

function CaseInsensitiveStartsWith(const AStr, APrefix: string): Boolean;
var
  I: Integer;
begin
  if Length(AStr) < Length(APrefix) then
    Exit(False);
  for I := 1 to Length(APrefix) do
    if LowerChar(AStr[I]) <> LowerChar(APrefix[I]) then
      Exit(False);
  Result := True;
end;

{ Find byte sequence in TBytes starting at AStart }
function FindBytes(const AData: TBytes; AStart: SizeUInt; const APattern: TBytes): SizeInt;
var
  LDataLen, LPatLen: SizeUInt;
  I, J: SizeUInt;
  LMatch: Boolean;
begin
  LDataLen := Length(AData);
  LPatLen := Length(APattern);
  if (LPatLen = 0) or (LDataLen < LPatLen) then
    Exit(-1);
  if AStart + LPatLen > LDataLen then
    Exit(-1);
  for I := AStart to LDataLen - LPatLen do
  begin
    LMatch := True;
    for J := 0 to LPatLen - 1 do
      if AData[I + J] <> APattern[J] then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
      Exit(SizeInt(I));
  end;
  Result := -1;
end;

function StringToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Byte(S[I]);
end;

{ Extract quoted or unquoted parameter value from header }
function ExtractParam(const AHeader: string; const AParamName: string): string;
var
  LPos, LStart, LEnd, LLen: Integer;
  LLower, LSearch: string;
begin
  Result := '';
  LLen := Length(AHeader);
  SetLength(LLower, LLen);
  for LPos := 1 to LLen do
    LLower[LPos] := LowerChar(AHeader[LPos]);

  LSearch := LowerChar(AParamName[1]);
  for LPos := 2 to Length(AParamName) do
    LSearch := LSearch + LowerChar(AParamName[LPos]);
  LSearch := LSearch + '=';

  LPos := Pos(LSearch, LLower);
  if LPos = 0 then
    Exit;

  LStart := LPos + Length(LSearch);
  if LStart > LLen then
    Exit;

  if AHeader[LStart] = '"' then
  begin
    Inc(LStart);
    LEnd := LStart;
    while (LEnd <= LLen) and (AHeader[LEnd] <> '"') do
      Inc(LEnd);
    Result := Copy(AHeader, LStart, LEnd - LStart);
  end
  else
  begin
    LEnd := LStart;
    while (LEnd <= LLen) and (AHeader[LEnd] <> ';') and (AHeader[LEnd] <> ' ') do
      Inc(LEnd);
    Result := Copy(AHeader, LStart, LEnd - LStart);
  end;
end;

{ Parse headers from a part's header section (bytes) }
procedure ParsePartHeaders(const AData: TBytes; AStart, AEnd: SizeUInt;
  out AHeaders: TMultipartHeaderArray; out AName, AFileName, AContentType: string);
var
  LLine: string;
  LLineStart, LPos: SizeUInt;
  LColonPos: Integer;
  LHeaderName, LHeaderValue: string;
  LCount: Integer;
begin
  AName := '';
  AFileName := '';
  AContentType := '';
  LCount := 0;
  SetLength(AHeaders, 0);
  LLineStart := AStart;

  while LLineStart < AEnd do
  begin
    LPos := LLineStart;
    while (LPos + 1 <= AEnd) and not ((AData[LPos] = 13) and (AData[LPos + 1] = 10)) do
      Inc(LPos);

    { Build line string }
    SetLength(LLine, LPos - LLineStart);
    if Length(LLine) > 0 then
      Move(AData[LLineStart], LLine[1], LPos - LLineStart);

    if LLine = '' then
      Break;

    LColonPos := Pos(':', LLine);
    if LColonPos > 0 then
    begin
      LHeaderName := TrimStr(Copy(LLine, 1, LColonPos - 1));
      LHeaderValue := TrimStr(Copy(LLine, LColonPos + 1, Length(LLine) - LColonPos));

      Inc(LCount);
      SetLength(AHeaders, LCount);
      AHeaders[LCount - 1].Name := LHeaderName;
      AHeaders[LCount - 1].Value := LHeaderValue;

      if CaseInsensitiveEqual(LHeaderName, 'Content-Disposition') then
      begin
        AName := ExtractParam(LHeaderValue, 'name');
        AFileName := ExtractParam(LHeaderValue, 'filename');
      end
      else if CaseInsensitiveEqual(LHeaderName, 'Content-Type') then
        AContentType := TrimStr(LHeaderValue);
    end;

    { Skip CRLF }
    if (LPos + 1 < AEnd) and (AData[LPos] = 13) and (AData[LPos + 1] = 10) then
      LLineStart := LPos + 2
    else
      Break;
  end;
end;

{ --- Public API --- }

function MultipartExtractBoundary(const AContentType: string): string;
var
  LOk: Boolean;
begin
  LOk := TryMultipartExtractBoundary(AContentType, Result);
  if not LOk then
    raise Exception.Create('No boundary found in Content-Type');
end;

function TryMultipartExtractBoundary(const AContentType: string; out ABoundary: string): Boolean;
begin
  ABoundary := ExtractParam(AContentType, 'boundary');
  Result := ABoundary <> '';
end;

function ParseMultipart(const ABody: TBytes; const ABoundary: string): TMultipartPartArray;
var
  LOk: Boolean;
begin
  LOk := TryParseMultipart(ABody, ABoundary, Result);
  if not LOk then
    raise Exception.Create('Failed to parse multipart body');
end;

function TryParseMultipart(const ABody: TBytes; const ABoundary: string; out AParts: TMultipartPartArray): Boolean;
var
  LDelim: TBytes;
  LCrLfDelim: TBytes;
  LPos, LNextPos: SizeInt;
  LHeaderEnd: SizeInt;
  LBodyStart, LBodyEnd: SizeUInt;
  LCount: Integer;
  LHeaders: TMultipartHeaderArray;
  LName, LFileName, LContentType: string;
  LCrLfCrLf: TBytes;
begin
  SetLength(AParts, 0);
  if Length(ABody) = 0 then
    Exit(False);
  if ABoundary = '' then
    Exit(False);

  LDelim := StringToBytes('--' + ABoundary);
  { CRLF-anchored delimiter for subsequent boundaries }
  LCrLfDelim := StringToBytes(#13#10 + '--' + ABoundary);
  SetLength(LCrLfCrLf, 4);
  LCrLfCrLf[0] := 13; LCrLfCrLf[1] := 10; LCrLfCrLf[2] := 13; LCrLfCrLf[3] := 10;

  { Find first delimiter (must be at start of body or after CRLF) }
  LPos := FindBytes(ABody, 0, LDelim);
  if LPos < 0 then
    Exit(False);
  { First delimiter must be at position 0 or preceded by CRLF }
  if (LPos <> 0) and not ((LPos >= 2) and (ABody[LPos - 2] = 13) and (ABody[LPos - 1] = 10)) then
    Exit(False);

  { Skip past first delimiter + CRLF }
  LPos := LPos + SizeInt(Length(LDelim));
  if (LPos + 1 < SizeInt(Length(ABody))) and (ABody[LPos] = 13) and (ABody[LPos + 1] = 10) then
    Inc(LPos, 2);

  LCount := 0;
  while LPos < SizeInt(Length(ABody)) do
  begin
    { Find next CRLF-anchored delimiter }
    LNextPos := FindBytes(ABody, LPos, LCrLfDelim);
    if LNextPos < 0 then
      Break;

    { The part data is from LPos to LNextPos (CRLF before delimiter is part of delimiter) }
    LBodyEnd := SizeUInt(LNextPos);

    { Find header/body separator (CRLFCRLF) }
    LHeaderEnd := FindBytes(ABody, LPos, LCrLfCrLf);
    if (LHeaderEnd >= 0) and (SizeUInt(LHeaderEnd) < LBodyEnd) then
    begin
      LBodyStart := SizeUInt(LHeaderEnd) + 4;
      ParsePartHeaders(ABody, LPos, SizeUInt(LHeaderEnd), LHeaders, LName, LFileName, LContentType);
    end
    else
    begin
      { No headers, entire content is body }
      LBodyStart := LPos;
      SetLength(LHeaders, 0);
      LName := '';
      LFileName := '';
      LContentType := '';
    end;

    Inc(LCount);
    SetLength(AParts, LCount);
    AParts[LCount - 1].Name := LName;
    AParts[LCount - 1].FileName := LFileName;
    AParts[LCount - 1].ContentType := LContentType;
    AParts[LCount - 1].Headers := LHeaders;

    { Copy body bytes }
    if LBodyEnd > LBodyStart then
    begin
      SetLength(AParts[LCount - 1].Body, LBodyEnd - LBodyStart);
      Move(ABody[LBodyStart], AParts[LCount - 1].Body[0], LBodyEnd - LBodyStart);
    end
    else
      SetLength(AParts[LCount - 1].Body, 0);

    { Move past CRLF + delimiter }
    LPos := LNextPos + SizeInt(Length(LCrLfDelim));

    { Check if this is the end delimiter }
    if (LPos + 1 < SizeInt(Length(ABody))) and (ABody[LPos] = Ord('-')) and (ABody[LPos + 1] = Ord('-')) then
      Break;

    { Skip CRLF after delimiter }
    if (LPos + 1 < SizeInt(Length(ABody))) and (ABody[LPos] = 13) and (ABody[LPos + 1] = 10) then
      Inc(LPos, 2);
  end;

  Result := LCount > 0;
end;

function ParseMultipartFormData(const ABody: TBytes; const AContentType: string): TMultipartPartArray;
var
  LBoundary: string;
begin
  LBoundary := MultipartExtractBoundary(AContentType);
  Result := ParseMultipart(ABody, LBoundary);
end;

end.
