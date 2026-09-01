unit nextpas.core.sevenz.lzma.decoder;

{**
 * nextpas.core.sevenz.lzma.decoder - LZMA1/LZMA2 纯 Pascal 解码器
 *
 * 输出缓冲即字典窗口（整段输出驻留内存），因此距离回溯天然不回绕；
 * LZMA2 的字典重置边界用 FDictStart 单独看护。
 * 所有结构性违规统一抛 ESevenZError；解码尺寸由调用方声明并预先分配。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.lzma.rc;

type
  {** @desc 纯 Pascal 后端：ISevenZLzmaDecoder 实现 *}
  TSevenZLzmaDecoderPascal = class(TInterfacedObject, ISevenZLzmaDecoder)
  public
    function DecodeLzma2(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
    function DecodeLzma1(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
  end;

implementation

uses
  nextpas.core.errors;

const
  C_NUM_STATES = 12;
  C_NUM_POS_STATES_MAX = 16;
  C_END_POS_MODEL_INDEX = 14;
  C_NUM_ALIGN_BITS = 4;

  { 概率数组平面布局偏移 }
  PROB_ISMATCH    = 0;     { 12 * 16 }
  PROB_ISREP      = 192;   { 12 }
  PROB_ISREPG0    = 204;   { 12 }
  PROB_ISREPG1    = 216;   { 12 }
  PROB_ISREPG2    = 228;   { 12 }
  PROB_ISREP0LONG = 240;   { 12 * 16 }
  PROB_POSSLOT    = 432;   { 4 * 64 }
  PROB_SPECPOS    = 688;   { 116（slot13 最坏索引 114，留余量） }
  PROB_ALIGN      = 804;   { 16 }
  PROB_LEN        = 820;   { choice+choice2+low128+mid128+high256 = 514 }
  PROB_REPLEN     = 1334;  { 514 }
  PROB_LIT_BASE   = 1848;  { 动态：$300 shl (lc+lp) }

type
  TEngineState = record
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
    DictStart: SizeUInt;
    OutBuf: PByte;
    OutSize: SizeUInt;
    Pos: SizeUInt;
    Rc: TSevenZRcDecoder;
  end;

procedure EngineError(const AMsg: string);
begin
  raise ESevenZError.Create('lzma: ' + AMsg);
end;

procedure ParsePropsByte(APropsByte: Byte; out ALc, ALp, APb: Integer);
var
  LRest: Integer;
begin
  if APropsByte >= 9 * 5 * 5 then
    EngineError('props byte out of range');
  ALc := APropsByte mod 9;
  LRest := APropsByte div 9;
  ALp := LRest mod 5;
  APb := LRest div 5;
end;

procedure AllocProbs(var AE: TEngineState);
var
  LI: SizeInt;
begin
  SetLength(AE.Probs, PROB_LIT_BASE + ($300 shl (AE.Lc + AE.Lp)));
  for LI := 0 to High(AE.Probs) do
    AE.Probs[LI] := C_RC_INIT_PROB;
end;

procedure ResetState(var AE: TEngineState);
begin
  AllocProbs(AE);
  AE.State := 0;
  AE.Rep0 := 0;
  AE.Rep1 := 0;
  AE.Rep2 := 0;
  AE.Rep3 := 0;
end;

function TreeDecode(var AE: TEngineState; AOfs: SizeInt; ANumBits: Integer): UInt32;
var
  LM: SizeInt;
  LI: Integer;
  LBit: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LM := 1;
  for LI := 1 to ANumBits do
  begin
    LBit := AE.Rc.DecodeBit(AE.Probs[AOfs + LM]);
    LM := (LM shl 1) + SizeInt(LBit);
  end;
  Result := UInt32(LM) - UInt32(1 shl ANumBits);
  {$POP}
end;

function TreeReverseDecode(var AE: TEngineState; AOfs: SizeInt;
  ANumBits: Integer): UInt32;
var
  LM: SizeInt;
  LI: Integer;
  LBit: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LM := 1;
  Result := 0;
  for LI := 0 to ANumBits - 1 do
  begin
    LBit := AE.Rc.DecodeBit(AE.Probs[AOfs + LM]);
    LM := (LM shl 1) + SizeInt(LBit);
    Result := Result or (LBit shl LI);
  end;
  {$POP}
end;

procedure CheckWindow(var AE: TEngineState; ADist: SizeUInt);
var
  LAvail: SizeUInt;
begin
  { 距离 1-based：ADist = 0 即回退一字节；窗口下界由 LZMA2 字典重置决定 }
  LAvail := AE.Pos - AE.DictStart;
  if (LAvail = 0) or (ADist >= LAvail) then
    EngineError('distance beyond dictionary window');
end;

procedure CopyMatch(var AE: TEngineState; ADist: SizeUInt; ALen: SizeUInt);
var
  LSrc: SizeUInt;
  LI: SizeUInt;
begin
  CheckWindow(AE, ADist);
  if AE.Pos + ALen > AE.OutSize then
    EngineError('match overruns declared output size');
  {$PUSH}{$Q-}{$R-}
  LSrc := AE.Pos - ADist - 1;
  for LI := 0 to ALen - 1 do
  begin
    AE.OutBuf[AE.Pos] := AE.OutBuf[LSrc];
    Inc(LSrc);
    Inc(AE.Pos);
  end;
  {$POP}
end;

function DecodeLen(var AE: TEngineState; ABase: SizeInt; APosState: SizeInt): SizeUInt;
var
  LSym: SizeUInt;
begin
  if AE.Rc.DecodeBit(AE.Probs[ABase]) = 0 then
    LSym := TreeDecode(AE, ABase + 2 + APosState * 8, 3)
  else if AE.Rc.DecodeBit(AE.Probs[ABase + 1]) = 0 then
    LSym := TreeDecode(AE, ABase + 130 + APosState * 8, 3) + 8
  else
    LSym := TreeDecode(AE, ABase + 258, 8) + 16;
  Result := LSym + 2;
end;

procedure DecodeLiteral(var AE: TEngineState);
var
  LPrevByte: Byte;
  LLitState: SizeInt;
  LProbBase: SizeInt;
  LSymbol: UInt32;
  LMatchByte: Byte;
  LMatchBit: UInt32;
  LBit: UInt32;
begin
  if AE.Pos > 0 then
    LPrevByte := AE.OutBuf[AE.Pos - 1]
  else
    LPrevByte := 0;
  LLitState := SizeInt((AE.Pos and AE.LitMask) shl AE.Lc) +
    SizeInt(LPrevByte shr (8 - AE.Lc));
  LProbBase := PROB_LIT_BASE + LLitState * $300;
  LSymbol := 1;
  if AE.State >= 7 then
  begin
    CheckWindow(AE, AE.Rep0);
    LMatchByte := AE.OutBuf[AE.Pos - AE.Rep0 - 1];
    repeat
      LMatchBit := (LMatchByte shr 7) and 1;
      LMatchByte := Byte(LMatchByte shl 1);
      LBit := AE.Rc.DecodeBit(
        AE.Probs[LProbBase + SizeInt(((1 + LMatchBit) shl 8)) + SizeInt(LSymbol)]);
      LSymbol := (LSymbol shl 1) or LBit;
      if LMatchBit <> LBit then
        Break;
    until LSymbol >= $100;
  end;
  while LSymbol < $100 do
  begin
    LBit := AE.Rc.DecodeBit(AE.Probs[LProbBase + SizeInt(LSymbol)]);
    LSymbol := (LSymbol shl 1) or LBit;
  end;
  {$PUSH}{$Q-}{$R-}
  AE.OutBuf[AE.Pos] := Byte(LSymbol and $FF);
  Inc(AE.Pos);
  {$POP}
  if AE.State < 4 then
    AE.State := 0
  else if AE.State < 10 then
    Dec(AE.State, 3)
  else
    Dec(AE.State, 6);
end;

procedure RunSegment(var AE: TEngineState; ASegmentSize: SizeUInt);
var
  LPosState: SizeInt;
  LLen: SizeUInt;
  LLenToPos: SizeInt;
  LPosSlot: UInt32;
  LNumDirectBits: UInt32;
  LDist: SizeUInt;
begin
  while ASegmentSize > 0 do
  begin
    LPosState := SizeInt(AE.Pos and AE.PosMask);
    if AE.Rc.DecodeBit(AE.Probs[PROB_ISMATCH + AE.State * C_NUM_POS_STATES_MAX +
       LPosState]) = 0 then
    begin
      DecodeLiteral(AE);
      Dec(ASegmentSize);
      Continue;
    end;
    if AE.Rc.DecodeBit(AE.Probs[PROB_ISREP + AE.State]) <> 0 then
    begin
      { rep 分支：短复制或最近距离族 }
      if AE.Rc.DecodeBit(AE.Probs[PROB_ISREPG0 + AE.State]) = 0 then
      begin
        if AE.Rc.DecodeBit(AE.Probs[PROB_ISREP0LONG +
           AE.State * C_NUM_POS_STATES_MAX + LPosState]) = 0 then
        begin
          CopyMatch(AE, AE.Rep0, 1);  { SHORTREP }
          if AE.State < 7 then
            AE.State := 9
          else
            AE.State := 11;
          Dec(ASegmentSize);
          Continue;
        end;
      end
      else
      begin
        if AE.Rc.DecodeBit(AE.Probs[PROB_ISREPG1 + AE.State]) = 0 then
          LDist := AE.Rep1
        else
        begin
          if AE.Rc.DecodeBit(AE.Probs[PROB_ISREPG2 + AE.State]) = 0 then
            LDist := AE.Rep2
          else
          begin
            LDist := AE.Rep3;
            AE.Rep3 := AE.Rep2;
          end;
          AE.Rep2 := AE.Rep1;
        end;
        AE.Rep1 := AE.Rep0;
        AE.Rep0 := LDist;
      end;
      LLen := DecodeLen(AE, PROB_REPLEN, LPosState);
      if LLen > ASegmentSize then
        EngineError('rep match crosses segment boundary');
      CopyMatch(AE, AE.Rep0, LLen);
      if AE.State < 7 then
        AE.State := 8
      else
        AE.State := 11;
      Dec(ASegmentSize, LLen);
      Continue;
    end;
    { 普通匹配 }
    LLen := DecodeLen(AE, PROB_LEN, LPosState);
    LLenToPos := SizeInt(LLen) - 2;
    if LLenToPos > 3 then
      LLenToPos := 3;
    LPosSlot := TreeDecode(AE, PROB_POSSLOT + LLenToPos * 64, 6);
    if LPosSlot < 4 then
      LDist := LPosSlot
    else
    begin
      LNumDirectBits := (LPosSlot shr 1) - 1;
      {$PUSH}{$Q-}{$R-}
      LDist := SizeUInt(2 or (LPosSlot and 1)) shl LNumDirectBits;
      {$POP}
      if LPosSlot < C_END_POS_MODEL_INDEX then
        Inc(LDist, TreeReverseDecode(AE,
          PROB_SPECPOS + SizeInt(LDist) - SizeInt(LPosSlot), SizeInt(LNumDirectBits)))
      else
      begin
        Inc(LDist, SizeUInt(AE.Rc.DecodeDirectBits(
          LNumDirectBits - C_NUM_ALIGN_BITS)) shl C_NUM_ALIGN_BITS);
        Inc(LDist, TreeReverseDecode(AE, PROB_ALIGN, C_NUM_ALIGN_BITS));
      end;
    end;
    AE.Rep3 := AE.Rep2;
    AE.Rep2 := AE.Rep1;
    AE.Rep1 := AE.Rep0;
    AE.Rep0 := LDist;
    if LLen > ASegmentSize then
      EngineError('match crosses segment boundary');
    CopyMatch(AE, LDist, LLen);
    if AE.State < 7 then
      AE.State := 7
    else
      AE.State := 10;
    Dec(ASegmentSize, LLen);
  end;
end;

function ReadBE16(var AE: TEngineState): UInt32;
var
  LB0, LB1: Byte;
begin
  LB0 := AE.Rc.RawReadByte;
  LB1 := AE.Rc.RawReadByte;
  Result := (UInt32(LB0) shl 8) or LB1;
end;

{ TSevenZLzmaDecoderPascal }

function TSevenZLzmaDecoderPascal.DecodeLzma1(const AProps: TBytes;
  const APacked: TBytes; const AOutSize: SizeUInt): TBytes;
var
  LE: TEngineState;
  LPackedPtr: Pointer;
begin
  Result := nil;
  if Length(AProps) <> 5 then
    EngineError('lzma1 props must be 5 bytes');
  if AOutSize = 0 then
    Exit(nil);
  SetLength(Result, AOutSize);
  FillChar(Result[0], AOutSize, 0);
  LE.OutBuf := @Result[0];
  LE.OutSize := AOutSize;
  LE.Pos := 0;
  LE.DictStart := 0;
  ParsePropsByte(AProps[0], LE.Lc, LE.Lp, LE.Pb);
  LE.LitMask := (UInt32(1) shl LE.Lp) - 1;
  LE.PosMask := (UInt32(1) shl LE.Pb) - 1;
  ResetState(LE);
  if Length(APacked) = 0 then
    EngineError('empty lzma1 stream');
  LPackedPtr := @APacked[0];
  LE.Rc := TSevenZRcDecoder.Create(LPackedPtr^, SizeUInt(Length(APacked)));
  try
    LE.Rc.Init;
    RunSegment(LE, AOutSize);
  finally
    LE.Rc.Free;
  end;
end;

function TSevenZLzmaDecoderPascal.DecodeLzma2(const AProps: TBytes;
  const APacked: TBytes; const AOutSize: SizeUInt): TBytes;
var
  LE: TEngineState;
  LPackedPtr: Pointer;
  LControl: Byte;
  LUnpacked: SizeUInt;
  LPackedChunk: SizeUInt;
  LResetMode: Integer;
  LHaveProps: Boolean;
  LChunkStart: SizeUInt;
  LChunkEnd: SizeUInt;
begin
  Result := nil;
  if Length(AProps) <> 1 then
    EngineError('lzma2 props must be 1 byte');
  if AOutSize = 0 then
    Exit(nil);
  if Length(APacked) = 0 then
    EngineError('empty lzma2 stream');
  SetLength(Result, AOutSize);
  FillChar(Result[0], AOutSize, 0);
  LE.OutBuf := @Result[0];
  LE.OutSize := AOutSize;
  LE.Pos := 0;
  LE.DictStart := 0;
  LE.Lc := 3;
  LE.Lp := 0;
  LE.Pb := 2;
  LE.LitMask := 0;
  LE.PosMask := 3;
  LHaveProps := False;
  LPackedPtr := @APacked[0];
  LE.Rc := TSevenZRcDecoder.Create(LPackedPtr^, SizeUInt(Length(APacked)));
  try
    while True do
    begin
      LControl := LE.Rc.RawReadByte;
      if LControl = 0 then
        Break;  { 流结束标记 }
      if LControl < 3 then
      begin
        { 未压缩块：1 = 字典重置，2 = 无重置 }
        LUnpacked := SizeUInt(ReadBE16(LE)) + 1;
        if LE.Pos + LUnpacked > LE.OutSize then
          EngineError('uncompressed chunk overruns output size');
        if LControl = 1 then
          LE.DictStart := LE.Pos;
        LE.Rc.RawRead((LE.OutBuf + LE.Pos)^, LUnpacked);
        Inc(LE.Pos, LUnpacked);
        Continue;
      end;
      if LControl < $80 then
        EngineError('reserved lzma2 control byte');
      { LZ 压缩块 }
      LResetMode := (LControl shr 5) and 3;
      LUnpacked := (SizeUInt(LControl and $1F) shl 16) + ReadBE16(LE) + 1;
      LPackedChunk := SizeUInt(ReadBE16(LE)) + 1;
      if LResetMode >= 2 then
      begin
        ParsePropsByte(LE.Rc.RawReadByte, LE.Lc, LE.Lp, LE.Pb);
        LE.LitMask := (UInt32(1) shl LE.Lp) - 1;
        LE.PosMask := (UInt32(1) shl LE.Pb) - 1;
        LHaveProps := True;
      end;
      if not LHaveProps then
        EngineError('lzma2 chunk before properties');
      if LE.Pos + LUnpacked > LE.OutSize then
        EngineError('lzma chunk overruns output size');
      LChunkStart := LE.Pos;
      LChunkEnd := LE.Rc.Position + LPackedChunk;
      if LResetMode = 3 then
        LE.DictStart := LE.Pos;
      if LResetMode >= 1 then
        ResetState(LE);
      { 压缩载荷区隔离：每个 LZ 块自带完整区间码流段（编码器逐块 flush），
        必须在块边界重新 Init 区间解码器 }
      LE.Rc.ClipTo(LE.Rc.Position + LPackedChunk);
      LE.Rc.Init;
      RunSegment(LE, LUnpacked);
      if LE.Pos - LChunkStart <> LUnpacked then
        EngineError('lzma chunk segment size mismatch');
      if LE.Rc.Position <> LChunkEnd then
        EngineError('lzma2 packed size mismatch');
      LE.Rc.RestoreLimit;
    end;
    if LE.Pos <> LE.OutSize then
      EngineError('stream ended before declared output size');
  finally
    LE.Rc.Free;
  end;
end;

end.
