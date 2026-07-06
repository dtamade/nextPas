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

  { Variant type — compiler must know this layout }
  TVarType = Word;
  PVarType = ^TVarType;

  TVarData = packed record
    case Integer of
      0: (VType: TVarType;
          case Integer of
            0: (VSmallInt: SmallInt;
                VPadding: array[0..5] of Byte);
            1: (VInteger: LongInt;
                VPadding2: array[0..3] of Byte);
            2: (VSingle: Single;
                VPadding3: array[0..3] of Byte);
            3: (VDouble: Double);
            4: (VCurrency: Int64);
            5: (VDate: Double);
            6: (VString: Pointer);
            7: (VBoolean: LongBool);
            8: (VShortInt: ShortInt;
                VPadding4: array[0..6] of Byte);
            9: (VByte: Byte;
                VPadding5: array[0..6] of Byte);
            10: (VWord: Word;
                 VPadding6: array[0..5] of Byte);
            11: (VLongWord: LongWord;
                 VPadding7: array[0..3] of Byte);
            12: (VInt64: Int64);
            13: (VQWord: QWord);
            14: (VUnknown: Pointer;
                 VUnknown2: Pointer);
            15: (VDispatch: Pointer;
                 VDispatch2: Pointer);
          );
      1: (Reserved1: array[0..1] of Word;
          Reserved2: array[0..6] of Byte);
  end;
  PVarData = ^TVarData;

const
  { Variant type constants }
  varEmpty    = $0000;
  varNull     = $0001;
  varSmallint = $0002;
  varInteger  = $0003;
  varSingle   = $0004;
  varDouble   = $0005;
  varCurrency = $0006;
  varDate     = $0007;
  varOleStr   = $0008;
  varDispatch = $0009;
  varError    = $000A;
  varBoolean  = $000B;
  varVariant  = $000C;
  varUnknown  = $000D;
  varShortInt = $0010;
  varByte     = $0011;
  varWord     = $0012;
  varLongWord = $0013;
  varInt64    = $0014;
  varQWord    = $0015;
  varString   = $0100;
  varAny      = $0101;
  varUString  = $0102;

  { Variant type flags }
  varTypeMask  = $0FFF;
  varArray     = $2000;
  varByRef     = $4000;

type
  { Dynamic array types — compiler must know these }
  TBytes = array of Byte;
  TCharArray = array of Char;
