program test_platform_files_android_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

var
  D: TPlatformDirHandle;
  E: TPlatformDirEntry;
  H: TPlatformFileHandle;
  S: TPlatformFileStat;
  R: Int32;

begin
  FillChar(D, SizeOf(D), 0);
  FillChar(E, SizeOf(E), 0);
  FillChar(H, SizeOf(H), 0);
  H.Value := -1;
  FillChar(S, SizeOf(S), 0);
  R := platform_file_stat(nil, S);
  R := R xor platform_file_lstat(nil, S);
  R := R xor platform_file_fstat(H, S);
  R := R xor platform_dir_open(nil, D);
  R := R xor platform_dir_read(D, E);
  R := R xor platform_dir_close(D);
  if R = High(Int32) then
    Halt(1);
end.
