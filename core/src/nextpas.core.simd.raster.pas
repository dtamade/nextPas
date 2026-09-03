{**
 * nextpas.core.simd.raster - 跨平台内联光栅抽象（FillSolid / BlendSrcOver）
 * 目标：不走 dispatch 分发表，编译期直联最优后端（SSE2/标量），可内联，零 dispatch。
 * 供 graphics.canvas.raster 等消费；缺口反哺本模块。批量亲和：FillTrapezoids 64-chunk
 * 复用（gradient CHUNK_SIZE=64 栈数组复用，RasterCopy/BlendVaried 单源 inline 零拷贝），
 * 复用 bytes.ops Move 单源语义（L0 层内 Move 对齐 BytesCopy，不引入 L1 依赖）。
 *
 * Tile 16 架构说明：TILE=16 匹配 64B cache line (16*4B=64)，SSE2 每迭代 4px/16B →
 * 每 tile 行 4 次迭代，批量 8px(32B) 对大跨进一步减半分支，inline 阈值 <4 走标量避免 SSE 启动开销。
 * 微优化：1)分支预测 early-exit 前置，2)指针 batch Inc(4/32)，3)批量 4/8 减循环开销 — 见 .inc 实现。
 *}
unit nextpas.core.simd.raster;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

// 用均匀颜色填充连续像素（非预乘写入，PByte 指向 RGBA 四字节像素序列）
// Dst 指向首像素，PixelCount 为像素个数，R/G/B/A 为均匀源色（TColor32 已拆）
procedure RasterFillSolid(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;

// 均匀颜色 src-over 混合到 Dst（Dst 读改写），非预乘路径：
//   dst.rgb = (src.rgb * A + dst.rgb * (255-A)) div 255
//   dst.a   = A + dst.a * (255-A) div 255
procedure RasterBlendSrcOver(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;

// 批式原地 Hue 置换（R,G,B -> G,B,R），行级批量，与 procedural 批化一致
procedure RasterRotateRGB(Dst: PByte; PixelCount: Integer); inline;

// 批式原地 LUT（256*3 字节，通道独立映射），行级批量
procedure RasterApplyLut(Dst: PByte; PixelCount: Integer; Lut: PByte); inline;

// 变长源批量拷贝（梯度 LUT Chunk 等逐块定长拷贝，复用 bytes.ops Move 单源 零拷贝，inline，64-chunk 复用）
procedure RasterCopySpan(Dst: PByte; Src: PLongWord; PixelCount: Integer); inline;

// 变长源 src-over 混合（每像素独立颜色，梯度/纹理逐块混合，封装手写 blend 细节，单源 inline 零 dispatch）
procedure RasterBlendVaried(Dst: PByte; Src: PLongWord; PixelCount: Integer); inline;

// 批量预乘/反预乘（RGBA，A 驱动 RGB 缩放，行级批量，供 image.base Premultiply 复用）
procedure RasterPremultiply(Dst: PByte; PixelCount: Integer); inline;
procedure RasterUnpremultiply(Dst: PByte; PixelCount: Integer); inline;

// BoxBlur 垂直归一化批量（复用 simd.raster AVX2 批处理，消除 graph 侧 64b 标量热点）
// 将 VSum(R/G/B/A) 按 (CntH*VC) 归一写回 DstRow，语义等价于 VSum div (CntH*VC) 的 fixed-point 近似 + 校正
procedure RasterBlurNormalizeRow(DstRow: PByte; VSumR, VSumG, VSumB, VSumA: PInteger; CntH: PInteger; CntInv: PCardinal; VC: Integer; VCInv: Cardinal; Width: Integer); inline;

implementation

uses
  nextpas.core.simd.cpuinfo;

{$IFDEF CPUX86_64}
  {$I nextpas.core.simd.raster.x86_64.inc}
{$ELSE}
  {$I nextpas.core.simd.raster.scalar.inc}
{$ENDIF}

end.
