unit nextpas.core.sevenz.lzma.encoder;

{**
 * nextpas.core.sevenz.lzma.encoder - LZMA2 纯 Pascal 编码器
 *
 * 区间编码 + LZMA 状态模型 + 哈希链匹配查找（hc4 + 单步 lazy）。
 * 产出标准 LZMA2 chunk 流：首块 mode=3（状态重置+属性+字典重置，
 * liblzma raw 流的硬性要求），后续压缩块默认 mode=0 续接状态与字典；
 * 不可压数据回退未压缩块（其后强制状态重置）；按 2MiB unpacked 与
 * packed 软上限切块，流尾写结束标记。每个压缩块的区间码流段独立，
 * 编码侧逐块 Flush，与解码器逐块重新 Init 的约定对称。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.lzma.rc;

type
  {** @desc 纯 Pascal 后端：ISevenZLzmaEncoder 实现 *}
  TSevenZLzmaEncoderPascal = class(TInterfacedObject, ISevenZLzmaEncoder)
  public
    function EncodeLzma2(const ARaw: TBytes;
      ALevel: TSevenZCompressionLevel): TSevenZLzmaEncoded;
  end;

implementation

const
  C_NUM_STATES = 12;
  C_NUM_POS_STATES_MAX = 16;
  C_END_POS_MODEL_INDEX = 14;
  C_NUM_ALIGN_BITS = 4;

  { 概率数组平面布局偏移（与解码器一致） }
  PROB_ISMATCH    = 0;     { 12 * 16 }
  PROB_ISREP      = 192;   { 12 }
  PROB_ISREPG0    = 204;   { 12 }
  PROB_ISREPG1    = 216;   { 12 }
  PROB_ISREPG2    = 228;   { 12 }
  PROB_ISREP0LONG = 240;   { 12 * 16 }
  PROB_POSSLOT    = 432;   { 4 * 64 }
  PROB_SPECPOS    = 688;
  PROB_ALIGN      = 804;   { 16 }
  PROB_LEN        = 820;   { choice+choice2+low128+mid128+high256 = 514 }
  PROB_REPLEN     = 1334;  { 本编码器不发 rep 匹配，保留布局对齐 }
  PROB_LIT_BASE   = 1848;  { 动态：$300 shl (lc+lp) }

  { 匹配查找参数 }
  C_HASH_BITS = 17;                { 4 字节哈希表规模 }
  C_HASH_SIZE = 1 shl C_HASH_BITS;
  C_MIN_MATCH = 4;
  C_MAX_MATCH = 273;               { LZMA 长度编码上限 }
  C_WINDOW_MAX = 1 shl 26;         { 链回溯距离上限 }

  { LZMA2 块限制 }
  C_CHUNK_UNPACKED_MAX = 1 shl 21;
  C_CHUNK_PACKED_SOFT  = 60000;    { packed 字段上限 65536，留安全余量 }
  C_CHUNK_STORED_MAX   = 65536;    { 未压缩块尺寸字段（BE16+1）上限 }

  { 固定属性字节：lc=3 lp=0 pb=2 → (pb*5+lp)*9+lc。
    仅用于 LZMA2 流内首块的 newProps 字节 }
  C_PROPS_BYTE = $5D;
  { 容器 coder props 是另一套编码：字典尺寸码，
    dictSize=(2 or (p and 1)) shl (p div 2 + 11)；p=28 ↔ 64MB=C_WINDOW_MAX。
    与 p>40 时解码端报 Unsupported 的约束一致 }
  C_CONTAINER_DICT_PROP = 28;

type
  TEngine = record
    Probs: array of Word;
    State: Integer;
    Rep0: SizeUInt;
    Rep1: SizeUInt;
    Rep2: SizeUInt;
    Rep3: SizeUInt;
    Lc: Integer;
    Lp: Integer;
    Pb: Integer;
    LitMask: UInt32;
    PosMask: UInt32;
    InBuf: PByte;
    InSize: SizeUInt;
    Pos: SizeUInt;
    Rc: TSevenZRcEncoder;
    Head: array of Int32;
    Prev: array of Int32;
    Watermark: SizeUInt;           { 已插入链的位置上界；防重插成环 }
  end;

procedure AllocProbs(var AE: TEngine);
var
  LI: SizeInt;
begin
  SetLength(AE.Probs, PROB_LIT_BASE + ($300 shl (AE.Lc + AE.Lp)));
  for LI := 0 to High(AE.Probs) do
    AE.Probs[LI] := C_RC_INIT_PROB;
end;

procedure ResetState(var AE: TEngine);
begin
  AllocProbs(AE);
  AE.State := 0;
  AE.Rep0 := 0;
  AE.Rep1 := 0;
  AE.Rep2 := 0;
  AE.Rep3 := 0;
end;

procedure MatcherAlloc(var AE: TEngine);
begin
  SetLength(AE.Head, C_HASH_SIZE);
  if Length(AE.Head) > 0 then
    FillChar(AE.Head[0], Length(AE.Head) * SizeOf(Int32), $FF);
  SetLength(AE.Prev, SizeInt(AE.InSize));
  if Length(AE.Prev) > 0 then
    FillChar(AE.Prev[0], Length(AE.Prev) * SizeOf(Int32), $FF);
  AE.Watermark := 0;
end;

function InByteAt(const AE: TEngine; AIdx: SizeUInt): Byte; inline;
begin
  if AIdx < AE.InSize then
    Result := AE.InBuf[AIdx]
  else
    Result := 0;
end;

function Hash4(const AE: TEngine; APos: SizeUInt): SizeUInt; inline;
var
  LV: UInt32;
  LProd: UInt32;
begin
  { 调用方保证 APos + 4 <= InSize。
    注意：FPC 运算中间值按原生位宽（64 位）计算，乘法必须先落
    UInt32 变量截断再移位，否则哈希值越出表界 }
  {$PUSH}{$Q-}{$R-}
  LV := (UInt32(AE.InBuf[APos]) shl 24) or (UInt32(AE.InBuf[APos + 1]) shl 16)
    or (UInt32(AE.InBuf[APos + 2]) shl 8) or UInt32(AE.InBuf[APos + 3]);
  LProd := LV * UInt32($9E3779B1);
  Result := SizeUInt(LProd shr (32 - C_HASH_BITS));
  {$POP}
end;

procedure HashInsert(var AE: TEngine; APos: SizeUInt);
var
  LH: SizeUInt;
begin
  { 只允许单调前进插入；压缩失败回退重走时跳过已插入位置，
    避免链自环（链里残留的"未来"候选由距离上界守卫挡下） }
  if APos >= AE.Watermark then
  begin
    LH := Hash4(AE, APos);
    AE.Prev[APos] := AE.Head[LH];
    AE.Head[LH] := Int32(APos);
    AE.Watermark := APos + 1;
  end;
end;

function MatchLenAt(const AE: TEngine; APos: SizeUInt; ADist: SizeUInt;
  AMax: SizeUInt): SizeUInt;
var
  LSrc: SizeUInt;
  LN: SizeUInt;
begin
  Result := 0;
  if ADist = 0 then
    Exit;
  if APos < ADist then
    Exit;
  LSrc := APos - ADist;
  if LSrc >= AE.InSize then
    Exit;
  LN := AE.InSize - APos;
  if LN > AMax then
    LN := AMax;
  {$PUSH}{$Q-}{$R-}
  while (Result + 8 <= LN) do
  begin
    if PUInt64(AE.InBuf + APos + Result)^ <> PUInt64(AE.InBuf + LSrc + Result)^ then
      Break;
    Inc(Result, 8);
  end;
  while (Result < LN) and (AE.InBuf[APos + Result] = AE.InBuf[LSrc + Result]) do
    Inc(Result);
  {$POP}
end;

{ 贪心哈希链查找：返回最佳匹配长度（< C_MIN_MATCH 表示无匹配），ADist 带出距离 }
function FindBestMatch(var AE: TEngine; APos: SizeUInt; ARoom: SizeUInt;
  ANiceLen: SizeUInt; AChainLimit: SizeUInt; out ADist: SizeUInt): SizeUInt;
var
  LCand: Int32;
  LLimit: SizeUInt;
  LDist: SizeUInt;
  LLen: SizeUInt;
  LChain: SizeUInt;
begin
  ADist := 0;
  Result := 0;
  if ARoom < C_MIN_MATCH then
    Exit;
  if APos + C_MIN_MATCH > AE.InSize then
    Exit;
  LCand := AE.Head[Hash4(AE, APos)];
  LLimit := ARoom;
  if LLimit > C_MAX_MATCH then
    LLimit := C_MAX_MATCH;
  LChain := AChainLimit;
  while (LCand >= 0) and (LChain > 0) do
  begin
    {$PUSH}{$Q-}{$R-}
    LDist := APos - SizeUInt(LCand);
    {$POP}
    if LDist > C_WINDOW_MAX then
      Break;                       { 链按位置降序，更老的只会更远 }
    LLen := MatchLenAt(AE, APos, LDist, LLimit);
    if LLen > Result then
    begin
      Result := LLen;
      ADist := LDist;
      if LLen >= ANiceLen then
        Break;
    end;
    Dec(LChain);
    LCand := AE.Prev[LCand];
  end;
end;

procedure TreeEncode(var AE: TEngine; AOfs: SizeInt; ANumBits: Integer;
  ASymbol: UInt32);
var
  LM: SizeInt;
  LI: Integer;
  LBit: UInt32;
begin
  LM := 1;
  for LI := ANumBits - 1 downto 0 do
  begin
    LBit := (ASymbol shr LI) and 1;
    AE.Rc.EncodeBit(AE.Probs[AOfs + LM], LBit);
    LM := (LM shl 1) or SizeInt(LBit);
  end;
end;

procedure TreeReverseEncode(var AE: TEngine; AOfs: SizeInt;
  ANumBits: Integer; ASymbol: UInt32);
var
  LM: SizeInt;
  LI: Integer;
  LBit: UInt32;
begin
  LM := 1;
  for LI := 0 to ANumBits - 1 do
  begin
    LBit := ASymbol and 1;
    ASymbol := ASymbol shr 1;
    AE.Rc.EncodeBit(AE.Probs[AOfs + LM], LBit);
    LM := LM shl 1;
    if LBit <> 0 then
      Inc(LM);
  end;
end;

procedure EncodeLiteral(var AE: TEngine);
var
  LPrevByte: Byte;
  LLitState: SizeInt;
  LProbBase: SizeInt;
  LSymbol: UInt32;
  LAcc: UInt32;
  LMatchByte: Byte;
  LMatchBit: UInt32;
  LBit: UInt32;
  LI: Integer;
begin
  if AE.Pos > 0 then
    LPrevByte := AE.InBuf[AE.Pos - 1]
  else
    LPrevByte := 0;
  LLitState := SizeInt((AE.Pos and AE.LitMask) shl AE.Lc) +
    SizeInt(LPrevByte shr (8 - AE.Lc));
  LProbBase := PROB_LIT_BASE + LLitState * $300;
  LSymbol := InByteAt(AE, AE.Pos);
  AE.Rc.EncodeBit(AE.Probs[PROB_ISMATCH + AE.State * C_NUM_POS_STATES_MAX +
    SizeInt(AE.Pos and AE.PosMask)], 0);
  if AE.State >= 7 then
  begin
    { matched 字面量：概率索引用带前导 1 的累加器，与解码器逐位对称 }
    LMatchByte := InByteAt(AE, AE.Pos - AE.Rep0 - 1);
    LAcc := 1;
    LI := 7;
    while LI >= 0 do
    begin
      LMatchBit := (LMatchByte shr 7) and 1;
      LMatchByte := Byte(LMatchByte shl 1);
      LBit := (LSymbol shr LI) and 1;
      AE.Rc.EncodeBit(AE.Probs[LProbBase +
        SizeInt((1 + LMatchBit) shl 8) + SizeInt(LAcc)], LBit);
      LAcc := (LAcc shl 1) or LBit;
      Dec(LI);
      if LMatchBit <> LBit then
      begin
        { 分歧后剩余位走普通树，累加器续接 }
        while LI >= 0 do
        begin
          LBit := (LSymbol shr LI) and 1;
          AE.Rc.EncodeBit(AE.Probs[LProbBase + SizeInt(LAcc)], LBit);
          LAcc := (LAcc shl 1) or LBit;
          Dec(LI);
        end;
      end;
    end;
  end
  else
    TreeEncode(AE, LProbBase, 8, LSymbol);
  Inc(AE.Pos);
  if AE.State < 4 then
    AE.State := 0
  else if AE.State < 10 then
    Dec(AE.State, 3)
  else
    Dec(AE.State, 6);
end;

procedure EncodeLenBits(var AE: TEngine; ABase: SizeInt; APosState: SizeInt;
  ALenSym: UInt32);
begin
  if ALenSym < 8 then
  begin
    AE.Rc.EncodeBit(AE.Probs[ABase], 0);
    TreeEncode(AE, ABase + 2 + APosState * 8, 3, ALenSym);
  end
  else if ALenSym < 16 then
  begin
    AE.Rc.EncodeBit(AE.Probs[ABase], 1);
    AE.Rc.EncodeBit(AE.Probs[ABase + 1], 0);
    TreeEncode(AE, ABase + 130 + APosState * 8, 3, ALenSym - 8);
  end
  else
  begin
    AE.Rc.EncodeBit(AE.Probs[ABase], 1);
    AE.Rc.EncodeBit(AE.Probs[ABase + 1], 1);
    TreeEncode(AE, ABase + 258, 8, ALenSym - 16);
  end;
end;

procedure EncodeDistance(var AE: TEngine; ALen: SizeUInt; ADist: SizeUInt);
var
  LLenToPos: SizeInt;
  LPosSlot: UInt32;
  LNumDirectBits: UInt32;
  LHb: SizeUInt;
  LV: SizeUInt;
  LBase: SizeUInt;
begin
  LLenToPos := SizeInt(ALen) - 2;
  if LLenToPos > 3 then
    LLenToPos := 3;
  { 由距离反推 posSlot：dist<4 直接当 slot；否则 hb=最高位序号、nd=hb-1、
    slot=((nd+1) shl 1) or ((dist shr nd) and 1) }
  if ADist < 4 then
    LPosSlot := UInt32(ADist)
  else
  begin
    LHb := 0;
    LV := ADist;
    while LV > 1 do
    begin
      LV := LV shr 1;
      Inc(LHb);
    end;
    LNumDirectBits := LHb - 1;
    {$PUSH}{$Q-}{$R-}
    LPosSlot := UInt32((LNumDirectBits + 1) shl 1) or
      ((UInt32(ADist) shr LNumDirectBits) and 1);
    {$POP}
  end;
  TreeEncode(AE, PROB_POSSLOT + LLenToPos * 64, 6, LPosSlot);
  if LPosSlot >= 4 then
  begin
    LNumDirectBits := (LPosSlot shr 1) - 1;
    LBase := (SizeUInt(2) or SizeUInt(LPosSlot and 1)) shl LNumDirectBits;
    if LPosSlot < C_END_POS_MODEL_INDEX then
      TreeReverseEncode(AE, PROB_SPECPOS + SizeInt(LBase) - SizeInt(LPosSlot),
        SizeInt(LNumDirectBits), UInt32(ADist - LBase))
    else
    begin
      { 高位直编在前，低 4 位对齐树在后，顺序与解码器一致 }
      AE.Rc.EncodeDirectBits(UInt32(ADist) shr C_NUM_ALIGN_BITS,
        LNumDirectBits - C_NUM_ALIGN_BITS);
      TreeReverseEncode(AE, PROB_ALIGN, C_NUM_ALIGN_BITS,
        UInt32(ADist) and $0F);
    end;
  end;
end;

procedure EmitMatch(var AE: TEngine; ALen: SizeUInt; ADist: SizeUInt);
var
  LPosState: SizeInt;
begin
  LPosState := SizeInt(AE.Pos and AE.PosMask);
  AE.Rc.EncodeBit(AE.Probs[PROB_ISMATCH + AE.State * C_NUM_POS_STATES_MAX +
    LPosState], 1);
  { 本编码器只发普通匹配，rep 位恒 0 }
  AE.Rc.EncodeBit(AE.Probs[PROB_ISREP + AE.State], 0);
  EncodeLenBits(AE, PROB_LEN, LPosState, UInt32(ALen - 2));
  EncodeDistance(AE, ALen, ADist);
  AE.Rep3 := AE.Rep2;
  AE.Rep2 := AE.Rep1;
  AE.Rep1 := AE.Rep0;
  AE.Rep0 := ADist;
  if AE.State < 7 then
    AE.State := 7
  else
    AE.State := 10;
  Inc(AE.Pos, ALen);
end;

{ 主编码循环：从当前 Pos 编码到 AChunkLimit 或码流触及软上限为止。
  每个操作先经 IsMatch/IsRep 概率位声明类型，再编载荷 }
procedure RunEncodeRange(var AE: TEngine; AChunkLimit: SizeUInt;
  ARcBuf: TSevenZOutBuffer; ANiceLen: SizeUInt; AChain: SizeUInt);
var
  LBestLen: SizeUInt;
  LBestDist: SizeUInt;
  LNextLen: SizeUInt;
  LNextDist: SizeUInt;
  LJ: SizeUInt;
  LPeeked: Boolean;
begin
  LPeeked := False;
  LBestLen := 0;
  LBestDist := 0;
  while AE.Pos < AChunkLimit do
  begin
    if not LPeeked then
    begin
      LBestLen := 0;
      LBestDist := 0;
      if AE.Pos + C_MIN_MATCH <= AE.InSize then
      begin
        HashInsert(AE, AE.Pos);
        LBestLen := FindBestMatch(AE, AE.Pos, AChunkLimit - AE.Pos, ANiceLen,
          AChain, LBestDist);
      end;
    end;
    LPeeked := False;

    if (LBestLen >= C_MIN_MATCH) and (LBestLen < ANiceLen) then
    begin
      { 单步 lazy：下一位置有更长匹配则发字面量让步 }
      LNextLen := 0;
      LNextDist := 0;
      if (AChunkLimit - AE.Pos - 1 >= C_MIN_MATCH) and
         (AE.Pos + 1 + C_MIN_MATCH <= AE.InSize) then
      begin
        HashInsert(AE, AE.Pos + 1);
        LNextLen := FindBestMatch(AE, AE.Pos + 1, AChunkLimit - AE.Pos - 1,
          ANiceLen, AChain, LNextDist);
        if LNextLen > LBestLen then
        begin
          EncodeLiteral(AE);
          LBestLen := LNextLen;
          LBestDist := LNextDist;
          LPeeked := True;         { 新位置已插入并求值，下轮直接复用 }
          Continue;
        end;
      end;
    end;

    if LBestLen >= C_MIN_MATCH then
    begin
      { 查找器距离为候选位置差 P-C；LZMA 距离定义为解码读 Pos-D-1，
        故落码前减一 }
      EmitMatch(AE, LBestLen, LBestDist - 1);
      { 匹配覆盖区内部位置补插入，保持链完整 }
      LJ := AE.Pos - LBestLen + 1;
      while LJ < AE.Pos do
      begin
        if LJ + C_MIN_MATCH <= AE.InSize then
          HashInsert(AE, LJ);
        Inc(LJ);
      end;
    end
    else
      EncodeLiteral(AE);

    if ARcBuf.Length >= C_CHUNK_PACKED_SOFT then
      Break;
  end;
end;

procedure LevelParams(ALevel: TSevenZCompressionLevel; out ANice: SizeUInt;
  out AChain: SizeUInt);
begin
  case ALevel of
    szclFastest:
      begin
        ANice := 32;
        AChain := 32;
      end;
    szclBest:
      begin
        ANice := C_MAX_MATCH;
        AChain := 256;
      end;
  else
    begin
      ANice := 128;
      AChain := 128;
    end;
  end;
end;

procedure PutBE16(const AOut: TSevenZOutBuffer; AVal: SizeUInt); inline;
begin
  AOut.Put(Byte((AVal shr 8) and $FF));
  AOut.Put(Byte(AVal and $FF));
end;

procedure StoreAll(const ARaw: TBytes; const AOut: TSevenZOutBuffer);
var
  LPos: SizeUInt;
  LTake: SizeUInt;
  LSize: SizeUInt;
begin
  LSize := SizeUInt(Length(ARaw));
  LPos := 0;
  while LPos < LSize do
  begin
    LTake := LSize - LPos;
    if LTake > C_CHUNK_STORED_MAX then
      LTake := C_CHUNK_STORED_MAX;
    if LPos = 0 then
      AOut.Put(1)                  { 未压缩块 + 字典重置 }
    else
      AOut.Put(2);                 { 未压缩块，无重置 }
    PutBE16(AOut, LTake - 1);
    AOut.Write(ARaw[SizeInt(LPos)], LTake);
    Inc(LPos, LTake);
  end;
  AOut.Put($00);
end;

{ TSevenZLzmaEncoderPascal }

function TSevenZLzmaEncoderPascal.EncodeLzma2(const ARaw: TBytes;
  ALevel: TSevenZCompressionLevel): TSevenZLzmaEncoded;
var
  LOut: TSevenZOutBuffer;
  LChunkBuf: TSevenZOutBuffer;
  LRc: TSevenZRcEncoder;
  LE: TEngine;
  LSize: SizeUInt;
  LNice: SizeUInt;
  LChain: SizeUInt;
  LChunkStart: SizeUInt;
  LChunkLimit: SizeUInt;
  LConsumed: SizeUInt;
  LPacked: TBytes;
  LPackedLen: SizeUInt;
  LControl: Byte;
  LSnapshot: array of Word;
  LSavedState: Integer;
  LSavedRep0: SizeUInt;
  LSavedRep1: SizeUInt;
  LSavedRep2: SizeUInt;
  LSavedRep3: SizeUInt;
  LFirstChunk: Boolean;
  LAfterUncomp: Boolean;
begin
  Result := Default(TSevenZLzmaEncoded);
  SetLength(Result.Props, 1);
  Result.Props[0] := C_CONTAINER_DICT_PROP;
  LSize := SizeUInt(Length(ARaw));
  LOut := TSevenZOutBuffer.Create;
  try
    if LSize = 0 then
    begin
      { 空输入：仅流尾结束标记 }
      LOut.Put($00);
    end
    else if ALevel = szclNone then
    begin
      StoreAll(ARaw, LOut);
    end
    else
    begin
      LE.Lc := 3;
      LE.Lp := 0;
      LE.Pb := 2;
      LE.LitMask := 0;
      LE.PosMask := 3;
      LE.InBuf := @ARaw[0];
      LE.InSize := LSize;
      LE.Pos := 0;
      LE.Rc := nil;
      ResetState(LE);
      MatcherAlloc(LE);
      LevelParams(ALevel, LNice, LChain);
      LFirstChunk := True;
      LAfterUncomp := False;
      while LE.Pos < LSize do
      begin
        { 未压缩块之后的压缩块以 $C0 发码：解码器侧会重置状态，
          编码器必须同步归零，否则概率模型失步 }
        if LAfterUncomp then
          ResetState(LE);
        LChunkStart := LE.Pos;
        LChunkLimit := LE.Pos + C_CHUNK_UNPACKED_MAX;
        if LChunkLimit > LSize then
          LChunkLimit := LSize;

        { 快照可学习状态，压缩失败回退时还原（丢弃的编码不得污染主流） }
        LSnapshot := Copy(LE.Probs, 0, Length(LE.Probs));
        LSavedState := LE.State;
        LSavedRep0 := LE.Rep0;
        LSavedRep1 := LE.Rep1;
        LSavedRep2 := LE.Rep2;
        LSavedRep3 := LE.Rep3;

        LChunkBuf := TSevenZOutBuffer.Create;
        try
          LRc := TSevenZRcEncoder.Create(LChunkBuf);
          try
            LE.Rc := LRc;
            LRc.Init;
            RunEncodeRange(LE, LChunkLimit, LChunkBuf, LNice, LChain);
            LRc.Flush;
          finally
            LE.Rc := nil;
            LRc.Free;
          end;
          LPacked := LChunkBuf.Steal;
        finally
          LChunkBuf.Free;
        end;

        LConsumed := LE.Pos - LChunkStart;
        LPackedLen := SizeUInt(Length(LPacked));
        if (LPackedLen < LConsumed) and (LPackedLen <= C_CHUNK_STORED_MAX) then
        begin
          { 压缩有效：首块 mode=3（状态重置+新属性+字典重置，liblzma
            raw 流要求首块字典重置）；未压缩块之后强制状态重置规避
            方言差异；其余 mode=0 续接状态与字典 }
          if LFirstChunk then
            LControl := $E0
          else if LAfterUncomp then
            LControl := $C0
          else
            LControl := $80;
          LOut.Put(Byte(LControl or Byte((LConsumed - 1) shr 16)));
          PutBE16(LOut, LConsumed - 1);
          PutBE16(LOut, LPackedLen - 1);
          if LControl <> $80 then
            LOut.Put(C_PROPS_BYTE);
          if LPackedLen > 0 then
            LOut.Write(LPacked[0], LPackedLen);
          LAfterUncomp := False;
        end
        else
        begin
          { 回退未压缩块：还原快照；游标推进到块尾（未压缩载荷不经
            状态机，与解码器语义对称），否则同一块会被无限重编 }
          LE.Probs := LSnapshot;
          LE.State := LSavedState;
          LE.Rep0 := LSavedRep0;
          LE.Rep1 := LSavedRep1;
          LE.Rep2 := LSavedRep2;
          LE.Rep3 := LSavedRep3;
          LConsumed := LChunkLimit - LChunkStart;
          { 未压缩块尺寸字段为 BE16+1，单块最多 65536 字节 }
          if LConsumed > C_CHUNK_STORED_MAX then
            LConsumed := C_CHUNK_STORED_MAX;
          LE.Pos := LChunkStart + LConsumed;
          if LFirstChunk then
            LControl := 1              { 未压缩块 + 字典重置 }
          else
            LControl := 2;
          LOut.Put(LControl);
          PutBE16(LOut, LConsumed - 1);
          LOut.Write(ARaw[SizeInt(LChunkStart)], LConsumed);
          LAfterUncomp := True;
        end;
        LFirstChunk := False;
      end;
      LOut.Put($00);                   { 流尾结束标记 }
    end;
    Result.PackedData := LOut.Steal;
  finally
    LOut.Free;
  end;
end;

end.
