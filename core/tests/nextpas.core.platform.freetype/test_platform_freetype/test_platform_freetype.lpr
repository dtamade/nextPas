program test_platform_freetype;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.platform.freetype,
  nextpas.core.platform.freetype.ffi;

var
  T: TTestSuite;

procedure TestLoadUnload;
begin
  // Test that load/unload works without crash
  Check(ft_load = FT_ERR_OK, 'ft_load should succeed');
  Check(ft_is_loaded, 'ft_is_loaded should be true after load');
  ft_unload;
  Check(not ft_is_loaded, 'ft_is_loaded should be false after unload');
end;

procedure TestDoubleLoad;
begin
  // Test ref-counted loading
  Check(ft_load = FT_ERR_OK, 'first ft_load');
  Check(ft_load = FT_ERR_OK, 'second ft_load');
  Check(ft_is_loaded, 'should be loaded');
  ft_unload;
  Check(ft_is_loaded, 'should still be loaded after first unload');
  ft_unload;
  Check(not ft_is_loaded, 'should be unloaded after second unload');
end;

procedure TestDoubleUnload;
begin
  // Test that double unload doesn't crash
  ft_unload;
  ft_unload;
  Check(not ft_is_loaded, 'should not be loaded');
end;

procedure TestLoadWithoutFreetype;
begin
  // This test verifies that ft_load handles missing freetype gracefully
  // On systems without freetype installed, ft_load should return error
  // On systems with freetype, it should succeed
  // We just test that it doesn't crash
  ft_unload; // ensure clean state
  ft_load;   // try to load
  ft_unload; // cleanup
  Check(True, 'load/unload cycle completed without crash');
end;

procedure TestFunctionPointers;
begin
  // Test that function pointers are properly loaded
  Check(ft_load = FT_ERR_OK, 'ft_load');
  Check(@FT_Init_FreeType <> nil, 'FT_Init_FreeType should be loaded');
  Check(@FT_Done_FreeType <> nil, 'FT_Done_FreeType should be loaded');
  ft_unload;
end;

procedure TestLoadUnloadStress;
var
  I: Int32;
begin
  // Test multiple load/unload cycles
  for I := 1 to 10 do
  begin
    Check(ft_load = FT_ERR_OK, 'ft_load cycle ' + IntToStr(I));
    Check(ft_is_loaded, 'should be loaded in cycle ' + IntToStr(I));
    ft_unload;
    Check(not ft_is_loaded, 'should be unloaded in cycle ' + IntToStr(I));
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.freetype');
  T.Test('load/unload', @TestLoadUnload);
  T.Test('double load', @TestDoubleLoad);
  T.Test('double unload', @TestDoubleUnload);
  T.Test('load without freetype', @TestLoadWithoutFreetype);
  T.Test('function pointers', @TestFunctionPointers);
  T.Test('load/unload stress', @TestLoadUnloadStress);
  if not T.Run then Halt(1);
end.
