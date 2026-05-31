unit nextpas.core.http.url;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base;

type
  TQueryParam = record
    Name: string;
    Value: string;
  end;
  TQueryParams = array of TQueryParam;

function UrlEncode(const AStr: string): string;
function UrlDecode(const AStr: string): string;
function ParseQueryString(const AQuery: string): TQueryParams;
function EncodeQueryString(const AParams: TQueryParams): string;
function QueryParamValue(const AParams: TQueryParams; const AName: string): string;
function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;

implementation

const
  CHexDigits: array[0..15] of Char = '0123456789ABCDEF';

function IsUnreserved(const ACh: Char): Boolean; inline;
begin
  case ACh of
    'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~':
      Result := True;
  else
    Result := False;
  end;
end;

function HexVal(const ACh: Char): Integer; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function UrlEncode(const AStr: string): string;
var
  LI, LJ, LLen: SizeInt;
  LByte: Byte;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  SetLength(Result, LLen * 3);
  LJ := 1;
  for LI := 1 to LLen do
  begin
    if IsUnreserved(AStr[LI]) then
    begin
      Result[LJ] := AStr[LI];
      Inc(LJ);
    end
    else
    begin
      LByte := Byte(Ord(AStr[LI]));
      Result[LJ]     := '%';
      Result[LJ + 1] := CHexDigits[LByte shr 4];
      Result[LJ + 2] := CHexDigits[LByte and $0F];
      Inc(LJ, 3);
    end;
  end;
  SetLength(Result, LJ - 1);
end;

function UrlDecode(const AStr: string): string;
var
  LI, LJ, LLen: SizeInt;
  LHi, LLo: Integer;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  SetLength(Result, LLen);
  LI := 1;
  LJ := 1;
  while LI <= LLen do
  begin
    if AStr[LI] = '%' then
    begin
      if LI + 2 > LLen then
        raise EHttpError.Create('Invalid percent-encoding: incomplete sequence');
      LHi := HexVal(AStr[LI + 1]);
      LLo := HexVal(AStr[LI + 2]);
      if (LHi < 0) or (LLo < 0) then
        raise EHttpError.Create('Invalid percent-encoding: non-hex digit');
      Result[LJ] := Char((LHi shl 4) or LLo);
      Inc(LI, 3);
    end
    else if AStr[LI] = '+' then
    begin
      Result[LJ] := ' ';
      Inc(LI);
    end
    else
    begin
      Result[LJ] := AStr[LI];
      Inc(LI);
    end;
    Inc(LJ);
  end;
  SetLength(Result, LJ - 1);
end;

function ParseQueryString(const AQuery: string): TQueryParams;
var
  LI, LStart, LLen: SizeInt;
  LPair: string;
  LEqPos: SizeInt;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  LCount := 0;
  if AQuery = '' then
    Exit;

  LLen := Length(AQuery);
  LCap := 1;
  for LI := 1 to LLen do
    if AQuery[LI] = '&' then Inc(LCap);
  SetLength(Result, LCap);

  LStart := 1;
  LI := 1;
  while LI <= LLen + 1 do
  begin
    if (LI > LLen) or (AQuery[LI] = '&') then
    begin
      LPair := Copy(AQuery, LStart, LI - LStart);
      if LPair <> '' then
      begin
        LEqPos := Pos('=', LPair);
        if LEqPos > 0 then
        begin
          Result[LCount].Name := UrlDecode(Copy(LPair, 1, LEqPos - 1));
          Result[LCount].Value := UrlDecode(Copy(LPair, LEqPos + 1, Length(LPair) - LEqPos));
        end
        else
        begin
          Result[LCount].Name := UrlDecode(LPair);
          Result[LCount].Value := '';
        end;
        Inc(LCount);
      end;
      LStart := LI + 1;
    end;
    Inc(LI);
  end;
  SetLength(Result, LCount);
end;

function EncodeQueryString(const AParams: TQueryParams): string;
var
  LI: SizeInt;
begin
  Result := '';
  for LI := 0 to High(AParams) do
  begin
    if LI > 0 then
      Result := Result + '&';
    Result := Result + UrlEncode(AParams[LI].Name) + '=' + UrlEncode(AParams[LI].Value);
  end;
end;

function QueryParamValue(const AParams: TQueryParams; const AName: string): string;
var
  LI: SizeInt;
begin
  for LI := 0 to High(AParams) do
    if AParams[LI].Name = AName then
    begin
      Result := AParams[LI].Value;
      Exit;
    end;
  Result := '';
end;

function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;
var
  LI: SizeInt;
begin
  for LI := 0 to High(AParams) do
    if AParams[LI].Name = AName then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

end.
