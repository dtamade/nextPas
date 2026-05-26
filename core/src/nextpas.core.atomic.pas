unit nextpas.core.atomic;

{$I nextpas.core.settings.inc}

interface

type
  TMemoryOrder = (
    moRelaxed,
    moAcquire,
    moRelease,
    moAcqRel,
    moSeqCst
  );

{ ============================================================ }
{ Int32 atomics                                                }
{ ============================================================ }

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst);
function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;

{ ============================================================ }
{ Int64 atomics                                                }
{ ============================================================ }

function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64;
procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst);
function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64;
function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64;
function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64;
function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64;

{ ============================================================ }
{ Pointer atomics                                              }
{ ============================================================ }

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer;
procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst);
function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer;
function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer;

{ ============================================================ }
{ Fences and hints                                             }
{ ============================================================ }

procedure AtomicThreadFence(const AOrder: TMemoryOrder = moSeqCst);
procedure AtomicSignalFence(const AOrder: TMemoryOrder = moSeqCst);
procedure CpuPause; inline;

implementation

{ Platform-specific implementation }
{$IFDEF NEXTPAS_X86_64}
  {$I nextpas.core.atomic.x86_64.inc}
{$ELSE}
  {$FATAL 'nextpas.core.atomic: unsupported CPU architecture'}
{$ENDIF}

end.
