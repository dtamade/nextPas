unit nextpas.core.http.impl.h2.hpack;
{**
 * @desc HPACK encoder/decoder (RFC 7541).
 *       Implements integer variable-length encoding, Huffman coding,
 *       dynamic table management, and header field representation encoding/decoding.
 *
 * @see RFC 7541 - HPACK: Header Compression for HTTP/2
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h2.hpack.table;

const
  { Default dynamic table size limit (RFC 7541 Section 6.5.2: SETTINGS_HEADER_TABLE_SIZE) }
  HPACK_DEFAULT_DYNAMIC_TABLE_SIZE = 4096;

  { Overhead per dynamic table entry (RFC 7541 Section 4.1: 32 bytes) }
  HPACK_ENTRY_OVERHEAD = 32;

type
  { Header field name-value pair }
  THPackHeader = record
    Name: AnsiString;
    Value: AnsiString;
  end;

  { Dynamic table: ring buffer of recently used header fields }
  THPackDynamicTable = record
  private
    FEntries: array of THPackHeader;
    FCapacity: SizeInt;       { max total byte size }
    FTotalSize: SizeInt;      { current total byte size }
    FCount: SizeInt;          { current number of entries }
    FHead: SizeInt;           { index of oldest entry }
    FTail: SizeInt;           { index next write position }
    procedure Evict(ANeeded: SizeInt);
    function EntrySize(const AEntry: THPackHeader): SizeInt; inline;
  public
    procedure Init(ACapacity: SizeInt = HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
    procedure Resize(ACapacity: SizeInt);
    procedure Add(const AName, AValue: AnsiString);
    function Get(AIndex: SizeInt; out AName, AValue: AnsiString): Boolean;
    function Count: SizeInt; inline;
    function Capacity: SizeInt; inline;
    function TotalSize: SizeInt; inline;
  end;

  { HPACK encoder state: emits encoded header blocks }
  THPackEncoder = record
  private
    FDynamicTable: THPackDynamicTable;
    procedure EncodeInteger(var AOut: AnsiString; AValue: UInt32;
      APrefixBits: Byte; APrefixMask: Byte);
    procedure EncodeHuffman(var AOut: AnsiString; const AStr: AnsiString);
    procedure EncodeRaw(var AOut: AnsiString; const AStr: AnsiString);
    procedure EncodeString(var AOut: AnsiString; const AStr: AnsiString;
      AHuffman: Boolean);
    procedure EncodeNameValue(var AOut: AnsiString; const AName, AValue: AnsiString;
      AIndex: SizeInt; AIndexing: Boolean);
  public
    procedure Init(ADynamicTableSize: SizeInt = HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
    { Encode a list of header fields into an HPACK header block }
    function Encode(const AHeaders: array of THPackHeader): AnsiString;
    { Update the dynamic table size limit (sends SETTINGS_HEADER_TABLE_SIZE) }
    procedure SetDynamicTableSize(ASize: UInt32);
  end;

  { HPACK decoder state: parses encoded header blocks }
  THPackDecoder = record
  private
    FDynamicTable: THPackDynamicTable;
    FMaxDynamicTableSize: UInt32;
    procedure DecodeInteger(const ABlock: AnsiString; var APos: SizeInt;
      APrefixBits: Byte; out AValue: UInt32);
    procedure DecodeHuffman(const ABlock: AnsiString; var APos: SizeInt;
      ALen: SizeInt; out AStr: AnsiString);
    procedure DecodeRaw(const ABlock: AnsiString; var APos: SizeInt;
      ALen: SizeInt; out AStr: AnsiString);
    function DecodeString(const ABlock: AnsiString; var APos: SizeInt;
      out AStr: AnsiString): Boolean;
  public
    procedure Init(ADynamicTableSize: UInt32 = HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
    { Decode an HPACK header block into a list of header fields }
    function Decode(const ABlock: AnsiString; out AHeaders: array of THPackHeader): Boolean;
    { Maximum allowed dynamic table size (for SETTINGS acknowledgment) }
    property MaxDynamicTableSize: UInt32 read FMaxDynamicTableSize write FMaxDynamicTableSize;
  end;

{** Helper: look up a header in the combined static+dynamic table.
 *  AIndex is 1-based. Indices 1..61 are static, 62+ are dynamic.
 *  Returns True if found. }
function HPackLookup(AStaticCount: SizeInt;
  const ADynamic: THPackDynamicTable; AIndex: SizeInt;
  out AName, AValue: AnsiString): Boolean;

implementation

uses
  SysUtils,
  nextpas.core.http.impl.h2.hpack.huffman;

{ === HPackLookup === }

function HPackLookup(AStaticCount: SizeInt;
  const ADynamic: THPackDynamicTable; AIndex: SizeInt;
  out AName, AValue: AnsiString): Boolean;
var
  LDynamicIdx: SizeInt;
begin
  if (AIndex >= 1) and (AIndex <= AStaticCount) then
  begin
    AName := HPACK_STATIC_TABLE[AIndex].Name;
    if HPACK_STATIC_TABLE[AIndex].Value <> nil then
      SetString(AValue, HPACK_STATIC_TABLE[AIndex].Value, HPACK_STATIC_TABLE[AIndex].ValueLen)
    else
      AValue := '';
    Result := True;
  end
  else if AIndex > AStaticCount then
  begin
    LDynamicIdx := AIndex - AStaticCount - 1; { 0-based }
    Result := ADynamic.Get(LDynamicIdx, AName, AValue);
  end
  else
    Result := False;
end;

{ === THPackDynamicTable === }

procedure THPackDynamicTable.Init(ACapacity: SizeInt);
begin
  FCapacity := ACapacity;
  FTotalSize := 0;
  FCount := 0;
  FHead := 0;
  FTail := 0;
  SetLength(FEntries, 16); { initial ring buffer }
end;

function THPackDynamicTable.EntrySize(const AEntry: THPackHeader): SizeInt;
begin
  Result := Length(AEntry.Name) + Length(AEntry.Value) + HPACK_ENTRY_OVERHEAD;
end;

procedure THPackDynamicTable.Evict(ANeeded: SizeInt);
var
  LIdx: SizeInt;
begin
  while (FCount > 0) and (FTotalSize + ANeeded > FCapacity) do
  begin
    LIdx := FHead mod Length(FEntries);
    Dec(FTotalSize, EntrySize(FEntries[LIdx]));
    FEntries[LIdx].Name := '';
    FEntries[LIdx].Value := '';
    FHead := (FHead + 1);
    Dec(FCount);
  end;
end;

procedure THPackDynamicTable.Resize(ACapacity: SizeInt);
begin
  if ACapacity < FCapacity then
  begin
    FCapacity := ACapacity;
    Evict(0); { evict until within new capacity }
  end
  else
    FCapacity := ACapacity;
end;

procedure THPackDynamicTable.Add(const AName, AValue: AnsiString);
var
  LEntrySize: SizeInt;
  LIdx: SizeInt;
begin
  LEntrySize := Length(AName) + Length(AValue) + HPACK_ENTRY_OVERHEAD;
  if LEntrySize > FCapacity then
  begin
    { Entry exceeds maximum capacity: clear table (RFC 7541 Section 4.4) }
    while FCount > 0 do
    begin
      LIdx := FHead mod Length(FEntries);
      FEntries[LIdx].Name := '';
      FEntries[LIdx].Value := '';
      FHead := (FHead + 1);
      Dec(FCount);
    end;
    FTotalSize := 0;
    Exit;
  end;
  Evict(LEntrySize);
  { Grow ring buffer if needed }
  if FCount >= Length(FEntries) then
    SetLength(FEntries, Length(FEntries) * 2);
  LIdx := FTail mod Length(FEntries);
  FEntries[LIdx].Name := AName;
  FEntries[LIdx].Value := AValue;
  FTail := (FTail + 1);
  Inc(FCount);
  Inc(FTotalSize, LEntrySize);
end;

function THPackDynamicTable.Get(AIndex: SizeInt; out AName, AValue: AnsiString): Boolean;
var
  LIdx: SizeInt;
begin
  if (AIndex >= 0) and (AIndex < FCount) then
  begin
    { Dynamic table indices are front-to-back: index 0 = newest (tail-1), index N-1 = oldest (head) }
    LIdx := (FTail - 1 - AIndex + Length(FEntries)) mod Length(FEntries);
    AName := FEntries[LIdx].Name;
    AValue := FEntries[LIdx].Value;
    Result := True;
  end
  else
    Result := False;
end;

function THPackDynamicTable.Count: SizeInt;
begin
  Result := FCount;
end;

function THPackDynamicTable.Capacity: SizeInt;
begin
  Result := FCapacity;
end;

function THPackDynamicTable.TotalSize: SizeInt;
begin
  Result := FTotalSize;
end;

{ === THPackEncoder === }

function AnsiStringEqualsPtr(const ALeft: AnsiString; const ARight: PAnsiChar;
  ARightLen: SizeUInt): Boolean;
begin
  if SizeUInt(Length(ALeft)) <> ARightLen then
    Exit(False);
  if ARightLen = 0 then
    Exit(True);
  Result := CompareMem(@ALeft[1], ARight, ARightLen);
end;

function TryFindStaticFull(const AName, AValue: AnsiString; out AIndex: SizeInt): Boolean;
var
  LIndex: SizeInt;
begin
  for LIndex := 1 to HPACK_STATIC_TABLE_COUNT do
  begin
    if AnsiStringEqualsPtr(AName, HPACK_STATIC_TABLE[LIndex].Name,
      HPACK_STATIC_TABLE[LIndex].NameLen) and
      (HPACK_STATIC_TABLE[LIndex].Value <> nil) and
      AnsiStringEqualsPtr(AValue, HPACK_STATIC_TABLE[LIndex].Value,
        HPACK_STATIC_TABLE[LIndex].ValueLen) then
    begin
      AIndex := LIndex;
      Exit(True);
    end;
  end;
  AIndex := 0;
  Result := False;
end;

function TryFindStaticName(const AName: AnsiString; out AIndex: SizeInt): Boolean;
var
  LIndex: SizeInt;
begin
  for LIndex := 1 to HPACK_STATIC_TABLE_COUNT do
  begin
    if AnsiStringEqualsPtr(AName, HPACK_STATIC_TABLE[LIndex].Name,
      HPACK_STATIC_TABLE[LIndex].NameLen) then
    begin
      AIndex := LIndex;
      Exit(True);
    end;
  end;
  AIndex := 0;
  Result := False;
end;

function TryFindDynamicFull(const ADynamicTable: THPackDynamicTable;
  const AName, AValue: AnsiString; out AIndex: SizeInt): Boolean;
var
  LDynamicIndex: SizeInt;
  LName: AnsiString;
  LValue: AnsiString;
begin
  for LDynamicIndex := 0 to ADynamicTable.Count - 1 do
  begin
    if ADynamicTable.Get(LDynamicIndex, LName, LValue) and
      (LName = AName) and (LValue = AValue) then
    begin
      AIndex := HPACK_STATIC_TABLE_COUNT + 1 + LDynamicIndex;
      Exit(True);
    end;
  end;
  AIndex := 0;
  Result := False;
end;

function TryFindDynamicName(const ADynamicTable: THPackDynamicTable;
  const AName: AnsiString; out AIndex: SizeInt): Boolean;
var
  LDynamicIndex: SizeInt;
  LName: AnsiString;
  LValue: AnsiString;
begin
  for LDynamicIndex := 0 to ADynamicTable.Count - 1 do
  begin
    if ADynamicTable.Get(LDynamicIndex, LName, LValue) and (LName = AName) then
    begin
      AIndex := HPACK_STATIC_TABLE_COUNT + 1 + LDynamicIndex;
      Exit(True);
    end;
  end;
  AIndex := 0;
  Result := False;
end;

procedure THPackEncoder.Init(ADynamicTableSize: SizeInt);
begin
  FDynamicTable.Init(ADynamicTableSize);
end;

procedure THPackEncoder.EncodeInteger(var AOut: AnsiString; AValue: UInt32;
  APrefixBits: Byte; APrefixMask: Byte);
var
  LPrefixMask: UInt32;
  LIdx: SizeInt;
begin
  LPrefixMask := (UInt32(1) shl APrefixBits) - 1;
  LIdx := Length(AOut);
  SetLength(AOut, LIdx + 1);
  if AValue < LPrefixMask then
    AOut[LIdx + 1] := AnsiChar(APrefixMask or Byte(AValue))
  else
  begin
    AOut[LIdx + 1] := AnsiChar(APrefixMask or Byte(LPrefixMask));
    Dec(AValue, LPrefixMask);
    while AValue >= 128 do
    begin
      LIdx := Length(AOut);
      SetLength(AOut, LIdx + 1);
      AOut[LIdx + 1] := AnsiChar(Byte(AValue and $7F) or $80);
      AValue := AValue shr 7;
    end;
    LIdx := Length(AOut);
    SetLength(AOut, LIdx + 1);
    AOut[LIdx + 1] := AnsiChar(Byte(AValue));
  end;
end;

procedure THPackEncoder.EncodeHuffman(var AOut: AnsiString; const AStr: AnsiString);
var
  LEncoded: AnsiString;
begin
  LEncoded := H2HuffmanEncode(AStr);
  EncodeRaw(AOut, LEncoded);
end;

procedure THPackEncoder.EncodeRaw(var AOut: AnsiString; const AStr: AnsiString);
var
  LPos: SizeInt;
begin
  if AStr = '' then
    Exit;
  LPos := Length(AOut);
  SetLength(AOut, LPos + Length(AStr));
  Move(AStr[1], AOut[LPos + 1], Length(AStr));
end;

procedure THPackEncoder.EncodeString(var AOut: AnsiString; const AStr: AnsiString;
  AHuffman: Boolean);
var
  LEncoded: AnsiString;
begin
  if AHuffman then
  begin
    LEncoded := H2HuffmanEncode(AStr);
    EncodeInteger(AOut, UInt32(Length(LEncoded)), 7, $80);
    EncodeRaw(AOut, LEncoded);
  end
  else
  begin
    EncodeInteger(AOut, UInt32(Length(AStr)), 7, $00);
    EncodeRaw(AOut, AStr);
  end;
end;

procedure THPackEncoder.EncodeNameValue(var AOut: AnsiString;
  const AName, AValue: AnsiString; AIndex: SizeInt; AIndexing: Boolean);
begin
  if AIndexing then
    EncodeInteger(AOut, UInt32(AIndex), 6, $40)
  else
    EncodeInteger(AOut, UInt32(AIndex), 4, $00);
  if AIndex = 0 then
    EncodeString(AOut, AName, True);
  EncodeString(AOut, AValue, True);
end;

function THPackEncoder.Encode(const AHeaders: array of THPackHeader): AnsiString;
var
  I: SizeInt;
  LIndex: SizeInt;
  LNameIndex: SizeInt;
  LName, LValue: AnsiString;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
  begin
    LName := AHeaders[I].Name;
    LValue := AHeaders[I].Value;

    if TryFindStaticFull(LName, LValue, LIndex) or
      TryFindDynamicFull(FDynamicTable, LName, LValue, LIndex) then
    begin
      EncodeInteger(Result, UInt32(LIndex), 7, $80);
      Continue;
    end;

    if not TryFindStaticName(LName, LNameIndex) then
      TryFindDynamicName(FDynamicTable, LName, LNameIndex);

    { Literal Header Field with Incremental Indexing }
    if LNameIndex > 0 then
      EncodeInteger(Result, UInt32(LNameIndex), 6, $40)
    else
    begin
      EncodeInteger(Result, 0, 6, $40);
      EncodeString(Result, LName, True);
    end;
    EncodeString(Result, LValue, True);
    { Add to dynamic table }
    FDynamicTable.Add(LName, LValue);
  end;
end;

procedure THPackEncoder.SetDynamicTableSize(ASize: UInt32);
begin
  FDynamicTable.Resize(ASize);
end;

{ === THPackDecoder === }

procedure THPackDecoder.Init(ADynamicTableSize: UInt32);
begin
  FDynamicTable.Init(ADynamicTableSize);
  FMaxDynamicTableSize := ADynamicTableSize;
end;

procedure THPackDecoder.DecodeInteger(const ABlock: AnsiString; var APos: SizeInt;
  APrefixBits: Byte; out AValue: UInt32);
var
  LPrefixMask: UInt32;
  LByte: Byte;
  LShift: Byte;
begin
  LPrefixMask := (UInt32(1) shl APrefixBits) - 1;
  if APos > Length(ABlock) then
  begin
    AValue := 0;
    Exit;
  end;
  LByte := Byte(ABlock[APos]);
  Inc(APos);
  AValue := LByte and LPrefixMask;
  if AValue < LPrefixMask then
    Exit;
  { Multi-byte integer }
  LShift := 0;
  repeat
    if APos > Length(ABlock) then
      Exit;
    LByte := Byte(ABlock[APos]);
    Inc(APos);
    AValue := AValue + ((LByte and $7F) shl LShift);
    Inc(LShift, 7);
  until (LByte and $80) = 0;
end;

procedure THPackDecoder.DecodeHuffman(const ABlock: AnsiString; var APos: SizeInt;
  ALen: SizeInt; out AStr: AnsiString);
var
  LSlice: AnsiString;
begin
  { Slice out the HPACK Huffman-encoded bytes and delegate to the
    shared Huffman decoder in hpack.huffman. }
  SetString(LSlice, @ABlock[APos], ALen);
  AStr := H2HuffmanDecode(LSlice);
  Inc(APos, ALen);
end;

procedure THPackDecoder.DecodeRaw(const ABlock: AnsiString; var APos: SizeInt;
  ALen: SizeInt; out AStr: AnsiString);
begin
  if APos + ALen - 1 > Length(ABlock) then
  begin
    AStr := '';
    Exit;
  end;
  SetString(AStr, @ABlock[APos], ALen);
  Inc(APos, ALen);
end;

function THPackDecoder.DecodeString(const ABlock: AnsiString; var APos: SizeInt;
  out AStr: AnsiString): Boolean;
var
  LByte: Byte;
  LLen: UInt32;
  LHuffman: Boolean;
begin
  Result := False;
  if APos > Length(ABlock) then
    Exit;
  LByte := Byte(ABlock[APos]);
  LHuffman := (LByte and $80) <> 0;
  DecodeInteger(ABlock, APos, 7, LLen);
  if APos + SizeInt(LLen) - 1 > Length(ABlock) then
    Exit;
  if LHuffman then
    DecodeHuffman(ABlock, APos, LLen, AStr)
  else
    DecodeRaw(ABlock, APos, LLen, AStr);
  Result := True;
end;

function THPackDecoder.Decode(const ABlock: AnsiString; out AHeaders: array of THPackHeader): Boolean;
var
  LPos: SizeInt;
  LByte: Byte;
  LIndex: UInt32;
  LName, LValue: AnsiString;
  LHeaderCount: SizeInt;
begin
  Result := False;
  LPos := 1;
  LHeaderCount := 0;
  while LPos <= Length(ABlock) do
  begin
    LByte := Byte(ABlock[LPos]);
    if (LByte and $80) <> 0 then
    begin
      { Indexed Header Field (1xxxxxxx) }
      DecodeInteger(ABlock, LPos, 7, LIndex);
      if not HPackLookup(HPACK_STATIC_TABLE_COUNT, FDynamicTable, LIndex, LName, LValue) then
        Exit;
      if LHeaderCount <= High(AHeaders) then
      begin
        AHeaders[LHeaderCount].Name := LName;
        AHeaders[LHeaderCount].Value := LValue;
      end;
      Inc(LHeaderCount);
    end
    else if (LByte and $C0) = $40 then
    begin
      { Literal Header Field with Incremental Indexing (01xxxxxx) }
      DecodeInteger(ABlock, LPos, 6, LIndex);
      if LIndex > 0 then
      begin
        if not HPackLookup(HPACK_STATIC_TABLE_COUNT, FDynamicTable, LIndex, LName, LValue) then
          Exit;
        { LName is the name, we still need to read the value }
      end;
      if not DecodeString(ABlock, LPos, LValue) then
        Exit;
      if LIndex = 0 then
      begin
        { New name }
        LName := LValue;
        if not DecodeString(ABlock, LPos, LValue) then
          Exit;
      end;
      FDynamicTable.Add(LName, LValue);
      if LHeaderCount <= High(AHeaders) then
      begin
        AHeaders[LHeaderCount].Name := LName;
        AHeaders[LHeaderCount].Value := LValue;
      end;
      Inc(LHeaderCount);
    end
    else if (LByte and $F0) = $00 then
    begin
      { Literal Header Field without Indexing (0000xxxx) }
      DecodeInteger(ABlock, LPos, 4, LIndex);
      if LIndex > 0 then
      begin
        if not HPackLookup(HPACK_STATIC_TABLE_COUNT, FDynamicTable, LIndex, LName, LValue) then
          Exit;
      end;
      if not DecodeString(ABlock, LPos, LValue) then
        Exit;
      if LIndex = 0 then
      begin
        LName := LValue;
        if not DecodeString(ABlock, LPos, LValue) then
          Exit;
      end;
      if LHeaderCount <= High(AHeaders) then
      begin
        AHeaders[LHeaderCount].Name := LName;
        AHeaders[LHeaderCount].Value := LValue;
      end;
      Inc(LHeaderCount);
    end
    else if (LByte and $F0) = $10 then
    begin
      { Literal Header Field Never Indexed (0001xxxx) }
      DecodeInteger(ABlock, LPos, 4, LIndex);
      if LIndex > 0 then
      begin
        if not HPackLookup(HPACK_STATIC_TABLE_COUNT, FDynamicTable, LIndex, LName, LValue) then
          Exit;
      end;
      if not DecodeString(ABlock, LPos, LValue) then
        Exit;
      if LIndex = 0 then
      begin
        LName := LValue;
        if not DecodeString(ABlock, LPos, LValue) then
          Exit;
      end;
      if LHeaderCount <= High(AHeaders) then
      begin
        AHeaders[LHeaderCount].Name := LName;
        AHeaders[LHeaderCount].Value := LValue;
      end;
      Inc(LHeaderCount);
    end
    else if (LByte and $E0) = $20 then
    begin
      { Dynamic Table Size Update (001xxxxx) }
      DecodeInteger(ABlock, LPos, 5, LIndex);
      if LIndex > FMaxDynamicTableSize then
        Exit; { protocol error }
      FDynamicTable.Resize(LIndex);
    end
    else
      Exit; { unknown first byte pattern }
  end;
  Result := True;
end;

end.
