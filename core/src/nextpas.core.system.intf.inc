{**
 * @desc Interface types for the nextPas system kernel.
 *
 * Defines IUnknown, TGUID, TInterfaceEntry, TMethod.
 * Depends on base.inc and str.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

type
  { GUID type }
  TGUID = record
    D1: LongWord;
    D2: Word;
    D3: Word;
    D4: array[0..7] of Byte;
  end;
  PGUID = ^TGUID;

  { Interface base types }
  IUnknown = interface
    ['{00000000-0000-0000-C000-000000000046}']
    function QueryInterface(const IID: TGUID; out Obj): LongInt; stdcall;
    function _AddRef: LongInt; stdcall;
    function _Release: LongInt; stdcall;
  end;

  IInterface = IUnknown;

  { Interface entry types }
  TInterfaceEntryType = (etStandard, etField, etVirtualMethod);
  PInterfaceEntry = ^TInterfaceEntry;
  TInterfaceEntry = record
    IID: TGUID;
    VTable: Pointer;
    IOffset: SizeInt;
    case Integer of
      0: (IsField: Boolean);
      1: (ImplGetter: SizeUInt);
  end;

  PInterfaceTable = ^TInterfaceTable;
  TInterfaceTable = record
    EntryCount: SizeInt;
    Entries: array[0..9999] of TInterfaceEntry;
  end;

  { Method type }
  TMethod = record
    Code: Pointer;
    Data: Pointer;
  end;
  PMethod = ^TMethod;

implementation

{ TGUID operators — implemented in implementation section }
{ Note: Forward declarations needed in interface section }

{ These operators will be available after interface section }
{ operator = (const A, B: TGUID): Boolean; }
{ operator <> (const A, B: TGUID): Boolean; }
