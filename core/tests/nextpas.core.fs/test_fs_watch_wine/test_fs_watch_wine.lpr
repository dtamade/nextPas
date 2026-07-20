program test_fs_watch_wine;

{ L2 fs.watch Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime.
  platform.watch may return UNSUPPORTED under Wine; that is documented. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.watch,
  nextpas.core.path
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

procedure TestWatchCreateOrUnsupported;
var
  W: IFsWatcher;
  Raised: Boolean;
  Msg: string;
begin
  Raised := False;
  Msg := '';
  try
    W := Watch;
    Check(W <> nil, 'Watch non-nil when supported');
    W.Close;
  except
    on E: Exception do
    begin
      Raised := True;
      Msg := E.Message;
    end;
  end;
  Check((not Raised) or (Pos('95', Msg) > 0) or (Pos('not supported', Msg) > 0) or
    (Pos('UNSUPPORTED', Msg) > 0) or (Pos('unsupported', Msg) > 0),
    'Watch works or documents UNSUPPORTED: ' + Msg);
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('fs.watch L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('create or unsupported', @TestWatchCreateOrUnsupported);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
