program test_dependency_graph;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.dependencies;

var
  LDeps: TOpenSSLModuleSet;
  LDep: TOpenSSLModule;
  LPassCount, LFailCount: Integer;

procedure TestCase(const AName: string; AResult: Boolean);
begin
  if AResult then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(LPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(LFailCount);
  end;
end;

begin
  LPassCount := 0;
  LFailCount := 0;

  WriteLn('=== Test Module Dependency Graph ===');
  WriteLn;

  // Test 1: Core module has no dependencies
  WriteLn('Test 1: Core module dependencies');
  LDeps := TOpenSSLLoader.GetModuleDependencies(osmCore);
  TestCase('osmCore has no direct dependencies', LDeps = []);

  // Test 2: RSA depends on Core and BN
  WriteLn('Test 2: RSA module dependencies');
  LDeps := TOpenSSLLoader.GetModuleDependencies(osmRSA);
  TestCase('osmRSA depends on osmCore', osmCore in LDeps);
  TestCase('osmRSA depends on osmBN', osmBN in LDeps);
  TestCase('osmRSA has exactly 2 dependencies', LDeps = [osmCore, osmBN]);

  // Test 3: ECDSA transitive dependencies
  WriteLn('Test 3: ECDSA transitive dependencies');
  LDeps := TOpenSSLLoader.GetAllModuleDependencies(osmECDSA);
  TestCase('osmECDSA all deps includes osmCore', osmCore in LDeps);
  TestCase('osmECDSA all deps includes osmBN', osmBN in LDeps);
  TestCase('osmECDSA all deps includes osmEC', osmEC in LDeps);

  // Test 4: GetModuleName function
  WriteLn('Test 4: GetModuleName function');
  TestCase('GetModuleName(osmRSA) = "RSA"', GetModuleName(osmRSA) = 'RSA');
  TestCase('GetModuleName(osmX509) = "X509"', GetModuleName(osmX509) = 'X509');
  TestCase('GetModuleName(osmCore) = "Core"', GetModuleName(osmCore) = 'Core');

  // Test 5: GetModuleDependencyDescription
  WriteLn('Test 5: GetModuleDependencyDescription');
  WriteLn('  RSA: ', GetModuleDependencyDescription(osmRSA));
  WriteLn('  ECDSA: ', GetModuleDependencyDescription(osmECDSA));
  WriteLn('  X509: ', GetModuleDependencyDescription(osmX509));
  TestCase('Description format check (contains arrow)', Pos(' -> ', GetModuleDependencyDescription(osmRSA)) > 0);

  // Test 6: Dependencies not loaded initially
  WriteLn('Test 6: Dependencies not loaded initially');
  TestCase('RSA dependencies not loaded (no modules loaded)', not TOpenSSLLoader.AreModuleDependenciesLoaded(osmRSA));

  // Test 7: Module loading simulation
  WriteLn('Test 7: Module loading simulation');
  TOpenSSLLoader.SetModuleLoaded(osmCore, True);
  TOpenSSLLoader.SetModuleLoaded(osmBN, True);
  TestCase('After loading Core+BN, RSA deps ready', TOpenSSLLoader.AreModuleDependenciesLoaded(osmRSA));
  TestCase('ECDSA deps still not ready (missing EC)', not TOpenSSLLoader.AreModuleDependenciesLoaded(osmECDSA));

  TOpenSSLLoader.SetModuleLoaded(osmEC, True);
  TestCase('After loading EC, ECDSA deps ready', TOpenSSLLoader.AreModuleDependenciesLoaded(osmECDSA));

  // Test 8: GetUnloadedDependencies
  WriteLn('Test 8: GetUnloadedDependencies');
  TOpenSSLLoader.ResetModuleStates;
  TOpenSSLLoader.SetModuleLoaded(osmCore, True);
  LDeps := GetUnloadedDependencies(osmRSA);
  TestCase('RSA missing BN', osmBN in LDeps);
  TestCase('RSA not missing Core', not (osmCore in LDeps));

  // Summary
  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', LPassCount);
  WriteLn('Failed: ', LFailCount);
  WriteLn('Total:  ', LPassCount + LFailCount);

  if LFailCount > 0 then
    Halt(1);
end.
