program test_window_base;
{ base 类型根门禁：默认选项快照、CheckWindowOptions 全规则、
  六类错误族的类目定值表。全部离线可跑；heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.window.base;

procedure TestDefaultsSnapshot;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  CheckEqual('', LOptions.Title);
  CheckEqual(Int64(1024), Int64(LOptions.Width));
  CheckEqual(Int64(768), Int64(LOptions.Height));
  CheckEqual(Int64(0), Int64(LOptions.MinWidth));
  CheckEqual(Int64(0), Int64(LOptions.MinHeight));
  CheckEqual(Int64(0), Int64(LOptions.MaxWidth));
  CheckEqual(Int64(0), Int64(LOptions.MaxHeight));
  CheckEqual(True, LOptions.Resizable);
  CheckEqual(False, LOptions.Maximized);
  Check(LOptions.ParentHandle = nil, 'default ParentHandle nil');
end;

procedure TestOptionsAcceptPath;
begin
  CheckWindowOptions(DefaultWindowOptions);
  { 0 表示不设限制，应通过 }
  CheckWindowOptions(DefaultWindowOptions);
end;

procedure TestWidthHeightZeroMeansDefault;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.Width := 0;
  LOptions.Height := 0;
  CheckWindowOptions(LOptions);
end;

procedure TestNegativeDimensionsRejected;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.Width := -1;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for Width -1');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.MinWidth := -1;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MinWidth -1');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.MaxHeight := -5;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MaxHeight -5');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestMaxLessThanMinRejected;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.MinWidth := 800;
  LOptions.MaxWidth := 400;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MaxWidth < MinWidth');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.MinHeight := 600;
  LOptions.MaxHeight := 200;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MaxHeight < MinHeight');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  { 仅一侧为 0 时不校验 }
  LOptions := DefaultWindowOptions;
  LOptions.MinWidth := 800;
  LOptions.MaxWidth := 0;
  CheckWindowOptions(LOptions);

  LOptions := DefaultWindowOptions;
  LOptions.MinWidth := 0;
  LOptions.MaxWidth := 400;
  CheckWindowOptions(LOptions);
end;

procedure TestErrorCategoryTable;
var
  LErr: ENextPasError;
begin
  LErr := EWindowError.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWindowBackendUnavailable.Create('probe');
  try CheckEqual(Ord(ecNotFound), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWindowNotInitialized.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWindowInvalidState.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWindowClosed.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWindowUnsupported.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;
end;

procedure TestWindowKindOrder;
begin
  { wkFake 必须收尾（家族惯例） }
  CheckEqual(Ord(wkFake), Ord(High(TWindowKind)));
  Check(Ord(wkGtk) < Ord(wkFake), 'gtk before fake');
  Check(Ord(wkSdl2) < Ord(wkFake), 'sdl2 before fake');
end;

procedure TestEventRecordZeroFields;
var
  LEvent: TWindowEvent;
begin
  FillChar(LEvent, SizeOf(LEvent), 0);
  LEvent.Kind := weResized;
  LEvent.Width := 800;
  LEvent.Height := 600;
  CheckEqual(Int64(800), Int64(LEvent.Width));
  CheckEqual(Int64(600), Int64(LEvent.Height));
  CheckEqual(Int64(0), Int64(LEvent.X));
  CheckEqual(Int64(0), Int64(LEvent.Y));
  CheckEqual(Double(0.0), LEvent.NewScale);
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.base');
  T.Test('defaults snapshot', @TestDefaultsSnapshot);
  T.Test('options accept path', @TestOptionsAcceptPath);
  T.Test('width height zero means default', @TestWidthHeightZeroMeansDefault);
  T.Test('negative dimensions rejected', @TestNegativeDimensionsRejected);
  T.Test('max less than min rejected', @TestMaxLessThanMinRejected);
  T.Test('error category table', @TestErrorCategoryTable);
  T.Test('window kind order', @TestWindowKindOrder);
  T.Test('event record zero fields', @TestEventRecordZeroFields);
  if not T.Run then Halt(1);
end.
