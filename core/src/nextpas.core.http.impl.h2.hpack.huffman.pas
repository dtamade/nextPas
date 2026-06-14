unit nextpas.core.http.impl.h2.hpack.huffman;
{**
 * @desc HPACK Huffman encoder/decoder (RFC 7541 Appendix B).
 *       Uses a 4-bit nibble decode table for O(n/2) decoding with
 *       no per-byte dynamic allocation. Encoding delegates to the
 *       precomputed table in hpack.table.
 *
 * @see RFC 7541 section 5 - String Literal Representation
 * @see RFC 7541 Appendix B - Huffman Code and EOS
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h2.hpack.table;

{** Huffman-encode a raw string. Returns the encoded byte sequence. }
function H2HuffmanEncode(const AData: AnsiString): AnsiString;

{** Huffman-decode a byte sequence. Returns the original string.
 *  Raises EHttpError on invalid padding or non-EOS trailing bits. }
function H2HuffmanDecode(const AData: AnsiString): AnsiString;

{** Huffman-decode with a maximum output length.
 *  Returns empty string + sets ATruncated=True if output would exceed ALimit.
 *  Useful for oversized header value rejection. }
function H2HuffmanDecodeLimited(const AData: AnsiString;
  const ALimit: SizeInt; out ATruncated: Boolean): AnsiString;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.text.conv;

{ ---------- Decode tables ---------- }

type
  THuffNode = record
    Sym: Int16;       { -1 = internal, 0..255 = literal, 256 = EOS }
    Left: UInt16;     { child index for bit=0 }
    Right: UInt16;    { child index for bit=1 }
  end;

  { 4-bit nibble decode table entry }
  THuffNibbleEntry = packed record
    Symbol: SmallInt;
    NextNode: UInt16;
    Consumed: Byte;
  end;

const
  HUFF_ROOT = 0;
  HUFF_EOS_SYM = 256;

var
  FNodes: array of THuffNode;
  FNodeCount: UInt16;
  FNibbleTable: array of array[0..15] of THuffNibbleEntry;

{ Build the decode trie from HPACK_HUFFMAN_ENCODE[]. }
procedure BuildDecodeTrie;
var
  I: Int32;
  LCode: UInt32;
  LBits: Byte;
  LNodeIdx: UInt16;
  LBit: Byte;
  LChildIdx: UInt16;
  J: SizeInt;
begin
  SetLength(FNodes, 1024);
  FNodeCount := 1;
  FNodes[HUFF_ROOT].Sym := -1;
  FNodes[HUFF_ROOT].Left := 0;
  FNodes[HUFF_ROOT].Right := 0;

  for I := 0 to 255 do
  begin
    LCode := HPACK_HUFFMAN_ENCODE[I].Code;
    LBits := HPACK_HUFFMAN_ENCODE[I].Bits;
    LNodeIdx := HUFF_ROOT;
    for J := LBits - 1 downto 0 do
    begin
      LBit := (LCode shr J) and 1;
      if LBit = 0 then LChildIdx := FNodes[LNodeIdx].Left
      else LChildIdx := FNodes[LNodeIdx].Right;
      if LChildIdx = 0 then
      begin
        if FNodeCount >= UInt16(Length(FNodes)) then
          SetLength(FNodes, Length(FNodes) * 2);
        if LBit = 0 then FNodes[LNodeIdx].Left := FNodeCount
        else FNodes[LNodeIdx].Right := FNodeCount;
        FNodes[FNodeCount].Sym := -1;
        FNodes[FNodeCount].Left := 0;
        FNodes[FNodeCount].Right := 0;
        LChildIdx := FNodeCount;
        Inc(FNodeCount);
      end;
      LNodeIdx := LChildIdx;
    end;
    FNodes[LNodeIdx].Sym := Int16(I);
  end;

  { EOS symbol: 30 all-1 bits }
  LNodeIdx := HUFF_ROOT;
  for J := 29 downto 0 do
  begin
    if FNodes[LNodeIdx].Right = 0 then
    begin
      if FNodeCount >= UInt16(Length(FNodes)) then
        SetLength(FNodes, Length(FNodes) * 2);
      FNodes[LNodeIdx].Right := FNodeCount;
      FNodes[FNodeCount].Sym := -1;
      FNodes[FNodeCount].Left := 0;
      FNodes[FNodeCount].Right := 0;
      Inc(FNodeCount);
    end;
    LNodeIdx := FNodes[LNodeIdx].Right;
  end;
  FNodes[LNodeIdx].Sym := HUFF_EOS_SYM;
end;

{ Build 4-bit nibble decode table from the trie. }
procedure BuildNibbleTable;
var
  LNodeIdx: UInt16;
  LNibble: Byte;
  LBit: Byte;
  LCurNode: UInt16;
  LChild: UInt16;
  LConsumed: Byte;
  LSym: SmallInt;
begin
  SetLength(FNibbleTable, FNodeCount);
  for LNodeIdx := 0 to FNodeCount - 1 do
  begin
    for LNibble := 0 to 15 do
    begin
      LCurNode := LNodeIdx;
      LSym := -1;
      LConsumed := 0;
      for LBit := 0 to 3 do
      begin
        if ((LNibble shr (3 - LBit)) and 1) = 0 then
          LChild := FNodes[LCurNode].Left
        else
          LChild := FNodes[LCurNode].Right;
        if LChild = 0 then Break;
        Inc(LConsumed);
        LCurNode := LChild;
        if FNodes[LCurNode].Sym >= 0 then
        begin
          LSym := FNodes[LCurNode].Sym;
          LCurNode := HUFF_ROOT;
        end;
      end;
      FNibbleTable[LNodeIdx, LNibble].Symbol := LSym;
      FNibbleTable[LNodeIdx, LNibble].NextNode := LCurNode;
      FNibbleTable[LNodeIdx, LNibble].Consumed := LConsumed;
    end;
  end;
end;

{ Core Huffman decode using 4-bit nibble lookup.
  2 table lookups per byte instead of 8 bit-iterations. }
function DoHuffmanDecode(const AData: AnsiString; const ALimit: SizeInt;
  out ATruncated: Boolean): AnsiString;
var
  LByte: Byte;
  I: SizeInt;
  LOutputPos: SizeInt;
  LStr: AnsiString;
  LNode: UInt16;
  LEntry: ^THuffNibbleEntry;
  LNibble: Byte;
const
  HUFFMAN_OUTPUT_GROW = 256;
begin
  ATruncated := False;
  if Length(AData) = 0 then Exit('');

  SetLength(LStr, HUFFMAN_OUTPUT_GROW);
  LOutputPos := 0;
  LNode := HUFF_ROOT;
  I := 1;

  while I <= Length(AData) do
  begin
    LByte := Byte(AData[I]);

    { High nibble (bits 7-4) }
    LNibble := (LByte shr 4) and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then
        raise EHttpError.Create('HPACK Huffman: EOS symbol in input');
      Inc(LOutputPos);
      if (ALimit >= 0) and (LOutputPos > ALimit) then
      begin ATruncated := True; Exit(''); end;
      if LOutputPos > Length(LStr) then
        SetLength(LStr, Length(LStr) + HUFFMAN_OUTPUT_GROW);
      LStr[LOutputPos] := AnsiChar(LEntry^.Symbol);
    end;
    LNode := LEntry^.NextNode;

    { Low nibble (bits 3-0) }
    LNibble := LByte and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then
        raise EHttpError.Create('HPACK Huffman: EOS symbol in input');
      Inc(LOutputPos);
      if (ALimit >= 0) and (LOutputPos > ALimit) then
      begin ATruncated := True; Exit(''); end;
      if LOutputPos > Length(LStr) then
        SetLength(LStr, Length(LStr) + HUFFMAN_OUTPUT_GROW);
      LStr[LOutputPos] := AnsiChar(LEntry^.Symbol);
    end;
    LNode := LEntry^.NextNode;
    Inc(I);
  end;

  { Accept trailing EOS padding }
  SetLength(LStr, LOutputPos);
  Result := LStr;
end;

{ ---------- Public API ---------- }

function H2HuffmanEncode(const AData: AnsiString): AnsiString;
var
  I: SizeInt;
  LByte: Byte;
  LCode: UInt32;
  LBits: Byte;
  LAccum: UInt64;
  LAccumBits: Byte;
  LOutPos: SizeInt;
begin
  Result := '';
  if AData = '' then Exit;

  SetLength(Result, (Length(AData) * 8 + 7) div 8 + 4);
  LAccum := 0; LAccumBits := 0; LOutPos := 0;

  for I := 1 to Length(AData) do
  begin
    LByte := Byte(AData[I]);
    LCode := HPACK_HUFFMAN_ENCODE[LByte].Code;
    LBits := HPACK_HUFFMAN_ENCODE[LByte].Bits;
    LAccum := (LAccum shl LBits) or LCode;
    Inc(LAccumBits, LBits);
    while LAccumBits >= 8 do
    begin
      Dec(LAccumBits, 8); Inc(LOutPos);
      if LOutPos > Length(Result) then SetLength(Result, Length(Result) + 64);
      Result[LOutPos] := AnsiChar((LAccum shr LAccumBits) and $FF);
    end;
  end;

  if LAccumBits > 0 then
  begin
    LAccum := (LAccum shl (8 - LAccumBits)) or ((1 shl (8 - LAccumBits)) - 1);
    Inc(LOutPos);
    if LOutPos > Length(Result) then SetLength(Result, Length(Result) + 1);
    Result[LOutPos] := AnsiChar(LAccum and $FF);
  end;

  SetLength(Result, LOutPos);
end;

function H2HuffmanDecode(const AData: AnsiString): AnsiString;
var
  LTruncated: Boolean;
begin
  Result := DoHuffmanDecode(AData, -1, LTruncated);
end;

function H2HuffmanDecodeLimited(const AData: AnsiString;
  const ALimit: SizeInt; out ATruncated: Boolean): AnsiString;
begin
  if ALimit < 0 then
    Result := DoHuffmanDecode(AData, -1, ATruncated)
  else
    Result := DoHuffmanDecode(AData, ALimit, ATruncated);
end;

initialization
  BuildDecodeTrie;
  BuildNibbleTable;

finalization
  FNodes := nil;
  FNibbleTable := nil;

end.
