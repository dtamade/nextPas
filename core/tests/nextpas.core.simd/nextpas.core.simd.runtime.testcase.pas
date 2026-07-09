unit nextpas.core.simd.runtime.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  Classes, nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd,
  nextpas.core.simd.testcase, nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo, nextpas.core.simd.dispatch,
  nextpas.core.simd.runtime;

type
  TTestCase_RuntimeAPI = class(TSimdBackendStatefulTestCase)
  private
    class procedure AssertBackendArrayEquals(const aMessage: string;
      const aExpected, aActual: TSimdBackendArray); static;
  published
    procedure Test_RuntimeCurrentBackend_View_Matches_LegacyFacade;
    procedure Test_RuntimeDispatchableView_Matches_LegacyFacadeAliases;
    procedure Test_RuntimeControlPlane_SwitchAndReset_Match_LegacyFacade;
    procedure Test_FacadeCpuCapability_View_Uses_Canonical_Cpuinfo_Semantics;
    procedure Test_RuntimeSnapshot_Canonical_Name_Aliases_Legacy_Subunit_Name;
    procedure Test_FacadeRuntimeSnapshot_View_Matches_Runtime_Subunit;
    procedure Test_FacadeRuntimeControlPlane_Wrappers_Interoperate_With_Legacy_Aliases;
    procedure Test_RuntimeSnapshot_View_Matches_Runtime_And_Legacy_Helpers;
    procedure Test_RuntimeSnapshot_Switch_Tracks_ControlPlane_And_Dispatch;
  end;

implementation

class procedure TTestCase_RuntimeAPI.AssertBackendArrayEquals(const aMessage: string;
  const aExpected, aActual: TSimdBackendArray);
var
  LIndex: Integer;
begin
  CheckEqual(Length(aExpected), Length(aActual), aMessage + ' length');
  for LIndex := 0 to High(aExpected) do
    CheckEqual(Ord(aExpected[LIndex]), Ord(aActual[LIndex]), aMessage + ' item[' + IntToStr(LIndex) + ']');
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeCurrentBackend_View_Matches_LegacyFacade;
var
  LDispatch: PSimdDispatchTable;
  LLegacyInfo: TSimdBackendInfo;
  LRuntimeInfo: TSimdBackendInfo;
begin
  LDispatch := GetDispatchTable;
  CheckTrue(LDispatch <> nil, 'GetDispatchTable should be assigned');

  CheckEqual(Ord(nextpas.core.simd.GetCurrentBackend), Ord(nextpas.core.simd.runtime.GetCurrentBackend), 'runtime current backend should match legacy facade helper');
  CheckEqual(Ord(LDispatch^.Backend), Ord(nextpas.core.simd.runtime.GetCurrentBackend), 'runtime current backend should match dispatch snapshot backend');

  LLegacyInfo := nextpas.core.simd.GetCurrentBackendInfo;
  LRuntimeInfo := nextpas.core.simd.runtime.GetCurrentBackendInfo;

  CheckEqual(Ord(LLegacyInfo.Backend), Ord(LRuntimeInfo.Backend), 'runtime backend info backend should match legacy helper');
  CheckEqual(LLegacyInfo.Name, LRuntimeInfo.Name, 'runtime backend info name should match legacy helper');
  CheckEqual(LLegacyInfo.Description, LRuntimeInfo.Description, 'runtime backend info description should match legacy helper');
  CheckEqual(LLegacyInfo.Available, LRuntimeInfo.Available, 'runtime backend info availability should match legacy helper');
  CheckEqual(LLegacyInfo.Priority, LRuntimeInfo.Priority, 'runtime backend info priority should match legacy helper');
  CheckTrue(LLegacyInfo.Capabilities = LRuntimeInfo.Capabilities, 'runtime backend info capabilities should match legacy helper');
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeDispatchableView_Matches_LegacyFacadeAliases;
var
  LRuntimeDispatchable: TSimdBackendArray;
  LLegacyDispatchable: TSimdBackendArray;
  LLegacyAvailable: TSimdBackendArray;
  LIndex: Integer;
begin
  LRuntimeDispatchable := nextpas.core.simd.runtime.GetDispatchableBackendList;
  LLegacyDispatchable := nextpas.core.simd.GetDispatchableBackendList;
  LLegacyAvailable := nextpas.core.simd.GetAvailableBackendList;

  AssertBackendArrayEquals('runtime dispatchable backends should match legacy dispatchable helper', LLegacyDispatchable, LRuntimeDispatchable);
  AssertBackendArrayEquals('runtime dispatchable backends should match legacy available alias', LLegacyAvailable, LRuntimeDispatchable);
  CheckEqual(Ord(nextpas.core.simd.GetBestDispatchableBackend), Ord(nextpas.core.simd.runtime.GetBestDispatchableBackend), 'runtime best dispatchable backend should match legacy helper');

  for LIndex := 0 to High(LRuntimeDispatchable) do
  begin
    CheckTrue(IsBackendSupportedOnCPU(LRuntimeDispatchable[LIndex]), 'dispatchable backend should remain CPU-supported');
    CheckTrue(nextpas.core.simd.runtime.IsBackendRegisteredInBinary(LRuntimeDispatchable[LIndex]), 'dispatchable backend should remain registered in binary');
  end;
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeControlPlane_SwitchAndReset_Match_LegacyFacade;
begin
  CheckTrue(nextpas.core.simd.runtime.TrySetCurrentBackend(sbScalar), 'TrySetCurrentBackend(sbScalar) should succeed');
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.runtime.GetCurrentBackend), 'runtime current backend should switch to Scalar');
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.GetCurrentBackend), 'legacy current backend should track runtime switch');
  CheckEqual(Ord(sbScalar), Ord(GetDispatchTable^.Backend), 'dispatch snapshot should track runtime switch');

  nextpas.core.simd.runtime.ResetCurrentBackendSelection;
  CheckEqual(Ord(nextpas.core.simd.GetBestDispatchableBackend), Ord(nextpas.core.simd.runtime.GetCurrentBackend), 'runtime reset should restore automatic best backend');
  CheckEqual(Ord(nextpas.core.simd.runtime.GetCurrentBackend), Ord(nextpas.core.simd.GetCurrentBackend), 'legacy current backend should track runtime reset');
  CheckEqual(Ord(nextpas.core.simd.runtime.GetCurrentBackend), Ord(GetDispatchTable^.Backend), 'dispatch snapshot should track runtime reset');
end;

procedure TTestCase_RuntimeAPI.Test_FacadeCpuCapability_View_Uses_Canonical_Cpuinfo_Semantics;
var
  LFacadeCanonicalCPUInfo: TCPUInfo;
  LFacadeCPUInfo: TCPUInfo;
  LCanonicalCPUInfo: TCPUInfo;
  LFacadeSupported: TSimdBackendArray;
  LCanonicalSupported: TSimdBackendArray;
begin
  LFacadeCanonicalCPUInfo := nextpas.core.simd.GetCPUInfo;
  LFacadeCPUInfo := nextpas.core.simd.GetCPUInformation;
  LCanonicalCPUInfo := nextpas.core.simd.cpuinfo.GetCPUInfo;

  CheckEqual(Ord(LFacadeCPUInfo.Arch), Ord(LFacadeCanonicalCPUInfo.Arch), 'facade canonical GetCPUInfo should match legacy GetCPUInformation arch');
  CheckEqual(LFacadeCPUInfo.Vendor, LFacadeCanonicalCPUInfo.Vendor, 'facade canonical GetCPUInfo should match legacy GetCPUInformation vendor');
  CheckEqual(LFacadeCPUInfo.Model, LFacadeCanonicalCPUInfo.Model, 'facade canonical GetCPUInfo should match legacy GetCPUInformation model');

  CheckEqual(Ord(LCanonicalCPUInfo.Arch), Ord(LFacadeCanonicalCPUInfo.Arch), 'facade CPU info arch should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.Vendor, LFacadeCanonicalCPUInfo.Vendor, 'facade CPU info vendor should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.Model, LFacadeCanonicalCPUInfo.Model, 'facade CPU info model should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.LogicalCores, LFacadeCanonicalCPUInfo.LogicalCores, 'facade CPU logical core count should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.PhysicalCores, LFacadeCanonicalCPUInfo.PhysicalCores, 'facade CPU physical core count should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.OSXSAVE, LFacadeCanonicalCPUInfo.OSXSAVE, 'facade CPU OSXSAVE flag should match canonical cpuinfo getter');
  CheckEqual(LCanonicalCPUInfo.XCR0, LFacadeCanonicalCPUInfo.XCR0, 'facade CPU XCR0 should match canonical cpuinfo getter');
  CheckTrue(LCanonicalCPUInfo.GenericRaw = LFacadeCanonicalCPUInfo.GenericRaw, 'facade CPU raw generic features should match canonical cpuinfo getter');
  CheckTrue(LCanonicalCPUInfo.GenericUsable = LFacadeCanonicalCPUInfo.GenericUsable, 'facade CPU usable generic features should match canonical cpuinfo getter');

  LFacadeSupported := nextpas.core.simd.GetSupportedBackendList;
  LCanonicalSupported := nextpas.core.simd.cpuinfo.GetSupportedBackendList;
  AssertBackendArrayEquals('facade supported backend list should stay on canonical cpuinfo semantics', LCanonicalSupported, LFacadeSupported);
  CheckEqual(Ord(nextpas.core.simd.cpuinfo.GetBestSupportedBackend), Ord(nextpas.core.simd.GetBestSupportedBackend), 'facade best supported backend should match canonical cpuinfo getter');
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeSnapshot_Canonical_Name_Aliases_Legacy_Subunit_Name;
var
  LCanonicalSnapshot: TSimdRuntimeSnapshot;
  LLegacySnapshot: TSimdRuntimeSnapshot;
begin
  LCanonicalSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
  LLegacySnapshot := nextpas.core.simd.runtime.GetCurrentSimdRuntimeSnapshot;

  CheckEqual(Ord(LLegacySnapshot.CurrentBackend), Ord(LCanonicalSnapshot.CurrentBackend), 'runtime snapshot canonical getter should match legacy alias current backend');
  CheckEqual(Ord(LLegacySnapshot.CurrentBackendInfo.Backend), Ord(LCanonicalSnapshot.CurrentBackendInfo.Backend), 'runtime snapshot canonical getter should match legacy alias backend info backend');
  CheckEqual(LLegacySnapshot.CurrentBackendInfo.Name, LCanonicalSnapshot.CurrentBackendInfo.Name, 'runtime snapshot canonical getter should match legacy alias backend info name');
  CheckEqual(LLegacySnapshot.CurrentBackendInfo.Description, LCanonicalSnapshot.CurrentBackendInfo.Description, 'runtime snapshot canonical getter should match legacy alias backend info description');
  CheckEqual(LLegacySnapshot.CurrentBackendInfo.Available, LCanonicalSnapshot.CurrentBackendInfo.Available, 'runtime snapshot canonical getter should match legacy alias backend info availability');
  CheckEqual(LLegacySnapshot.CurrentBackendInfo.Priority, LCanonicalSnapshot.CurrentBackendInfo.Priority, 'runtime snapshot canonical getter should match legacy alias backend info priority');
  CheckTrue(LLegacySnapshot.CurrentBackendInfo.Capabilities = LCanonicalSnapshot.CurrentBackendInfo.Capabilities, 'runtime snapshot canonical getter should match legacy alias backend info capabilities');
  AssertBackendArrayEquals('runtime snapshot canonical getter should match legacy alias registered backends', LLegacySnapshot.RegisteredBackends, LCanonicalSnapshot.RegisteredBackends);
  AssertBackendArrayEquals('runtime snapshot canonical getter should match legacy alias dispatchable backends', LLegacySnapshot.DispatchableBackends, LCanonicalSnapshot.DispatchableBackends);
  CheckEqual(Ord(LLegacySnapshot.BestDispatchableBackend), Ord(LCanonicalSnapshot.BestDispatchableBackend), 'runtime snapshot canonical getter should match legacy alias best dispatchable backend');
end;

procedure TTestCase_RuntimeAPI.Test_FacadeRuntimeSnapshot_View_Matches_Runtime_Subunit;
var
  LFacadeSnapshot: TSimdRuntimeSnapshot;
  LRuntimeSnapshot: TSimdRuntimeSnapshot;
begin
  LFacadeSnapshot := nextpas.core.simd.GetCurrentRuntimeSnapshot;
  LRuntimeSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;

  CheckEqual(Ord(LRuntimeSnapshot.CurrentBackend), Ord(LFacadeSnapshot.CurrentBackend), 'facade runtime snapshot current backend should match runtime subunit snapshot');
  CheckEqual(Ord(LRuntimeSnapshot.CurrentBackendInfo.Backend), Ord(LFacadeSnapshot.CurrentBackendInfo.Backend), 'facade runtime snapshot backend info backend should match runtime subunit snapshot');
  CheckEqual(LRuntimeSnapshot.CurrentBackendInfo.Name, LFacadeSnapshot.CurrentBackendInfo.Name, 'facade runtime snapshot backend info name should match runtime subunit snapshot');
  CheckEqual(LRuntimeSnapshot.CurrentBackendInfo.Description, LFacadeSnapshot.CurrentBackendInfo.Description, 'facade runtime snapshot backend info description should match runtime subunit snapshot');
  CheckEqual(LRuntimeSnapshot.CurrentBackendInfo.Available, LFacadeSnapshot.CurrentBackendInfo.Available, 'facade runtime snapshot backend info availability should match runtime subunit snapshot');
  CheckEqual(LRuntimeSnapshot.CurrentBackendInfo.Priority, LFacadeSnapshot.CurrentBackendInfo.Priority, 'facade runtime snapshot backend info priority should match runtime subunit snapshot');
  CheckTrue(LRuntimeSnapshot.CurrentBackendInfo.Capabilities = LFacadeSnapshot.CurrentBackendInfo.Capabilities, 'facade runtime snapshot backend info capabilities should match runtime subunit snapshot');
  AssertBackendArrayEquals('facade runtime snapshot registered backends should match runtime subunit snapshot', LRuntimeSnapshot.RegisteredBackends, LFacadeSnapshot.RegisteredBackends);
  AssertBackendArrayEquals('facade runtime snapshot dispatchable backends should match runtime subunit snapshot', LRuntimeSnapshot.DispatchableBackends, LFacadeSnapshot.DispatchableBackends);
  CheckEqual(Ord(LRuntimeSnapshot.BestDispatchableBackend), Ord(LFacadeSnapshot.BestDispatchableBackend), 'facade runtime snapshot best dispatchable backend should match runtime subunit snapshot');
end;

procedure TTestCase_RuntimeAPI.Test_FacadeRuntimeControlPlane_Wrappers_Interoperate_With_Legacy_Aliases;
begin
  CheckTrue(nextpas.core.simd.TrySetCurrentBackend(sbScalar), 'facade TrySetCurrentBackend(sbScalar) should succeed');
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.runtime.GetCurrentBackend), 'runtime subunit getter should track facade TrySetCurrentBackend');
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.GetCurrentRuntimeSnapshot.CurrentBackend), 'facade runtime snapshot should track facade TrySetCurrentBackend');

  nextpas.core.simd.ResetBackendSelection;
  CheckEqual(Ord(nextpas.core.simd.GetBestDispatchableBackend), Ord(nextpas.core.simd.GetCurrentBackend), 'legacy ResetBackendSelection should restore best dispatchable backend after facade TrySetCurrentBackend');

  nextpas.core.simd.ForceBackend(sbScalar);
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.GetCurrentBackend), 'facade GetCurrentBackend should track legacy ForceBackend');
  CheckEqual(Ord(sbScalar), Ord(nextpas.core.simd.GetCurrentRuntimeSnapshot.CurrentBackend), 'facade runtime snapshot should track legacy ForceBackend');

  nextpas.core.simd.ResetCurrentBackendSelection;
  CheckEqual(Ord(nextpas.core.simd.GetBestDispatchableBackend), Ord(nextpas.core.simd.GetCurrentBackend), 'facade ResetCurrentBackendSelection should restore best dispatchable backend after legacy ForceBackend');
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeSnapshot_View_Matches_Runtime_And_Legacy_Helpers;
var
  LSnapshot: TSimdRuntimeSnapshot;
  LDispatch: PSimdDispatchTable;
begin
  LSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
  LDispatch := GetDispatchTable;

  CheckTrue(LDispatch <> nil, 'GetDispatchTable should be assigned');
  CheckEqual(Ord(nextpas.core.simd.runtime.GetCurrentBackend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot current backend should match runtime getter');
  CheckEqual(Ord(nextpas.core.simd.GetCurrentBackend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot current backend should match legacy facade getter');
  CheckEqual(Ord(LDispatch^.Backend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot current backend should match dispatch snapshot backend');

  CheckEqual(Ord(LSnapshot.CurrentBackend), Ord(LSnapshot.CurrentBackendInfo.Backend), 'runtime snapshot backend info backend should match snapshot backend');
  CheckEqual(nextpas.core.simd.runtime.GetCurrentBackendInfo.Name, LSnapshot.CurrentBackendInfo.Name, 'runtime snapshot backend info name should match runtime getter');
  CheckEqual(nextpas.core.simd.runtime.GetCurrentBackendInfo.Description, LSnapshot.CurrentBackendInfo.Description, 'runtime snapshot backend info description should match runtime getter');
  CheckEqual(nextpas.core.simd.runtime.GetCurrentBackendInfo.Available, LSnapshot.CurrentBackendInfo.Available, 'runtime snapshot backend info availability should match runtime getter');
  CheckEqual(nextpas.core.simd.runtime.GetCurrentBackendInfo.Priority, LSnapshot.CurrentBackendInfo.Priority, 'runtime snapshot backend info priority should match runtime getter');
  CheckTrue(LSnapshot.CurrentBackendInfo.Capabilities = nextpas.core.simd.runtime.GetCurrentBackendInfo.Capabilities, 'runtime snapshot backend info capabilities should match runtime getter');

  AssertBackendArrayEquals('runtime snapshot registered backends should match runtime getter', nextpas.core.simd.runtime.GetRegisteredBackendList, LSnapshot.RegisteredBackends);
  AssertBackendArrayEquals('runtime snapshot dispatchable backends should match runtime getter', nextpas.core.simd.runtime.GetDispatchableBackendList, LSnapshot.DispatchableBackends);
  CheckEqual(Ord(nextpas.core.simd.runtime.GetBestDispatchableBackend), Ord(LSnapshot.BestDispatchableBackend), 'runtime snapshot best dispatchable backend should match runtime getter');
end;

procedure TTestCase_RuntimeAPI.Test_RuntimeSnapshot_Switch_Tracks_ControlPlane_And_Dispatch;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  CheckTrue(nextpas.core.simd.runtime.TrySetCurrentBackend(sbScalar), 'TrySetCurrentBackend(sbScalar) should succeed in runtime snapshot test');

  LSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
  CheckEqual(Ord(sbScalar), Ord(LSnapshot.CurrentBackend), 'runtime snapshot current backend should switch to Scalar');
  CheckEqual(Ord(sbScalar), Ord(LSnapshot.CurrentBackendInfo.Backend), 'runtime snapshot backend info backend should switch to Scalar');
  CheckEqual(Ord(GetDispatchTable^.Backend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot should match dispatch snapshot backend after switch');
  CheckEqual(Ord(nextpas.core.simd.runtime.GetCurrentBackend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot should match runtime getter after switch');

  nextpas.core.simd.runtime.ResetCurrentBackendSelection;
  LSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
  CheckEqual(Ord(nextpas.core.simd.runtime.GetBestDispatchableBackend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot reset should restore automatic current backend');
  CheckEqual(Ord(GetDispatchTable^.Backend), Ord(LSnapshot.CurrentBackend), 'runtime snapshot should match dispatch snapshot backend after reset');
  CheckEqual(Ord(LSnapshot.CurrentBackend), Ord(LSnapshot.CurrentBackendInfo.Backend), 'runtime snapshot backend info backend should match reset backend');
end;


end.