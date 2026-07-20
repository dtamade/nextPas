program test_path_wine;

{ L2 path Windows evidence under Wine (mostly pure string).
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.path
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

procedure TestJoinClean;
begin
  CheckEqual('C:\a\b', PathJoin('C:\a', 'b'), 'Join drive path');
  Check(PathClean('C:\a\.\b\..\c') <> '', 'Clean non-empty');
end;

procedure TestIsAbsVolume;
begin
  Check(PathIsAbsolute('C:\x'), 'C:\x is abs');
  Check(PathIsAbsolute('\\server\share\x') or (not PathIsAbsolute('rel')), 'unc or rel');
  Check(PathVolume('C:\tools') <> '', 'Volume C:');
end;

procedure TestToSlash;
begin
  CheckEqual('a/b/c', PathToSlash('a\b\c'), 'ToSlash');
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('path L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('join clean', @TestJoinClean);
  T.Test('isabs volume', @TestIsAbsVolume);
  T.Test('toslash', @TestToSlash);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
