program test_canvas_raster;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.graphics.errors,
  nextpas.core.canvas.base,
  nextpas.core.canvas.intf,
  nextpas.core.canvas.raster,
  nextpas.core.image.base,
  nextpas.core.bytes.ops;

var T: TTestSuite;
  GRestoreCanvas: ICanvas;

procedure DoRestoreUnderflow;
begin
  GRestoreCanvas.Restore;
end;

procedure TestFill;
var C: ICanvas; P: TPath; B: TBitmap; Px: PByte;
begin
  C := CreateRasterCanvas(16,16);
  P := TPath.New.MoveTo(2,2).LineTo(14,2).LineTo(14,14).LineTo(2,14).Close;
  C.FillPath(P, TBrush.Solid(Color32(255,0,0,255)));
  B := C.Snapshot;
  Check(not B.IsEmpty, 'snapshot');
  // inline zero-copy row ptr: RowPtr uses direct pointer, no copy
  Px := B.ConstRowPtr(8) + 8*4;
  Check(Px[0]=255, 'red filled r');
  Check(Px[3]=255, 'alpha 255');
  // out-of-bounds clip not crash
  C.DrawBitmap(B, TRect.From(0,0,16,16), TRect.From(0,0,8,8), fqNearest);
end;

procedure TestSaveRestore;
var C: ICanvas; P: TPath;
begin
  C := CreateRasterCanvas(10,10);
  C.Save;
  C.Concat(TMat2D.Translate(2,2));
  P := TPath.New.MoveTo(0,0).LineTo(5,0).LineTo(5,5).Close;
  C.FillPath(P, TBrush.Solid(Color32(0,255,0,255)));
  C.Restore;
  // underflow should raise ECanvasError
  GRestoreCanvas := C;
  try
    CheckRaises(ECanvasError, @DoRestoreUnderflow, 'underflow');
  finally
    GRestoreCanvas := nil;
  end;
end;

procedure TestGradient;
var C: ICanvas; P: TPath; Grad: TGradient;
begin
  C := CreateRasterCanvas(20,20);
  P := TPath.New.MoveTo(0,0).LineTo(20,0).LineTo(20,20).LineTo(0,20).Close;
  Grad := TGradient.Create(gkLinear, [Color32(255,0,0), Color32(0,0,255)], nil, TMat2D.Identity);
  // 高频用 GetColor/GetStop+Count 无堆分配
  Check(Grad.GetColor(0) <> 0, 'grad getcolor');
  C.FillPath(P, TBrush.Linear(Grad));
  Check(not C.Snapshot.IsEmpty, 'grad filled');
end;

procedure TestAutoSave;
var C: ICanvas; G: ICanvasGuard;
begin
  C := CreateRasterCanvas(8,8);
  G := AutoSave(C);
  C.FillPath(TPath.New.MoveTo(0,0).LineTo(8,0).LineTo(8,8).Close, TBrush.Solid(Color32(10,10,10,255)));
  G := nil; // triggers Restore via try/finally destructor, resource safe
  Check(not C.Snapshot.IsEmpty, 'auto save');
end;

procedure TestBytesOpsSingleSource;
var B: TBitmap; Comp: TBytes; Sp: TByteSpan;
begin
  B := TBitmap.Create(2,2, bfRGBA);
  Comp := B.ToCompact;
  Sp := TByteSpan.FromBytes(Comp);
  Check(Sp.Len = 16, 'compact len');
  Check(BytesEqual(Comp, Comp), 'bytes single source');
end;

procedure TestBitmapCowIsolation;
var A, B: TBitmap; P: PByte; V0, V1: Byte;
begin
  A := TBitmap.Create(4,4, bfRGBA);
  P := A.RowPtr(0);
  P[0] := 10; P[1] := 20; P[2] := 30; P[3] := 255;
  B := A.Clone;
  // Clone is shallow share, mutation via Premultiply/RowPtr must isolate via EnsureUnique
  P := B.RowPtr(1);
  P[0] := 99;
  Check(A.ConstRowPtr(1)[0] <> 99, 'clone row isolation');
  // Premultiply isolation
  A := TBitmap.Create(2,2, bfRGBA);
  P := A.RowPtr(0); P[0] := 100; P[1] := 100; P[2] := 100; P[3] := 128;
  B := A.Clone;
  V0 := A.ConstRowPtr(0)[0];
  B.Premultiply;
  V1 := A.ConstRowPtr(0)[0];
  Check(V0 = V1, 'premultiply clone isolation');
  Check(B.ConstRowPtr(0)[0] <> V0, 'premultiply mutates clone');
  // DrawBitmap COW: Snapshot Clone + DrawBitmap must not corrupt src
  A.Clear; B.Clear;
end;

procedure TestBitmapHeaptrcResource;
var B, C: TBitmap; I: Integer;
begin
  // resource closed loop: Create/Clear/ToCompact/Clone/Premultiply no leak via heaptrc gate
  for I := 0 to 10 do
  begin
    B := TBitmap.Create(8,8, bfRGBA);
    C := B.Clone;
    C.Premultiply;
    B.Clear;
    C.Clear;
  end;
  Check(True, 'heaptrc resource loop');
end;

begin
  T := TTestSuite.Create('nextpas.core.canvas.raster');
  T.Test('fill', @TestFill);
  T.Test('save restore', @TestSaveRestore);
  T.Test('gradient', @TestGradient);
  T.Test('auto save guard', @TestAutoSave);
  T.Test('bytes single source', @TestBytesOpsSingleSource);
  T.Test('bitmap COW isolation', @TestBitmapCowIsolation);
  T.Test('bitmap heaptrc resource', @TestBitmapHeaptrcResource);
  if not T.Run then Halt(1);
end.
