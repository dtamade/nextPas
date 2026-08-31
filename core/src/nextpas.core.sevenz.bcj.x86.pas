unit nextpas.core.sevenz.bcj.x86;

{**
 * nextpas.core.sevenz.bcj.x86 - BCJ x86 分支/调用地址转换过滤器
 *
 * 对 x86 机器码中的 E8/E9 近调用与相对转移做 地址↔相对位移 双向换算，
 * 使可执行内容对 LZMA 更可压。逐字对齐 xz simple/x86.c 参考实现
 * （Igor Pavlov / Lasse Collin，与 p7zip 同源算法）：
 * 候选操作数最高位须为 $00/$FF 才转换；掩码跟踪与前序指令的字节重叠，
 * 重叠位形经迭代修正仅改写非共享高位。编解码互为镜像算术。
 * 按整流一次性变换（单调用无跨块状态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.bcj.utils;

{ BCJ x86 原位转换。AEncode=True：绝对→相对（编码方向）；
  AEncode=False：相对→绝对（解码方向）。AStartIp 为镜像基址
  （容器 props 的 4 字节小端起始地址）}
procedure SevenZBcjX86Convert(var AData: TBytes; AStartIp: UInt32;
  AEncode: Boolean);

implementation

{ 操作数最高位为 $FF/$00 时才视为可转换的调用/转移候选 }
function TestMsByte(B: Byte): Boolean; inline;
begin
  Result := (B = $00) or (B = $FF);
end;

procedure SevenZBcjX86Convert(var AData: TBytes; AStartIp: UInt32;
  AEncode: Boolean);
const
  { 掩码值 -> 操作数内已共享的低字节序号 }
  C_MASK_TO_BIT_NUMBER: array[0..4] of UInt32 = (0, 1, 2, 2, 3);
var
  LPrevMask: UInt32;
  LPrevPos: Int64;
  LOffset: Int64;
  LNowPos: Int64;
  LLimit: SizeInt;
  LBP: SizeInt;
  LI: Int64;
  LB: Byte;
  LSrc: UInt32;
  LDest: UInt32;
  LCur: UInt32;
begin
  if Length(AData) < 5 then
    Exit;
  LPrevMask := 0;
  LNowPos := 0;          { 单次整流：流内基点为 0 }
  LPrevPos := -5;        { 参考实现的流首哨兵 }
  LBP := 0;
  LLimit := Length(AData) - 5;
  while LBP <= LLimit do
  begin
    LB := AData[LBP];
    if (LB <> $E8) and (LB <> $E9) then
    begin
      Inc(LBP);
      Continue;
    end;
    LOffset := LNowPos + LBP - LPrevPos;
    LPrevPos := LNowPos + LBP;
    if LOffset > 5 then
      LPrevMask := 0
    else
    begin
      {$PUSH}{$Q-}{$R-}
      for LI := 1 to LOffset do
      begin
        LPrevMask := LPrevMask and $77;
        LPrevMask := LPrevMask shl 1;
      end;
      {$POP}
    end;

    LB := AData[LBP + 4];
    if TestMsByte(LB) and ((LPrevMask shr 1) <= 4) and
       ((LPrevMask shr 1) <> 3) then
    begin
      {$PUSH}{$Q-}{$R-}
      LSrc := (UInt32(LB) shl 24) or (UInt32(AData[LBP + 3]) shl 16) or
        (UInt32(AData[LBP + 2]) shl 8) or UInt32(AData[LBP + 1]);
      while True do
      begin
        LCur := AddPc(UInt32(AStartIp), UInt32(LNowPos + LBP + 5));
        if AEncode then
          LDest := AddPc(LSrc, LCur)
        else
          LDest := SubPc(LSrc, LCur);
        if LPrevMask = 0 then
          Break;
        LI := Int64(C_MASK_TO_BIT_NUMBER[LPrevMask shr 1]);
        LB := Byte(LDest shr (24 - LI * 8));
        if not TestMsByte(LB) then
          Break;
        { 与前序结果重叠的高位保持其 $00/$FF 形态：
          抹掉低位后作为下一轮迭代输入 }
        LSrc := LDest xor ((UInt32(1) shl (32 - LI * 8)) - 1);
      end;
      {$POP}
      { 结果最高位归一化为全 0/全 1 字节 }
      if ((LDest shr 24) and 1) <> 0 then
        AData[LBP + 4] := $FF
      else
        AData[LBP + 4] := $00;
      AData[LBP + 3] := Byte(LDest shr 16);
      AData[LBP + 2] := Byte(LDest shr 8);
      AData[LBP + 1] := Byte(LDest);
      Inc(LBP, 5);
      LPrevMask := 0;
    end
    else
    begin
      Inc(LBP);
      LPrevMask := LPrevMask or 1;
      if TestMsByte(LB) then
        LPrevMask := LPrevMask or $10;
    end;
  end;
end;

end.
