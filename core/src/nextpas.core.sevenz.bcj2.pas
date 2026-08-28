unit nextpas.core.sevenz.bcj2;

{**
 * nextpas.core.sevenz.bcj2 - BCJ2 四流分支过滤器解码器
 *
 * 逐字移植自官方 7-Zip 的 C/Bcj2.c（Igor Pavlov，Public domain）。
 * BCJ2 将 x86 近调用/跳转的操作数改换为绝对地址后拆入四条子流：
 * MAIN（指令主体）、CALL（E8 操作数，大端）、JUMP（E9 与 0F8x 操作数，
 * 大端）、RC（区间编码的选择位流）。候选判定与模型更新顺序与参考
 * 实现严格一致；本单元仅去除分块续传面（整档一次性解码场景），
 * 区间初始化、自适应概率、部分写恢复等语义原样保留。属性字节在
 * 参考实现中即未接线（ip 恒从 0 起），故同样忽略。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.base;

{ 解码 BCJ2 四条输入子流，输出精确 AOutSize 字节。任一子流不足或
  区间码流非法抛 ESevenZError }
procedure SevenZBcj2Decode(const AMain, ACall, AJump, ARc: TBytes;
  AOutSize: UInt64; out AOut: TBytes);

implementation

const
  { 区间编码常数：与 Bcj2.c 一致 }
  C_TOP_VALUE = UInt32(1) shl 24;
  C_BIT_MODEL_TOTAL = UInt32(1) shl 11;
  C_NUM_MOVE_BITS = 5;

  { 流序：与 BCJ2_STREAM_* 枚举一致 }
  C_STREAM_CALL = 1;
  C_STREAM_JUMP = 2;
  C_STREAM_RC = 3;

type
  { 单条子流的游标（Buf 前进至 Lim 即耗尽） }
  TBcj2Cursor = record
    Buf: PByte;
    Lim: PByte;
  end;

  TBcj2Dec = record
    { 状态字沿用 C 的整数语义：0..3 为流等待态，4..7 为部分写恢复态 }
    State: Integer;
    Ip: UInt32;
    Temp: UInt32;
    Range: UInt32;
    Code: UInt32;
    Dest: PByte;
    DestLim: PByte;
    Streams: array[0..3] of TBcj2Cursor;
    Probs: array[0..257] of Word;
  end;

  { 大端读 4 字节（GetBe32a） }
  function GetBe32(const ACur: PByte): UInt32; inline;
  begin
    {$PUSH}{$Q-}{$R-}
    Result := (UInt32(ACur[0]) shl 24) or (UInt32(ACur[1]) shl 16) or
      (UInt32(ACur[2]) shl 8) or UInt32(ACur[3]);
    {$POP}
  end;

  { 小端写 4 字节（SetUi32） }
  procedure SetLe32(ADest: PByte; AVal: UInt32); inline;
  begin
    {$PUSH}{$Q-}{$R-}
    ADest[0] := Byte(AVal);
    ADest[1] := Byte(AVal shr 8);
    ADest[2] := Byte(AVal shr 16);
    ADest[3] := Byte(AVal shr 24);
    {$POP}
  end;

  function RcByte(var P: TBcj2Dec): Byte; inline;
  begin
    if P.Streams[C_STREAM_RC].Buf = P.Streams[C_STREAM_RC].Lim then
      raise ESevenZError.Create('bcj2 rc stream truncated');
    Result := P.Streams[C_STREAM_RC].Buf^;
    Inc(P.Streams[C_STREAM_RC].Buf);
  end;

  procedure Bcj2DecInit(var P: TBcj2Dec);
  var
    LI: Integer;
  begin
    P.State := C_STREAM_RC;
    P.Ip := 0;
    P.Temp := 0;
    P.Range := 0;
    P.Code := 0;
    for LI := 0 to High(P.Probs) do
      P.Probs[LI] := C_BIT_MODEL_TOTAL shr 1;
  end;

  { 单步推进：返回 0 = 正常（含待数据挂起），非 0 = 数据错误。
    与 Bcj2Dec_Decode 逐句对应 }
  function Bcj2DecStep(var P: TBcj2Dec): Integer;
  var
    v: UInt32;
    LState: Integer;
    LI: Integer;
    b: UInt32;
    LDestRem: SizeInt;
    LC: Cardinal;
    LProbIdx: Cardinal;
    LTtt, LBound: UInt32;
    LCj: Integer;
    LCur: PByte;
    LIp: UInt32;
    LDone: Boolean;
  label
    LOuterContinue;
  begin
    Result := 0;
    v := P.Temp;

    { 区间码延迟初始化：首字节必须为 0，共吞 5 字节 }
    if P.Range <= 5 then
    begin
      {$PUSH}{$Q-}{$R-}
      for LI := 0 to 4 do
      begin
        if (LI = 1) and (P.Code <> 0) then
          Exit(1);
        P.Code := (P.Code shl 8) or RcByte(P);
      end;
      {$POP}
      if P.Code = $FFFFFFFF then
        Exit(1);
      P.Range := $FFFFFFFF;
    end
    else
    begin
      { 挂起恢复：32 位操作数半写 / ORIG 尾字节重放（分块场景路径，
        整档模式下仅在部分写触发后同轮内不会再现，保留以对齐参考实现） }
      LState := P.State;
      if (LState = C_STREAM_CALL) or (LState = C_STREAM_JUMP) then
      begin
        LCur := P.Streams[LState].Buf;
        if LCur = P.Streams[LState].Lim then
          Exit(0);
        Inc(P.Streams[LState].Buf, 4);
        {$PUSH}{$Q-}{$R-}
        LIp := P.Ip + 4;
        v := GetBe32(LCur) - LIp;
        P.Ip := LIp;
        {$POP}
        LState := 4;  { BCJ2_DEC_STATE_ORIG_0 }
      end;
      if (LState >= 4) and (LState <= 7) then
      begin
        while True do
        begin
          if P.Dest = P.DestLim then
          begin
            P.State := LState;
            P.Temp := v;
            Exit(0);
          end;
          P.Dest^ := Byte(v);
          Inc(P.Dest);
          Inc(LState);
          if LState = 8 then
            Break;
          {$PUSH}{$Q-}{$R-}
          v := v shr 8;
          {$POP}
        end;
      end;
    end;

    { 主循环 }
    while True do
    begin
      if P.Range < C_TOP_VALUE then
      begin
        {$PUSH}{$Q-}{$R-}
        P.Range := P.Range shl 8;
        P.Code := (P.Code shl 8) or RcByte(P);
        {$POP}
      end;

      { 批量拷贝段（逐字节等价实现）：候选即断出 }
      while True do
      begin
        if P.Dest = P.DestLim then
        begin
          P.State := 0;  { BCJ2_STREAM_MAIN：主输出完成 }
          Exit(0);
        end;
        if P.Streams[0].Buf = P.Streams[0].Lim then
        begin
          P.State := 0;
          Exit(0);
        end;
        b := P.Streams[0].Buf^;
        Inc(P.Streams[0].Buf);
        P.Dest^ := Byte(b);
        Inc(P.Dest);
        Inc(P.Ip);
        {$PUSH}{$Q-}{$R-}
        v := (v shl 24) or b;
        {$POP}
        { E8/E9 候选 }
        if ((b + $18) and $FE) = 0 then
          Break;
        { 0F 8x 长跳窗口候选 }
        if ((v - $0F000080) and $FFFFFFF0) = 0 then
          Break;
      end;

      { 自适应位：0 = 该候选按普通数据处理，继续拷贝 }
      {$PUSH}{$Q-}{$R-}
      LC := ((v + $17) shr 6) and 1;
      LProbIdx := ((Cardinal(0) - LC) and (v shr 24)) + LC +
        ((v shr 5) and 1);
      {$POP}
      LTtt := P.Probs[LProbIdx];
      LBound := (P.Range shr 11) * LTtt;
      if P.Code < LBound then
      begin
        P.Range := LBound;
        P.Probs[LProbIdx] :=
          Word(LTtt + ((C_BIT_MODEL_TOTAL - LTtt) shr C_NUM_MOVE_BITS));
        Continue;
      end;
      {$PUSH}{$Q-}{$R-}
      P.Range := P.Range - LBound;
      P.Code := P.Code - LBound;
      {$POP}
      P.Probs[LProbIdx] := Word(LTtt - (LTtt shr C_NUM_MOVE_BITS));

      { 位为 1：操作数已转换，取自 CALL（E8）或 JUMP（其余）流 }
      {$PUSH}{$Q-}{$R-}
      LCj := C_STREAM_CALL + Integer(((v + $57) shr 6) and 1);
      {$POP}
      if P.Streams[LCj].Lim - P.Streams[LCj].Buf < 4 then
      begin
        P.State := LCj;
        Break;
      end;
      LCur := P.Streams[LCj].Buf;
      Inc(P.Streams[LCj].Buf, 4);
      {$PUSH}{$Q-}{$R-}
      LIp := P.Ip + 4;
      v := GetBe32(LCur) - LIp;
      P.Ip := LIp;
      {$POP}
      LDestRem := P.DestLim - P.Dest;
      if LDestRem < 4 then
      begin
        if LDestRem > 0 then
        begin
          P.Dest[0] := Byte(v);
          v := v shr 8;
          if LDestRem > 1 then
          begin
            P.Dest[1] := Byte(v);
            v := v shr 8;
            if LDestRem > 2 then
            begin
              P.Dest[2] := Byte(v);
              v := v shr 8;
            end;
          end;
        end;
        P.Temp := v;
        Inc(P.Dest, LDestRem);
        P.State := 4 + Integer(LDestRem);  { ORIG_0 + rem }
        Break;
      end;
      SetLe32(P.Dest, v);
      Inc(P.Dest, 4);
      v := v shr 24;
    end;

    { 尾部归一化一次（与参考实现的循环外补位一致） }
    if (P.Range < C_TOP_VALUE) and
       (P.Streams[C_STREAM_RC].Buf <> P.Streams[C_STREAM_RC].Lim) then
    begin
      {$PUSH}{$Q-}{$R-}
      P.Range := P.Range shl 8;
      P.Code := (P.Code shl 8) or RcByte(P);
      {$POP}
    end;
  end;

procedure SevenZBcj2Decode(const AMain, ACall, AJump, ARc: TBytes;
  AOutSize: UInt64; out AOut: TBytes);
var
  P: TBcj2Dec;
  LDestPos: SizeInt;
begin
  AOut := nil;
  SetLength(AOut, AOutSize);
  P := Default(TBcj2Dec);
  P.Streams[0].Buf := Pointer(AMain);
  P.Streams[0].Lim := P.Streams[0].Buf + Length(AMain);
  P.Streams[C_STREAM_CALL].Buf := Pointer(ACall);
  P.Streams[C_STREAM_CALL].Lim := P.Streams[C_STREAM_CALL].Buf + Length(ACall);
  P.Streams[C_STREAM_JUMP].Buf := Pointer(AJump);
  P.Streams[C_STREAM_JUMP].Lim := P.Streams[C_STREAM_JUMP].Buf + Length(AJump);
  P.Streams[C_STREAM_RC].Buf := Pointer(ARc);
  P.Streams[C_STREAM_RC].Lim := P.Streams[C_STREAM_RC].Buf + Length(ARc);
  if Length(AOut) > 0 then
  begin
    P.Dest := @AOut[0];
    P.DestLim := P.Dest + Length(AOut);
  end
  else
  begin
    P.Dest := nil;
    P.DestLim := nil;
  end;
  Bcj2DecInit(P);
  while P.Dest <> P.DestLim do
  begin
    LDestPos := P.Dest - PByte(Pointer(AOut));
    if Bcj2DecStep(P) <> 0 then
      raise ESevenZError.Create('bcj2 range coder data error');
    { 无任何输出推进 = 输入不足以完成解码（截断） }
    if P.Dest - PByte(Pointer(AOut)) = LDestPos then
      raise ESevenZError.Create('bcj2 input truncated');
  end;
end;

end.
