unit nextpas.core.json.scanner;
// SIMD structural character scanner for JSON parsing.
// Identifies positions of { } [ ] : , " using unified vec SIMD comparison.
// Correctly handles escaped quotes via full odd-backslash algorithm.
// Ring buffer (256 entries) filled lazily on demand.
//
// Algorithm per VecWidth-byte chunk:
// 1. CmpEq for each structural char -> OR into structural mask
// 2. Odd-backslash: find escaped positions via even/odd carry propagation
// 3. PrefixXor for in-string tracking
// 4. Filter structural chars outside strings + real quotes
// 5. Expand bitmask to position array via Ctz loop

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

procedure ClassifyJsonChunkQuotes(const AQuote, ABackslash: TVecMask;
  const AInString, APrevEscaped: Boolean; out ARealQuotes: TVecMask;
  out ANextPrevEscaped: Boolean); inline;
var
  I: Int32;
  LBit: TVecMask;
  LInString, LEscaped: Boolean;
begin
  ARealQuotes := TVecMask(0);
  LInString := AInString;
  LEscaped := APrevEscaped and AInString;

  for I := 0 to VecWidth - 1 do
  begin
    LBit := TVecMask(1) shl I;
    if not LInString then
    begin
      LEscaped := False;
      if (AQuote and LBit) <> TVecMask(0) then
      begin
        ARealQuotes := ARealQuotes or LBit;
        LInString := True;
      end;
    end
    else if LEscaped then
      LEscaped := False
    else if (ABackslash and LBit) <> TVecMask(0) then
      LEscaped := True
    else if (AQuote and LBit) <> TVecMask(0) then
    begin
      ARealQuotes := ARealQuotes or LBit;
      LInString := False;
    end;
  end;

  ANextPrevEscaped := LInString and LEscaped;
end;

procedure TJsonStructScanner.FillBuffer;
var
  LQuote, LBs, LRealQuotes, LInStr, LStruct, LResult: TVecMask;
  LBit: Int32;
  LCarry: TVecMask;
begin
  while (Byte(FTail - FHead) < 128) and (FScanPos + VecWidth <= FLen) do
  begin
    LQuote := VecCmpEq(@FInput[FScanPos], Ord('"'));
    LBs := VecCmpEq(@FInput[FScanPos], Ord('\'));
    if (LBs = TVecMask(0)) and (not FPrevEscaped) then
    begin
      LRealQuotes := LQuote;
      FPrevEscaped := False;
    end
    else
      ClassifyJsonChunkQuotes(LQuote, LBs, FInString, FPrevEscaped,
        LRealQuotes, FPrevEscaped);
    if FInString then LCarry := TVecMask(not TVecMask(0)) else LCarry := TVecMask(0);
    LInStr := PrefixXorMask(LRealQuotes) xor LCarry;
    FInString := (LInStr shr (VecWidth - 1)) <> 0;
    if (LInStr = TVecMask(not TVecMask(0))) and (LRealQuotes = TVecMask(0)) then
    begin
      Inc(FScanPos, VecWidth);
      Continue;
    end;
    LStruct := VecCmpEq(@FInput[FScanPos], Ord('{')) or
               VecCmpEq(@FInput[FScanPos], Ord('}')) or
               VecCmpEq(@FInput[FScanPos], Ord('[')) or
               VecCmpEq(@FInput[FScanPos], Ord(']')) or
               VecCmpEq(@FInput[FScanPos], Ord(':')) or
               VecCmpEq(@FInput[FScanPos], Ord(','));
    LResult := (LStruct and (not LInStr)) or LRealQuotes;
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
    if FInString then
    begin
      if FPrevEscaped then
        FPrevEscaped := False
      else if FInput[FScanPos] = '\' then
        FPrevEscaped := True
      else if FInput[FScanPos] = '"' then
      begin
        FBuf[FTail] := UInt32(FScanPos);
        Inc(FTail);
        FInString := False;
      end;
    end
    else
    begin
      FPrevEscaped := False;
      case FInput[FScanPos] of
        '"':
          begin
            FBuf[FTail] := UInt32(FScanPos);
            Inc(FTail);
            FInString := True;
          end;
        '{', '}', '[', ']', ':', ',':
          begin
            FBuf[FTail] := UInt32(FScanPos);
            Inc(FTail);
          end;
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
