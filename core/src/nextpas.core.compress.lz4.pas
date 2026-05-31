unit nextpas.core.compress.lz4;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function Lz4Compress(const AData: TBytes): TBytes;
function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
function Lz4CompressBound(const AInputSize: SizeUInt): SizeUInt; inline;

implementation

uses
  nextpas.core.errors;

const
  LZ4_MIN_MATCH = 4;
  LZ4_HASH_LOG = 12;
  LZ4_HASH_SIZE = 1 shl LZ4_HASH_LOG;
  LZ4_MAX_INPUT_SIZE = $7E000000;

function LZ4_hash(AVal: UInt32): UInt32; inline;
var
  LMul: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LMul := UInt32(AVal * UInt32(2654435761));
  {$POP}
  Result := LMul shr (32 - LZ4_HASH_LOG);
end;

function Lz4Compress(const AData: TBytes): TBytes;
type
  THashArray = array[0..LZ4_HASH_SIZE - 1] of Int32;
  PHashArray = ^THashArray;
var
  LHashTable: PHashArray;
  LSrc, LAnchor, LEnd, LRef: Int32;
  LLen: SizeUInt;
  LDst: Int32;
  LTokenPos: Int32;
  LMatchLen, LLitLen: Int32;
  LOffset: UInt16;
  LH: UInt32;
  LML: Int32;
begin
  LLen := Length(AData);
  if (LLen = 0) or (LLen > LZ4_MAX_INPUT_SIZE) then
  begin
    Result := nil;
    Exit;
  end;

  GetMem(LHashTable, SizeOf(THashArray));
  try
    FillChar(LHashTable^[0], SizeOf(THashArray), $FF);

    SetLength(Result, LLen + (LLen div 255) + 16 + 4);
    LSrc := 0;
    LAnchor := 0;
    LEnd := Int32(LLen);
    LDst := 0;

    while LSrc + 4 < LEnd do
    begin
      LH := LZ4_hash(PUInt32(@AData[LSrc])^);
      LRef := LHashTable^[LH];
      LHashTable^[LH] := LSrc;

      if (LRef >= 0) and (LRef + 4 <= LEnd) and (LSrc - LRef < 65536) and
         (PUInt32(@AData[LRef])^ = PUInt32(@AData[LSrc])^) then
      begin
        LMatchLen := 4;
        while (LSrc + LMatchLen < LEnd) and (LRef + LMatchLen < LEnd) and
              (AData[LRef + LMatchLen] = AData[LSrc + LMatchLen]) do
          Inc(LMatchLen);

        LLitLen := LSrc - LAnchor;

        if LDst + LLitLen + LMatchLen + 16 > Length(Result) then
          SetLength(Result, (LDst + LLitLen + LMatchLen + 16) * 2);

        LTokenPos := LDst; Inc(LDst);
        if LLitLen >= 15 then
        begin
          Result[LTokenPos] := (15 shl 4);
          LML := LLitLen - 15;
          while LML >= 255 do begin Result[LDst] := 255; Inc(LDst); Dec(LML, 255); end;
          Result[LDst] := Byte(LML); Inc(LDst);
        end
        else
          Result[LTokenPos] := Byte(LLitLen shl 4);

        if LLitLen > 0 then
        begin
          Move(AData[LAnchor], Result[LDst], LLitLen);
          Inc(LDst, LLitLen);
        end;

        LOffset := UInt16(LSrc - LRef);
        Result[LDst] := Byte(LOffset); Inc(LDst);
        Result[LDst] := Byte(LOffset shr 8); Inc(LDst);

        LML := LMatchLen - LZ4_MIN_MATCH;
        if LML >= 15 then
        begin
          Result[LTokenPos] := Result[LTokenPos] or 15;
          Dec(LML, 15);
          while LML >= 255 do begin Result[LDst] := 255; Inc(LDst); Dec(LML, 255); end;
          Result[LDst] := Byte(LML); Inc(LDst);
        end
        else
          Result[LTokenPos] := Result[LTokenPos] or Byte(LML);

        Inc(LSrc, LMatchLen);
        LAnchor := LSrc;
      end
      else
        Inc(LSrc);
    end;

    LLitLen := LEnd - LAnchor;
    if LDst + LLitLen + 16 > Length(Result) then
      SetLength(Result, LDst + LLitLen + 16);
    LTokenPos := LDst; Inc(LDst);
    if LLitLen >= 15 then
    begin
      Result[LTokenPos] := (15 shl 4);
      LML := LLitLen - 15;
      while LML >= 255 do begin Result[LDst] := 255; Inc(LDst); Dec(LML, 255); end;
      Result[LDst] := Byte(LML); Inc(LDst);
    end
    else
      Result[LTokenPos] := Byte(LLitLen shl 4);
    if LLitLen > 0 then
    begin
      Move(AData[LAnchor], Result[LDst], LLitLen);
      Inc(LDst, LLitLen);
    end;

    SetLength(Result, LDst);
  finally
    FreeMem(LHashTable);
  end;
end;

function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
var
  LSrc, LDst, LEnd: Int32;
  LToken, LLitLen, LMatchLen: Int32;
  LOffset: UInt16;
  LMatchPos: Int32;
begin
  if (Length(AData) = 0) or (AOriginalSize <= 0) then
  begin
    Result := nil;
    Exit;
  end;

  SetLength(Result, AOriginalSize);
  LSrc := 0;
  LDst := 0;
  LEnd := Length(AData);

  while LSrc < LEnd do
  begin
    LToken := AData[LSrc]; Inc(LSrc);
    LLitLen := LToken shr 4;
    if LLitLen = 15 then
    begin
      repeat
        if LSrc >= LEnd then
          raise EIOError.Create('lz4: truncated literal length');
        LLitLen := LLitLen + AData[LSrc]; Inc(LSrc);
        if LLitLen > AOriginalSize then
          raise EIOError.Create('lz4: literal length overflow');
      until AData[LSrc - 1] <> 255;
    end;

    if LLitLen > 0 then
    begin
      if LSrc + LLitLen > LEnd then
        raise EIOError.Create('lz4: literal overflow');
      if LDst + LLitLen > AOriginalSize then
        raise EIOError.Create('lz4: output overflow');
      Move(AData[LSrc], Result[LDst], LLitLen);
      Inc(LSrc, LLitLen);
      Inc(LDst, LLitLen);
    end;

    if LSrc >= LEnd then
      Break;

    if LSrc + 2 > LEnd then
      raise EIOError.Create('lz4: truncated offset');
    LOffset := UInt16(AData[LSrc]) or (UInt16(AData[LSrc + 1]) shl 8);
    Inc(LSrc, 2);
    if LOffset = 0 then
      raise EIOError.Create('lz4: zero offset');

    LMatchPos := LDst - Int32(LOffset);
    if LMatchPos < 0 then
      raise EIOError.Create('lz4: offset before start');

    LMatchLen := (LToken and $0F) + LZ4_MIN_MATCH;
    if (LToken and $0F) = 15 then
    begin
      repeat
        if LSrc >= LEnd then
          raise EIOError.Create('lz4: truncated match length');
        LMatchLen := LMatchLen + AData[LSrc]; Inc(LSrc);
        if LMatchLen > AOriginalSize then
          raise EIOError.Create('lz4: match length overflow');
      until AData[LSrc - 1] <> 255;
    end;

    if LDst + LMatchLen > AOriginalSize then
      raise EIOError.Create('lz4: output overflow');
    if Int32(LOffset) >= LMatchLen then
    begin
      Move(Result[LMatchPos], Result[LDst], LMatchLen);
      Inc(LDst, LMatchLen);
    end
    else
    begin
      while LMatchLen > 0 do
      begin
        Result[LDst] := Result[LMatchPos];
        Inc(LDst);
        Inc(LMatchPos);
        Dec(LMatchLen);
      end;
    end;
  end;

  if LDst <> AOriginalSize then
    raise EIOError.Create('lz4: decompressed size mismatch');
end;

function Lz4CompressBound(const AInputSize: SizeUInt): SizeUInt;
begin
  Result := AInputSize + (AInputSize div 255) + 16;
end;

end.