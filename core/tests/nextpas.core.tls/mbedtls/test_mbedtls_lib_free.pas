program test_mbedtls_lib_free;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.mbedtls.lib;

var
  LLib: TMbedTLSLibrary;

begin
  WriteLn('Test: Library Initialize → Finalize → Free');

  LLib := TMbedTLSLibrary.Create;
  WriteLn('  Created');

  LLib.Initialize;
  WriteLn('  Initialized');

  LLib.Finalize;
  WriteLn('  Finalized');

  WriteLn('  About to Free...');
  LLib.Free;
  WriteLn('  ✅ Freed successfully!');

  WriteLn;
  WriteLn('🎉 Test passed!');
end.
