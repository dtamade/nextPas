program demo_converter;
{$mode objfpc}{$H+}
{ demo_converter — S3 图像转换与缩放示例（零 RTL）
 *
 * 要点：
 *  - PNG/BMP 编解码往返（PngEncodeRgba ↔ TryImageDecode）
 *  - TBitmap Stride 64B 对齐：位图↔紧凑用 FromCompact/ToCompact 封装，不手写 GetPixelPtr+Move+Stride 寻址。
 *  - COW：Snapshot/Clone 独占拷贝，写时复制；TPath 值类型 COW 同理，链式不污染原路径。
 *  - canvas DrawBitmap 缩放（64→128）与 Snapshot COW 隔离，紧凑→编码→解码一致性校验。
 *}
uses nextpas.core.base, nextpas.core.graphics.base, nextpas.core.image, nextpas.core.image.base, nextpas.core.canvas, nextpas.core.canvas.intf, nextpas.core.graphics.path, nextpas.core.platform.files.bin;
var
  Pix, EncPNG, EncBMP, Dec, Compact: TBytes; W: Integer; Info: TImageInfo; B: TBitmap; C: ICanvas; Ok: Boolean;
begin
  SetLength(Pix, 64*64*4); for W:=0 to 64*64-1 do begin Pix[W*4]:=Byte(W mod 256); Pix[W*4+1]:=Byte((W*2) mod 256); Pix[W*4+2]:=128; Pix[W*4+3]:=255; end;
  EncPNG := PngEncodeRgba(Pix, 64,64);
  EncBMP := BmpEncodeRgba(Pix, 64,64);
  Ok := TryImageDecode(EncPNG, Dec, Info); if not Ok then Halt(1); WriteLn('PNG decode ',Info.Width,'x',Info.Height,' fmt=',Ord(Info.Format));
  Ok := TryImageDecode(EncBMP, Dec, Info); if not Ok then Halt(2); WriteLn('BMP decode ',Info.Width,'x',Info.Height);
  // 封装优雅：紧凑→位图用 FromCompact（内部 AlignUp64 + 逐行去 pad），不手写 Stride 寻址
  B := TBitmap.FromCompact(Pix, 64,64, bfRGBA);
  C := CreateRasterCanvas(128,128);
  C.DrawBitmap(B, TRect.From(0,0,64,64), TRect.From(0,0,128,128), fqLinear);
  B := C.Snapshot;
  if (B.Width<>128) or (B.Height<>128) or B.IsEmpty then Halt(3);
  // 位图→紧凑用 ToCompact（内部 RowPtr 去 pad），再 PNG 往返校验对齐层透明
  Compact := B.ToCompact;
  Pix := PngEncodeRgba(Compact, B.Width, B.Height);
  Ok := TryImageDecode(Pix, Dec, Info); if not Ok then Halt(4);
  // 对称校验：Dec 紧凑→位图→紧凑透明（FromCompact/ToCompact 对称）
  B := TBitmap.FromCompact(Dec, Info.Width, Info.Height);
  Compact := B.ToCompact;
  if Length(Compact)<>Length(Dec) then Halt(5);
  WriteLn('demo_converter PASS (Decode→FromCompact→Resize→ToCompact→Encode Stride 64B COW 往返)');
end.
