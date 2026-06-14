unit nextpas.core.http.impl.h2.hpack.huffman;
{**
 * @desc HPACK Huffman encoder/decoder (RFC 7541 Appendix B).
 *       Uses a 4-bit nibble decode table for O(n/2) decoding with
 *       no per-byte dynamic allocation. Raw-pointer decode API
 *       avoids intermediate AnsiString allocation for HPACK decoder.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h2.hpack.table;

function H2HuffmanEncode(const AData: AnsiString): AnsiString;
function H2HuffmanDecode(const AData: AnsiString): AnsiString;
function H2HuffmanDecodeLimited(const AData: AnsiString;
  const ALimit: SizeInt; out ATruncated: Boolean): AnsiString;
function H2HuffmanDecodeRaw(const AData: PAnsiChar; const ALen: SizeInt): AnsiString;
{** Decode huffman data into a caller-provided buffer (typically stack-allocated).
 *  Returns True on success, False if EOS symbol encountered.
 *  ABuf must be at least ADataLen * 2 bytes (huffman max expansion < 2x).
 *  ABufSize is the buffer capacity in bytes.
 *  Sets AOutLen to the decoded length. If buffer is too small, AOutLen = 0
 *  and returns False. }
function H2HuffmanDecodeBuf(const AData: PAnsiChar; const ADataLen: SizeInt;
  var ABuf; const ABufSize: SizeInt; out AOutLen: SizeInt): Boolean;
{** Decode huffman data directly into a newly allocated AnsiString.
 *  Pre-allocates to max possible size, decodes in-place, then trims.
 *  Avoids the intermediate stack buffer + copy of H2HuffmanDecodeBuf + SetString. }
procedure H2HuffmanDecodeInto(const AData: PAnsiChar; const ADataLen: SizeInt;
  out AStr: AnsiString);

implementation

uses
  nextpas.core.http.base,
  nextpas.core.text.conv;

type
  THuffNode = record
    Sym: Int16;
    Left: UInt16;
    Right: UInt16;
  end;

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

procedure BuildDecodeTrie;
var I: Int32; LCode: UInt32; LBits: Byte; LNodeIdx: UInt16;
  LBit: Byte; LChildIdx: UInt16; J: SizeInt;
begin
  SetLength(FNodes, 1024); FNodeCount := 1;
  FNodes[HUFF_ROOT].Sym := -1; FNodes[HUFF_ROOT].Left := 0; FNodes[HUFF_ROOT].Right := 0;
  for I := 0 to 255 do
  begin
    LCode := HPACK_HUFFMAN_ENCODE[I].Code; LBits := HPACK_HUFFMAN_ENCODE[I].Bits;
    LNodeIdx := HUFF_ROOT;
    for J := LBits - 1 downto 0 do
    begin
      LBit := (LCode shr J) and 1;
      if LBit = 0 then LChildIdx := FNodes[LNodeIdx].Left else LChildIdx := FNodes[LNodeIdx].Right;
      if LChildIdx = 0 then
      begin
        if FNodeCount >= UInt16(Length(FNodes)) then SetLength(FNodes, Length(FNodes) * 2);
        if LBit = 0 then FNodes[LNodeIdx].Left := FNodeCount else FNodes[LNodeIdx].Right := FNodeCount;
        FNodes[FNodeCount].Sym := -1; FNodes[FNodeCount].Left := 0; FNodes[FNodeCount].Right := 0;
        LChildIdx := FNodeCount; Inc(FNodeCount);
      end;
      LNodeIdx := LChildIdx;
    end;
    FNodes[LNodeIdx].Sym := Int16(I);
  end;
  LNodeIdx := HUFF_ROOT;
  for J := 29 downto 0 do
  begin
    if FNodes[LNodeIdx].Right = 0 then
    begin
      if FNodeCount >= UInt16(Length(FNodes)) then SetLength(FNodes, Length(FNodes) * 2);
      FNodes[LNodeIdx].Right := FNodeCount;
      FNodes[FNodeCount].Sym := -1; FNodes[FNodeCount].Left := 0; FNodes[FNodeCount].Right := 0;
      Inc(FNodeCount);
    end;
    LNodeIdx := FNodes[LNodeIdx].Right;
  end;
  FNodes[LNodeIdx].Sym := HUFF_EOS_SYM;
end;

procedure BuildNibbleTable;
var LNodeIdx: UInt16; LNibble: Byte; LBit: Byte;
  LCurNode, LChild: UInt16; LConsumed: Byte; LSym: SmallInt;
begin
  SetLength(FNibbleTable, FNodeCount);
  for LNodeIdx := 0 to FNodeCount - 1 do
    for LNibble := 0 to 15 do
    begin
      LCurNode := LNodeIdx; LSym := -1; LConsumed := 0;
      for LBit := 0 to 3 do
      begin
        if ((LNibble shr (3 - LBit)) and 1) = 0 then LChild := FNodes[LCurNode].Left
        else LChild := FNodes[LCurNode].Right;
        if LChild = 0 then Break;
        Inc(LConsumed); LCurNode := LChild;
        if FNodes[LCurNode].Sym >= 0 then begin LSym := FNodes[LCurNode].Sym; LCurNode := HUFF_ROOT; end;
      end;
      FNibbleTable[LNodeIdx, LNibble].Symbol := LSym;
      FNibbleTable[LNodeIdx, LNibble].NextNode := LCurNode;
      FNibbleTable[LNodeIdx, LNibble].Consumed := LConsumed;
    end;
end;

function CoreDecode(const AData: PAnsiChar; const ADataLen: SizeInt;
  const ALimit: SizeInt; out ATruncated: Boolean): AnsiString;
const
  STACK_BUF_SIZE = 512;
var LByte: Byte; I: SizeInt; LOutputPos: SizeInt;
  LNode: UInt16; LEntry: ^THuffNibbleEntry; LNibble: Byte;
  LStackBuf: array[0..STACK_BUF_SIZE - 1] of AnsiChar;
  LHeapStr: AnsiString;
begin
  ATruncated := False;
  if (AData = nil) or (ADataLen <= 0) then Exit('');
  LOutputPos := 0; LNode := HUFF_ROOT; I := 0;
  LHeapStr := '';
  while I < ADataLen do
  begin
    LByte := Byte(AData[I]);
    LNibble := (LByte shr 4) and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then raise EHttpError.Create('HPACK Huffman: EOS symbol');
      Inc(LOutputPos);
      if (ALimit >= 0) and (LOutputPos > ALimit) then begin ATruncated := True; Exit(''); end;
      if LOutputPos <= STACK_BUF_SIZE then
        LStackBuf[LOutputPos - 1] := AnsiChar(LEntry^.Symbol)
      else
      begin
        if LHeapStr = '' then
        begin
          SetLength(LHeapStr, LOutputPos);
          Move(LStackBuf[0], LHeapStr[1], LOutputPos - 1);
        end;
        if LOutputPos > Length(LHeapStr) then
          SetLength(LHeapStr, LOutputPos + 255);
        LHeapStr[LOutputPos] := AnsiChar(LEntry^.Symbol);
      end;
    end;
    LNode := LEntry^.NextNode;
    LNibble := LByte and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then raise EHttpError.Create('HPACK Huffman: EOS symbol');
      Inc(LOutputPos);
      if (ALimit >= 0) and (LOutputPos > ALimit) then begin ATruncated := True; Exit(''); end;
      if LOutputPos <= STACK_BUF_SIZE then
        LStackBuf[LOutputPos - 1] := AnsiChar(LEntry^.Symbol)
      else
      begin
        if LHeapStr = '' then
        begin
          SetLength(LHeapStr, LOutputPos);
          Move(LStackBuf[0], LHeapStr[1], LOutputPos - 1);
        end;
        if LOutputPos > Length(LHeapStr) then
          SetLength(LHeapStr, LOutputPos + 255);
        LHeapStr[LOutputPos] := AnsiChar(LEntry^.Symbol);
      end;
    end;
    LNode := LEntry^.NextNode;
    Inc(I);
  end;
  if LHeapStr <> '' then
  begin
    SetLength(LHeapStr, LOutputPos);
    Result := LHeapStr;
  end
  else
    SetString(Result, LStackBuf, LOutputPos);
end;

function H2HuffmanEncode(const AData: AnsiString): AnsiString;
var I: SizeInt; LByte: Byte; LCode: UInt32; LBits: Byte;
  LAccum: UInt64; LAccumBits: Byte; LOutPos: SizeInt;
begin
  Result := ''; if AData = '' then Exit;
  SetLength(Result, (Length(AData) * 8 + 7) div 8 + 4);
  LAccum := 0; LAccumBits := 0; LOutPos := 0;
  for I := 1 to Length(AData) do
  begin
    LByte := Byte(AData[I]);
    LCode := HPACK_HUFFMAN_ENCODE[LByte].Code;
    LBits := HPACK_HUFFMAN_ENCODE[LByte].Bits;
    LAccum := (LAccum shl LBits) or LCode; Inc(LAccumBits, LBits);
    while LAccumBits >= 8 do
    begin Dec(LAccumBits, 8); Inc(LOutPos);
      if LOutPos > Length(Result) then SetLength(Result, Length(Result) + 64);
      Result[LOutPos] := AnsiChar((LAccum shr LAccumBits) and $FF);
    end;
  end;
  if LAccumBits > 0 then
  begin
    LAccum := (LAccum shl (8 - LAccumBits)) or ((1 shl (8 - LAccumBits)) - 1);
    Inc(LOutPos); if LOutPos > Length(Result) then SetLength(Result, Length(Result) + 1);
    Result[LOutPos] := AnsiChar(LAccum and $FF);
  end;
  SetLength(Result, LOutPos);
end;

function H2HuffmanDecode(const AData: AnsiString): AnsiString;
var LTruncated: Boolean;
begin
  Result := CoreDecode(PAnsiChar(AData), Length(AData), -1, LTruncated);
end;

function H2HuffmanDecodeLimited(const AData: AnsiString;
  const ALimit: SizeInt; out ATruncated: Boolean): AnsiString;
begin
  if ALimit < 0 then Result := CoreDecode(PAnsiChar(AData), Length(AData), -1, ATruncated)
  else Result := CoreDecode(PAnsiChar(AData), Length(AData), ALimit, ATruncated);
end;

function H2HuffmanDecodeRaw(const AData: PAnsiChar; const ALen: SizeInt): AnsiString;
var LTruncated: Boolean;
begin
  if (AData = nil) or (ALen <= 0) then Exit('');
  Result := CoreDecode(AData, ALen, -1, LTruncated);
end;

function H2HuffmanDecodeBuf(const AData: PAnsiChar; const ADataLen: SizeInt;
  var ABuf; const ABufSize: SizeInt; out AOutLen: SizeInt): Boolean;
var LByte: Byte; I: SizeInt; LOutputPos: SizeInt;
  LNode: UInt16; LEntry: ^THuffNibbleEntry; LNibble: Byte;
  LOut: PAnsiChar;
begin
  if (AData = nil) or (ADataLen <= 0) then begin AOutLen := 0; Exit(True); end;
  LOutputPos := 0; LNode := HUFF_ROOT; I := 0;
  LOut := PAnsiChar(@ABuf);
  while I < ADataLen do
  begin
    LByte := Byte(AData[I]);
    LNibble := (LByte shr 4) and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then begin AOutLen := 0; Exit(False); end;
      Inc(LOutputPos);
      if LOutputPos > ABufSize then begin AOutLen := 0; Exit(False); end;
      LOut[LOutputPos - 1] := AnsiChar(LEntry^.Symbol);
    end;
    LNode := LEntry^.NextNode;
    LNibble := LByte and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then begin AOutLen := 0; Exit(False); end;
      Inc(LOutputPos);
      if LOutputPos > ABufSize then begin AOutLen := 0; Exit(False); end;
      LOut[LOutputPos - 1] := AnsiChar(LEntry^.Symbol);
    end;
    LNode := LEntry^.NextNode;
    Inc(I);
  end;
  AOutLen := LOutputPos;
  Result := True;
end;

procedure H2HuffmanDecodeInto(const AData: PAnsiChar; const ADataLen: SizeInt;
  out AStr: AnsiString);
var LByte: Byte; I: SizeInt; LOutputPos: SizeInt;
  LNode: UInt16; LEntry: ^THuffNibbleEntry; LNibble: Byte;
  LOut: PAnsiChar;
begin
  if (AData = nil) or (ADataLen <= 0) then begin AStr := ''; Exit; end;
  { Pre-allocate to max possible size (huffman max expansion < 2x) }
  SetLength(AStr, ADataLen * 2 + 16);
  LOut := PAnsiChar(AStr);
  LOutputPos := 0; LNode := HUFF_ROOT; I := 0;
  while I < ADataLen do
  begin
    LByte := Byte(AData[I]);
    LNibble := (LByte shr 4) and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then begin AStr := ''; Exit; end;
      LOut[LOutputPos] := AnsiChar(LEntry^.Symbol);
      Inc(LOutputPos);
    end;
    LNode := LEntry^.NextNode;
    LNibble := LByte and $F;
    LEntry := @FNibbleTable[LNode, LNibble];
    if LEntry^.Symbol >= 0 then
    begin
      if LEntry^.Symbol = HUFF_EOS_SYM then begin AStr := ''; Exit; end;
      LOut[LOutputPos] := AnsiChar(LEntry^.Symbol);
      Inc(LOutputPos);
    end;
    LNode := LEntry^.NextNode;
    Inc(I);
  end;
  SetLength(AStr, LOutputPos);
end;

initialization
  BuildDecodeTrie;
  BuildNibbleTable;

finalization
  FNodes := nil;
  FNibbleTable := nil;

end.
