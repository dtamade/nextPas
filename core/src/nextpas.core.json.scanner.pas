unit nextpas.core.json.scanner;

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
  nextpas.core.simd.vec16
{$IFDEF HAS_AVX2}
  , nextpas.core.simd.vec32
{$ENDIF}
  ;

function PrefixXor16(M: TMask16): TMask16; inline;
begin
  M := M xor (M shl 1);
  M := M xor (M shl 2);
  M := M xor (M shl 4);
  M := M xor (M shl 8);
  Result := M;
end;

{$IFDEF HAS_AVX2}
function PrefixXor32(M: TMask32): TMask32; inline;
begin
  M := M xor (M shl 1);
  M := M xor (M shl 2);
  M := M xor (M shl 4);
  M := M xor (M shl 8);
  M := M xor (M shl 16);
  Result := M;
end;
{$ENDIF}

procedure TJsonStructScanner.Init(const AData: PAnsiChar; const ALen: SizeUInt);
begin
  FInput := AData;
  FLen := ALen;
  FScanPos := 0;
  FHead := 0;
  FTail := 0;
  FInString := False;
end;

procedure TJsonStructScanner.FillBuffer;
var
  LQuote, LBs, LEscaped, LRealQuotes, LInStr, LStruct, LResult: TMask16;
  LBit: Int32;
  LCarry: TMask16;
{$IFDEF HAS_AVX2}
  LQ32, LB32, LE32, LRQ32, LIS32, LS32, LR32: TMask32;
  LCarry32: TMask32;
  LBit32: Int32;
{$ENDIF}
begin
{$IFDEF HAS_AVX2}
  while (Byte(FTail - FHead) < 128) and (FScanPos + 32 <= FLen) do
  begin
    LQ32 := Vec32CmpEq(@FInput[FScanPos], Ord('"'));
    LB32 := Vec32CmpEq(@FInput[FScanPos], Ord('\'));
    LE32 := LB32 shl 1;
    LRQ32 := LQ32 and (not LE32);
    if FInString then LCarry32 := MASK32_ALL_SET else LCarry32 := MASK32_NONE_SET;
    LIS32 := PrefixXor32(LRQ32) xor LCarry32;
    FInString := (LIS32 shr 31) <> 0;
    LS32 := Vec32CmpEq(@FInput[FScanPos], Ord('{')) or
            Vec32CmpEq(@FInput[FScanPos], Ord('}')) or
            Vec32CmpEq(@FInput[FScanPos], Ord('[')) or
            Vec32CmpEq(@FInput[FScanPos], Ord(']')) or
            Vec32CmpEq(@FInput[FScanPos], Ord(':')) or
            Vec32CmpEq(@FInput[FScanPos], Ord(','));
    LR32 := (LS32 and (not LIS32)) or (LQ32 and (not LE32));
    while LR32 <> MASK32_NONE_SET do
    begin
      LBit32 := Vec32Ctz(LR32);
      FBuf[FTail] := UInt32(FScanPos) + UInt32(LBit32);
      Inc(FTail);
      LR32 := LR32 and (LR32 - 1);
    end;
    Inc(FScanPos, 32);
  end;
{$ENDIF}
  while (Byte(FTail - FHead) < 128) and (FScanPos + 16 <= FLen) do
  begin
    LQuote := Vec16CmpEq(@FInput[FScanPos], Ord('"'));
    LBs := Vec16CmpEq(@FInput[FScanPos], Ord('\'));
    LEscaped := LBs shl 1;
    LRealQuotes := LQuote and (not LEscaped);
    if FInString then LCarry := MASK16_ALL_SET else LCarry := MASK16_NONE_SET;
    LInStr := PrefixXor16(LRealQuotes) xor LCarry;
    FInString := (LInStr shr 15) <> 0;
    LStruct := Vec16CmpEq(@FInput[FScanPos], Ord('{')) or
               Vec16CmpEq(@FInput[FScanPos], Ord('}')) or
               Vec16CmpEq(@FInput[FScanPos], Ord('[')) or
               Vec16CmpEq(@FInput[FScanPos], Ord(']')) or
               Vec16CmpEq(@FInput[FScanPos], Ord(':')) or
               Vec16CmpEq(@FInput[FScanPos], Ord(','));
    LResult := (LStruct and (not LInStr)) or (LQuote and (not LEscaped));
    while LResult <> MASK16_NONE_SET do
    begin
      LBit := Vec16Ctz(LResult);
      FBuf[FTail] := UInt32(FScanPos) + UInt32(LBit);
      Inc(FTail);
      LResult := LResult and (LResult - 1);
    end;
    Inc(FScanPos, 16);
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
