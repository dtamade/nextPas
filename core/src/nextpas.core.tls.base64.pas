unit nextpas.core.tls.base64;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface


type
  EBase64Error = class(Exception);

  TBase64Utils = class
  private
    class function Base64Index(AChar: Char): Integer; static;
  public
    class function Encode(const AData: TBytes): string; static;
    class function Decode(const ABase64: string): TBytes; static;
    class function TryDecode(const ABase64: string; out AData: TBytes): Boolean; static;
  end;

implementation

const
  BASE64_ALPHABET: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

class function TBase64Utils.Base64Index(AChar: Char): Integer;
begin
  if (AChar >= 'A') and (AChar <= 'Z') then
    Exit(Ord(AChar) - Ord('A'));

  if (AChar >= 'a') and (AChar <= 'z') then
    Exit(Ord(AChar) - Ord('a') + 26);

  if (AChar >= '0') and (AChar <= '9') then
    Exit(Ord(AChar) - Ord('0') + 52);

  if AChar = '+' then
    Exit(62);

  if AChar = '/' then
    Exit(63);

  Result := -1;
end;

class function TBase64Utils.Encode(const AData: TBytes): string;
var
  LLen: Integer;
  I: Integer;
  O: Integer;
  B0, B1, B2: Byte;
  HasB1, HasB2: Boolean;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit('');

  SetLength(Result, ((LLen + 2) div 3) * 4);

  I := 0;
  O := 1;
  while I < LLen do
  begin
    B0 := AData[I];
    HasB1 := (I + 1) < LLen;
    HasB2 := (I + 2) < LLen;

    if HasB1 then
      B1 := AData[I + 1]
    else
      B1 := 0;

    if HasB2 then
      B2 := AData[I + 2]
    else
      B2 := 0;

    Result[O] := BASE64_ALPHABET[B0 shr 2];
    Result[O + 1] := BASE64_ALPHABET[((B0 and $03) shl 4) or (B1 shr 4)];

    if HasB1 then
      Result[O + 2] := BASE64_ALPHABET[((B1 and $0F) shl 2) or (B2 shr 6)]
    else
      Result[O + 2] := '=';

    if HasB2 then
      Result[O + 3] := BASE64_ALPHABET[B2 and $3F]
    else
      Result[O + 3] := '=';

    Inc(I, 3);
    Inc(O, 4);
  end;
end;

class function TBase64Utils.TryDecode(const ABase64: string; out AData: TBytes): Boolean;
var
  CleanCount: Integer;
  PadCount: Integer;
  OutLen: Integer;
  I: Integer;
  C: Char;
  Last1, Last2: Char;
  G: Integer;
  Group: array[0..3] of Integer;
  OutPos: Integer;
  PaddingSeen: Boolean;
begin
  Result := False;
  SetLength(AData, 0);

  CleanCount := 0;
  Last1 := #0;
  Last2 := #0;

  for I := 1 to Length(ABase64) do
  begin
    C := ABase64[I];
    if C <= ' ' then
      Continue;

    Inc(CleanCount);
    Last2 := Last1;
    Last1 := C;
  end;

  if CleanCount = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (CleanCount mod 4) <> 0 then
    Exit;

  PadCount := 0;
  if Last1 = '=' then
  begin
    Inc(PadCount);
    if Last2 = '=' then
      Inc(PadCount);
  end;

  OutLen := (CleanCount div 4) * 3 - PadCount;
  if OutLen < 0 then
    Exit;

  SetLength(AData, OutLen);

  G := 0;
  OutPos := 0;
  PaddingSeen := False;

  for I := 1 to Length(ABase64) do
  begin
    C := ABase64[I];
    if C <= ' ' then
      Continue;

    if PaddingSeen then
      Exit;

    if C = '=' then
      Group[G] := -2
    else
    begin
      Group[G] := Base64Index(C);
      if Group[G] < 0 then
        Exit;
    end;

    Inc(G);
    if G = 4 then
    begin
      if (Group[0] < 0) or (Group[1] < 0) then
        Exit;

      if Group[2] = -2 then
      begin
        if Group[3] <> -2 then
          Exit;

        if OutPos + 1 > OutLen then
          Exit;

        AData[OutPos] := Byte((Group[0] shl 2) or (Group[1] shr 4));
        Inc(OutPos);
        PaddingSeen := True;
      end
      else if Group[3] = -2 then
      begin
        if OutPos + 2 > OutLen then
          Exit;

        AData[OutPos] := Byte((Group[0] shl 2) or (Group[1] shr 4));
        Inc(OutPos);
        AData[OutPos] := Byte(((Group[1] and $0F) shl 4) or (Group[2] shr 2));
        Inc(OutPos);
        PaddingSeen := True;
      end
      else
      begin
        if OutPos + 3 > OutLen then
          Exit;

        AData[OutPos] := Byte((Group[0] shl 2) or (Group[1] shr 4));
        Inc(OutPos);
        AData[OutPos] := Byte(((Group[1] and $0F) shl 4) or (Group[2] shr 2));
        Inc(OutPos);
        AData[OutPos] := Byte(((Group[2] and $03) shl 6) or Group[3]);
        Inc(OutPos);
      end;

      G := 0;
    end;
  end;

  if (G <> 0) or (OutPos <> OutLen) then
    Exit;

  Result := True;
end;

class function TBase64Utils.Decode(const ABase64: string): TBytes;
begin
  if not TryDecode(ABase64, Result) then
    raise EBase64Error.Create('Invalid Base64 input');
end;

end.
