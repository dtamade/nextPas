unit nextpas.core.bytes.ops.ascii;

{$I nextpas.core.settings.inc}
{ bytes.ops.ascii — ascii/xor helpers (no raw Move)
  Leaf under bytes.ops, pure pascal, inline hot tiny wrappers.
  Reuses bytes.ops single source via facade, no duplicate Move. }

interface

uses
  nextpas.core.base;

procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;
procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;

implementation

uses
  nextpas.core.base.utils;

procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
var
  LOff: SizeUInt;
begin
  if (ADst = nil) or (AKey = nil) or (ALen = 0) then
    Exit;
  LOff := 0;
  {$PUSH}{$Q-}{$R-}
  while LOff + 8 <= ALen do
  begin
    PQWord(ADst + LOff)^ := PQWord(ADst + LOff)^ xor PQWord(AKey + LOff)^;
    Inc(LOff, 8);
  end;
  while LOff < ALen do
  begin
    (ADst + LOff)^ := (ADst + LOff)^ xor (AKey + LOff)^;
    Inc(LOff);
  end;
  {$POP}
end;

procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;
begin
  if ADst.Len = 0 then
    Exit;
  if ADst.Len <> AKey.Len then
    raise EInvalidArgument.Create('SpanXorInplace: length mismatch');
  XorInplace(ADst.Data, AKey.Data, ADst.Len);
end;

procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
var
  LOff: SizeUInt;
  P: PByte;
begin
  if (AData = nil) or (ALen = 0) then
    Exit;
  for LOff := 0 to ALen - 1 do
  begin
    P := AData + LOff;
    if (P^ >= 65) and (P^ <= 90) then
      P^ := P^ + 32;
  end;
end;

procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
var
  LOff: SizeUInt;
  P: PByte;
begin
  if (AData = nil) or (ALen = 0) then
    Exit;
  for LOff := 0 to ALen - 1 do
  begin
    P := AData + LOff;
    if (P^ >= 97) and (P^ <= 122) then
      P^ := P^ - 32;
  end;
end;

procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
begin
  if ASpan.Len > 0 then
    AsciiToLowerInplace(ASpan.Data, ASpan.Len);
end;

procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;
begin
  if ASpan.Len > 0 then
    AsciiToUpperInplace(ASpan.Data, ASpan.Len);
end;

end.
