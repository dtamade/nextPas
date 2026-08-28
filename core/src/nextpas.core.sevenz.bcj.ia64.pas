unit nextpas.core.sevenz.bcj.ia64;

{**
 * nextpas.core.sevenz.bcj.ia64 - BCJ IA-64 (Itanium) 分支地址转换过滤器
 *
 * 移植 xz simple/ia64.c：16 字节 bundle 对齐，3 slot 分支检测，
 *   5+41*slot 位域抽取 6 字节指令，21 位 src <<4 与 pc 加减。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

procedure SevenZBcjIa64Convert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

const
  CBranchTable: array[0..31] of UInt32 = (
    0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0,
    4,4,6,6, 0,0,7,7,
    4,4,0,0, 4,4,0,0);

procedure SevenZBcjIa64Convert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LSlot: SizeInt;
  LMask: UInt32;
  LBitPos: UInt32;
  LBytePos: SizeInt;
  LBitRes: UInt32;
  LInstr, LNorm: UInt64;
  LSrc, LDest, LPC: UInt32;
  LJ: SizeInt;
begin
  LSize := Length(AData) and not 15;
  LI := 0;
  while LI < LSize do
  begin
    LMask := CBranchTable[AData[LI] and $1F];
    LBitPos := 5;
    for LSlot := 0 to 2 do
    begin
      if ((LMask shr LSlot) and 1) = 0 then
      begin
        Inc(LBitPos, 41);
        Continue;
      end;
      LBytePos := LBitPos shr 3;
      LBitRes := LBitPos and 7;
      LInstr := 0;
      for LJ := 0 to 5 do
        LInstr := LInstr or (UInt64(AData[LI + LJ + LBytePos]) shl (8 * LJ));
      LNorm := LInstr shr LBitRes;
      if (((LNorm shr 37) and $F) = $5) and (((LNorm shr 9) and 7) = 0) then
      begin
        {$PUSH}{$Q-}{$R-}
        LSrc := UInt32((LNorm shr 13) and $FFFFF);
        LSrc := LSrc or (UInt32((LNorm shr 36) and 1) shl 20);
        LSrc := LSrc shl 4;
        LPC := AStartOffset + UInt32(LI);
        if AEncode then
          LDest := LPC + LSrc
        else
          LDest := LSrc - LPC;
        LDest := LDest shr 4;
        LNorm := LNorm and not (UInt64($8FFFFF) shl 13);
        LNorm := LNorm or (UInt64(LDest and $FFFFF) shl 13);
        LNorm := LNorm or (UInt64(LDest and $100000) shl (36 - 20));
        LInstr := LInstr and ((UInt64(1) shl LBitRes) - 1);
        LInstr := LInstr or (LNorm shl LBitRes);
        for LJ := 0 to 5 do
          AData[LI + LJ + LBytePos] := Byte((LInstr shr (8 * LJ)) and $FF);
        {$POP}
      end;
      Inc(LBitPos, 41);
    end;
    Inc(LI, 16);
  end;
end;

end.
