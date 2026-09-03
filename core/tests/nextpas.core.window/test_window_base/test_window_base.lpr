program test_window_base;
{ base 类型根门禁：默认选项快照、CheckWindowOptions 全规则、
  六类错误族的类目定值表。全部离线可跑；heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.window.base,
  nextpas.core.window.impl;

procedure TestDefaultsSnapshot;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  CheckEqual('', LOptions.Title);
  CheckEqual(Int64(1024), Int64(LOptions.Size.Width));
  CheckEqual(Int64(768), Int64(LOptions.Size.Height));
  CheckEqual(Int64(0), Int64(LOptions.Constraints.MinWidth));
  CheckEqual(Int64(0), Int64(LOptions.Constraints.MinHeight));
  CheckEqual(Int64(0), Int64(LOptions.Constraints.MaxWidth));
  CheckEqual(Int64(0), Int64(LOptions.Constraints.MaxHeight));
  CheckEqual(True, LOptions.Resizable);
  CheckEqual(False, LOptions.Maximized);
  Check(LOptions.ParentHandle = nil, 'default ParentHandle nil');
  { 强类型封装：Size/Constraints 双记录 inline 零拷贝值语义 }
  Check(LOptions.Size.Width = 1024, 'Size strongly typed');
  Check(LOptions.Constraints.IsEmpty, 'Constraints strongly typed empty');
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
  LOptions.Size.Width := 0;
  LOptions.Size.Height := 0;
  CheckWindowOptions(LOptions);
  Check(LOptions.Size.IsEmpty, 'Size empty after zero');
end;

procedure TestNegativeDimensionsRejected;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.Size.Width := -1;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for Width -1');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.Constraints.MinWidth := -1;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MinWidth -1');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.Constraints.MaxHeight := -5;
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
  LOptions.Constraints.MinWidth := 800;
  LOptions.Constraints.MaxWidth := 400;
  try
    CheckWindowOptions(LOptions);
    Check(False, 'expected EWindowInvalidState for MaxWidth < MinWidth');
  except
    on E: EWindowInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWindowOptions;
  LOptions.Constraints.MinHeight := 600;
  LOptions.Constraints.MaxHeight := 200;
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
  LOptions.Constraints.MinWidth := 800;
  LOptions.Constraints.MaxWidth := 0;
  CheckWindowOptions(LOptions);

  LOptions := DefaultWindowOptions;
  LOptions.Constraints.MinWidth := 0;
  LOptions.Constraints.MaxWidth := 400;
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
  { wkFake 必须收尾（家族惯例），wkWasm 紧邻 fake 之前（attach 族） }
  CheckEqual(Ord(wkFake), Ord(High(TWindowKind)));
  CheckEqual(Ord(wkWasm), Ord(High(TWindowKind)) - 1, 'wasm penultimate');
  Check(Ord(wkGtk) < Ord(wkFake), 'gtk before fake');
  Check(Ord(wkSdl2) < Ord(wkFake), 'sdl2 before fake');
  Check(Ord(wkGtk) < Ord(wkWasm), 'gtk before wasm');
  Check(Ord(wkWasm) < Ord(wkFake), 'wasm before fake');
end;

procedure TestStrongTypes;
var
  LSize: TWindowSize;
  LC: TWindowConstraints;
begin
  LSize := TWindowSize.Create(1024, 768);
  CheckEqual(Int64(1024), Int64(LSize.Width));
  CheckEqual(Int64(768), Int64(LSize.Height));
  Check(not LSize.IsEmpty, 'size not empty');
  LSize := TWindowSize.Default;
  CheckEqual(Int64(1024), Int64(LSize.Width), 'default width');
  LC := TWindowConstraints.Create(0, 0, 800, 600);
  CheckEqual(Int64(800), Int64(LC.MaxWidth));
  Check(not LC.IsEmpty, 'constraints not empty');
  LC := TWindowConstraints.Default;
  Check(LC.IsEmpty, 'default constraints empty');
end;

procedure TestEventRecordZeroFields;
var
  LEvent: TWindowEvent;
begin
  FillChar(LEvent, SizeOf(LEvent), 0);
  LEvent.Kind := weResized;
  LEvent.Width := TWindowPixel(800);
  LEvent.Height := TWindowPixel(600);
  CheckEqual(Int64(800), Int64(LEvent.Width));
  CheckEqual(Int64(600), Int64(LEvent.Height));
  CheckEqual(Int64(0), Int64(LEvent.X));
  CheckEqual(Int64(0), Int64(LEvent.Y));
  CheckEqual(Double(0.0), LEvent.NewScale.Factor);
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
  T.Test('strong types', @TestStrongTypes);
  T.Test('event record zero fields', @TestEventRecordZeroFields);
  if not T.Run then Halt(1);
end.
