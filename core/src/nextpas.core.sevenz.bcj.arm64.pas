unit nextpas.core.sevenz.bcj.arm64;

{**
 * nextpas.core.sevenz.bcj.arm64 - BCJ ARM64 分支/地址转换过滤器
 *
 * 对 ARM64 机器码中的 BL（0x25）与 ADRP（0x90）做 地址↔相对位移 换算，
 * 逐字对齐 xz simple/arm64.c 参考实现（Lasse Collin / Jia Tan）：
 * BL 取低 26 位，ADRP 取重组后的 21 位页内位移，分别以指令为单位
 * 与 pc 做加减，保长，无跨块状态。start_offset 需 4 字节对齐。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.bcj.utils;

procedure SevenZBcjArm64Convert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

procedure SevenZBcjArm64Convert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LPC: UInt32;
  LInstr, LSrc, LDest: UInt32;
begin
  AStartOffset := AStartOffset and not UInt32(3);
  LSize := Length(AData) and not 3;
  LI := 0;
  while LI < LSize do
  begin
    LPC := AStartOffset + UInt32(LI);
    LInstr := ReadLE32(AData, LI);
    if (LInstr shr 26) = $25 then
    begin
      { BL:26 位 }
      LSrc := LInstr;
      LInstr := $94000000;
      LPC := LPC shr 2;
      if not AEncode then
        LPC := SubPc(0, LPC);
      {$PUSH}{$Q-}{$R-}
      LInstr := LInstr or ((AddPc(LSrc, LPC)) and $03FFFFFF);
      {$POP}
      WriteLE32(AData, LI, LInstr);
    end
    else if (LInstr and $9F000000) = $90000000 then
    begin
      { ADRP }
      LSrc := ((LInstr shr 29) and 3) or ((LInstr shr 3) and $001FFFFC);
      {$PUSH}{$Q-}{$R-}
      if ((AddPc(LSrc, $00020000)) and $001C0000) <> 0 then
      begin
        Inc(LI, 4);
        Continue;
      end;
      LInstr := LInstr and $9000001F;
      LPC := LPC shr 12;
      if not AEncode then
        LPC := SubPc(0, LPC);
      LDest := AddPc(LSrc, LPC);
      LInstr := LInstr or ((LDest and 3) shl 29);
      LInstr := LInstr or ((LDest and $0003FFFC) shl 3);
      LInstr := LInstr or ((SubPc(0, (LDest and $00020000))) and $00E00000);
      {$POP}
      WriteLE32(AData, LI, LInstr);
    end;
    Inc(LI, 4);
  end;
end;

end.
