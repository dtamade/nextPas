unit nextpas.core.sevenz.bcj.arm;

{**
 * nextpas.core.sevenz.bcj.arm - BCJ ARM 分支/调用地址转换过滤器
 *
 * 对 ARM（little-endian）机器码中的 BL 指令（0xEB）做 地址↔相对位移
 * 双向换算，逐字对齐 xz simple/arm.c 参考实现（Igor Pavlov / Lasse Collin）：
 * 4 字节对齐扫描，src 取低 24 位 <<2 的相对位移，编码时 src+pc+8，解码时
 * src-pc-8，再 >>2 回写。保长变换，无跨块状态。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ BCJ ARM 原位转换。AEncode=True 编码（绝对→相对取反？按 xz 定义
  is_encoder=True 为相对→绝对），AStartOffset 为镜像基址（props 小端） }
procedure SevenZBcjArmConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

procedure SevenZBcjArmConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LSrc, LDest, LPC: UInt32;
begin
  LSize := Length(AData) and not 3;
  LI := 0;
  while LI < LSize do
  begin
    if AData[LI + 3] = $EB then
    begin
      {$PUSH}{$Q-}{$R-}
      LSrc := (UInt32(AData[LI + 2]) shl 16) or (UInt32(AData[LI + 1]) shl 8) or
        UInt32(AData[LI]);
      LSrc := LSrc shl 2;
      LPC := AStartOffset + UInt32(LI) + 8;
      if AEncode then
        LDest := LPC + LSrc
      else
        LDest := LSrc - LPC;
      LDest := LDest shr 2;
      AData[LI + 2] := Byte((LDest shr 16) and $FF);
      AData[LI + 1] := Byte((LDest shr 8) and $FF);
      AData[LI] := Byte(LDest and $FF);
      {$POP}
    end;
    Inc(LI, 4);
  end;
end;

end.
