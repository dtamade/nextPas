unit nextpas.core.json.scanner;
{ SIMD structural character scanner for JSON parsing.
  Identifies positions of { } [ ] : , " using unified vec SIMD comparison.
  Correctly handles escaped quotes via full odd-backslash algorithm.
  Ring buffer (256 entries) filled lazily on demand.

  Algorithm per VecWidth-byte chunk:
  1. CmpEq for each structural char -> OR into structural mask
  2. Odd-backslash: find escaped positions via even/odd carry propagation
  3. PrefixXor for in-string tracking
  4. Filter structural chars outside strings + real quotes
  5. Expand bitmask to position array via Ctz loop }

{$I nextpas.core.settings.inc}

interface

type
  TJsonStructScanner = record
  private
    FInput: PAnsiChar;
    FLen: SizeUInt;
    FScanPos: SizeUInt;
    FBuf: array[0..255] of UInt32;
    FHead: Byte;
    FTail: Byte;
    FInString: Boolean;
    FPrevEscaped: Boolean;
    procedure FillBuffer;
  public
    procedure Init(const AData: PAnsiChar; const ALen: SizeUInt);
    function Next: UInt32; inline;
    function Peek: UInt32; inline;
    function PeekChar: Byte; inline;
    function IsEmpty: Boolean; inline;
    function Available: Byte; inline;
  end;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec;

function PrefixXorMask(M: TVecMask): TVecMask; inline;
begin
  M := M xor (M shl 1);
  M := M xor (M shl 2);
  M := M xor (M shl 4);
  M := M xor (M shl 8);
  {$IF VecWidth = 32}
  M := M xor (M shl 16);
  {$ENDIF}
  Result := M;
end;

procedure TJsonStructScanner.Init(const AData: PAnsiChar; const ALen: SizeUInt);
begin
  FInput := AData;
  FLen := ALen;
  FScanPos := 0;
  FHead := 0;
  FTail := 0;
  FInString := False;
  FPrevEscaped := False;
end;

function OddBackslashEscaped(ABs: TVecMask; APrevEscaped: Boolean): TVecMask; inline;
const
  EVEN_BITS: TVecMask = TVecMask({$IF VecWidth = 32}$55555555{$ELSE}$5555{$ENDIF});
  ODD_BITS: TVecMask = TVecMask({$IF VecWidth = 32}$AAAAAAAA{$ELSE}$AAAA{$ENDIF});
var
  LStarts, LEvenStarts, LOddStarts: TVecMask;
  LEvenCarries, LOddCarries: TVecMask;
  LEvenEsc, LOddEsc, LEscaped: TVecMask;
begin
  if (ABs = TVecMask(0)) and (not APrevEscaped) then
    Exit(TVecMask(0));
  if (ABs = TVecMask(0)) and APrevEscaped then
    Exit(TVecMask(1));

  LStarts := ABs and (not (ABs shl 1));
  if APrevEscaped then
    LStarts := LStarts and not TVecMask(1);

  LEvenStarts := LStarts and EVEN_BITS;
  LOddStarts := LStarts and ODD_BITS;

  LEvenCarries := (ABs + LEvenStarts) xor ABs;
  LOddCarries := (ABs + LOddStarts) xor ABs;

  LEvenEsc := LEvenCarries and ODD_BITS and (not ABs);
  LOddEsc := LOddCarries and EVEN_BITS and (not ABs);

  LEscaped := LEvenEsc or LOddEsc;
  if APrevEscaped then
    LEscaped := LEscaped or TVecMask(1);
  Result := LEscaped;
end;

procedure TJsonStructScanner.FillBuffer;
var
  LQuote, LBs, LEscaped, LRealQuotes, LInStr, LStruct, LResult: TVecMask;
  LBit: Int32;
  LCarry: TVecMask;
begin
  while (Byte(FTail - FHead) < 128) and (FScanPos + VecWidth <= FLen) do
  begin
    LQuote := VecCmpEq(@FInput[FScanPos], Ord('"'));
    LBs := VecCmpEq(@FInput[FScanPos], Ord('\'));
    LEscaped := OddBackslashEscaped(LBs, FPrevEscaped);
    FPrevEscaped := (LEscaped shr (VecWidth - 1)) <> 0;
    LRealQuotes := LQuote and (not LEscaped);
    if FInString then LCarry := TVecMask(not TVecMask(0)) else LCarry := TVecMask(0);
    LInStr := PrefixXorMask(LRealQuotes) xor LCarry;
    FInString := (LInStr shr (VecWidth - 1)) <> 0;
    LStruct := VecCmpEq(@FInput[FScanPos], Ord('{')) or
               VecCmpEq(@FInput[FScanPos], Ord('}')) or
               VecCmpEq(@FInput[FScanPos], Ord('[')) or
               VecCmpEq(@FInput[FScanPos], Ord(']')) or
               VecCmpEq(@FInput[FScanPos], Ord(':')) or
               VecCmpEq(@FInput[FScanPos], Ord(','));
    LResult := (LStruct and (not LInStr)) or (LQuote and (not LEscaped));
    while LResult <> TVecMask(0) do
    begin
      LBit := VecCtz(LResult);
      FBuf[FTail] := UInt32(FScanPos) + UInt32(LBit);
      Inc(FTail);
      LResult := LResult and (LResult - 1);
    end;
    Inc(FScanPos, VecWidth);
  end;
  while (Byte(FTail - FHead) < 128) and (FScanPos < FLen) do
  begin
    case FInput[FScanPos] of
      '"':
        if not FInString then
        begin
          FBuf[FTail] := UInt32(FScanPos);
          Inc(FTail);
          FInString := True;
        end
        else
        begin
          FBuf[FTail] := UInt32(FScanPos);
          Inc(FTail);
          FInString := False;
        end;
      '\':
        if FInString then
        begin
          Inc(FScanPos);
        end;
      '{', '}', '[', ']', ':', ',':
        if not FInString then
        begin
          FBuf[FTail] := UInt32(FScanPos);
          Inc(FTail);
        end;
    end;
    Inc(FScanPos);
  end;
end;

function TJsonStructScanner.Next: UInt32;
begin
  if FHead = FTail then
    FillBuffer;
  if FHead = FTail then
    Exit(UInt32($FFFFFFFF));
  Result := FBuf[FHead];
  Inc(FHead);
end;

function TJsonStructScanner.Peek: UInt32;
begin
  if FHead = FTail then
    FillBuffer;
  if FHead = FTail then
    Exit(UInt32($FFFFFFFF));
  Result := FBuf[FHead];
end;

function TJsonStructScanner.PeekChar: Byte;
var
  LPos: UInt32;
begin
  LPos := Peek;
  if LPos = UInt32($FFFFFFFF) then
    Result := 0
  else
    Result := Byte(FInput[LPos]);
end;

function TJsonStructScanner.IsEmpty: Boolean;
begin
  if FHead <> FTail then
    Exit(False);
  FillBuffer;
  Result := FHead = FTail;
end;

function TJsonStructScanner.Available: Byte;
begin
  Result := FTail - FHead;
end;

end.
