unit nextpas.core.zlib.pure;

{**
 * @desc nextpas.core.zlib.pure - 纯 Pascal Deflate/Inflate（raw -15 + zlib-wrapped）
 *
 * c2pas素材（inflate.c / inftrees.c / inffast.c + adler32.c / deflate.c / trees.c / compress.c）手调，
 * 零 paszlib/zlib 依赖；Decode 支持裸流与 RFC1950 包装双路径，
 * Adler 校验 + 32MiB 爆破上限（ZLIB_MAX_DECOMPRESS_BYTES）。
 * Encode 采用固定 Huffman + Stored 回退，窗口 32K，hash-chain 加速，
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
    function Decode(const AData: TBytes): TBytes;
    function DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
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
  CNumLitLen = 286;
  CNumDist = 30;
  CNumCLen = 19;
  CWindowSize = 32768;
  CTableSize = 1 shl CMaxBits;
  CHashSize = 32768;
  CHashMask = CHashSize - 1;

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

  TBitWriter = record
    Buf: TBytes;
    Len: SizeUInt;
    Cap: SizeUInt;
    Hold: LongWord;
    Bits: Integer;
  end;

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
begin
  while AR.Bits < ANeed do
  begin
    if AR.Pos >= AR.Len then
      Exit;
    AR.Hold := AR.Hold or (LongWord(AR.Data[AR.Pos]) shl AR.Bits);
    Inc(AR.Pos);
    Inc(AR.Bits, 8);
  end;
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
  BW.Hold := BW.Hold or (AValue shl BW.Bits);
  Inc(BW.Bits, ABits);
  while BW.Bits >= 8 do
  begin
    BwEnsure(BW, 1);
    BW.Buf[BW.Len] := Byte(BW.Hold);
    Inc(BW.Len);
    BW.Hold := BW.Hold shr 8;
    Dec(BW.Bits, 8);
  end;
end;

procedure BwAlign(var BW: TBitWriter); inline;
begin
  if BW.Bits > 0 then
  begin
    BwEnsure(BW, 1);
    BW.Buf[BW.Len] := Byte(BW.Hold);
    Inc(BW.Len);
    BW.Hold := 0;
    BW.Bits := 0;
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
  GFixedReady: Boolean = False;

procedure EnsureFixed;
begin
  if GFixedReady then Exit;
  BuildFixedTables(GFixedLit, GFixedDist);
  GFixedReady := True;
end;

{ ── Helpers for length/distance symbol ───────────────────── }

function FindLengthSym(ALen: Word; out ASym: Integer; out AExtra: Word; out AExtraBits: Byte): Boolean;
var
  I: Integer;
  LBase, LLimit: Word;
begin
  for I := 0 to 28 do
  begin
    LBase := CBaseLength[I];
    if CExtraLength[I] = 0 then
      LLimit := LBase
    else
      LLimit := LBase + (Word(1) shl CExtraLength[I]) - 1;
    if (ALen >= LBase) and (ALen <= LLimit) then
    begin
      ASym := 257 + I;
      AExtra := ALen - LBase;
      AExtraBits := CExtraLength[I];
      Exit(True);
    end;
  end;
  Result := False;
end;

function FindDistSym(ADist: Word; out ASym: Integer; out AExtra: Word; out AExtraBits: Byte): Boolean;
var
  I: Integer;
  LBase, LLimit: Word;
begin
  for I := 0 to 29 do
  begin
    LBase := CBaseDist[I];
    if CExtraDist[I] = 0 then
      LLimit := LBase
    else
      LLimit := LBase + (Word(1) shl CExtraDist[I]) - 1;
    if (ADist >= LBase) and (ADist <= LLimit) then
    begin
      ASym := I;
      AExtra := ADist - LBase;
      AExtraBits := CExtraDist[I];
      Exit(True);
    end;
  end;
  Result := False;
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
  LBFinal: LongWord;
  LLen: Word;
begin
  LPos := 0;
  LRem := SizeUInt(Length(AData));
  if LRem = 0 then
  begin
    BwWrite(BW, 1, 1);
    BwWrite(BW, 0, 2);
    BwAlign(BW);
    BwEnsure(BW, 4);
    BW.Buf[BW.Len] := 0; Inc(BW.Len);
    BW.Buf[BW.Len] := 0; Inc(BW.Len);
    BW.Buf[BW.Len] := $FF; Inc(BW.Len);
    BW.Buf[BW.Len] := $FF; Inc(BW.Len);
    Exit;
  end;
  while LPos < LRem do
  begin
    LChunk := LRem - LPos;
    if LChunk > 65535 then LChunk := 65535;
    if LPos + LChunk >= LRem then LBFinal := 1 else LBFinal := 0;
    BwWrite(BW, LBFinal, 1);
    BwWrite(BW, 0, 2);
    BwAlign(BW);
    LLen := Word(LChunk);
    BwEnsure(BW, 4 + LChunk);
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

{ ── Fixed Huffman with hash chain ────────────────────────── }

procedure DeflateFixed(const AData: TBytes; var BW: TBitWriter; ALevel: TZlibLevel);
var
  LLen: SizeUInt;
  LPos: SizeUInt;
  LHead: array[0..CHashSize - 1] of Integer;
  LPrev: array of Integer;
  LHash: Integer;
  LCand, LBestLen, LBestDist, LCurLen, LMaxLen, LMaxChain, LChainCnt: Integer;
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
  SetLength(LPrev, LLen);
  for I := 0 to Integer(LLen) - 1 do LPrev[I] := -1;
  case ALevel of
    zlFastest: LMaxChain := 8;
    zlBest:    LMaxChain := 128;
  else
    LMaxChain := 32;
  end;
  LMaxDist := CWindowSize;
  BwWrite(BW, 1, 1);
  BwWrite(BW, 1, 2);
  LPos := 0;
  while LPos < LLen do
  begin
    if LPos + 2 < LLen then
    begin
      LHash := ((Integer(AData[LPos]) * 31 + Integer(AData[LPos+1])) * 31 + Integer(AData[LPos+2])) and CHashMask;
      LCand := LHead[LHash];
      LBestLen := 0;
      LBestDist := 0;
      LChainCnt := 0;
      while (LCand >= 0) and (LChainCnt < LMaxChain) do
      begin
        if LPos - SizeUInt(LCand) > SizeUInt(LMaxDist) then
        begin
          LCand := LPrev[LCand];
          Inc(LChainCnt);
          Continue;
        end;
        if AData[LCand] = AData[LPos] then
        begin
          LMaxLen := Integer(LLen - LPos);
          if LMaxLen > 258 then LMaxLen := 258;
          LCurLen := 0;
          while (LCurLen < LMaxLen) and (AData[LCand + LCurLen] = AData[LPos + LCurLen]) do
            Inc(LCurLen);
          if (LCurLen >= 3) and (LCurLen > LBestLen) then
          begin
            LBestLen := LCurLen;
            LBestDist := Integer(LPos) - LCand;
            if LBestLen = 258 then Break;
          end;
        end;
        LCand := LPrev[LCand];
        Inc(LChainCnt);
      end;
      LPrev[LPos] := LHead[LHash];
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
            LHash := ((Integer(AData[LPos+I]) * 31 + Integer(AData[LPos+I+1])) * 31 + Integer(AData[LPos+I+2])) and CHashMask;
            LPrev[LPos+I] := LHead[LHash];
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

function DeflateEncodeRaw(const AData: TBytes; ALevel: TZlibLevel; AStoredOnly: Boolean): TBytes;
var
  BW: TBitWriter;
  LEst: SizeUInt;
begin
  LEst := SizeUInt(Length(AData)) + 16;
  if LEst < 64 then LEst := 64;
  BwInit(BW, LEst);
  if AStoredOnly then
    DeflateStored(AData, BW)
  else
    DeflateFixed(AData, BW, ALevel);
  SetLength(BW.Buf, BW.Len);
  Result := BW.Buf;
end;

function DeflateEncodeZlib(const AData: TBytes; ALevel: TZlibLevel): TBytes;
var
  LRaw: TBytes;
  LHeader: Word;
  LAdler: LongWord;
  LTotal: SizeUInt;
begin
  if ALevel = zlNone then
    LRaw := DeflateEncodeRaw(AData, ALevel, True)
  else
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
  LWindow: array[0..CWindowSize - 1] of Byte;
  LWinPos: SizeUInt;
  LBFinal: LongWord;
  LBType: LongWord;
  LLitBuild, LDistBuild: THuffBuild;
  LFixedLit, LFixedDist: THuffBuild;
  LFixedReady: Boolean;
  HLIT, HDIST, HCLEN: Integer;
  LCLens: array[0..CNumCLen - 1] of Byte;
  LCLBuild: THuffBuild;
  LCodeLens: array[0..CNumLitLen + CNumDist - 1] of Byte;
  I, LSym, LPrev, LRepeat, LValue: Integer;
  LLen, LDist, LExtra: LongWord;
  LCopyPos, LCopyLen: SizeUInt;
  LStoredLen, LStoredNLen: Word;
  J: SizeUInt;
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
  FillChar(LWindow, SizeOf(LWindow), 0);
  LFixedReady := False;
  FillChar(LFixedLit, SizeOf(LFixedLit), 0);
  FillChar(LFixedDist, SizeOf(LFixedDist), 0);
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
          LWindow[(LWinPos + J) and (CWindowSize - 1)] := R.Data[R.Pos + J];
        LWinPos := (LWinPos + LStoredLen) and (CWindowSize - 1);
        Inc(LOutLen, LStoredLen);
        Inc(R.Pos, LStoredLen);
      end;
    end
    else if (LBType = 1) or (LBType = 2) then
    begin
      if LBType = 1 then
      begin
        if not LFixedReady then
        begin
          BuildFixedTables(LFixedLit, LFixedDist);
          LFixedReady := True;
        end;
        LLitBuild := LFixedLit;
        LDistBuild := LFixedDist;
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
      end;
      while True do
      begin
        LSym := DecodeSymbol(R, LLitBuild);
        if LSym < 256 then
        begin
          GrowBytes(LOut, LOutLen, LCap, 1, AMax);
          LOut[LOutLen] := Byte(LSym);
          LWindow[LWinPos] := Byte(LSym);
          LWinPos := (LWinPos + 1) and (CWindowSize - 1);
          Inc(LOutLen);
        end
        else if LSym = 256 then
          Break
        else if (LSym >= 257) and (LSym <= 285) then
        begin
          LLen := CBaseLength[LSym - 257];
          LExtra := CExtraLength[LSym - 257];
          if LExtra > 0 then
            LLen := LLen + BrGet(R, LExtra);
          LSym := DecodeSymbol(R, LDistBuild);
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
          GrowBytes(LOut, LOutLen, LCap, LLen, AMax);
          LCopyPos := (LOutLen - LDist);
          for LCopyLen := 0 to LLen - 1 do
          begin
            LOut[LOutLen] := LOut[LCopyPos + LCopyLen];
            LWindow[LWinPos] := LOut[LOutLen];
            LWinPos := (LWinPos + 1) and (CWindowSize - 1);
            Inc(LOutLen);
          end;
        end
        else
          RaiseZlib(zecCorruptStream, 'zlib: corrupt stream');
      end;
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

function TZlibPureDecoder.Adler32(const AData: TBytes): LongWord;
begin
  Result := ZlibAdler32(AData);
end;

function TZlibPureDecoder.Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdlerUpdate(AAdler, AData, ALen);
end;

end.
