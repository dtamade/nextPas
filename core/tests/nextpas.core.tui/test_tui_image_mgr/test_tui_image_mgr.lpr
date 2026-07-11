program test_tui_image_mgr;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
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
  LMgr.InvalidateAll; // idempotent
  Check(True, 'InvalidateAll twice should not crash');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAllEmpty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  // No Resolve called, slot count = 0
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

begin
  T := TTestSuite.Create('tui_image_mgr');
  T.Test('TImageManager.Create kitty', @TestImageManagerCreate);
  T.Test('TImageManager.Create sixel', @TestImageManagerCreateSixel);
  T.Test('TImageManager.InvalidateAll', @TestImageManagerInvalidateAll);
  T.Test('TImageManager.Create half-block', @TestImageManagerCreateHalfBlock);
  T.Test('TImageManager.InvalidateAll twice', @TestImageManagerInvalidateAllTwice);
  T.Test('TImageManager.InvalidateAll empty', @TestImageManagerInvalidateAllEmpty);
  T.Test('TImageManager.Create multiple', @TestImageManagerCreateMultiple);
  if not T.Run then Halt(1);
end.
