unit nextpas.core.sevenz.bcj.ppc;

{**
 * nextpas.core.sevenz.bcj.ppc - BCJ PowerPC 分支/调用地址转换过滤器
 *
 * 对 PowerPC（big-endian）机器码中的 b/bl 做 地址↔相对位移 换算，
 * 逐字对齐 xz simple/powerpc.c 参考实现：
 * 4 字节对齐，判定 (buf[0]>>2)==0x12 且 (buf[3]&3)==1，src 为 26 位
 * 有符号位移（大端拼接，低 2 位掩码），编码时 src+pc，解码时 src-pc。
 * 保长，无跨块状态。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

procedure SevenZBcjPpcConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

procedure SevenZBcjPpcConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LSrc, LDest: UInt32;
begin
  LSize := Length(AData) and not 3;
  LI := 0;
  while LI < LSize do
  begin
    if ((AData[LI] shr 2) = $12) and ((AData[LI + 3] and 3) = 1) then
    begin
      {$PUSH}{$Q-}{$R-}
      LSrc := ((UInt32(AData[LI] and 3) shl 24) or
        (UInt32(AData[LI + 1]) shl 16) or (UInt32(AData[LI + 2]) shl 8) or
        (UInt32(AData[LI + 3]) and not UInt32(3)));
      if AEncode then
        LDest := UInt32(AStartOffset) + UInt32(LI) + LSrc
      else
        LDest := LSrc - (UInt32(AStartOffset) + UInt32(LI));
      AData[LI] := $48 or Byte((LDest shr 24) and $03);
      AData[LI + 1] := Byte((LDest shr 16) and $FF);
      AData[LI + 2] := Byte((LDest shr 8) and $FF);
      AData[LI + 3] := (AData[LI + 3] and $03) or Byte(LDest and $FF);
      {$POP}
    end;
    Inc(LI, 4);
  end;
end;

end.
