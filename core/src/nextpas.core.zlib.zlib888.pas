unit nextpas.core.zlib.zlib888;

{**
 * @desc nextpas.core.zlib.pure - 纯 Pascal Deflate/Inflate（raw -15 + zlib-wrapped）
 *
 * c2pas素材（inflate.c / inftrees.c / inffast.c + adler32.c / deflate.c / trees.c / compress.c）手调，
 * 零 paszlib/zlib 依赖；Decode 支持裸流与 RFC1950 包装双路径，
 * Adler 校验 + 32MiB 爆破上限（ZLIB_MAX_DECOMPRESS_BYTES）。
 * Encode 采用动态 Huffman（Heap 建树、码长限制 15、Code 生成）+ 固定/Stored 回退，
 * 窗口 32K，hash-chain 加速，游程码长按级别对齐 compress2 0/1/6/9。
 * 输出 zlib-wrapped（header + deflate + adler），level 映射 0/1/-1/9。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.zlib.base,
  nextpas.core.zlib.intf;

type
  TZlibPureDecoder = class(TInterfacedObject, IZlibDecoder, IZlibEncoder)
  public
    function Encode(const AData: TBytes): TBytes;
    function EncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
    function TryEncode(const AData: TBytes; out AEncoded: TBytes): Boolean;
    function TryEncodeWithError(const AData: TBytes; out AEncoded: TBytes; out AError: string): Boolean;
    function TryEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes): Boolean;
    function TryEncodeWithLevelWithError(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes; out AError: string): Boolean;
    function Decode(const AData: TBytes): TBytes;
    function DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
    function TryDecode(const AData: TBytes; out ADecoded: TBytes): Boolean;
    function TryDecodeWithError(const AData: TBytes; out ADecoded: TBytes; out AError: string): Boolean;
    function TryDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes): Boolean;
    function TryDecodeWithLimitWithError(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes; out AError: string): Boolean;
    function Adler32(const AData: TBytes): LongWord;
    function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
  end;

function ZlibPureDecode(const AData: TBytes): TBytes;
function ZlibPureDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
function ZlibPureDecodeRaw(const AData: TBytes): TBytes;
function ZlibPureDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;

function ZlibPureEncode(const AData: TBytes): TBytes;
function ZlibPureEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
function ZlibPureEncodeRaw(const AData: TBytes): TBytes;
function ZlibPureEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;

function CreateZlibPureDecoder: IZlibDecoder;
function CreateZlibPureEncoder: IZlibEncoder;

implementation

const
  CMaxBits = 15;
  CMaxBLBits = 7;
  CNumLitLen = 286;
  CNumDist = 30;
  CNumCLen = 19;
  CWindowSize = 32768;
  CTableSize = 1 shl CMaxBits;
  CHashSize = 32768;
  CHashMask = CHashSize - 1;
  CWindowMask = CWindowSize - 1;

  CLengthOrder: array[0..18] of Byte = (16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

  CBaseLength: array[0..28] of Word = (
    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258
  );
  CExtraLength: array[0..28] of Byte = (
    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0
  );
  CBaseDist: array[0..29] of Word = (
    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577
  );
  CExtraDist: array[0..29] of Byte = (
    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13
  );

type
  TBitReader = record
    Data: PByte;
    Len: SizeUInt;
    Pos: SizeUInt;
    Hold: LongWord;
    Bits: Integer;
  end;

  THuffBuild = record
    MaxBits: Integer;
    Count: Integer;
    Codes: array[0..CNumLitLen - 1] of Word;
    Lens: array[0..CNumLitLen - 1] of Byte;
  end;

  THuffEntry = record
    Bits: Byte;
    Symbol: Word;
  end;
  THuffFastTable = record
    FastBits: Integer;
    FastMask: LongWord;
    SecBits: Integer;
    SecMask: LongWord;
    MaxBits: Integer;
    Fast: array of THuffEntry;
    Second: array of array of THuffEntry;
  end;

  TBitWriter = record
    Buf: TBytes;
    Len: SizeUInt;
    Cap: SizeUInt;
    Hold: QWord;
    Bits: Integer;
  end;

  TDeflateToken = record
    IsLit: Boolean;
    Lit: Byte;
    LenSym: Integer;
    LenExtra: Word;
    LenBits: Byte;
    DistSym: Integer;
    DistExtra: Word;
    DistBits: Byte;
  end;
  TDeflateTokens = array of TDeflateToken;

procedure RaiseZlib(ACode: TZlibErrorCode; const AMsg: string); inline;
begin
  raise EZlibError.Create(ACode, AMsg);
end;

function ReverseBits(AValue: LongWord; ABits: Integer): LongWord; inline;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ABits - 1 do
  begin
    Result := (Result shl 1) or (AValue and 1);
    AValue := AValue shr 1;
  end;
end;

procedure BrInit(var AR: TBitReader; AData: PByte; ALen: SizeUInt); inline;
begin
  AR.Data := AData;
  AR.Len := ALen;
  AR.Pos := 0;
  AR.Hold := 0;
  AR.Bits := 0;
end;

procedure BrFill(var AR: TBitReader; ANeed: Integer); inline;
var
  LRem: SizeUInt;
begin
  while AR.Bits < ANeed do
  begin
    if AR.Pos >= AR.Len then
      Exit;
    LRem := AR.Len - AR.Pos;
    if (ANeed >= 15) and (AR.Bits <= 16) and (LRem >= 2) then
    begin
      AR.Hold := AR.Hold or (LongWord(PWord(AR.Data + AR.Pos)^) shl AR.Bits);
      Inc(AR.Pos, 2);
      Inc(AR.Bits, 16);
    end
    else
    begin
      AR.Hold := AR.Hold or (LongWord(AR.Data[AR.Pos]) shl AR.Bits);
      Inc(AR.Pos);
      Inc(AR.Bits, 8);
    end;
  end;
end;

procedure BrFill15(var AR: TBitReader); inline;
begin
  BrFill(AR, 15);
end;

function BrBits(var AR: TBitReader; ANeed: Integer): LongWord; inline;
begin
  BrFill(AR, ANeed);
  if AR.Bits < ANeed then
    RaiseZlib(zecTruncated, 'zlib: truncated stream');
  Result := AR.Hold and ((LongWord(1) shl ANeed) - 1);
end;

procedure BrDrop(var AR: TBitReader; ANeed: Integer); inline;
begin
  AR.Hold := AR.Hold shr ANeed;
  Dec(AR.Bits, ANeed);
end;

function BrGet(var AR: TBitReader; ANeed: Integer): LongWord; inline;
begin
  Result := BrBits(AR, ANeed);
  BrDrop(AR, ANeed);
end;

procedure BrAlign(var AR: TBitReader); inline;
var
  LSkip: Integer;
begin
  LSkip := AR.Bits and 7;
  if LSkip <> 0 then
    BrDrop(AR, LSkip);
end;

function IsValidZlibHeader(const A0, A1: Byte): Boolean; inline;
var
  LHeader: Word;
begin
  Result := False;
  if (A0 and $0F) <> ZLIB_CMF_DEFLATED then Exit;
  if (A0 shr 4) > 7 then Exit;
  LHeader := (Word(A0) shl 8) or Word(A1);
  if (LHeader mod 31) <> 0 then Exit;
  if (A1 and $20) <> 0 then Exit;
  Result := True;
end;

procedure BuildHuffman(const ALens: PByte; ACount: Integer; var AOut: THuffBuild);
var
  LCount: array[0..15] of Integer;
  LNext: array[0..15] of LongWord;
  LCode: LongWord;
  I, LLen: Integer;
  LMax: Integer;
  LRev: LongWord;
begin
  FillChar(LCount, SizeOf(LCount), 0);
  LMax := 0;
  for I := 0 to ACount - 1 do
  begin
    LLen := ALens[I];
    if LLen > CMaxBits then
      RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
    if LLen > LMax then LMax := LLen;
    if LLen > 0 then Inc(LCount[LLen]);
  end;
  AOut.MaxBits := LMax;
  AOut.Count := ACount;
  for I := 0 to ACount - 1 do
  begin
    AOut.Codes[I] := 0;
    AOut.Lens[I] := 0;
  end;
  if LMax = 0 then Exit;
  LCode := 0;
  LNext[0] := 0;
  for I := 1 to CMaxBits do
  begin
    LCode := (LCode + LongWord(LCount[I - 1])) shl 1;
    LNext[I] := LCode;
  end;
  for I := 0 to ACount - 1 do
  begin
    LLen := ALens[I];
    if LLen = 0 then Continue;
    LCode := LNext[LLen];
    Inc(LNext[LLen]);
    LRev := ReverseBits(LCode, LLen);
    AOut.Codes[I] := Word(LRev);
    AOut.Lens[I] := Byte(LLen);
  end;
end;

function DecodeSymbol(var AR: TBitReader; const ABuild: THuffBuild): Integer;
var
  LLen: Integer;
  LPeek: LongWord;
  I: Integer;
begin
  if ABuild.MaxBits = 0 then
    RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  for LLen := 1 to ABuild.MaxBits do
  begin
    BrFill(AR, LLen);
    if AR.Bits < LLen then
      RaiseZlib(zecTruncated, 'zlib: truncated stream');
    LPeek := AR.Hold and ((LongWord(1) shl LLen) - 1);
    for I := 0 to ABuild.Count - 1 do
      if (ABuild.Lens[I] = LLen) and (ABuild.Codes[I] = Word(LPeek)) then
      begin
        BrDrop(AR, LLen);
        Exit(I);
      end;
  end;
  RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  Result := -1;
end;

const
  CFastBitsLit = 10;
  CFastBitsDist = 7;
  CFastMarkSecond = 255;

procedure BuildFastTable(const ABuild: THuffBuild; AFastBits: Integer; var ATable: THuffFastTable);
var
  LFastSize, LSecSize, LMax, LLen: Integer;
  I, K, LCode: Integer;
  LPrefix, LSuffix, LRem, LCopies, LSecIdx: Integer;
  J: Integer;
begin
  LMax := ABuild.MaxBits;
  ATable.FastBits := AFastBits;
  ATable.FastMask := (LongWord(1) shl AFastBits) - 1;
  ATable.MaxBits := LMax;
  if LMax > AFastBits then
  begin
    ATable.SecBits := LMax - AFastBits;
    ATable.SecMask := (LongWord(1) shl ATable.SecBits) - 1;
  end
  else
  begin
    ATable.SecBits := 0;
    ATable.SecMask := 0;
  end;
  LFastSize := 1 shl AFastBits;
  SetLength(ATable.Fast, LFastSize);
  for I := 0 to LFastSize - 1 do
  begin
    ATable.Fast[I].Bits := 0;
    ATable.Fast[I].Symbol := $FFFF;
  end;
  SetLength(ATable.Second, LFastSize);
  for I := 0 to LFastSize - 1 do
    SetLength(ATable.Second[I], 0);
  if LMax = 0 then Exit;
  if ATable.SecBits > 0 then
    LSecSize := 1 shl ATable.SecBits
  else
    LSecSize := 0;
  for I := 0 to ABuild.Count - 1 do
  begin
    LLen := ABuild.Lens[I];
    if LLen = 0 then Continue;
    LCode := Integer(ABuild.Codes[I]);
    if LLen <= AFastBits then
    begin
      LCopies := 1 shl (AFastBits - LLen);
      for K := 0 to LCopies - 1 do
      begin
        LSecIdx := LCode or (K shl LLen);
        ATable.Fast[LSecIdx].Bits := Byte(LLen);
        ATable.Fast[LSecIdx].Symbol := Word(I);
      end;
    end
    else
    begin
      LPrefix := LCode and Integer(ATable.FastMask);
      LSuffix := LCode shr AFastBits;
      LRem := LLen - AFastBits;
      if Length(ATable.Second[LPrefix]) = 0 then
      begin
        SetLength(ATable.Second[LPrefix], LSecSize);
        for J := 0 to LSecSize - 1 do
        begin
          ATable.Second[LPrefix][J].Bits := 0;
          ATable.Second[LPrefix][J].Symbol := $FFFF;
        end;
      end;
      LCopies := 1 shl (ATable.SecBits - LRem);
      for K := 0 to LCopies - 1 do
      begin
        LSecIdx := LSuffix or (K shl LRem);
        ATable.Second[LPrefix][LSecIdx].Bits := Byte(LLen);
        ATable.Second[LPrefix][LSecIdx].Symbol := Word(I);
      end;
      ATable.Fast[LPrefix].Bits := CFastMarkSecond;
    end;
  end;
end;

function FastDecodeSymbol(var AR: TBitReader; const ATbl: THuffFastTable): Integer; inline;
var
  LIdx, LSecIdx: LongWord;
  E: THuffEntry;
begin
  BrFill(AR, ATbl.MaxBits);
  LIdx := AR.Hold and ATbl.FastMask;
  E := ATbl.Fast[LIdx];
  if E.Bits = 0 then
    RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  if E.Bits <> CFastMarkSecond then
  begin
    if AR.Bits < E.Bits then
      RaiseZlib(zecTruncated, 'zlib: truncated stream');
    BrDrop(AR, E.Bits);
    Result := Integer(E.Symbol);
    Exit;
  end;
  if ATbl.SecBits = 0 then
    RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  LSecIdx := (AR.Hold shr ATbl.FastBits) and ATbl.SecMask;
  if (Integer(LIdx) >= Length(ATbl.Second)) or (Length(ATbl.Second[LIdx]) = 0) then
    RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  E := ATbl.Second[LIdx][LSecIdx];
  if E.Bits = 0 then
    RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  if AR.Bits < E.Bits then
    RaiseZlib(zecTruncated, 'zlib: truncated stream');
  BrDrop(AR, E.Bits);
  Result := Integer(E.Symbol);
end;

procedure GrowBytes(var ABuf: TBytes; var ALen: SizeUInt; var ACap: SizeUInt; ANeed: SizeUInt; ALimit: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  if (ANeed > ALimit) or (ALen > ALimit - ANeed) then
    RaiseZlib(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
  LNewCap := ACap;
  if LNewCap = 0 then LNewCap := 64;
  if LNewCap > ALimit then LNewCap := ALimit;
  while LNewCap < ALen + ANeed do
  begin
    if LNewCap > ALimit div 2 then
      LNewCap := ALimit
    else
      LNewCap := LNewCap shl 1;
    if LNewCap > ALimit then LNewCap := ALimit;
    if (LNewCap = ALimit) and (LNewCap < ALen + ANeed) then
      RaiseZlib(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
  end;
  SetLength(ABuf, LNewCap);
  ACap := LNewCap;
end;

procedure BuildFixedTables(var ALit: THuffBuild; var ADist: THuffBuild);
var
  LLens: array[0..CNumLitLen - 1] of Byte;
  DLens: array[0..CNumDist - 1] of Byte;
  I: Integer;
begin
  for I := 0 to CNumLitLen - 1 do
  begin
    if I <= 143 then LLens[I] := 8
    else if I <= 255 then LLens[I] := 9
    else if I <= 279 then LLens[I] := 7
    else LLens[I] := 8;
  end;
  for I := 0 to CNumDist - 1 do
    DLens[I] := 5;
  BuildHuffman(@LLens[0], CNumLitLen, ALit);
  BuildHuffman(@DLens[0], CNumDist, ADist);
end;

{ ── BitWriter ──────────────────────────────────────────────── }

procedure BwInit(var BW: TBitWriter; ACap: SizeUInt); inline;
begin
  BW.Len := 0;
  BW.Cap := 0;
  BW.Hold := 0;
  BW.Bits := 0;
  if ACap = 0 then ACap := 64;
  SetLength(BW.Buf, ACap);
  BW.Cap := ACap;
end;

procedure BwEnsure(var BW: TBitWriter; ANeed: SizeUInt); inline;
var
  LNewCap: SizeUInt;
begin
  if BW.Len + ANeed <= BW.Cap then Exit;
  LNewCap := BW.Cap;
  if LNewCap = 0 then LNewCap := 64;
  while LNewCap < BW.Len + ANeed do
  begin
    if LNewCap > High(SizeUInt) div 2 then
      LNewCap := High(SizeUInt)
    else
      LNewCap := LNewCap shl 1;
  end;
  SetLength(BW.Buf, LNewCap);
  BW.Cap := LNewCap;
end;

procedure BwWrite(var BW: TBitWriter; AValue: LongWord; ABits: Integer); inline;
begin
  BW.Hold := BW.Hold or (QWord(AValue) shl BW.Bits);
  Inc(BW.Bits, ABits);
  while BW.Bits >= 32 do
  begin
    BwEnsure(BW, 4);
    PLongWord(@BW.Buf[BW.Len])^ := LongWord(BW.Hold and $FFFFFFFF);
    Inc(BW.Len, 4);
    BW.Hold := BW.Hold shr 32;
    Dec(BW.Bits, 32);
  end;
end;

procedure BwAlign(var BW: TBitWriter); inline;
begin
  if BW.Bits > 0 then
  begin
    while BW.Bits >= 32 do
    begin
      BwEnsure(BW, 4);
      PLongWord(@BW.Buf[BW.Len])^ := LongWord(BW.Hold and $FFFFFFFF);
      Inc(BW.Len, 4);
      BW.Hold := BW.Hold shr 32;
      Dec(BW.Bits, 32);
    end;
    if BW.Bits >= 16 then
    begin
      BwEnsure(BW, 2);
      PWord(@BW.Buf[BW.Len])^ := Word(BW.Hold and $FFFF);
      Inc(BW.Len, 2);
      BW.Hold := BW.Hold shr 16;
      Dec(BW.Bits, 16);
    end;
    if BW.Bits >= 8 then
    begin
      BwEnsure(BW, 1);
      BW.Buf[BW.Len] := Byte(BW.Hold);
      Inc(BW.Len);
      BW.Hold := BW.Hold shr 8;
      Dec(BW.Bits, 8);
    end;
    if BW.Bits > 0 then
    begin
      BwEnsure(BW, 1);
      BW.Buf[BW.Len] := Byte(BW.Hold);
      Inc(BW.Len);
      BW.Hold := 0;
      BW.Bits := 0;
    end
    else
    begin
      BW.Hold := 0;
      BW.Bits := 0;
    end;
  end;
end;

procedure BwFlush(var BW: TBitWriter); inline;
begin
  BwAlign(BW);
end;

{ ── Fixed tables cache ───────────────────────────────────── }

var
  GFixedLit: THuffBuild;
  GFixedDist: THuffBuild;
  GFixedReady: LongInt = 0;
  GFixedLock: TRTLCriticalSection;
  GFixedFastLit: THuffFastTable;
  GFixedFastDist: THuffFastTable;
  GFixedFastReady: LongInt = 0;

procedure EnsureFixed;
begin
  if InterlockedCompareExchange(GFixedReady, 0, 0) <> 0 then Exit;
  EnterCriticalSection(GFixedLock);
  try
    if GFixedReady <> 0 then Exit;
    BuildFixedTables(GFixedLit, GFixedDist);
    InterlockedExchange(GFixedReady, 1);
  finally
    LeaveCriticalSection(GFixedLock);
  end;
end;

procedure EnsureFixedFast;
begin
  if InterlockedCompareExchange(GFixedFastReady, 0, 0) <> 0 then Exit;
  EnterCriticalSection(GFixedLock);
  try
    if GFixedFastReady <> 0 then Exit;
    EnsureFixed;
    BuildFastTable(GFixedLit, CFastBitsLit, GFixedFastLit);
    BuildFastTable(GFixedDist, CFastBitsDist, GFixedFastDist);
    InterlockedExchange(GFixedFastReady, 1);
  finally
    LeaveCriticalSection(GFixedLock);
  end;
end;

{ ── Helpers for length/distance symbol ───────────────────── }

var
  GLenSym: array[0..258] of SmallInt;
  GLenExtra: array[0..258] of Word;
  GLenBits: array[0..258] of Byte;
  GDistSym: array[0..32768] of SmallInt;
  GDistExtra: array[0..32768] of Word;
  GDistBits: array[0..32768] of Byte;
  GLenDistReady: LongInt = 0;
  GLenDistLock: TRTLCriticalSection;

procedure EnsureLenDist;
var I, J: Integer; LBase, LLimit: Word;
begin
  if InterlockedCompareExchange(GLenDistReady, 0, 0) <> 0 then Exit;
  EnterCriticalSection(GLenDistLock);
  try
    if GLenDistReady <> 0 then Exit;
    for I := 0 to 258 do begin GLenSym[I] := -1; GLenExtra[I] := 0; GLenBits[I] := 0; end;
    for I := 0 to 28 do
    begin
      LBase := CBaseLength[I];
      if CExtraLength[I] = 0 then LLimit := LBase else LLimit := LBase + (Word(1) shl CExtraLength[I]) - 1;
      for J := LBase to LLimit do if (J <= 258) then begin GLenSym[J] := SmallInt(257 + I); GLenExtra[J] := Word(J - LBase); GLenBits[J] := CExtraLength[I]; end;
    end;
    for I := 0 to 32768 do begin GDistSym[I] := -1; GDistExtra[I] := 0; GDistBits[I] := 0; end;
    for I := 0 to 29 do
    begin
      LBase := CBaseDist[I];
      if CExtraDist[I] = 0 then LLimit := LBase else LLimit := LBase + (Word(1) shl CExtraDist[I]) - 1;
      for J := LBase to LLimit do if (J <= 32768) then begin GDistSym[J] := SmallInt(I); GDistExtra[J] := Word(J - LBase); GDistBits[J] := CExtraDist[I]; end;
    end;
    InterlockedExchange(GLenDistReady, 1);
  finally
    LeaveCriticalSection(GLenDistLock);
  end;
end;

function FindLengthSym(ALen: Word; out ASym: Integer; out AExtra: Word; out AExtraBits: Byte): Boolean; inline;
begin
  EnsureLenDist;
  if (ALen < 3) or (ALen > 258) then Exit(False);
  ASym := GLenSym[ALen];
  if ASym < 0 then Exit(False);
  AExtra := GLenExtra[ALen];
  AExtraBits := GLenBits[ALen];
  Result := True;
end;

function FindDistSym(ADist: Word; out ASym: Integer; out AExtra: Word; out AExtraBits: Byte): Boolean; inline;
begin
  EnsureLenDist;
  if (ADist < 1) or (ADist > 32768) then Exit(False);
  ASym := GDistSym[ADist];
  if ASym < 0 then Exit(False);
  AExtra := GDistExtra[ADist];
  AExtraBits := GDistBits[ADist];
  Result := True;
end;

function ZlibHeaderForLevel(ALevel: TZlibLevel): Word;
var
  Cmf: Byte;
  FLevel: Byte;
  Flg: Byte;
begin
  Cmf := $78;
  case ALevel of
    zlNone:    FLevel := 0;
    zlFastest: FLevel := 0;
    zlBest:    FLevel := 3;
  else
    FLevel := 2;
  end;
  Flg := FLevel shl 6;
  Flg := Flg or Byte((31 - ((Word(Cmf) shl 8 or Flg) mod 31)) mod 31);
  Result := (Word(Cmf) shl 8) or Word(Flg);
end;

{ ── Stored (no compression) ──────────────────────────────── }

procedure DeflateStored(const AData: TBytes; var BW: TBitWriter);
var
  LPos, LRem, LChunk: SizeUInt;
  LLen: Word;
  LTotal: SizeUInt;
  LBlocks: SizeUInt;
begin
  LRem := SizeUInt(Length(AData));
  if LRem = 0 then
  begin
    if BW.Bits <> 0 then
      BwAlign(BW);
    BwEnsure(BW, 5);
    BW.Buf[BW.Len] := 1; Inc(BW.Len);
    BW.Buf[BW.Len] := 0; Inc(BW.Len);
    BW.Buf[BW.Len] := 0; Inc(BW.Len);
    BW.Buf[BW.Len] := $FF; Inc(BW.Len);
    BW.Buf[BW.Len] := $FF; Inc(BW.Len);
    Exit;
  end;
  if BW.Bits <> 0 then
    BwAlign(BW);
  LBlocks := (LRem + 65535 - 1) div 65535;
  LTotal := LRem + LBlocks * 5;
  BwEnsure(BW, LTotal);
  LPos := 0;
  while LPos < LRem do
  begin
    LChunk := LRem - LPos;
    if LChunk > 65535 then LChunk := 65535;
    if LPos + LChunk >= LRem then
      BW.Buf[BW.Len] := 1
    else
      BW.Buf[BW.Len] := 0;
    Inc(BW.Len);
    LLen := Word(LChunk);
    BW.Buf[BW.Len] := Byte(LLen and $FF); Inc(BW.Len);
    BW.Buf[BW.Len] := Byte(LLen shr 8); Inc(BW.Len);
    BW.Buf[BW.Len] := Byte((not LLen) and $FF); Inc(BW.Len);
    BW.Buf[BW.Len] := Byte((not LLen shr 8) and $FF); Inc(BW.Len);
    if LChunk > 0 then
    begin
      Move(AData[LPos], BW.Buf[BW.Len], LChunk);
      Inc(BW.Len, LChunk);
    end;
    Inc(LPos, LChunk);
  end;
end;

{ ── Huffman lens builder (Heap + overflow) ───────────────── }

procedure BuildLensFromFreq(const AFreq: PLongWord; ACount: Integer; AMaxBits: Integer; ALens: PByte);
var
  LMaxNodes: Integer;
  LNodesFreq: array of LongWord;
  LNodesDad: array of Integer;
  LHeap: array of Integer;
  LHeapCnt: Integer;
  LLens: array of Integer;
  LBlCount: array[0..32] of Integer;
  LSorted: array of Integer;
  I, J, K, LNode, LBestA, LBestB: Integer;
  LOverflow: Integer;
  LBits, LMax: Integer;
  LTmp: Integer;
  // heap helpers inline
  procedure HeapPush(AIdx: Integer);
  var Idx, Par: Integer; Tmp: Integer;
  begin
    Idx := LHeapCnt;
    LHeap[Idx] := AIdx;
    Inc(LHeapCnt);
    while Idx > 0 do
    begin
      Par := (Idx - 1) shr 1;
      if LNodesFreq[LHeap[Par]] <= LNodesFreq[LHeap[Idx]] then Break;
      Tmp := LHeap[Par]; LHeap[Par] := LHeap[Idx]; LHeap[Idx] := Tmp;
      Idx := Par;
    end;
  end;
  function HeapPop: Integer;
  var Idx, Ch, Best: Integer; Tmp: Integer;
  begin
    Result := LHeap[0];
    Dec(LHeapCnt);
    if LHeapCnt > 0 then
    begin
      LHeap[0] := LHeap[LHeapCnt];
      Idx := 0;
      while True do
      begin
        Ch := Idx * 2 + 1;
        if Ch >= LHeapCnt then Break;
        Best := Ch;
        if (Ch + 1 < LHeapCnt) and (LNodesFreq[LHeap[Ch + 1]] < LNodesFreq[LHeap[Ch]]) then Best := Ch + 1;
        if LNodesFreq[LHeap[Idx]] <= LNodesFreq[LHeap[Best]] then Break;
        Tmp := LHeap[Idx]; LHeap[Idx] := LHeap[Best]; LHeap[Best] := Tmp;
        Idx := Best;
      end;
    end;
  end;
begin
  for I := 0 to ACount - 1 do ALens[I] := 0;
  LMaxNodes := ACount * 2 + 4;
  SetLength(LNodesFreq, LMaxNodes);
  SetLength(LNodesDad, LMaxNodes);
  for I := 0 to LMaxNodes - 1 do
  begin
    LNodesFreq[I] := 0;
    LNodesDad[I] := -1;
  end;
  for I := 0 to ACount - 1 do LNodesFreq[I] := AFreq[I];
  SetLength(LHeap, LMaxNodes);
  LHeapCnt := 0;
  for I := 0 to ACount - 1 do
    if AFreq[I] <> 0 then
    begin
      LHeap[LHeapCnt] := I;
      Inc(LHeapCnt);
    end;
  // heapify bottom-up — O(n) vs O(n log n) push
  for I := (LHeapCnt div 2) - 1 downto 0 do
  begin
    K := I;
    while True do
    begin
      J := K * 2 + 1;
      if J >= LHeapCnt then Break;
      LNode := J;
      if (J + 1 < LHeapCnt) and (LNodesFreq[LHeap[J + 1]] < LNodesFreq[LHeap[J]]) then
        LNode := J + 1;
      if LNodesFreq[LHeap[K]] <= LNodesFreq[LHeap[LNode]] then Break;
      LTmp := LHeap[K]; LHeap[K] := LHeap[LNode]; LHeap[LNode] := LTmp;
      K := LNode;
    end;
  end;
  if LHeapCnt = 0 then Exit;
  if LHeapCnt = 1 then
  begin
    for I := 0 to ACount - 1 do
      if AFreq[I] = 0 then
      begin
        LNodesFreq[I] := 1;
        HeapPush(I);
        Break;
      end;
    if LHeapCnt = 1 then
    begin
      ALens[LHeap[0]] := 1;
      Exit;
    end;
  end;
  if LHeapCnt = 2 then
  begin
    LBestA := HeapPop; LBestB := HeapPop;
    ALens[LBestA] := 1;
    ALens[LBestB] := 1;
    Exit;
  end;
  LNode := ACount;
  while LHeapCnt > 1 do
  begin
    LBestA := HeapPop;
    LBestB := HeapPop;
    LNodesFreq[LNode] := LNodesFreq[LBestA] + LNodesFreq[LBestB];
    LNodesDad[LBestA] := LNode;
    LNodesDad[LBestB] := LNode;
    LNodesDad[LNode] := -1;
    HeapPush(LNode);
    Inc(LNode);
  end;
  SetLength(LLens, ACount);
  for I := 0 to ACount - 1 do LLens[I] := 0;
  LMax := 0;
  for I := 0 to ACount - 1 do
    if AFreq[I] <> 0 then
    begin
      K := I; J := 0;
      while LNodesDad[K] <> -1 do begin K := LNodesDad[K]; Inc(J); if J > 32 then Break; end;
      LLens[I] := J;
      if J > LMax then LMax := J;
    end;
  if LMax <= AMaxBits then
  begin
    for I := 0 to ACount - 1 do ALens[I] := Byte(LLens[I]);
    Exit;
  end;
  // overflow handling: bl_count
  for I := 0 to 32 do LBlCount[I] := 0;
  LOverflow := 0;
  for I := 0 to ACount - 1 do
    if LLens[I] <> 0 then
    begin
      if LLens[I] > AMaxBits then
      begin
        Inc(LBlCount[AMaxBits]);
        Inc(LOverflow);
      end else Inc(LBlCount[LLens[I]]);
    end;
  // single-scan bl_count correction
  LBits := AMaxBits - 1;
  while LOverflow > 0 do
  begin
    while (LBits > 0) and (LBlCount[LBits] = 0) do Dec(LBits);
    if LBits = 0 then Break;
    Dec(LBlCount[LBits]);
    Inc(LBlCount[LBits + 1], 2);
    Dec(LBlCount[AMaxBits]);
    Dec(LOverflow, 2);
    if LBlCount[LBits] = 0 then Dec(LBits);
  end;
  // reassign lens by frequency order
  SetLength(LSorted, ACount);
  for I := 0 to ACount - 1 do LSorted[I] := I;
  // sort by freq descending, zero last
  for I := 0 to ACount - 2 do
    for J := I + 1 to ACount - 1 do
      if AFreq[LSorted[I]] < AFreq[LSorted[J]] then
      begin LTmp := LSorted[I]; LSorted[I] := LSorted[J]; LSorted[J] := LTmp; end;
  // skip zero freq at end
  K := 0;
  for LBits := 1 to AMaxBits do
  begin
    for I := 1 to LBlCount[LBits] do
    begin
      while (K < ACount) and (AFreq[LSorted[K]] = 0) do Inc(K);
      if K >= ACount then Break;
      LLens[LSorted[K]] := LBits;
      Inc(K);
    end;
  end;
  // ensure zero freq stays 0 (overwritten already)
  for I := 0 to ACount - 1 do if AFreq[I] = 0 then LLens[I] := 0;
  for I := 0 to ACount - 1 do ALens[I] := Byte(LLens[I]);
end;

{ ── Hash helpers ─────────────────────────────────────────── }

function Hash3(const AData: TBytes; APos: SizeUInt): Integer; inline;
var
  P: PByte;
begin
  P := @AData[APos];
  Result := (Integer(PWord(P)^) xor (Integer(P[2]) shl 5)) and CHashMask;
end;

procedure FindBest(const AData: TBytes; APos: SizeUInt; ALen: SizeUInt;
  const LHead: array of Integer; const LPrev: array of Integer;
  AMaxChain, AMaxDist, ANice: Integer; out ABestLen, ABestDist: Integer);
var
  LHash, LCand, LChain, LCur, LMax: Integer;
begin
  ABestLen := 0; ABestDist := 0;
  if APos + 2 >= ALen then Exit;
  LHash := Hash3(AData, APos);
  LCand := LHead[LHash];
  LChain := 0;
  LMax := Integer(ALen - APos);
  if LMax > 258 then LMax := 258;
  if ANice <= 0 then ANice := 258;
  if ANice > 258 then ANice := 258;
  while (LCand >= 0) and (LChain < AMaxChain) do
  begin
    if Integer(APos) - LCand > AMaxDist then
    begin
      LCand := LPrev[LCand and CWindowMask];
      Inc(LChain);
      Continue;
    end;
    if (LMax >= 8) and (Integer(ALen) - LCand >= 8) then
    begin
      if PLongWord(@AData[LCand])^ <> PLongWord(@AData[APos])^ then
      begin
        LCand := LPrev[LCand and CWindowMask];
        Inc(LChain);
        Continue;
      end;
      LCur := 4;
      while LCur + 8 <= LMax do
      begin
        if PQWord(@AData[LCand + LCur])^ <> PQWord(@AData[APos + LCur])^ then Break;
        Inc(LCur, 8);
      end;
      while LCur + 4 <= LMax do
      begin
        if PLongWord(@AData[LCand + LCur])^ <> PLongWord(@AData[APos + LCur])^ then Break;
        Inc(LCur, 4);
      end;
      while (LCur < LMax) and (AData[LCand + LCur] = AData[APos + LCur]) do Inc(LCur);
    end
    else if (LMax >= 4) and (Integer(ALen) - LCand >= 4) then
    begin
      if PLongWord(@AData[LCand])^ <> PLongWord(@AData[APos])^ then
      begin
        LCand := LPrev[LCand and CWindowMask];
        Inc(LChain);
        Continue;
      end;
      LCur := 4;
      while LCur + 4 <= LMax do
      begin
        if PLongWord(@AData[LCand + LCur])^ <> PLongWord(@AData[APos + LCur])^ then Break;
        Inc(LCur, 4);
      end;
      while (LCur < LMax) and (AData[LCand + LCur] = AData[APos + LCur]) do Inc(LCur);
    end
    else
    begin
      if AData[LCand] <> AData[APos] then
      begin
        LCand := LPrev[LCand and CWindowMask];
        Inc(LChain);
        Continue;
      end;
      LCur := 1;
      while (LCur < LMax) and (AData[LCand + LCur] = AData[APos + LCur]) do Inc(LCur);
    end;
    if (LCur >= 3) and (LCur > ABestLen) then
    begin
      ABestLen := LCur;
      ABestDist := Integer(APos) - LCand;
      if ABestLen >= ANice then Break;
    end;
    LCand := LPrev[LCand and CWindowMask];
    Inc(LChain);
  end;
end;

{ ── Token collection ─────────────────────────────────────── }

procedure CollectTokens(const AData: TBytes; AMaxChain, ANice, ALazyThresh, AMaxDist: Integer;
  out ATokens: TDeflateTokens; out ALitFreq: array of LongWord; out ADistFreq: array of LongWord);
var
  LLen: SizeUInt;
  LHead: array of Integer;
  LPrev: array of Integer;
  LPos: SizeUInt;
  LBestLen, LBestDist: Integer;
  LNextLen, LNextDist: Integer;
  LSym: Integer;
  LExtra: Word;
  LBits: Byte;
  LDSym: Integer;
  LDExtra: Word;
  LDBits: Byte;
  LTok: TDeflateToken;
  I: Integer;
  LTokCount, LTokCap: Integer;
begin
  LLen := SizeUInt(Length(AData));
  SetLength(LHead, CHashSize);
  if CHashSize > 0 then
    FillChar(LHead[0], CHashSize * SizeOf(Integer), $FF);
  SetLength(LPrev, CWindowSize);
  FillChar(LPrev[0], CWindowSize * SizeOf(Integer), $FF);
  SetLength(ATokens, 0);
  for I := 0 to High(ALitFreq) do ALitFreq[I] := 0;
  for I := 0 to High(ADistFreq) do ADistFreq[I] := 0;
  if LLen = 0 then Exit;
  EnsureLenDist;
  // pre-allocate tokens: doubling growth to avoid O(n^2) SetLength
  SetLength(ATokens, 1024);
  LTokCount := 0;
  LTokCap := 1024;
  LPos := 0;
  while LPos < LLen do
  begin
    FindBest(AData, LPos, LLen, LHead, LPrev, AMaxChain, AMaxDist, ANice, LBestLen, LBestDist);
    // lazy: ALazyThresh = 0 disables, 4 classic, 8-16 for best speed
    if (ALazyThresh > 0) and (LBestLen >= ALazyThresh) and (LBestLen < 258) and (LPos + 1 < LLen) then
    begin
      if LPos + 2 < LLen then
      begin
        LPrev[LPos and CWindowMask] := LHead[Hash3(AData, LPos)];
        LHead[Hash3(AData, LPos)] := Integer(LPos);
      end;
      FindBest(AData, LPos + 1, LLen, LHead, LPrev, AMaxChain, AMaxDist, ANice, LNextLen, LNextDist);
      if LNextLen > LBestLen then
      begin
        LTok.IsLit := True;
        LTok.Lit := AData[LPos];
        if LTokCount >= LTokCap then
        begin
          LTokCap := LTokCap * 2;
          SetLength(ATokens, LTokCap);
        end;
        ATokens[LTokCount] := LTok;
        Inc(LTokCount);
        Inc(ALitFreq[AData[LPos]]);
        Inc(LPos);
        Continue;
      end else
      begin
        LSym := GLenSym[LBestLen]; LExtra := GLenExtra[LBestLen]; LBits := GLenBits[LBestLen];
        if LSym < 0 then RaiseZlib(zecInternal, 'zlib: length sym fail');
        LDSym := GDistSym[LBestDist]; LDExtra := GDistExtra[LBestDist]; LDBits := GDistBits[LBestDist];
        if LDSym < 0 then RaiseZlib(zecInternal, 'zlib: dist sym fail');
        LTok.IsLit := False;
        LTok.LenSym := LSym;
        LTok.LenExtra := LExtra;
        LTok.LenBits := LBits;
        LTok.DistSym := LDSym;
        LTok.DistExtra := LDExtra;
        LTok.DistBits := LDBits;
        if LTokCount >= LTokCap then
        begin
          LTokCap := LTokCap * 2;
          SetLength(ATokens, LTokCap);
        end;
        ATokens[LTokCount] := LTok;
        Inc(LTokCount);
        Inc(ALitFreq[LSym]);
        Inc(ADistFreq[LDSym]);
        if AMaxDist >= CWindowSize then
          for I := 1 to LBestLen - 1 do
          begin
            if LPos + SizeUInt(I) + 2 < LLen then
            begin
              LPrev[(LPos + SizeUInt(I)) and CWindowMask] := LHead[Hash3(AData, LPos + I)];
              LHead[Hash3(AData, LPos + I)] := Integer(LPos + I);
            end;
          end;
        Inc(LPos, SizeUInt(LBestLen));
        Continue;
      end;
    end;
    if LBestLen >= 3 then
    begin
      if LPos + 2 < LLen then
      begin
        LPrev[LPos and CWindowMask] := LHead[Hash3(AData, LPos)];
        LHead[Hash3(AData, LPos)] := Integer(LPos);
      end;
      LSym := GLenSym[LBestLen]; LExtra := GLenExtra[LBestLen]; LBits := GLenBits[LBestLen];
      if LSym < 0 then RaiseZlib(zecInternal, 'zlib: length sym fail');
      LDSym := GDistSym[LBestDist]; LDExtra := GDistExtra[LBestDist]; LDBits := GDistBits[LBestDist];
      if LDSym < 0 then RaiseZlib(zecInternal, 'zlib: dist sym fail');
      LTok.IsLit := False;
      LTok.LenSym := LSym;
      LTok.LenExtra := LExtra;
      LTok.LenBits := LBits;
      LTok.DistSym := LDSym;
      LTok.DistExtra := LDExtra;
      LTok.DistBits := LDBits;
      if LTokCount >= LTokCap then
      begin
        LTokCap := LTokCap * 2;
        SetLength(ATokens, LTokCap);
      end;
      ATokens[LTokCount] := LTok;
      Inc(LTokCount);
      Inc(ALitFreq[LSym]);
      Inc(ADistFreq[LDSym]);
      if AMaxDist >= CWindowSize then
        for I := 1 to LBestLen - 1 do
        begin
          if LPos + SizeUInt(I) + 2 < LLen then
          begin
            LPrev[(LPos + SizeUInt(I)) and CWindowMask] := LHead[Hash3(AData, LPos + I)];
            LHead[Hash3(AData, LPos + I)] := Integer(LPos + I);
          end;
        end;
      Inc(LPos, SizeUInt(LBestLen));
    end else
    begin
      if LPos + 2 < LLen then
      begin
        LPrev[LPos and CWindowMask] := LHead[Hash3(AData, LPos)];
        LHead[Hash3(AData, LPos)] := Integer(LPos);
      end;
      LTok.IsLit := True;
      LTok.Lit := AData[LPos];
      if LTokCount >= LTokCap then
      begin
        LTokCap := LTokCap * 2;
        SetLength(ATokens, LTokCap);
      end;
      ATokens[LTokCount] := LTok;
      Inc(LTokCount);
      Inc(ALitFreq[AData[LPos]]);
      Inc(LPos);
    end;
  end;
  SetLength(ATokens, LTokCount);
end;

{ ── Dynamic block writer ─────────────────────────────────── }

procedure WriteDynamicBlock(const ATokens: TDeflateTokens;
  const ALitFreq, ADistFreq: array of LongWord; var BW: TBitWriter; AIsLast: Boolean);
var
  LLens: array[0..CNumLitLen - 1] of Byte;
  DLens: array[0..CNumDist - 1] of Byte;
  LBLens: array[0..CNumCLen - 1] of Byte;
  LitBuild, DistBuild, BLBuild: THuffBuild;
  LitNum, DistNum, BlNum: Integer;
  I, LLast: Integer;
  LCombined: array of Byte;
  BLFreq: array[0..CNumCLen - 1] of LongWord;
  LMaxCode: Integer;
  LPrevLen, LCurLen, LNextLen, LCount, LMaxCnt, LMinCnt: Integer;
begin
  for I := 0 to CNumLitLen - 1 do LLens[I] := 0;
  for I := 0 to CNumDist - 1 do DLens[I] := 0;
  for I := 0 to CNumCLen - 1 do LBLens[I] := 0;
  // build lens from freq (ensure EOB)
  BuildLensFromFreq(@ALitFreq[0], CNumLitLen, CMaxBits, @LLens[0]);
  // must have EOB 256 at least 1
  if LLens[256] = 0 then
  begin
    // force one
    LLens[256] := 1;
  end;
  BuildLensFromFreq(@ADistFreq[0], CNumDist, CMaxBits, @DLens[0]);
  // trim
  LLast := CNumLitLen - 1;
  while (LLast > 256) and (LLens[LLast] = 0) do Dec(LLast);
  LitNum := LLast + 1;
  if LitNum < 257 then LitNum := 257;
  LLast := CNumDist - 1;
  while (LLast > 0) and (DLens[LLast] = 0) do Dec(LLast);
  DistNum := LLast + 1;
  if DistNum < 1 then DistNum := 1;
  if (DistNum = 1) and (DLens[0] = 0) then DLens[0] := 1;
  // combined
  SetLength(LCombined, LitNum + DistNum + 1);
  for I := 0 to LitNum - 1 do LCombined[I] := LLens[I];
  for I := 0 to DistNum - 1 do LCombined[LitNum + I] := DLens[I];
  LCombined[LitNum + DistNum] := $FF;
  // scan for BL freq
  for I := 0 to CNumCLen - 1 do BLFreq[I] := 0;
  LMaxCode := LitNum + DistNum - 1;
  LPrevLen := -1;
  LCount := 0;
  LNextLen := LCombined[0];
  if LNextLen = 0 then begin LMaxCnt := 138; LMinCnt := 3; end else begin LMaxCnt := 7; LMinCnt := 4; end;
  for I := 0 to LMaxCode do
  begin
    LCurLen := LNextLen;
    LNextLen := LCombined[I + 1];
    Inc(LCount);
    if (LCount < LMaxCnt) and (LCurLen = LNextLen) then Continue;
    if LCount < LMinCnt then
      Inc(BLFreq[LCurLen], LCount)
    else if LCurLen <> 0 then
    begin
      if LCurLen <> LPrevLen then Inc(BLFreq[LCurLen]);
      Inc(BLFreq[16]);
    end else if LCount <= 10 then
      Inc(BLFreq[17])
    else
      Inc(BLFreq[18]);
    LCount := 0;
    LPrevLen := LCurLen;
    if LNextLen = 0 then begin LMaxCnt := 138; LMinCnt := 3; end
    else if LCurLen = LNextLen then begin LMaxCnt := 6; LMinCnt := 3; end
    else begin LMaxCnt := 7; LMinCnt := 4; end;
  end;
  // build BL lens (max 7)
  BuildLensFromFreq(@BLFreq[0], CNumCLen, CMaxBLBits, @LBLens[0]);
  // build codes
  BuildHuffman(@LLens[0], CNumLitLen, LitBuild);
  BuildHuffman(@DLens[0], CNumDist, DistBuild);
  BuildHuffman(@LBLens[0], CNumCLen, BLBuild);
  // determine HCLEN
  LLast := 18;
  while (LLast >= 0) and (LBLens[CLengthOrder[LLast]] = 0) do Dec(LLast);
  BlNum := LLast + 1;
  if BlNum < 4 then BlNum := 4;
  // header
  if AIsLast then BwWrite(BW, 1, 1) else BwWrite(BW, 0, 1);
  BwWrite(BW, 2, 2); // dynamic
  BwWrite(BW, LongWord(LitNum - 257), 5);
  BwWrite(BW, LongWord(DistNum - 1), 5);
  BwWrite(BW, LongWord(BlNum - 4), 4);
  for I := 0 to BlNum - 1 do
    BwWrite(BW, LBLens[CLengthOrder[I]], 3);
  // send combined lens RLE using BL codes
  LPrevLen := -1;
  LCount := 0;
  LNextLen := LCombined[0];
  if LNextLen = 0 then begin LMaxCnt := 138; LMinCnt := 3; end else begin LMaxCnt := 7; LMinCnt := 4; end;
  for I := 0 to LMaxCode do
  begin
    LCurLen := LNextLen;
    LNextLen := LCombined[I + 1];
    Inc(LCount);
    if (LCount < LMaxCnt) and (LCurLen = LNextLen) then Continue;
    if LCount < LMinCnt then
    begin
      while LCount > 0 do
      begin
        BwWrite(BW, BLBuild.Codes[LCurLen], BLBuild.Lens[LCurLen]);
        Dec(LCount);
      end;
    end else if LCurLen <> 0 then
    begin
      if LCurLen <> LPrevLen then
      begin
        BwWrite(BW, BLBuild.Codes[LCurLen], BLBuild.Lens[LCurLen]);
        Dec(LCount);
      end;
      BwWrite(BW, BLBuild.Codes[16], BLBuild.Lens[16]);
      BwWrite(BW, LongWord(LCount - 3), 2);
    end else if LCount <= 10 then
    begin
      BwWrite(BW, BLBuild.Codes[17], BLBuild.Lens[17]);
      BwWrite(BW, LongWord(LCount - 3), 3);
    end else
    begin
      BwWrite(BW, BLBuild.Codes[18], BLBuild.Lens[18]);
      BwWrite(BW, LongWord(LCount - 11), 7);
    end;
    LCount := 0;
    LPrevLen := LCurLen;
    if LNextLen = 0 then begin LMaxCnt := 138; LMinCnt := 3; end
    else if LCurLen = LNextLen then begin LMaxCnt := 6; LMinCnt := 3; end
    else begin LMaxCnt := 7; LMinCnt := 4; end;
  end;
  // tokens
  for I := 0 to High(ATokens) do
  begin
    if ATokens[I].IsLit then
      BwWrite(BW, LitBuild.Codes[ATokens[I].Lit], LitBuild.Lens[ATokens[I].Lit])
    else
    begin
      BwWrite(BW, LitBuild.Codes[ATokens[I].LenSym], LitBuild.Lens[ATokens[I].LenSym]);
      if ATokens[I].LenBits > 0 then BwWrite(BW, ATokens[I].LenExtra, ATokens[I].LenBits);
      BwWrite(BW, DistBuild.Codes[ATokens[I].DistSym], DistBuild.Lens[ATokens[I].DistSym]);
      if ATokens[I].DistBits > 0 then BwWrite(BW, ATokens[I].DistExtra, ATokens[I].DistBits);
    end;
  end;
  BwWrite(BW, LitBuild.Codes[256], LitBuild.Lens[256]);
end;

{ ── Fixed Huffman with hash chain ────────────────────────── }

procedure DeflateFixed(const AData: TBytes; var BW: TBitWriter; ALevel: TZlibLevel);
var
  LLen: SizeUInt;
  LPos: SizeUInt;
  LHead: array[0..CHashSize - 1] of Integer;
  LPrev: array of Integer;
  LHash: Integer;
  LCand, LBestLen, LBestDist, LCurLen, LMaxLen, LMaxChain, LChainCnt, LNice: Integer;
  LSym: Integer;
  LWExtra: Word;
  LEBits: Byte;
  LDSym: Integer;
  LDExtra: Word;
  LDEBits: Byte;
  I: Integer;
  LMaxDist: Integer;
begin
  EnsureFixed;
  LLen := SizeUInt(Length(AData));
  if LLen = 0 then
  begin
    BwWrite(BW, 1, 1);
    BwWrite(BW, 1, 2);
    BwWrite(BW, GFixedLit.Codes[256], GFixedLit.Lens[256]);
    BwFlush(BW);
    Exit;
  end;
  for I := 0 to CHashSize - 1 do LHead[I] := -1;
  SetLength(LPrev, CWindowSize);
  FillChar(LPrev[0], CWindowSize * SizeOf(Integer), $FF);
  case ALevel of
    zlFastest: begin LMaxChain := 8; LNice := 8; end;
    zlBest:    begin LMaxChain := 128; LNice := 258; end;
  else
    begin LMaxChain := 8; LNice := 32; end;
  end;
  LMaxDist := CWindowSize;
  BwWrite(BW, 1, 1);
  BwWrite(BW, 1, 2);
  LPos := 0;
  while LPos < LLen do
  begin
    if LPos + 2 < LLen then
    begin
      LHash := Hash3(AData, LPos);
      LCand := LHead[LHash];
      LBestLen := 0;
      LBestDist := 0;
      LChainCnt := 0;
      LMaxLen := Integer(LLen - LPos);
      if LMaxLen > 258 then LMaxLen := 258;
      while (LCand >= 0) and (LChainCnt < LMaxChain) do
      begin
        if LPos - SizeUInt(LCand) > SizeUInt(LMaxDist) then
        begin
          LCand := LPrev[LCand and CWindowMask];
          Inc(LChainCnt);
          Continue;
        end;
        if (LMaxLen >= 8) and (Integer(LLen) - LCand >= 8) then
        begin
          if PLongWord(@AData[LCand])^ <> PLongWord(@AData[LPos])^ then
          begin
            LCand := LPrev[LCand and CWindowMask];
            Inc(LChainCnt);
            Continue;
          end;
          LCurLen := 4;
          while LCurLen + 8 <= LMaxLen do
          begin
            if PQWord(@AData[LCand + LCurLen])^ <> PQWord(@AData[LPos + LCurLen])^ then Break;
            Inc(LCurLen, 8);
          end;
          while LCurLen + 4 <= LMaxLen do
          begin
            if PLongWord(@AData[LCand + LCurLen])^ <> PLongWord(@AData[LPos + LCurLen])^ then Break;
            Inc(LCurLen, 4);
          end;
          while (LCurLen < LMaxLen) and (AData[LCand + LCurLen] = AData[LPos + LCurLen]) do
            Inc(LCurLen);
        end
        else if (LMaxLen >= 4) and (Integer(LLen) - LCand >= 4) then
        begin
          if PLongWord(@AData[LCand])^ <> PLongWord(@AData[LPos])^ then
          begin
            LCand := LPrev[LCand and CWindowMask];
            Inc(LChainCnt);
            Continue;
          end;
          LCurLen := 4;
          while LCurLen + 4 <= LMaxLen do
          begin
            if PLongWord(@AData[LCand + LCurLen])^ <> PLongWord(@AData[LPos + LCurLen])^ then Break;
            Inc(LCurLen, 4);
          end;
          while (LCurLen < LMaxLen) and (AData[LCand + LCurLen] = AData[LPos + LCurLen]) do
            Inc(LCurLen);
        end
        else
        begin
          if AData[LCand] <> AData[LPos] then
          begin
            LCand := LPrev[LCand and CWindowMask];
            Inc(LChainCnt);
            Continue;
          end;
          LCurLen := 1;
          while (LCurLen < LMaxLen) and (AData[LCand + LCurLen] = AData[LPos + LCurLen]) do
            Inc(LCurLen);
        end;
        if (LCurLen >= 3) and (LCurLen > LBestLen) then
        begin
          LBestLen := LCurLen;
          LBestDist := Integer(LPos) - LCand;
          if LBestLen >= LNice then Break;
        end;
        LCand := LPrev[LCand and CWindowMask];
        Inc(LChainCnt);
      end;
      LPrev[LPos and CWindowMask] := LHead[LHash];
      LHead[LHash] := Integer(LPos);
      if LBestLen >= 3 then
      begin
        if not FindLengthSym(Word(LBestLen), LSym, LWExtra, LEBits) then
          RaiseZlib(zecInternal, 'zlib: length sym fail');
        BwWrite(BW, GFixedLit.Codes[LSym], GFixedLit.Lens[LSym]);
        if LEBits > 0 then
          BwWrite(BW, LWExtra, LEBits);
        if not FindDistSym(Word(LBestDist), LDSym, LDExtra, LDEBits) then
          RaiseZlib(zecInternal, 'zlib: dist sym fail');
        BwWrite(BW, GFixedDist.Codes[LDSym], GFixedDist.Lens[LDSym]);
        if LDEBits > 0 then
          BwWrite(BW, LDExtra, LDEBits);
        for I := 1 to LBestLen - 1 do
        begin
          if LPos + SizeUInt(I) + 2 < LLen then
          begin
            LHash := Hash3(AData, LPos + SizeUInt(I));
            LPrev[(LPos + SizeUInt(I)) and CWindowMask] := LHead[LHash];
            LHead[LHash] := Integer(LPos+I);
          end;
        end;
        Inc(LPos, SizeUInt(LBestLen));
        Continue;
      end;
      BwWrite(BW, GFixedLit.Codes[AData[LPos]], GFixedLit.Lens[AData[LPos]]);
      Inc(LPos);
    end
    else
    begin
      BwWrite(BW, GFixedLit.Codes[AData[LPos]], GFixedLit.Lens[AData[LPos]]);
      Inc(LPos);
    end;
  end;
  BwWrite(BW, GFixedLit.Codes[256], GFixedLit.Lens[256]);
  BwFlush(BW);
end;

procedure DeflateDynamic(const AData: TBytes; var BW: TBitWriter; ALevel: TZlibLevel);
var
  LLitFreq: array[0..CNumLitLen - 1] of LongWord;
  LDistFreq: array[0..CNumDist - 1] of LongWord;
  LTokens: TDeflateTokens;
  LMaxChain, LNice, LLazyThresh, LBlockSize, LMaxDist: Integer;
  LLen, LPos, LChunk: SizeUInt;
  LSlice: TBytes;
  LIsLast: Boolean;
begin
  if Length(AData) = 0 then
  begin
    EnsureFixed;
    BwWrite(BW, 1, 1);
    BwWrite(BW, 1, 2);
    BwWrite(BW, GFixedLit.Codes[256], GFixedLit.Lens[256]);
    BwFlush(BW);
    Exit;
  end;
  case ALevel of
    zlFastest: begin LMaxChain := 8; LNice := 8; LLazyThresh := 0; LBlockSize := 0; LMaxDist := 2048; end;
    zlBest: begin LMaxChain := 128; LNice := 32; LLazyThresh := 0; LBlockSize := 0; LMaxDist := CWindowSize; end;
  else
    begin LMaxChain := 8; LNice := 32; LLazyThresh := 0; LBlockSize := 0; LMaxDist := CWindowSize; end;
  end;
  LLen := SizeUInt(Length(AData));
  if (LBlockSize <= 0) or (LLen <= SizeUInt(LBlockSize)) then
  begin
    CollectTokens(AData, LMaxChain, LNice, LLazyThresh, LMaxDist, LTokens, LLitFreq, LDistFreq);
    Inc(LLitFreq[256]);
    WriteDynamicBlock(LTokens, LLitFreq, LDistFreq, BW, True);
    BwFlush(BW);
    Exit;
  end;
  LPos := 0;
  while LPos < LLen do
  begin
    LChunk := LLen - LPos;
    if LChunk > SizeUInt(LBlockSize) then LChunk := SizeUInt(LBlockSize);
    // avoid tiny tail < 4KB
    if (LChunk < 4096) and (LPos + LChunk < LLen) then
      LChunk := LLen - LPos;
    SetLength(LSlice, LChunk);
    if LChunk > 0 then
      Move(AData[LPos], LSlice[0], LChunk);
    CollectTokens(LSlice, LMaxChain, LNice, LLazyThresh, LMaxDist, LTokens, LLitFreq, LDistFreq);
    Inc(LLitFreq[256]);
    LIsLast := (LPos + LChunk >= LLen);
    WriteDynamicBlock(LTokens, LLitFreq, LDistFreq, BW, LIsLast);
    Inc(LPos, LChunk);
  end;
  BwFlush(BW);
end;

function DeflateEncodeRaw(const AData: TBytes; ALevel: TZlibLevel; AStoredOnly: Boolean): TBytes;
var
  BW: TBitWriter;
  LEst: SizeUInt;
  LLen: SizeUInt;
  LBlocks: SizeUInt;
  LPos, LChunk: SizeUInt;
  LOff: SizeUInt;
  LLenW: Word;
begin
  Result := nil;
  if AStoredOnly then
  begin
    LLen := SizeUInt(Length(AData));
    if LLen = 0 then
    begin
      SetLength(Result, 5);
      Result[0] := 1; Result[1] := 0; Result[2] := 0; Result[3] := $FF; Result[4] := $FF;
      Exit;
    end;
    LBlocks := (LLen + 65535 - 1) div 65535;
    SetLength(Result, LLen + LBlocks * 5);
    LPos := 0;
    LOff := 0;
    while LPos < LLen do
    begin
      LChunk := LLen - LPos;
      if LChunk > 65535 then LChunk := 65535;
      if LPos + LChunk >= LLen then
        Result[LOff] := 1
      else
        Result[LOff] := 0;
      Inc(LOff);
      LLenW := Word(LChunk);
      Result[LOff] := Byte(LLenW and $FF); Inc(LOff);
      Result[LOff] := Byte(LLenW shr 8); Inc(LOff);
      Result[LOff] := Byte((not LLenW) and $FF); Inc(LOff);
      Result[LOff] := Byte((not LLenW shr 8) and $FF); Inc(LOff);
      if LChunk > 0 then
      begin
        Move(AData[LPos], Result[LOff], LChunk);
        Inc(LOff, LChunk);
      end;
      Inc(LPos, LChunk);
    end;
    Exit;
  end;
  LEst := SizeUInt(Length(AData)) + 16;
  if LEst < 64 then LEst := 64;
  BwInit(BW, LEst);
  DeflateDynamic(AData, BW, ALevel);
  SetLength(BW.Buf, BW.Len);
  Result := BW.Buf;
end;

function DeflateEncodeZlib(const AData: TBytes; ALevel: TZlibLevel): TBytes;
var
  LRaw: TBytes;
  LHeader: Word;
  LAdler: LongWord;
  LTotal: SizeUInt;
  LLen: SizeUInt;
  LBlocks, LStoredSize: SizeUInt;
  LPos, LChunk: SizeUInt;
  LOff: SizeUInt;
  LLenW: Word;
begin
  if ALevel = zlNone then
  begin
    LLen := SizeUInt(Length(AData));
    LHeader := ZlibHeaderForLevel(ALevel);
    if Length(AData) = 0 then
      LAdler := ZLIB_ADLER_INIT
    else
      LAdler := ZlibAdlerUpdate(ZLIB_ADLER_INIT, @AData[0], LLen);
    if LLen = 0 then
      LStoredSize := 5
    else
    begin
      LBlocks := (LLen + 65535 - 1) div 65535;
      LStoredSize := LLen + LBlocks * 5;
    end;
    LTotal := 2 + LStoredSize + 4;
    SetLength(Result, LTotal);
    Result[0] := Byte(LHeader shr 8);
    Result[1] := Byte(LHeader and $FF);
    LOff := 2;
    if LLen = 0 then
    begin
      Result[LOff] := 1; Inc(LOff);
      Result[LOff] := 0; Inc(LOff);
      Result[LOff] := 0; Inc(LOff);
      Result[LOff] := $FF; Inc(LOff);
      Result[LOff] := $FF; Inc(LOff);
    end
    else
    begin
      LPos := 0;
      while LPos < LLen do
      begin
        LChunk := LLen - LPos;
        if LChunk > 65535 then LChunk := 65535;
        if LPos + LChunk >= LLen then
          Result[LOff] := 1
        else
          Result[LOff] := 0;
        Inc(LOff);
        LLenW := Word(LChunk);
        Result[LOff] := Byte(LLenW and $FF); Inc(LOff);
        Result[LOff] := Byte(LLenW shr 8); Inc(LOff);
        Result[LOff] := Byte((not LLenW) and $FF); Inc(LOff);
        Result[LOff] := Byte((not LLenW shr 8) and $FF); Inc(LOff);
        if LChunk > 0 then
        begin
          Move(AData[LPos], Result[LOff], LChunk);
          Inc(LOff, LChunk);
        end;
        Inc(LPos, LChunk);
      end;
    end;
    Result[LTotal - 4] := Byte(LAdler shr 24);
    Result[LTotal - 3] := Byte((LAdler shr 16) and $FF);
    Result[LTotal - 2] := Byte((LAdler shr 8) and $FF);
    Result[LTotal - 1] := Byte(LAdler and $FF);
    ZlibLevelToZlib(ALevel);
    Exit;
  end;
  LRaw := DeflateEncodeRaw(AData, ALevel, False);
  LHeader := ZlibHeaderForLevel(ALevel);
  if Length(AData) = 0 then
    LAdler := ZLIB_ADLER_INIT
  else
    LAdler := ZlibAdlerUpdate(ZLIB_ADLER_INIT, @AData[0], SizeUInt(Length(AData)));
  LTotal := 2 + SizeUInt(Length(LRaw)) + 4;
  SetLength(Result, LTotal);
  Result[0] := Byte(LHeader shr 8);
  Result[1] := Byte(LHeader and $FF);
  if Length(LRaw) > 0 then
    Move(LRaw[0], Result[2], Length(LRaw));
  Result[LTotal - 4] := Byte(LAdler shr 24);
  Result[LTotal - 3] := Byte((LAdler shr 16) and $FF);
  Result[LTotal - 2] := Byte((LAdler shr 8) and $FF);
  Result[LTotal - 1] := Byte(LAdler and $FF);
  ZlibLevelToZlib(ALevel);
end;

function InflateRawInternal(AData: PByte; ALen: SizeUInt; AMax: SizeUInt): TBytes;
var
  R: TBitReader;
  LOut: TBytes;
  LOutLen, LCap: SizeUInt;
  LWindowBuf: array[0..CWindowSize - 1] of Byte;
  LWinPtr: PByte;
  LWinPos: SizeUInt;
  LBFinal: LongWord;
  LBType: LongWord;
  LLitBuild, LDistBuild: THuffBuild;
  LLitFast, LDistFast: THuffFastTable;
  HLIT, HDIST, HCLEN: Integer;
  LCLens: array[0..CNumCLen - 1] of Byte;
  LCLBuild: THuffBuild;
  LCodeLens: array[0..CNumLitLen + CNumDist - 1] of Byte;
  I, LSym, LPrev, LRepeat, LValue: Integer;
  LLen, LDist, LExtra: LongWord;
  LCopyPos: SizeUInt;
  LStoredLen, LStoredNLen: Word;
  J: SizeUInt;
  LBase, LFill: Byte;
  K: SizeUInt;
  LFastIdx: Integer;
  LFastIter: Integer;
begin
  Result := nil;
  if AMax = 0 then AMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if AMax > ZLIB_MAX_DECOMPRESS_BYTES then
    AMax := ZLIB_MAX_DECOMPRESS_BYTES;
  BrInit(R, AData, ALen);
  LOutLen := 0;
  LCap := 0;
  if ALen = 0 then
  begin
    SetLength(LOut, 0);
    Result := LOut;
    Exit;
  end;
  LWinPos := 0;
  LWinPtr := @LWindowBuf[0];
  FillChar(LWindowBuf, SizeOf(LWindowBuf), 0);
  repeat
    LBFinal := BrGet(R, 1);
    LBType := BrGet(R, 2);
    if LBType = 0 then
    begin
      BrAlign(R);
      if R.Pos + 4 > R.Len then
        RaiseZlib(zecTruncated, 'zlib: truncated stream');
      LStoredLen := Word(R.Data[R.Pos]) or (Word(R.Data[R.Pos + 1]) shl 8);
      LStoredNLen := Word(R.Data[R.Pos + 2]) or (Word(R.Data[R.Pos + 3]) shl 8);
      Inc(R.Pos, 4);
      R.Hold := 0;
      R.Bits := 0;
      if Word(LStoredLen xor $FFFF) <> LStoredNLen then
        RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
      if R.Pos + LStoredLen > R.Len then
        RaiseZlib(zecTruncated, 'zlib: truncated stream');
      if LStoredLen > 0 then
      begin
        GrowBytes(LOut, LOutLen, LCap, LStoredLen, AMax);
        Move(R.Data[R.Pos], LOut[LOutLen], LStoredLen);
        for J := 0 to LStoredLen - 1 do
          LWinPtr[(LWinPos + J) and CWindowMask] := R.Data[R.Pos + J];
        LWinPos := (LWinPos + LStoredLen) and CWindowMask;
        Inc(LOutLen, LStoredLen);
        Inc(R.Pos, LStoredLen);
      end;
    end
    else if (LBType = 1) or (LBType = 2) then
    begin
      if LBType = 1 then
      begin
        EnsureFixedFast;
        LLitFast := GFixedFastLit;
        LDistFast := GFixedFastDist;
      end
      else
      begin
        HLIT := Integer(BrGet(R, 5)) + 257;
        HDIST := Integer(BrGet(R, 5)) + 1;
        HCLEN := Integer(BrGet(R, 4)) + 4;
        if (HLIT > CNumLitLen) or (HDIST > CNumDist) then
          RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
        for I := 0 to CNumCLen - 1 do LCLens[I] := 0;
        for I := 0 to HCLEN - 1 do
          LCLens[CLengthOrder[I]] := Byte(BrGet(R, 3));
        BuildHuffman(@LCLens[0], CNumCLen, LCLBuild);
        for I := 0 to HLIT + HDIST - 1 do LCodeLens[I] := 0;
        I := 0;
        LPrev := 0;
        while I < HLIT + HDIST do
        begin
          LSym := DecodeSymbol(R, LCLBuild);
          if LSym <= 15 then
          begin
            LCodeLens[I] := Byte(LSym);
            LPrev := LSym;
            Inc(I);
          end
          else if LSym = 16 then
          begin
            if I = 0 then RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
            LRepeat := Integer(BrGet(R, 2)) + 3;
            LValue := LPrev;
            while LRepeat > 0 do
            begin
              if I >= HLIT + HDIST then RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
              LCodeLens[I] := Byte(LValue);
              Inc(I);
              Dec(LRepeat);
            end;
          end
          else if LSym = 17 then
          begin
            LRepeat := Integer(BrGet(R, 3)) + 3;
            while LRepeat > 0 do
            begin
              if I >= HLIT + HDIST then RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
              LCodeLens[I] := 0;
              Inc(I);
              Dec(LRepeat);
            end;
          end
          else if LSym = 18 then
          begin
            LRepeat := Integer(BrGet(R, 7)) + 11;
            while LRepeat > 0 do
            begin
              if I >= HLIT + HDIST then RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
              LCodeLens[I] := 0;
              Inc(I);
              Dec(LRepeat);
            end;
          end
          else
            RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
        end;
        BuildHuffman(@LCodeLens[0], HLIT, LLitBuild);
        BuildHuffman(@LCodeLens[HLIT], HDIST, LDistBuild);
        if LLitBuild.MaxBits = 0 then
          RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
        BuildFastTable(LLitBuild, CFastBitsLit, LLitFast);
        BuildFastTable(LDistBuild, CFastBitsDist, LDistFast);
      end;
      // inffast: 64 symbols per burst, 15-bit resident, PByte window mask
      while True do
      begin
        for LFastIter := 0 to 63 do
        begin
          BrFill15(R);
          LSym := FastDecodeSymbol(R, LLitFast);
          if LSym < 256 then
          begin
            if LOutLen + 1 > LCap then
              GrowBytes(LOut, LOutLen, LCap, 1, AMax);
            LOut[LOutLen] := Byte(LSym);
            LWinPtr[LWinPos] := Byte(LSym);
            LWinPos := (LWinPos + 1) and CWindowMask;
            Inc(LOutLen);
            Continue;
          end
          else if LSym = 256 then
            Break
          else if (LSym >= 257) and (LSym <= 285) then
          begin
            LLen := CBaseLength[LSym - 257];
            LExtra := CExtraLength[LSym - 257];
            if LExtra > 0 then
              LLen := LLen + BrGet(R, LExtra);
            BrFill15(R);
            LSym := FastDecodeSymbol(R, LDistFast);
            if (LSym < 0) or (LSym >= CNumDist) then
              RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
            LDist := CBaseDist[LSym];
            LExtra := CExtraDist[LSym];
            if LExtra > 0 then
              LDist := LDist + BrGet(R, LExtra);
            if LDist > LOutLen then
            begin
              if LDist > CWindowSize then
                RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
              RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
            end;
            if LDist = 0 then
              RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
            if LOutLen + LLen > LCap then
              GrowBytes(LOut, LOutLen, LCap, LLen, AMax);
            LCopyPos := LOutLen - LDist;
            if LDist = 1 then
            begin
              LBase := LOut[LCopyPos];
              FillChar(LOut[LOutLen], LLen, LBase);
              if LWinPos + LLen <= CWindowSize then
                FillChar(LWinPtr[LWinPos], LLen, LBase)
              else
              begin
                FillChar(LWinPtr[LWinPos], CWindowSize - LWinPos, LBase);
                FillChar(LWinPtr[0], LLen - (CWindowSize - LWinPos), LBase);
              end;
              LWinPos := (LWinPos + LLen) and CWindowMask;
              Inc(LOutLen, LLen);
            end
            else if LLen <= LDist then
            begin
              Move(LOut[LCopyPos], LOut[LOutLen], LLen);
              if LWinPos + LLen <= CWindowSize then
                Move(LOut[LOutLen], LWinPtr[LWinPos], LLen)
              else
              begin
                Move(LOut[LOutLen], LWinPtr[LWinPos], CWindowSize - LWinPos);
                Move(LOut[LOutLen + CWindowSize - LWinPos], LWinPtr[0], LLen - (CWindowSize - LWinPos));
              end;
              LWinPos := (LWinPos + LLen) and CWindowMask;
              Inc(LOutLen, LLen);
            end
            else
            begin
              for K := 0 to LLen - 1 do
              begin
                LFill := LOut[LCopyPos + K];
                LOut[LOutLen + K] := LFill;
              end;
              if LWinPos + LLen <= CWindowSize then
                Move(LOut[LOutLen], LWinPtr[LWinPos], LLen)
              else
              begin
                Move(LOut[LOutLen], LWinPtr[LWinPos], CWindowSize - LWinPos);
                Move(LOut[LOutLen + CWindowSize - LWinPos], LWinPtr[0], LLen - (CWindowSize - LWinPos));
                // still need byte-wise for overlapping tail already copied via loop above
              end;
              // ensure window matches overlapping pattern (already via Move from LOut)
              LWinPos := (LWinPos + LLen) and CWindowMask;
              Inc(LOutLen, LLen);
            end;
          end
          else
            RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
          Continue;
        end;
        // after 64, check if last was EOB
        if LSym = 256 then Break;
      end
    end
    else
      RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
  until LBFinal <> 0;
  SetLength(LOut, LOutLen);
  Result := LOut;
end;

function InflateDetectAndDecompress(AData: PByte; ALen: SizeUInt; AMax: SizeUInt; ARaw: Boolean): TBytes;
var
  LIsWrapped: Boolean;
  LAdlerExp, LAdlerGot: LongWord;
  LDecoded: TBytes;
begin
  if ALen = 0 then
    Exit(nil);
  if ARaw then
    Exit(InflateRawInternal(AData, ALen, AMax));
  if ALen < 2 then
    RaiseZlib(zecTruncated, 'zlib: truncated stream');
  LIsWrapped := IsValidZlibHeader(AData[0], AData[1]);
  if LIsWrapped then
  begin
    if ALen < 6 then
      RaiseZlib(zecTruncated, 'zlib: truncated stream');
    LDecoded := InflateRawInternal(AData + 2, ALen - 6, AMax);
    LAdlerExp := (LongWord(AData[ALen - 4]) shl 24) or (LongWord(AData[ALen - 3]) shl 16) or
                 (LongWord(AData[ALen - 2]) shl 8) or LongWord(AData[ALen - 1]);
    if Length(LDecoded) = 0 then
      LAdlerGot := ZLIB_ADLER_INIT
    else
      LAdlerGot := ZlibAdlerUpdate(ZLIB_ADLER_INIT, @LDecoded[0], SizeUInt(Length(LDecoded)));
    if LAdlerGot <> LAdlerExp then
      RaiseZlib(zecCorruptStream, 'zlib: adler mismatch');
    Result := LDecoded;
  end
  else
  begin
    Result := InflateRawInternal(AData, ALen, AMax);
  end;
end;

function ZlibPureDecode(const AData: TBytes): TBytes;
begin
  Result := ZlibPureDecodeWithLimit(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function ZlibPureDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
var
  LMax: SizeUInt;
begin
  LMax := AMaxOutputSize;
  if LMax = 0 then LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if LMax > ZLIB_MAX_DECOMPRESS_BYTES then
    LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if Length(AData) = 0 then
    Exit(nil);
  Result := InflateDetectAndDecompress(@AData[0], SizeUInt(Length(AData)), LMax, False);
end;

function ZlibPureDecodeRaw(const AData: TBytes): TBytes;
begin
  Result := ZlibPureDecodeRawWithLimit(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function ZlibPureDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
var
  LMax: SizeUInt;
begin
  LMax := AMaxOutputSize;
  if LMax = 0 then LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if LMax > ZLIB_MAX_DECOMPRESS_BYTES then
    LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if Length(AData) = 0 then
    Exit(nil);
  Result := InflateDetectAndDecompress(@AData[0], SizeUInt(Length(AData)), LMax, True);
end;

function ZlibPureEncode(const AData: TBytes): TBytes;
begin
  Result := ZlibPureEncodeWithLevel(AData, zlDefault);
end;

function ZlibPureEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := DeflateEncodeZlib(AData, ALevel);
end;

function ZlibPureEncodeRaw(const AData: TBytes): TBytes;
begin
  Result := ZlibPureEncodeRawWithLevel(AData, zlDefault);
end;

function ZlibPureEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
var
  LStored: Boolean;
begin
  LStored := ALevel = zlNone;
  Result := DeflateEncodeRaw(AData, ALevel, LStored);
end;

function CreateZlibPureDecoder: IZlibDecoder;
begin
  Result := TZlibPureDecoder.Create;
end;

function CreateZlibPureEncoder: IZlibEncoder;
begin
  Result := TZlibPureDecoder.Create;
end;

{ TZlibPureDecoder }

function TZlibPureDecoder.Encode(const AData: TBytes): TBytes;
begin
  Result := DeflateEncodeZlib(AData, zlDefault);
end;

function TZlibPureDecoder.EncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := DeflateEncodeZlib(AData, ALevel);
end;

function TZlibPureDecoder.Decode(const AData: TBytes): TBytes;
begin
  Result := ZlibPureDecode(AData);
end;

function TZlibPureDecoder.DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := ZlibPureDecodeWithLimit(AData, AMaxOutputSize);
end;

function TZlibPureDecoder.TryEncode(const AData: TBytes; out AEncoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithError(AData, AEncoded, LDummy);
end;

function TZlibPureDecoder.TryEncodeWithError(const AData: TBytes; out AEncoded: TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := Encode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibPureDecoder.TryEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithLevelWithError(AData, ALevel, AEncoded, LDummy);
end;

function TZlibPureDecoder.TryEncodeWithLevelWithError(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := EncodeWithLevel(AData, ALevel);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibPureDecoder.TryDecode(const AData: TBytes; out ADecoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithError(AData, ADecoded, LDummy);
end;

function TZlibPureDecoder.TryDecodeWithError(const AData: TBytes; out ADecoded: TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := Decode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibPureDecoder.TryDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithLimitWithError(AData, AMaxOutputSize, ADecoded, LDummy);
end;

function TZlibPureDecoder.TryDecodeWithLimitWithError(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := DecodeWithLimit(AData, AMaxOutputSize);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibPureDecoder.Adler32(const AData: TBytes): LongWord;
begin
  Result := ZlibAdler32(AData);
end;

function TZlibPureDecoder.Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdlerUpdate(AAdler, AData, ALen);
end;

initialization
  InitCriticalSection(GFixedLock);
  InitCriticalSection(GLenDistLock);
finalization
  DoneCriticalSection(GLenDistLock);
  DoneCriticalSection(GFixedLock);
end.
