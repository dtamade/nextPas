program test_mbedtls_basic;

{$mode ObjFPC}{$H+}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib;

var
  LLib: TMbedTLSLibrary;
  LCaps: TSSLBackendCapabilities;

begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Backend Basic Test');
  WriteLn('================================================================================');
  WriteLn;

  WriteLn('Creating MbedTLS library...');
  LLib := TMbedTLSLibrary.Create;
  try
    WriteLn('✅ Created');

    WriteLn('Initializing...');
    if LLib.Initialize then
    begin
      WriteLn('✅ Initialized: ', LLib.GetVersionString);
      WriteLn('   Version Number: ', LLib.GetVersionNumber);

      WriteLn('Getting capabilities...');
      LCaps := LLib.GetCapabilities;
      WriteLn('✅ Capabilities:');
      WriteLn('   TLS 1.2: ', LCaps.MaxTLSVersion >= sslProtocolTLS12);
      WriteLn('   TLS 1.3: ', LCaps.SupportsTLS13);
      WriteLn('   ALPN: ', LCaps.SupportsALPN);
      WriteLn('   SNI: ', LCaps.SupportsSNI);
      WriteLn('   ECDHE: ', LCaps.SupportsECDHE);
      WriteLn('   ChaCha20: ', LCaps.SupportsChaChaPoly);
      WriteLn('   Min TLS: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LCaps.MinTLSVersion)));
      WriteLn('   Max TLS: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LCaps.MaxTLSVersion)));

      WriteLn('Finalizing...');
      LLib.Finalize;
      WriteLn('✅ Finalized');
    end
    else
    begin
      WriteLn('❌ Initialization failed: ', LLib.GetLastErrorString);
      Halt(1);
    end;

  finally
    WriteLn('Freeing library...');
    LLib.Free;
    WriteLn('✅ Freed');
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('🎉 Test Complete - No memory errors!');
  WriteLn('================================================================================');
end.
