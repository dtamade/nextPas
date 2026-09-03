program test_webview_base;
{ base 类型根门禁：默认选项快照、CheckWebviewOptions 全规则、
  invoke 命名空间校验、九类错误族的类目定值表与 EWebviewInvokeError
  的 Code 载荷。全部离线可跑；heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.validation, nextpas.core.exception;

procedure TestDefaultsSnapshot;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  CheckEqual(1024, LOptions.Width);
  CheckEqual(768, LOptions.Height);
  CheckEqual(True, LOptions.Resizable);
  CheckEqual(False, LOptions.Maximized);
  CheckEqual(False, LOptions.DebugTools);
  CheckEqual('npres', LOptions.SchemeName);
  CheckEqual(False, LOptions.EphemeralSession);
  CheckEqual('', LOptions.DataDirectory);
  CheckEqual(0, Length(LOptions.InitScripts));
end;

procedure TestOptionsAcceptPath;
begin
  { 合法路径不抛 }
  CheckWebviewOptions(DefaultWebviewOptions);
end;

procedure TestEphemeralDataDirMutuallyExclusive;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  LOptions.EphemeralSession := True;
  LOptions.DataDirectory := '/tmp/profile';
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'expected EWebviewInvalidState');
  except
    on E: EWebviewInvalidState do
      CheckEqual(Ord(ecInternal), Ord(E.Category));
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestNegativeDimensionsRejected;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  LOptions.Width := -1;
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'expected EWebviewInvalidState');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions := DefaultWebviewOptions;
  LOptions.MaxHeight := -5;
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'expected EWebviewInvalidState');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestMaxLessThanMinRejected;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  LOptions.MinWidth := 800;
  LOptions.MaxWidth := 400;
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'expected EWebviewInvalidState');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestSchemeTokenRules;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  LOptions.SchemeName := '';
  CheckWebviewOptions(LOptions);   { 空串允许：后端落 DEFAULT_WEBVIEW_SCHEME }

  LOptions.SchemeName := 'app-res';
  CheckWebviewOptions(LOptions);

  LOptions.SchemeName := 'Npres';
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'uppercase scheme must be rejected');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;

  LOptions.SchemeName := '1abc';
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'digit-leading scheme must be rejected');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestInitScriptNamespaceGuard;
var
  LOptions: TWebviewOptions;
begin
  LOptions := DefaultWebviewOptions;
  SetLength(LOptions.InitScripts, 1);
  LOptions.InitScripts[0] := 'window.__npw.hack = true;';
  try
    CheckWebviewOptions(LOptions);
    Check(False, 'init scripts must not touch __npw');
  except
    on E: EWebviewInvalidState do ;
    on E: Exception do
      Check(False, 'wrong exception: ' + E.ClassName);
  end;
end;

procedure TestInvokeCmdNamespace;
var
  LRaised: Boolean;
begin
  CheckInvokeCmd('fs.readText');
  CheckInvokeCmd('ping');

  LRaised := False;
  try
    CheckInvokeCmd('');
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'empty cmd must be rejected');

  LRaised := False;
  try
    CheckInvokeCmd('npw.handler_missing');
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'npw. prefix must be rejected');

  LRaised := False;
  try
    CheckInvokeCmd('_internal');
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'underscore prefix must be rejected');
end;

{ 经实例读公开 Category 属性（DefaultCategory 是 protected） }
procedure TestErrorCategoryTable;
var
  LErr: ENextPasError;
begin
  LErr := EWebviewBackendUnavailable.Create('probe');
  try CheckEqual(Ord(ecNotFound), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewEvalFailed.Create('probe');
  try CheckEqual(Ord(ecIO), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewBadFrame.Create('probe');
  try CheckEqual(Ord(ecParse), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewError.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewNotInitialized.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewInvalidState.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewClosed.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewTimeout.Create('probe');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;

  LErr := EWebviewInvokeError.Create('probe', '');
  try CheckEqual(Ord(ecInternal), Ord(LErr.Category)); finally LErr.Free; end;
end;

procedure TestInvokeErrorCodePayload;
var
  LErr: EWebviewInvokeError;
begin
  LErr := EWebviewInvokeError.Create('boom', 'app.quota');
  try
    CheckEqual('app.quota', LErr.Code);
    CheckEqual(Ord(ecInternal), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EWebviewInvokeError.CreateFmt('quota %d exceeded', 'app.quota',
    [42]);
  try
    CheckEqual('quota 42 exceeded', LErr.Message);
    CheckEqual('app.quota', LErr.Code);
  finally
    LErr.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.base');
  T.Test('defaults snapshot', @TestDefaultsSnapshot);
  T.Test('options accept path', @TestOptionsAcceptPath);
  T.Test('ephemeral/datadir mutually exclusive',
    @TestEphemeralDataDirMutuallyExclusive);
  T.Test('negative dimensions rejected', @TestNegativeDimensionsRejected);
  T.Test('max less than min rejected', @TestMaxLessThanMinRejected);
  T.Test('scheme token rules', @TestSchemeTokenRules);
  T.Test('init script namespace guard', @TestInitScriptNamespaceGuard);
  T.Test('invoke cmd namespace', @TestInvokeCmdNamespace);
  T.Test('error category table', @TestErrorCategoryTable);
  T.Test('invoke error code payload', @TestInvokeErrorCodePayload);
  if not T.Run then Halt(1);
end.
