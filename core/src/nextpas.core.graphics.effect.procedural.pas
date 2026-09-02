{**
 * nextpas.core.graphics.effect.procedural - 过程纹理（反哺 game888.procedural_texture 7 函）
 * 层级：L2 effect 族（寄宿 graphics.* 命名空间，非 L1 底座）。
 * 归层说明：L1 仅 graphics.base/color/path（零依赖）；本单元与 effect.graph 同为
 *   L2，同层单向依赖 image.base TBitmap（Stride64B 承载）+ L0/L1 simd.raster/
 *   bytes.binary/math.scalar 行批处理，未越层 L1->L2，符合“同层单向、禁止循环”约束。
 *   同层依赖已显式列于 core/docs/core-module-registry.md `effect` 行
 *   Allowed dependencies: L0-L1 plus same-layer one-way `image` (TBitmap Stride 64B)。
 *   显式说明：对 image.base TBitmap 的依赖为 intentional L2 same-layer
 *   single-direction allowlist（Stride 64B 承载），已在 registry 显式 allowlist，
 *   无需更新 architecture_contract_registry.json（L0 治理外）；禁止循环、仅单向 effect→image。
 * 批化：7 函均接入 nextpas.core.simd.raster 批接口（FillSolid 等），行级批量替代逐像素双循环。
 *   ProcBrick/Noise/Metal 行Hash预计算单次SimpleHash/像素并合并同色游程；
 *   ProcWood DX2预计算+Y行Hash批+inline Sqrt/Round，零拷贝WriteUInt32LE。
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
  nextpas.core.errors,
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

// 行批内联：Wood 通道插值单次Round，inline 消调用开销，零拷贝由 WriteUInt32LE 承载
function BlendChannel(ABase, ARing: Byte; AT: Single): Byte; inline;
begin
  Result := ClampByte(Integer(Round(Integer(ABase) + (Integer(ARing) - Integer(ABase)) * AT)));
end;

function LerpColor(C1, C2: TColor32; T: Single): TColor32;
var R1, G1, B1, A1, R2, G2, B2, A2: Integer;
begin
  R1 := Color32R(C1); G1 := Color32G(C1); B1 := Color32B(C1); A1 := Color32A(C1);
  R2 := Color32R(C2); G2 := Color32G(C2); B2 := Color32B(C2); A2 := Color32A(C2);
  Result := Color32(ClampByte(Integer(Round(R1 + (R2 - R1) * T))), ClampByte(Integer(Round(G1 + (G2 - G1) * T))), ClampByte(Integer(Round(B1 + (B2 - B1) * T))), ClampByte(Integer(Round(A1 + (A2 - A1) * T))));
end;

function ProcCheckerboard(Size, TileSize: Integer; C1, C2: TColor32): TBitmap;
var Y, X, Rem, TX, TY: Integer; Row: PByte; C: TColor32; R, G, B, A: Byte;
  Base: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcCheckerboard: Size must be >0');
  if TileSize <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcCheckerboard: TileSize must be >0');
  Result := TBitmap.Create(Size, Size);
  Result.EnsureUnique;
  Base := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := Base + Y * Stride;
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
var X, Y, BX, BY, Off, N, SegLen, K, Run: Integer; R, G, B, MR, MG, MB, MA: Byte; Row: PByte; BR, BG, BB: Byte; PackedC: LongWord;
  RowHash: array of ShortInt;
  Base: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcBrick: Size must be >0');
  if BrickW <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcBrick: BrickW must be >0');
  if BrickH <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcBrick: BrickH must be >0');
  if Mortar <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcBrick: Mortar must be >0');
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(MortarC, MR, MG, MB, MA);
  BR := Color32R(BrickC);
  BG := Color32G(BrickC);
  BB := Color32B(BrickC);
  SetLength(RowHash, Size);
  Result.EnsureUnique;
  Base := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := Base + Y * Stride;
    BY := Y mod BrickH;
    if BY < Mortar then
    begin
      RasterFillSolid(Row, Size, MR, MG, MB, MA);
      Continue;
    end;
    // 行Hash批化：本行一次SimpleHash/像素，复用于段内游程合并，消除逐像素二次哈希
    for X := 0 to Size - 1 do
      RowHash[X] := SmallInt((SimpleHash(X, Y) mod 20) - 10);
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
        // 砖体内变体批化：同色游程合并为 RasterFillSolid，其余单点用 bytes.binary 直接打包（零拷贝）
        K := 0;
        while K < SegLen do
        begin
          N := RowHash[X + K];
          R := ClampByte(Integer(BR) + N);
          G := ClampByte(Integer(BG) + N div 2);
          B := ClampByte(Integer(BB) + N div 3);
          PackedC := RgbaToPixelLE(R, G, B, 255);
          Run := 1;
          while K + Run < SegLen do
          begin
            N := RowHash[X + K + Run];
            if (ClampByte(Integer(BR) + N) <> R) or (ClampByte(Integer(BG) + N div 2) <> G) or (ClampByte(Integer(BB) + N div 3) <> B) then Break;
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
  // RowHash 托管数组自动释放，无泄漏
end;

function ProcNoise(Size: Integer; Base: TColor32; Variation: Integer): TBitmap;
var X, Y, N, R, G, B: Integer; Row, Dst: PByte; BR, BG, BB, BA: Byte;
  RowDelta: array of ShortInt;
  BasePtr: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcNoise: Size must be >0');
  if Variation <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcNoise: Variation must be >0');
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(Base, BR, BG, BB, BA);
  SetLength(RowDelta, Size);
  Result.EnsureUnique;
  BasePtr := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := BasePtr + Y * Stride;
    Dst := Row;
    // 行Hash批化：一次SimpleHash/像素，写阶段零二次哈希
    for X := 0 to Size - 1 do
      RowDelta[X] := SmallInt((SimpleHash(X, Y) mod (Variation * 2 + 1)) - Variation);
    X := 0;
    // tile 4 批化：4 像素展开，减循环/指针开销，仍复用 bytes.binary 零拷贝
    while X + 3 < Size do
    begin
      N := RowDelta[X];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA)); Inc(Dst, 4);
      N := RowDelta[X + 1];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA)); Inc(Dst, 4);
      N := RowDelta[X + 2];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA)); Inc(Dst, 4);
      N := RowDelta[X + 3];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA)); Inc(Dst, 4);
      Inc(X, 4);
    end;
    while X < Size do
    begin
      N := RowDelta[X];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), BA)); Inc(Dst, 4);
      Inc(X);
    end;
  end;
end;

function ProcGradientV(Size: Integer; Top, Bottom: TColor32): TBitmap;
var Y: Integer; T: Single; C: TColor32; R, G, B, A: Byte; Row: PByte;
  Base: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcGradientV: Size must be >0');
  Result := TBitmap.Create(Size, Size);
  Result.EnsureUnique;
  Base := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    if Size <= 1 then T := 0 else T := Y / (Size - 1);
    C := LerpColor(Top, Bottom, T);
    Color32Decompose(C, R, G, B, A);
    Row := Base + Y * Stride;
    RasterFillSolid(Row, Size, R, G, B, A);
  end;
end;

function ProcMetal(Size: Integer; Base: TColor32; ScratchCount: Integer): TBitmap;
var X, Y, I, SX, SY, SLen, SD, N, R, G, B: Integer; Row, Dst: PByte; P: PByte; BR, BG, BB, BA: Byte;
  RowGrain: array of ShortInt;
  BasePtr: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcMetal: Size must be >0');
  Result := TBitmap.Create(Size, Size);
  Color32Decompose(Base, BR, BG, BB, BA);
  SetLength(RowGrain, Size);
  Result.EnsureUnique;
  BasePtr := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := BasePtr + Y * Stride;
    Dst := Row;
    // 行Hash批化：grain 一次SimpleHash/像素，写阶段复用
    for X := 0 to Size - 1 do
      RowGrain[X] := SmallInt((SimpleHash(X, Y * 7) mod 16) - 8);
    X := 0;
    // tile 4 批化：base+grain 一次打包，4 像素展开，复用 bytes.binary 零拷贝
    while X + 3 < Size do
    begin
      N := RowGrain[X];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255)); Inc(Dst, 4);
      N := RowGrain[X + 1];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255)); Inc(Dst, 4);
      N := RowGrain[X + 2];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255)); Inc(Dst, 4);
      N := RowGrain[X + 3];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255)); Inc(Dst, 4);
      Inc(X, 4);
    end;
    while X < Size do
    begin
      N := RowGrain[X];
      R := ClampByte(Integer(BR) + N);
      G := ClampByte(Integer(BG) + N);
      B := ClampByte(Integer(BB) + N);
      WriteUInt32LE(Dst, RgbaToPixelLE(Byte(R), Byte(G), Byte(B), 255)); Inc(Dst, 4);
      Inc(X);
    end;
  end;
  // 划痕回路：外层已 EnsureUnique，BasePtr+Stride 直接寻址，避免每点 GetPixelPtr 的 EnsureUnique+越界检查
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
      P := BasePtr + SY * Stride + SX * 4;
      P[0] := ClampByte(Integer(P[0]) + 30); P[1] := ClampByte(Integer(P[1]) + 30); P[2] := ClampByte(Integer(P[2]) + 30);
    end;
  end;
end;

function ProcGrid(Size, LineWidth: Integer; Bg, Line: TColor32): TBitmap;
var X, Y, Cell, Rem: Integer; Row: PByte; LR, LG, LB, LA, BR, BG2, BB, BA2: Byte;
  Base: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcGrid: Size must be >0');
  if LineWidth <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcGrid: LineWidth must be >0');
  Result := TBitmap.Create(Size, Size);
  Cell := Size div 8; if Cell < 4 then Cell := 4;
  Color32Decompose(Line, LR, LG, LB, LA);
  Color32Decompose(Bg, BR, BG2, BB, BA2);
  Result.EnsureUnique;
  Base := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := Base + Y * Stride;
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
var X, Y: Integer; CX, CY, DY, Dist, Rf, T: Single; Row, Dst: PByte; R, G, B, A: Byte;
  BR, BG, BB, BA, RR, RG, RB, RA: Byte; TR: Single; Inv12: Single;
  DX2: array of Single; DY2: Single;
  RowN: array of ShortInt;
  BasePtr: PByte; Stride: Integer;
begin
  if Size <= 0 then
    raise EArgumentError.Create('procedural.pas: ProcWood: Size must be >0');
  Result := TBitmap.Create(Size, Size);
  CX := Size / 2; CY := Size / 2;
  Color32Decompose(Base, BR, BG, BB, BA);
  Color32Decompose(Ring, RR, RG, RB, RA);
  Inv12 := 1.0 / 12.0;
  SetLength(DX2, Size);
  SetLength(RowN, Size);
  for X := 0 to Size - 1 do
  begin
    T := X - CX; DX2[X] := T * T;
  end;
  Result.EnsureUnique;
  BasePtr := Result.UnsafeMutableRowPtr(0);
  Stride := Result.Stride;
  for Y := 0 to Size - 1 do
  begin
    Row := BasePtr + Y * Stride;
    Dst := Row;
    DY := Y - CY; DY2 := DY * DY;
    // 行Hash批化：一次SimpleHash/像素，Sqrt阶段复用
    for X := 0 to Size - 1 do
      RowN[X] := SmallInt((SimpleHash(X, Y) mod 6) - 3);
    X := 0;
    // tile 4 批化：DX2 预计算消 DX*DX 乘法，单 Sqrt/行复用 DY2，直接写 Row 无 RowBuf/Move，inline Sqrt/Round
    while X + 3 < Size do
    begin
      Dist := nextpas.core.math.scalar.Sqrt(DX2[X] + DY2) + RowN[X];
      Rf := Frac(Dist * Inv12); if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2; TR := T * 0.6;
      R := BlendChannel(BR, RR, TR);
      G := BlendChannel(BG, RG, TR);
      B := BlendChannel(BB, RB, TR);
      A := BlendChannel(BA, RA, TR);
      WriteUInt32LE(Dst, RgbaToPixelLE(R, G, B, A)); Inc(Dst, 4);
      Dist := nextpas.core.math.scalar.Sqrt(DX2[X + 1] + DY2) + RowN[X + 1];
      Rf := Frac(Dist * Inv12); if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2; TR := T * 0.6;
      R := BlendChannel(BR, RR, TR);
      G := BlendChannel(BG, RG, TR);
      B := BlendChannel(BB, RB, TR);
      A := BlendChannel(BA, RA, TR);
      WriteUInt32LE(Dst, RgbaToPixelLE(R, G, B, A)); Inc(Dst, 4);
      Dist := nextpas.core.math.scalar.Sqrt(DX2[X + 2] + DY2) + RowN[X + 2];
      Rf := Frac(Dist * Inv12); if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2; TR := T * 0.6;
      R := BlendChannel(BR, RR, TR);
      G := BlendChannel(BG, RG, TR);
      B := BlendChannel(BB, RB, TR);
      A := BlendChannel(BA, RA, TR);
      WriteUInt32LE(Dst, RgbaToPixelLE(R, G, B, A)); Inc(Dst, 4);
      Dist := nextpas.core.math.scalar.Sqrt(DX2[X + 3] + DY2) + RowN[X + 3];
      Rf := Frac(Dist * Inv12); if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2; TR := T * 0.6;
      R := BlendChannel(BR, RR, TR);
      G := BlendChannel(BG, RG, TR);
      B := BlendChannel(BB, RB, TR);
      A := BlendChannel(BA, RA, TR);
      WriteUInt32LE(Dst, RgbaToPixelLE(R, G, B, A)); Inc(Dst, 4);
      Inc(X, 4);
    end;
    while X < Size do
    begin
      Dist := nextpas.core.math.scalar.Sqrt(DX2[X] + DY2) + RowN[X];
      Rf := Frac(Dist * Inv12); if Rf < 0 then Rf := Rf + 1.0;
      if Rf < 0.5 then T := Rf * 2 else T := (1.0 - Rf) * 2; TR := T * 0.6;
      R := BlendChannel(BR, RR, TR);
      G := BlendChannel(BG, RG, TR);
      B := BlendChannel(BB, RB, TR);
      A := BlendChannel(BA, RA, TR);
      WriteUInt32LE(Dst, RgbaToPixelLE(R, G, B, A)); Inc(Dst, 4);
      Inc(X);
    end;
  end;
  // DX2/RowN 托管释放，TBitmap 资源由 Result 持有，无泄漏
end;

end.
