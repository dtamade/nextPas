unit nextpas.core.http.impl.h2.hpack.huffman;
{**
 * @desc HPACK Huffman encoder/decoder (RFC 7541 Appendix B).
 *       Uses a compact 2-ary trie for O(n) decoding with no per-byte
 *       dynamic allocation. Encoding delegates to the precomputed table
 *       in hpack.table.
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

{ ---------- Decode trie ---------- }

type
  { Each node is either internal (Left/Right point to child indices) or a leaf
    (Sym >= 0). Sym=-1 means internal node. }
  THuffNode = record
    Sym: Int16;       { -1 = internal, 0..255 = literal, 256 = EOS }
    Left: UInt16;     { child index for bit=0 }
    Right: UInt16;    { child index for bit=1 }
  end;

const
  HUFF_ROOT = 0;
  HUFF_EOS_SYM = 256;

var
  { Shared decode trie built once from the encode table at unit init.
    Indices 0..FNodeCount-1 are valid. FNodes[0] is root. }
  FNodes: array of THuffNode;
  FNodeCount: UInt16;

{ Build the decode trie from HPACK_HUFFMAN_ENCODE[].
  Each code is inserted bit-by-bit into the 2-ary tree. }
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
  { Initial estimate: 1024 nodes is enough for 256 symbols plus EOS. }
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
      if LBit = 0 then
        LChildIdx := FNodes[LNodeIdx].Left
      else
        LChildIdx := FNodes[LNodeIdx].Right;

      if LChildIdx = 0 then
      begin
        { Allocate new node }
        if FNodeCount >= UInt16(Length(FNodes)) then
          SetLength(FNodes, Length(FNodes) * 2);
        if LBit = 0 then
          FNodes[LNodeIdx].Left := FNodeCount
        else
          FNodes[LNodeIdx].Right := FNodeCount;
        FNodes[FNodeCount].Sym := -1;
        FNodes[FNodeCount].Left := 0;
        FNodes[FNodeCount].Right := 0;
        LChildIdx := FNodeCount;
        Inc(FNodeCount);
      end;
      LNodeIdx := LChildIdx;
    end;
    { Mark leaf with symbol }
    FNodes[LNodeIdx].Sym := Int16(I);
  end;

  { Insert EOS symbol: 30 all-1 bits }
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

{ Core Huffman decode. If ALimit >= 0, stops at ALimit output bytes. }
function DoHuffmanDecode(const AData: AnsiString; const ALimit: SizeInt;
  out ATruncated: Boolean): AnsiString;
var
  LDataLen: SizeInt;
  LNode: UInt16;
  LChild: UInt16;
  LBit: Byte;
  LByte: Byte;
  I: SizeInt;
  LOutputPos: SizeInt;
  LStr: AnsiString;
  LSym: Int16;
  LPendingBits: Byte;
  LPendingCode: UInt32;
const
  HUFFMAN_OUTPUT_GROW = 256;
begin
  ATruncated := False;
  LDataLen := Length(AData);
  if LDataLen = 0 then
    Exit('');

  SetLength(LStr, HUFFMAN_OUTPUT_GROW);
  LOutputPos := 0;
  LNode := HUFF_ROOT;
  LPendingBits := 0;
  LPendingCode := 0;
  I := 1;

  while I <= LDataLen do
  begin
    LByte := Byte(AData[I]);
    LBit := 0;
    while LBit < 8 do
    begin
      if ((LByte shr (7 - LBit)) and 1) = 0 then
        LChild := FNodes[LNode].Left
      else
        LChild := FNodes[LNode].Right;
      if LChild = 0 then
        raise EHttpError.Create('HPACK Huffman: invalid code path');
      LNode := LChild;
      LPendingCode := (LPendingCode shl 1) or
        UInt32((LByte shr (7 - LBit)) and 1);
      Inc(LPendingBits);
      Inc(LBit);

      if FNodes[LNode].Sym >= 0 then
      begin
        LSym := FNodes[LNode].Sym;
        if LSym = HUFF_EOS_SYM then
          raise EHttpError.Create('HPACK Huffman: EOS symbol in input');

        Inc(LOutputPos);
        if (ALimit >= 0) and (LOutputPos > ALimit) then
        begin
          ATruncated := True;
          Exit('');
        end;

        if LOutputPos > Length(LStr) then
          SetLength(LStr, Length(LStr) + HUFFMAN_OUTPUT_GROW);
        LStr[LOutputPos] := AnsiChar(LSym);
        LNode := HUFF_ROOT;
        LPendingBits := 0;
        LPendingCode := 0;
      end;
    end;
    Inc(I);
  end;

  { RFC 7541 section 5.2 allows at most seven trailing bits, and they
    must be the high-order prefix of EOS, i.e. all ones. }
  if LPendingBits > 0 then
  begin
    if (LPendingBits > 7) or
       (LPendingCode <> ((UInt32(1) shl LPendingBits) - 1)) then
      raise EHttpError.Create('HPACK Huffman: invalid EOS padding');
  end;

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
  if AData = '' then
    Exit;

  SetLength(Result, (Length(AData) * 8 + 7) div 8 + 4); { upper bound }
  LAccum := 0;
  LAccumBits := 0;
  LOutPos := 0;

  for I := 1 to Length(AData) do
  begin
    LByte := Byte(AData[I]);
    LCode := HPACK_HUFFMAN_ENCODE[LByte].Code;
    LBits := HPACK_HUFFMAN_ENCODE[LByte].Bits;
    LAccum := (LAccum shl LBits) or LCode;
    Inc(LAccumBits, LBits);

    while LAccumBits >= 8 do
    begin
      Dec(LAccumBits, 8);
      Inc(LOutPos);
      if LOutPos > Length(Result) then
        SetLength(Result, Length(Result) + 64);
      Result[LOutPos] := AnsiChar((LAccum shr LAccumBits) and $FF);
    end;
  end;

  { Pad last byte with EOS (all 1s) }
  if LAccumBits > 0 then
  begin
    LAccum := (LAccum shl (8 - LAccumBits)) or ((1 shl (8 - LAccumBits)) - 1);
    Inc(LOutPos);
    if LOutPos > Length(Result) then
      SetLength(Result, Length(Result) + 1);
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

finalization
  FNodes := nil;

end.
