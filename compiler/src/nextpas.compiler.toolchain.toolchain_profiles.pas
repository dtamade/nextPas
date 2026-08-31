unit nextpas.compiler.toolchain.toolchain_profiles;

{$mode objfpc}{$H+}

interface

uses
  np_toolchain_profiles;

type
  THostCompilerProfile = np_toolchain_profiles.THostCompilerProfile;
  TAssemblerProfile = np_toolchain_profiles.TAssemblerProfile;
  TLinkerProfile = np_toolchain_profiles.TLinkerProfile;
  TArchiverProfile = np_toolchain_profiles.TArchiverProfile;
  TResourceToolProfile = np_toolchain_profiles.TResourceToolProfile;
  TLlvmExecutableSet = np_toolchain_profiles.TLlvmExecutableSet;

implementation

end.
