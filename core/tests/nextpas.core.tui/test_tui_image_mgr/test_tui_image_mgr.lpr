program test_tui_image_mgr;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.image_mgr,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestImageManagerCreate;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  Check(LMgr <> nil, 'Should create image manager');
  LMgr.Free;
end;

procedure TestImageManagerCreateSixel;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  Check(LMgr <> nil, 'Should create sixel image manager');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAll;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll should not crash');
  LMgr.Free;
end;

procedure TestImageManagerCreateHalfBlock;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipHalfBlock);
  Check(LMgr <> nil, 'Should create half-block image manager');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAllTwice;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  LMgr.InvalidateAll;
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll twice should not crash');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAllEmpty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll on empty manager should not crash');
  LMgr.Free;
end;

procedure TestImageManagerCreateMultiple;
var
  LMgr1, LMgr2: TImageManager;
begin
  LMgr1 := TImageManager.Create(ipKitty);
  LMgr2 := TImageManager.Create(ipSixel);
  Check(LMgr1 <> nil, 'First manager created');
  Check(LMgr2 <> nil, 'Second manager created');
  LMgr1.Free;
  LMgr2.Free;
end;

procedure TestImageManagerCreateAuto;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipAuto);
  try
    Check(LMgr <> nil, 'auto protocol manager');
  finally
    LMgr.Free;
  end;
end;

procedure TestImageManagerInvalidateAllAllProtocols;
var
  P: TImageProtocol;
  LMgr: TImageManager;
begin
  for P := Low(TImageProtocol) to High(TImageProtocol) do
  begin
    LMgr := TImageManager.Create(P);
    try
      LMgr.InvalidateAll;
      Check(True, 'invalidate protocol');
    finally
      LMgr.Free;
    end;
  end;
end;

procedure TestImageManagerCreateFreeCycle;
var
  I: Integer;
  LMgr: TImageManager;
begin
  for I := 1 to 5 do
  begin
    LMgr := TImageManager.Create(ipKitty);
    LMgr.Free;
  end;
  Check(True, 'create/free cycle');
end;

procedure TestImageManagerSixelInvalidateEmpty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  try
    LMgr.InvalidateAll;
    LMgr.InvalidateAll;
    Check(True, 'sixel empty invalidate');
  finally
    LMgr.Free;
  end;
end;

procedure TestImageManagerHalfBlockThenKitty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipHalfBlock);
  LMgr.Free;
  LMgr := TImageManager.Create(ipKitty);
  try
    Check(LMgr <> nil, 'recreate kitty after halfblock');
  finally
    LMgr.Free;
  end;
end;

{ 回归：区域被布局撑大（封面区吸收残差、高 DPI）时，重传必须"仅缩小"，
  不得放大——传输字节有上界（原图 base64 ≈480KB），否则 resize 归位
  重传会膨胀到 1MB+，拖拽放大窗口后封面归位明显变慢。 }
procedure TestResolveLargeAreaTransmitBounded;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Pixels: array[0..300*300*4-1] of Byte;
  EmptyDiffs: TDiffEntries;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Pixels, SizeOf(Pixels), 128);
    SetLength(EmptyDiffs, 0);
    { 300x300 封面、CellW=8 CellH=20；区域高 44 行 → Target 224x880（高远超原图） }
    LBuf.PlaceImage($1234, TRect.Make(1, 5, 28, 44), @Pixels[0],
      300*300*4, 300, 300);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0);
    Check(LBackend.PendingLength <= 500000,
      '大区域重传应 ≤ 原图量级（约480KB），不得放大传输');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

begin
  T := TTestSuite.Create('tui_image_mgr');
  T.Test('TImageManager.Create kitty', @TestImageManagerCreate);
  T.Test('TImageManager.Create sixel', @TestImageManagerCreateSixel);
  T.Test('TImageManager.InvalidateAll', @TestImageManagerInvalidateAll);
  T.Test('TImageManager.Create half-block', @TestImageManagerCreateHalfBlock);
  T.Test('TImageManager.InvalidateAll twice', @TestImageManagerInvalidateAllTwice);
  T.Test('TImageManager.InvalidateAll empty', @TestImageManagerInvalidateAllEmpty);
  T.Test('TImageManager.Create multiple', @TestImageManagerCreateMultiple);
  T.Test('Create auto', @TestImageManagerCreateAuto);
  T.Test('InvalidateAll all protocols', @TestImageManagerInvalidateAllAllProtocols);
  T.Test('Create free cycle', @TestImageManagerCreateFreeCycle);
  T.Test('Sixel invalidate empty', @TestImageManagerSixelInvalidateEmpty);
  T.Test('HalfBlock then Kitty', @TestImageManagerHalfBlockThenKitty);
  T.Test('Resolve large-area transmit bounded', @TestResolveLargeAreaTransmitBounded);
  if not T.Run then Halt(1);
end.
