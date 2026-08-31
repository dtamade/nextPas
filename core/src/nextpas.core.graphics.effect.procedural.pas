{**
 * nextpas.core.graphics.effect.procedural - 过程纹理（反哺 game888.procedural_texture 7 函）
 * L2，零 RTL，仅 math，TBitmap(Stride64B) 承载。
 * 批化：7 函均接入 nextpas.core.simd.raster 批接口（FillSolid/Blend），行级批量替代逐像素双循环。
 *}
unit nextpas.core.graphics.effect.procedural;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.image.base,
  nextpas.core.math.scalar;

function ProcCheckerboard(Size, TileSize: Integer; C1, C2: TColor32): TBitmap;
function ProcBrick(Size, BrickW, BrickH, Mortar: Integer; BrickC, MortarC: TColor32): TBitmap;
function ProcNoise(Size: Integer; Base: TColor32; Variation: Integer): TBitmap;
function ProcGradientV(Size: Integer; Top, Bottom: TColor32): TBitmap;
function ProcMetal(Size: Integer; Base: TColor32; ScratchCount: Integer): TBitmap;
function ProcGrid(Size, LineWidth: Integer; Bg, Line: TColor32): TBitmap;
function ProcWood(Size: Integer; Base, Ring: TColor32): TBitmap;

implementation

uses
  nextpas.core.simd.raster,
  nextpas.core.bytes.binary;

function SimpleHash(X, Y: Integer): Integer; inline;
var H: DWord;
begin
  H := DWord(X * 374761393 + Y * 668265263);
  H := (H xor (H shr 13)) * 1274126177;
  H := H xor (H shr 16);
  Result := Integer(H and $7FFFFFFF);
end;

function LerpColor(C1, C2: TColor32; T: Single): TColor32;
var R1, G1, B1, A1, R2, G2, B2, A2: Integer;
begin
  R1 := Color32R(C1); G1 := Color32G(C1); B1 := Color32B(C1); A1 := Color32A(C1);
  R2 := Color32R(C2); G2 := Color32G(C2); B2 := Color32B(C2); A2 := Color32A(C2);
  Result := Color32(nextpas.core.math.scalar.ClampByte(Integer(Round(R1 + (R2 - R1) * T))), nextpas.core.math.scalar.ClampByte(Integer(Round(G1 + (G2 - G1) * T))), nextpas.core.math.scalar.ClampByte(Integer(Round(B1 + (B2 - B1) * T))), nextpas.core.math.scalar.ClampByte(Integer(Round(A1 + (A2 - A1) * T))));
end;

function ProcCheckerboard(Size, TileSize: Integer; C1, C2: TColor32): TBitmap;
var Y, X, Rem, TX, TY: Integer; Row: PByte; C: TColor32; R, G, B, A: Byte;
begin
  Result := TBitmap.Create(Size, Size);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    TY := Y div TileSize;
    X := 0;
    while X < Size do
    begin
      TX := X div TileSize;
      Rem := TileSize - (X mod TileSize);
      if Rem > Size - X then Rem := Size - X;
      if ((TX + TY) mod 2) = 0 then C := C1 else C := C2;
      Color32Decompose(C, R, G, B, A);
      RasterFillSolid(Row + X * 4, Rem, R, G, B, A);
      Inc(X, Rem);
    end;
  end;
end;

function ProcBrick(Size, BrickW, BrickH, Mortar: Integer; BrickC, MortarC: TColor32): TBitmap;
var X, Y, BX, BY, Off, N, SegLen, K, Run, N2: Integer; R, G, B, MR, MG, MB, MA: Byte; Row: PByte; BR, BG, BB: Byte; PackedC: LongWord;
begin
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(MortarC, MR, MG, MB, MA);
  BR := Color32R(BrickC);
  BG := Color32G(BrickC);
  BB := Color32B(BrickC);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    BY := Y mod BrickH;
    if BY < Mortar then
    begin
      RasterFillSolid(Row, Size, MR, MG, MB, MA);
      Continue;
    end;
    if ((Y div BrickH) mod 2) = 1 then Off := BrickW div 2 else Off := 0;
    X := 0;
    while X < Size do
    begin
      BX := (X + Off) mod BrickW;
      if BX < Mortar then
      begin
        SegLen := Mortar - BX;
        if SegLen > Size - X then SegLen := Size - X;
        RasterFillSolid(Row + X * 4, SegLen, MR, MG, MB, MA);
        Inc(X, SegLen);
      end
      else
      begin
        SegLen := BrickW - BX;
        if SegLen > Size - X then SegLen := Size - X;
        // 砖体内变体批化：同色游程合并为 RasterFillSolid，其余单点用 bytes.binary 直接打包
        K := 0;
        while K < SegLen do
        begin
          N := (SimpleHash(X + K, Y) mod 20) - 10;
          R := nextpas.core.math.scalar.ClampByte(Integer(BR) + N);
          G := nextpas.core.math.scalar.ClampByte(Integer(BG) + N div 2);
          B := nextpas.core.math.scalar.ClampByte(Integer(BB) + N div 3);
          PackedC := RgbaToPixelLE(R, G, B, 255);
          Run := 1;
          while K + Run < SegLen do
          begin
            N2 := (SimpleHash(X + K + Run, Y) mod 20) - 10;
            if (nextpas.core.math.scalar.ClampByte(Integer(BR) + N2) <> R) or (nextpas.core.math.scalar.ClampByte(Integer(BG) + N2 div 2) <> G) or (nextpas.core.math.scalar.ClampByte(Integer(BB) + N2 div 3) <> B) then Break;
            Inc(Run);
          end;
          if Run > 1 then
            RasterFillSolid(Row + (X + K) * 4, Run, R, G, B, 255)
          else
            WriteUInt32LE(Row + (X + K) * 4, PackedC);
          Inc(K, Run);
        end;
        Inc(X, SegLen);
      end;
    end;
  end;
end;

function ProcNoise(Size: Integer; Base: TColor32; Variation: Integer): TBitmap;
var X, Y, N, R, G, B: Integer; Row: PByte; BR, BG, BB, BA: Byte;
begin
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(Base, BR, BG, BB, BA);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    // 单遍行批：直接按 Base+variation 打包写入，复用 bytes.binary，避免先 Fill 再逐字节改
    for X := 0 to Size - 1 do
    begin
      N := (SimpleHash(X, Y) mod (Variation * 2 + 1)) - Variation;
      R := nextpas.core.math.scalar.ClampByte(Integer(BR) + N);
      G := nextpas.core.math.scalar.ClampByte(Integer(BG) + N);
      B := nextpas.core.math.scalar.ClampByte(Integer(BB) + N);
      WriteUInt32LE(Row + X * 4, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA));
    end;
  end;
end;

function ProcGradientV(Size: Integer; Top, Bottom: TColor32): TBitmap;
var Y: Integer; T: Single; C: TColor32; R, G, B, A: Byte; Row: PByte;
begin
  Result := TBitmap.Create(Size, Size);
  for Y := 0 to Size - 1 do
  begin
    if Size <= 1 then T := 0 else T := Y / (Size - 1);
    C := LerpColor(Top, Bottom, T);
    Color32Decompose(C, R, G, B, A);
    Row := Result.RowPtr(Y);
    RasterFillSolid(Row, Size, R, G, B, A);
  end;
end;

function ProcMetal(Size: Integer; Base: TColor32; ScratchCount: Integer): TBitmap;
var X, Y, I, SX, SY, SLen, SD, N, R, G, B: Integer; Row: PByte; P: PByte; BR, BG, BB, BA: Byte;
begin
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(Base, BR, BG, BB, BA);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    // 单遍行批：base+grain 一次打包，复用 bytes.binary，避免 Fill+改
    for X := 0 to Size - 1 do
    begin
      N := (SimpleHash(X, Y * 7) mod 16) - 8;
      R := nextpas.core.math.scalar.ClampByte(Integer(BR) + N);
      G := nextpas.core.math.scalar.ClampByte(Integer(BG) + N);
      B := nextpas.core.math.scalar.ClampByte(Integer(BB) + N);
      WriteUInt32LE(Row + X * 4, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255));
    end;
  end;
  for I := 0 to ScratchCount - 1 do
  begin
    SX := SimpleHash(I * 3, 0) mod Size; SY := SimpleHash(0, I * 5) mod Size;
    SLen := 10 + SimpleHash(I, I) mod 30; SD := SimpleHash(I * 7, I * 11) mod 4;
    for X := 0 to SLen - 1 do
    begin
      case SD of
        0: SX := (SX + 1) mod Size;
        1: SY := (SY + 1) mod Size;
        2: begin SX := (SX + 1) mod Size; SY := (SY + 1) mod Size; end;
        3: begin SX := (SX + 1) mod Size; if SY > 0 then Dec(SY); end;
      end;
      P := Result.GetPixelPtr(SX, SY);
      P[0] := nextpas.core.math.scalar.ClampByte(Integer(P[0]) + 30); P[1] := nextpas.core.math.scalar.ClampByte(Integer(P[1]) + 30); P[2] := nextpas.core.math.scalar.ClampByte(Integer(P[2]) + 30);
    end;
  end;
end;

function ProcGrid(Size, LineWidth: Integer; Bg, Line: TColor32): TBitmap;
var X, Y, Cell, Rem: Integer; Row: PByte; LR, LG, LB, LA, BR, BG2, BB, BA2: Byte;
begin
  Result := TBitmap.Create(Size, Size);
  Cell := Size div 8; if Cell < 4 then Cell := 4;
  Color32Decompose(Line, LR, LG, LB, LA);
  Color32Decompose(Bg, BR, BG2, BB, BA2);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    if (Y mod Cell) < LineWidth then
    begin
      RasterFillSolid(Row, Size, LR, LG, LB, LA);
      Continue;
    end;
    X := 0;
    while X < Size do
    begin
      if (X mod Cell) < LineWidth then
      begin
        Rem := LineWidth - (X mod Cell);
        if Rem > Size - X then Rem := Size - X;
        RasterFillSolid(Row + X * 4, Rem, LR, LG, LB, LA);
        Inc(X, Rem);
      end
      else
      begin
        Rem := Cell - (X mod Cell);
        if Rem > Size - X then Rem := Size - X;
        RasterFillSolid(Row + X * 4, Rem, BR, BG2, BB, BA2);
        Inc(X, Rem);
      end;
    end;
  end;
end;

function ProcWood(Size: Integer; Base, Ring: TColor32): TBitmap;
var X, Y, N: Integer; CX, CY, DY, DX, Dist, Rf, T: Single; Row: PByte; R, G, B, A: Byte;
  BR, BG, BB, BA, RR, RG, RB, RA: Byte; TR: Single; RowBuf: array of LongWord; Inv12: Single;
begin
  Result := TBitmap.Create(Size, Size);
  CX := Size / 2; CY := Size / 2;
  Color32Decompose(Base, BR, BG, BB, BA);
  Color32Decompose(Ring, RR, RG, RB, RA);
  Inv12 := 1.0 / 12.0;
  SetLength(RowBuf, Size);
  for Y := 0 to Size - 1 do
  begin
    Row := Result.RowPtr(Y);
    DY := Y - CY;
    for X := 0 to Size - 1 do
    begin
      DX := X - CX;
      Dist := Sqrt(DX * DX + DY * DY);
      N := (SimpleHash(X, Y) mod 6) - 3; Dist := Dist + N;
      Rf := Frac(Dist * Inv12);
      if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2;
      TR := T * 0.6;
      R := nextpas.core.math.scalar.ClampByte(Integer(Round(Integer(BR) + (Integer(RR) - Integer(BR)) * TR)));
      G := nextpas.core.math.scalar.ClampByte(Integer(Round(Integer(BG) + (Integer(RG) - Integer(BG)) * TR)));
      B := nextpas.core.math.scalar.ClampByte(Integer(Round(Integer(BB) + (Integer(RB) - Integer(BB)) * TR)));
      A := nextpas.core.math.scalar.ClampByte(Integer(Round(Integer(BA) + (Integer(RA) - Integer(BA)) * TR)));
      RowBuf[X] := RgbaToPixelLE(R, G, B, A);
    end;
    if Size > 0 then Move(RowBuf[0], Row^, Size * 4);
  end;
end;

end.
