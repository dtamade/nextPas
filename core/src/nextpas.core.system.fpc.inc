{**
 * @desc FPC compatibility layer — re-export FPC System types.
 *
 * This file is included when compiling under FPC.
 * It re-exports types from FPC's System unit so that
 * other nextpas.core units can import them via nextpas.core.system.
 *
 * NOTE: This file is only included under FPC.
 * For nextPas, see kernel.inc.
 *}

type
  { Re-export FPC System types }
  TObject = System.TObject;
  TClass = System.TClass;
  TTypeKind = System.TTypeKind;

  { Basic types — re-export from FPC System }
  SizeInt = System.SizeInt;
  SizeUInt = System.SizeUInt;
  PtrInt = System.PtrInt;
  PtrUInt = System.PtrUInt;
  NativeInt = System.NativeInt;
  NativeUInt = System.NativeUInt;

  { Pointer types }
  PByte = System.PByte;
  PWord = System.PWord;
  PLongInt = System.PLongInt;
  PLongWord = System.PLongWord;
  PInt64 = System.PInt64;
  PQWord = System.PQWord;
  PPointer = System.PPointer;
  PSizeInt = System.PSizeInt;
  PSizeUInt = System.PSizeUInt;

  { String types }
  ShortString = System.ShortString;
  AnsiString = System.AnsiString;
  WideString = System.WideString;
  UnicodeString = System.UnicodeString;

  { Character types }
  Char = System.Char;
  AnsiChar = System.AnsiChar;
  WideChar = System.WideChar;

  { Interface types }
  IUnknown = System.IUnknown;
  IInterface = System.IInterface;

  { GUID type }
  TGUID = System.TGUID;
  PGUID = System.PGUID;

  { VMT structures }
  PVmt = System.PVmt;
  TVmt = System.TVmt;

  { Interface structures }
  PInterfaceEntry = System.PInterfaceEntry;
  TInterfaceEntry = System.TInterfaceEntry;
  TInterfaceEntryType = System.TInterfaceEntryType;
  PInterfaceTable = System.PInterfaceTable;
  TInterfaceTable = System.TInterfaceTable;

  { Method type }
  TMethod = System.TMethod;
