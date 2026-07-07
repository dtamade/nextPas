{**
 * @desc Basic types for the nextPas system kernel.
 *
 * Platform-dependent integer types, pointer types, and C ABI types.
 * No dependencies on other kernel sub-modules.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

type
  { Platform-dependent integer types }
{$IFDEF CPU64}
  SizeInt = Int64;
  SizeUInt = QWord;
  PtrInt = Int64;
  PtrUInt = QWord;
  NativeInt = Int64;
  NativeUInt = QWord;
{$ELSE}
  SizeInt = LongInt;
  SizeUInt = LongWord;
  PtrInt = LongInt;
  PtrUInt = LongWord;
  NativeInt = LongInt;
  NativeUInt = LongWord;
{$ENDIF}

  { Pointer types }
  PByte = ^Byte;
  PWord = ^Word;
  PLongInt = ^LongInt;
  PLongWord = ^LongWord;
  PInt64 = ^Int64;
  PQWord = ^QWord;
  PPointer = ^Pointer;
  PSizeInt = ^SizeInt;
  PSizeUInt = ^SizeUInt;

  { C ABI types }
  CInt = LongInt;
  CUInt = LongWord;
  CLong = {$IFDEF CPU64}Int64{$ELSE}LongInt{$ENDIF};
  CULong = {$IFDEF CPU64}QWord{$ELSE}LongWord{$ENDIF};
  CChar = AnsiChar;
  PCChar = ^CChar;
