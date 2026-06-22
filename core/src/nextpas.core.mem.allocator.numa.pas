unit nextpas.core.mem.allocator.numa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf;

type
  TNumaAllocatorCapabilities = record
    Available: Boolean;
    SupportsNodeBinding: Boolean;
    SupportsInterleave: Boolean;
  end;

  INumaAllocatorProvider = interface
    ['{F5C8CB46-4EA1-4832-B262-E0D0E3D78D05}']
    function Capabilities: TNumaAllocatorCapabilities;
    function TryCreateNodeAllocator(aNode: UInt32; out aAllocator: IAllocator): Boolean;
    function TryCreateInterleavedAllocator(out aAllocator: IAllocator): Boolean;
  end;

function GetDefaultNumaAllocatorProvider: INumaAllocatorProvider;

implementation

type
  TNoOpNumaAllocatorProvider = class(TInterfacedObject, INumaAllocatorProvider)
  public
    function Capabilities: TNumaAllocatorCapabilities;
    function TryCreateNodeAllocator(aNode: UInt32; out aAllocator: IAllocator): Boolean;
    function TryCreateInterleavedAllocator(out aAllocator: IAllocator): Boolean;
  end;

var
  GNoOpProvider: INumaAllocatorProvider = nil;
  GNoOpProviderLock: TRTLCriticalSection;

function TNoOpNumaAllocatorProvider.Capabilities: TNumaAllocatorCapabilities;
begin
  Result.Available := False;
  Result.SupportsNodeBinding := False;
  Result.SupportsInterleave := False;
end;

function TNoOpNumaAllocatorProvider.TryCreateNodeAllocator(aNode: UInt32; out aAllocator: IAllocator): Boolean;
begin
  aAllocator := nil;
  Result := False;
end;

function TNoOpNumaAllocatorProvider.TryCreateInterleavedAllocator(out aAllocator: IAllocator): Boolean;
begin
  aAllocator := nil;
  Result := False;
end;

function GetDefaultNumaAllocatorProvider: INumaAllocatorProvider;
begin
  if GNoOpProvider = nil then
  begin
    EnterCriticalSection(GNoOpProviderLock);
    try
      if GNoOpProvider = nil then
        GNoOpProvider := TNoOpNumaAllocatorProvider.Create;
    finally
      LeaveCriticalSection(GNoOpProviderLock);
    end;
  end;
  Result := GNoOpProvider;
end;

initialization
  InitCriticalSection(GNoOpProviderLock);
finalization
  GNoOpProvider := nil;
  DoneCriticalSection(GNoOpProviderLock);

end.
