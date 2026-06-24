program test_pool_adapter;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing;

var
  T: TTestRunner;

{ TC-004: test_pool_adapter
  This test targets nextpas.core.mem.pool.adapter which depends on
  nextpas.core.mem.layout -- a unit that has been removed from the
  repository (see commit 50c2c4d7f). The adapter file is a leftover
  with a broken dependency and cannot be compiled.

  This test is a placeholder to document the situation. }

procedure TestAdapterCompilationBlocked;
begin
  // Document that the adapter unit has a broken dependency
  WriteLn('SKIP: nextpas.core.mem.pool.adapter depends on removed unit');
  WriteLn('      nextpas.core.mem.layout (removed in commit 50c2c4d7f).');
  WriteLn('      The adapter file needs to be updated or removed.');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.pool.adapter');
  T.Run('adapter compilation blocked by missing layout unit', @TestAdapterCompilationBlocked);
  T.Summary;
end.
