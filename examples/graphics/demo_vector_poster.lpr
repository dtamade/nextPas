program demo_vector_poster;
{$mode objfpc}{$H+}
{ demo_vector_poster — S3 能力海报：矢量+文本+滤镜 同源演示
 *
 * 要点：
 *  - TPath 不可变链 + COW：MoveTo/LineTo/QuadTo 值类型，每步 Copy 后新值，原路径不动，多处复用无污染。
 *  - 渐变/圆角高级感：TGradient.Linear + TBrush.Linear，QuadTo 圆角卡片，层次胜于 7 行棋盘+单色。
 *  - TBitmap Stride 64B 对齐：Create 按 AlignUp64(Width*4) 分配；位图→紧凑用 B.ToCompact/RowPtr 封装，不手写 @Pixels 悬垂。
 *  - COW：Snapshot/Clone 内部 SetLength 独占，G.Bake 输入输出隔离；EffectGraph.Bake tile64 并行。
 *}
uses nextpas.core.base, nextpas.core.graphics.base, nextpas.core.graphics.path, nextpas.core.canvas, nextpas.core.canvas.intf, nextpas.core.graphics.text, nextpas.core.graphics.effect.graph, nextpas.core.image, nextpas.core.image.base, nextpas.core.platform.files.bin, nextpas.core.fs;
var
  C: ICanvas; P, Card: TPath; B: TBitmap; Compact, FileBytes: TBytes;
  LayoutTitle, LayoutSub: TTextLayout; G: TEffectGraph;
  BgGrad, CardGrad: TGradient; OutPath, TmpPath: AnsiString;
  BgColors, CardColors: TColor32Array; BgStops, CardStops: TSingleArray;
begin
  C := CreateRasterCanvas(512, 256);
  // 渐变背景 — 线性渐变替代 7 行棋盘，展示 TGradient 封装高级感
  SetLength(BgColors, 2); BgColors[0] := Color32(248,250,255); BgColors[1] := Color32(224,231,255);
  SetLength(BgStops, 2); BgStops[0] := 0; BgStops[1] := 1;
  BgGrad := TGradient.Linear(BgColors, BgStops);
  P := TPath.New.MoveTo(0,0).LineTo(512,0).LineTo(512,256).LineTo(0,256).Close;
  C.FillPath(P, TBrush.Linear(BgGrad));
  // 顶部细线装饰增加层次（非棋盘硬分块）
  P := TPath.New.MoveTo(0,0).LineTo(512,0).LineTo(512,2).LineTo(0,2).Close;
  C.FillPath(P, TBrush.Solid(Color32(255,255,255)));
  // 圆角卡片 — QuadTo 四角 R16，COW 链式不污染原路径
  Card := TPath.New.MoveTo(56,40).LineTo(456,40).QuadTo(472,40,472,56).LineTo(472,164).QuadTo(472,180,456,180).LineTo(56,180).QuadTo(40,180,40,164).LineTo(40,56).QuadTo(40,40,56,40).Close;
  SetLength(CardColors, 2); CardColors[0] := Color32(99,102,241); CardColors[1] := Color32(139,92,246);
  SetLength(CardStops, 2); CardStops[0] := 0; CardStops[1] := 1;
  CardGrad := TGradient.Linear(CardColors, CardStops);
  C.FillPath(Card, TBrush.Linear(CardGrad));
  C.StrokePath(Card, TBrush.Solid(Color32(17,24,39)), TStrokeOptions.Create(3));
  // 文本双层级：主标题 + 副标题，GlyphRun 位置 Scale 打通
  LayoutTitle := LayoutText('nextPas graphics', 22, 1.0);
  C.DrawGlyphRun(LayoutTitle.GlyphRun, TVec2.Create(64, 98));
  LayoutSub := LayoutText('L1 Base  L2 Vector/Canvas/Effect  Stride 64B  COW', 11, 1.0);
  C.DrawGlyphRun(LayoutSub.GlyphRun, TVec2.Create(64, 128));
  B := C.Snapshot;
  // 滤镜：轻模糊，Bake 为 COW（输入不动，输出新图，tile64 并行）
  G := Default(TEffectGraph);
  G.AddBlur(1); B := G.Bake(B);
  // 封装优雅：Stride 对齐 → 紧凑用 ToCompact（内部 RowPtr 去 pad），不手写 SetLength+Move+@Pixels
  Compact := B.ToCompact;
  FileBytes := PngEncodeRgba(Compact, B.Width, B.Height);
  OutPath := 'demo_poster.png';
  FileWriteAllBytes(OutPath, FileBytes);
  TmpPath := GetTempDir + '/demo_poster.png';
  FileWriteAllBytes(TmpPath, FileBytes);
  WriteLn('demo_vector_poster -> ', OutPath, ' (+', TmpPath, ') ', Length(FileBytes), ' bytes (ToCompact + gradient/rounded)');
end.
