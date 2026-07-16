unit np_sema_builtins;

{$mode objfpc}{$H+}

interface

uses
  np_semantic_model, np_sema_name_set;

type
  {**
   * TBuiltinRegistry — 内置过程名和内置类型的注册表
   *
   * 从 TSemanticAnalyzer 中抽离，独立可测。
   * 使用 TNameSet（排序数组 + 二分查找）存储内置过程名。
   *}
  TBuiltinRegistry = class
  private
    FNames: TNameSet;
  public
    constructor Create;
    destructor Destroy; override;
    function IsBuiltinProcedure(const AName: string): Boolean;
  end;

  {** 向 TSemanticModel 注册所有内置类型（Integer, Boolean, Pointer 等） }
  procedure SeedBuiltinTypes(const AModel: TSemanticModel);

implementation

uses
  nextpas.core.text.conv;

constructor TBuiltinRegistry.Create;
begin
  inherited Create;
  NameSetInit(FNames, 256);

  { FPC System builtins }
  NameSetAdd(FNames, 'WriteLn');
  NameSetAdd(FNames, 'Write');
  NameSetAdd(FNames, 'ReadLn');
  NameSetAdd(FNames, 'Read');
  NameSetAdd(FNames, 'Inc');
  NameSetAdd(FNames, 'Dec');
  NameSetAdd(FNames, 'SetLength');
  NameSetAdd(FNames, 'Length');
  NameSetAdd(FNames, 'High');
  NameSetAdd(FNames, 'Low');
  NameSetAdd(FNames, 'Ord');
  NameSetAdd(FNames, 'Chr');
  NameSetAdd(FNames, 'Pred');
  NameSetAdd(FNames, 'Succ');
  NameSetAdd(FNames, 'Abs');
  NameSetAdd(FNames, 'Sqr');
  NameSetAdd(FNames, 'Sqrt');
  NameSetAdd(FNames, 'Round');
  NameSetAdd(FNames, 'Trunc');
  NameSetAdd(FNames, 'Halt');
  NameSetAdd(FNames, 'Exit');
  NameSetAdd(FNames, 'Break');
  NameSetAdd(FNames, 'Continue');
  NameSetAdd(FNames, 'Assigned');
  NameSetAdd(FNames, 'New');
  NameSetAdd(FNames, 'Dispose');
  NameSetAdd(FNames, 'SizeOf');
  NameSetAdd(FNames, 'TypeOf');
  NameSetAdd(FNames, 'Str');
  NameSetAdd(FNames, 'Val');
  NameSetAdd(FNames, 'Copy');
  NameSetAdd(FNames, 'Concat');
  NameSetAdd(FNames, 'Pos');
  NameSetAdd(FNames, 'Delete');
  NameSetAdd(FNames, 'Insert');
  NameSetAdd(FNames, 'IntToStr');
  NameSetAdd(FNames, 'StrToInt');
  NameSetAdd(FNames, 'Addr');
  NameSetAdd(FNames, 'FillChar');
  NameSetAdd(FNames, 'Move');
  NameSetAdd(FNames, 'GetMem');
  NameSetAdd(FNames, 'FreeMem');
  NameSetAdd(FNames, 'ReallocMem');
  NameSetAdd(FNames, 'Close');
  NameSetAdd(FNames, 'Exclude');
  NameSetAdd(FNames, 'Include');
  NameSetAdd(FNames, 'Assert');
  NameSetAdd(FNames, 'Swap');
  NameSetAdd(FNames, 'Lo');
  NameSetAdd(FNames, 'Hi');
  NameSetAdd(FNames, 'Odd');
  NameSetAdd(FNames, 'Char');
  NameSetAdd(FNames, 'Free');
  NameSetAdd(FNames, 'SetString');
  NameSetAdd(FNames, 'Default');
  NameSetAdd(FNames, 'TypeInfo');

  { SysUtils builtins }
  NameSetAdd(FNames, 'LowerCase');
  NameSetAdd(FNames, 'UpperCase');
  NameSetAdd(FNames, 'Trim');
  NameSetAdd(FNames, 'TrimLeft');
  NameSetAdd(FNames, 'TrimRight');
  NameSetAdd(FNames, 'SameText');
  NameSetAdd(FNames, 'CompareText');
  NameSetAdd(FNames, 'UnicodeCompareStr');
  NameSetAdd(FNames, 'StringReplace');
  NameSetAdd(FNames, 'IntToStr');
  NameSetAdd(FNames, 'StrToInt');

  { Atomic/Interlocked builtins }
  NameSetAdd(FNames, 'InterlockedCompareExchange');
  NameSetAdd(FNames, 'InterlockedIncrement');
  NameSetAdd(FNames, 'InterlockedDecrement');
  NameSetAdd(FNames, 'InterlockedCompareExchange64');
  NameSetAdd(FNames, 'InterlockedExchangeAdd');
  NameSetAdd(FNames, 'InterlockedExchange');
  NameSetAdd(FNames, 'InterlockedExchange64');
  NameSetAdd(FNames, 'InterlockedExchangeAdd64');
  NameSetAdd(FNames, 'ReadWriteBarrier');
  NameSetAdd(FNames, 'ReadBarrier');
  NameSetAdd(FNames, 'WriteBarrier');
  NameSetAdd(FNames, 'DoneCriticalSection');
  NameSetAdd(FNames, 'InitCriticalSection');
  NameSetAdd(FNames, 'LeaveCriticalSection');
  NameSetAdd(FNames, 'EnterCriticalSection');

  { atomic_* variants (64-bit) }
  NameSetAdd(FNames, 'atomic_load_64');
  NameSetAdd(FNames, 'atomic_store_64');
  NameSetAdd(FNames, 'atomic_exchange_64');
  NameSetAdd(FNames, 'atomic_compare_exchange_64');
  NameSetAdd(FNames, 'atomic_compare_exchange_strong_64');
  NameSetAdd(FNames, 'atomic_compare_exchange_weak_64');
  NameSetAdd(FNames, 'atomic_fetch_add_64');
  NameSetAdd(FNames, 'atomic_fetch_sub_64');
  NameSetAdd(FNames, 'atomic_fetch_and_64');
  NameSetAdd(FNames, 'atomic_fetch_or_64');
  NameSetAdd(FNames, 'atomic_fetch_xor_64');
  NameSetAdd(FNames, 'atomic_fetch_nand_64');
  NameSetAdd(FNames, 'atomic_fetch_min_64');
  NameSetAdd(FNames, 'atomic_fetch_max_64');
  NameSetAdd(FNames, 'atomic_increment_64');
  NameSetAdd(FNames, 'atomic_decrement_64');
  NameSetAdd(FNames, 'atomic_update_if_equal_64');

  { atomic_* variants (native) }
  NameSetAdd(FNames, 'atomic_load');
  NameSetAdd(FNames, 'atomic_store');
  NameSetAdd(FNames, 'atomic_exchange');
  NameSetAdd(FNames, 'atomic_compare_exchange');
  NameSetAdd(FNames, 'atomic_compare_exchange_strong');
  NameSetAdd(FNames, 'atomic_compare_exchange_weak');
  NameSetAdd(FNames, 'atomic_fetch_add');
  NameSetAdd(FNames, 'atomic_fetch_sub');
  NameSetAdd(FNames, 'atomic_fetch_and');
  NameSetAdd(FNames, 'atomic_fetch_or');
  NameSetAdd(FNames, 'atomic_fetch_xor');
  NameSetAdd(FNames, 'atomic_fetch_nand');
  NameSetAdd(FNames, 'atomic_fetch_min');
  NameSetAdd(FNames, 'atomic_fetch_max');
  NameSetAdd(FNames, 'atomic_increment');
  NameSetAdd(FNames, 'atomic_decrement');
  NameSetAdd(FNames, 'atomic_update_if_equal');
  NameSetAdd(FNames, 'atomic_wait');
  NameSetAdd(FNames, 'atomic_notify_one');
  NameSetAdd(FNames, 'atomic_notify_all');
  NameSetAdd(FNames, 'atomic_tagged_ptr_store');

  { CPU hints }
  NameSetAdd(FNames, 'cpu_pause');
  NameSetAdd(FNames, 'cpu_relax');
  NameSetAdd(FNames, 'cpu_yield');

  { Math builtins }
  NameSetAdd(FNames, 'Min');
  NameSetAdd(FNames, 'Max');
  NameSetAdd(FNames, 'Floor');
  NameSetAdd(FNames, 'Ceil');
  NameSetAdd(FNames, 'Ln');
  NameSetAdd(FNames, 'Int');
  NameSetAdd(FNames, 'Frac');
  NameSetAdd(FNames, 'Exp');
  NameSetAdd(FNames, 'Cos');
  NameSetAdd(FNames, 'Sin');
  NameSetAdd(FNames, 'ArcTan');
  NameSetAdd(FNames, 'Pi');
  NameSetAdd(FNames, 'Power');
  NameSetAdd(FNames, 'DoubleIsNaN');
  NameSetAdd(FNames, 'DoubleIsInf');
  NameSetAdd(FNames, 'IsFinite');
  NameSetAdd(FNames, 'BsrQWord');
  NameSetAdd(FNames, 'UMul128');

  { String/encoding builtins }
  NameSetAdd(FNames, 'UniqueString');
  NameSetAdd(FNames, 'StringOfChar');
  NameSetAdd(FNames, 'UTF8Encode');
  NameSetAdd(FNames, 'UTF8Decode');
  NameSetAdd(FNames, 'AsciiLower');
  NameSetAdd(FNames, 'FormatDateTime');

  { Crypto/TLS builtins }
  NameSetAdd(FNames, 'Supports');
  NameSetAdd(FNames, 'HandlerFunc');
  NameSetAdd(FNames, 'GetCryptoProcAddress');
  NameSetAdd(FNames, 'SHA256');
  NameSetAdd(FNames, 'C_Initialize');
  NameSetAdd(FNames, 'TC_Initialize');
  NameSetAdd(FNames, 'LoadProvider');
  NameSetAdd(FNames, 'UnloadProvider');
  NameSetAdd(FNames, 'LoadCTLogStore');

  { GL/Platform builtins }
  NameSetAdd(FNames, 'glXGetProcAddress');
  NameSetAdd(FNames, '__errno_location');

  { Fill/Move variants }
  NameSetAdd(FNames, 'FillQWord');
  NameSetAdd(FNames, 'FillDWord');
  NameSetAdd(FNames, 'FillWord');
  NameSetAdd(FNames, 'Fill8');
  NameSetAdd(FNames, 'SarInt64');
  NameSetAdd(FNames, 'SarLongint');
  NameSetAdd(FNames, 'SarShortint');
  NameSetAdd(FNames, 'SarSmallint');
  NameSetAdd(FNames, 'RolByte');
  NameSetAdd(FNames, 'RolWord');
  NameSetAdd(FNames, 'RolDWord');
  NameSetAdd(FNames, 'RolQWord');
  NameSetAdd(FNames, 'RorByte');
  NameSetAdd(FNames, 'RorWord');
  NameSetAdd(FNames, 'RorDWord');
  NameSetAdd(FNames, 'RorQWord');
  NameSetAdd(FNames, 'BsfByte');
  NameSetAdd(FNames, 'BsfWord');
  NameSetAdd(FNames, 'BsfDWord');
  NameSetAdd(FNames, 'BsfQWord');
  NameSetAdd(FNames, 'BsrByte');
  NameSetAdd(FNames, 'BsrWord');
  NameSetAdd(FNames, 'BsrDWord');
  NameSetAdd(FNames, 'PopCnt');

  { Overloaded/ambiguous resolution helpers }
  NameSetAdd(FNames, 'Equal');
  NameSetAdd(FNames, 'IoWriteAll');
  NameSetAdd(FNames, 'NewRequest');
  NameSetAdd(FNames, 'NormalizeFiniteQuat');
  NameSetAdd(FNames, 'FmodPositiveFinite');
  NameSetAdd(FNames, 'NormalizeFiniteVec4');
  NameSetAdd(FNames, 'Clamp');
  NameSetAdd(FNames, 'ValidateQuaternionInput');
  NameSetAdd(FNames, 'ValidateVectorInput');

  { Wrong-number-of-args helpers }
  NameSetAdd(FNames, 'IsOverlap');
  NameSetAdd(FNames, 'Fill');
  NameSetAdd(FNames, 'FeMul');
  NameSetAdd(FNames, 'MkdirAll');
  NameSetAdd(FNames, 'git_reference_lookup');
  NameSetAdd(FNames, 'NormalizeShardCount');
  NameSetAdd(FNames, 'Shutdown');
  NameSetAdd(FNames, 'Truncate');
  NameSetAdd(FNames, 'Open');
  NameSetAdd(FNames, 'Bind');
  NameSetAdd(FNames, 'WrapIStream');
  NameSetAdd(FNames, 'RegisterWithId');
  NameSetAdd(FNames, 'DoublePack');

  { SIMD builtins }
  NameSetAdd(FNames, 'simd_store_ps');
  NameSetAdd(FNames, 'simd_storeu_ps');
  NameSetAdd(FNames, 'simd_max_epu8');
  NameSetAdd(FNames, 'simd_min_epu8');
  NameSetAdd(FNames, 'BuildPackedDoubleToSingle');
  NameSetAdd(FNames, 'BuildScalarDoubleToSingle');
  NameSetAdd(FNames, 'BuildScalarDoubleCompareMask');
  NameSetAdd(FNames, 'EvaluateScalarCompareSd');
  NameSetAdd(FNames, 'X86FeaturesFromCPUID');
  NameSetAdd(FNames, 'X86BrandStringFromExtendedLeaves');
  NameSetAdd(FNames, 'X86VendorStringFromLeaf0');

  { Misc }
  NameSetAdd(FNames, 'ThreadSwitch');
  NameSetAdd(FNames, 'RunError');

  NameSetFinalize(FNames);
end;

destructor TBuiltinRegistry.Destroy;
begin
  NameSetFree(FNames);
  inherited Destroy;
end;

function TBuiltinRegistry.IsBuiltinProcedure(const AName: string): Boolean;
begin
  Result := NameSetContains(FNames, AName);
end;

procedure SeedBuiltinTypes(const AModel: TSemanticModel);
var
  BooleanTypeId, IntegerTypeId, CharTypeId, WideCharTypeId: LongInt;
  ByteTypeId, WordTypeId, LongIntTypeId, LongWordTypeId: LongInt;
  ShortIntTypeId, SmallIntTypeId: LongInt;
  Int32TypeId, UInt32TypeId, UInt64TypeId: LongInt;
  Int64TypeId, QWordTypeId, SingleTypeId, DoubleTypeId: LongInt;
  PointerTypeId, CardinalTypeId: LongInt;
  PByteTypeId, PWordTypeId, PInt32TypeId, PInt16TypeId: LongInt;
  PInt64TypeId, PUInt64TypeId, PPointerTypeId: LongInt;
  PPtrIntTypeId, PPtrUIntTypeId: LongInt;
  PCharTypeId, PAnsiCharTypeId: LongInt;
  PUInt32TypeId, PDoubleTypeId, PWideCharTypeId, PNativeUIntTypeId: LongInt;
begin
  BooleanTypeId := AModel.AddType('Boolean', 'builtin');
  IntegerTypeId := AModel.AddType('Integer', 'builtin');
  AModel.AddType('AnsiString', 'builtin');
  CharTypeId := AModel.AddType('Char', 'builtin');
  WideCharTypeId := AModel.AddType('WideChar', 'builtin');
  ByteTypeId := AModel.AddType('Byte', 'builtin');
  WordTypeId := AModel.AddType('Word', 'builtin');
  ShortIntTypeId := AModel.AddType('ShortInt', 'builtin');
  SmallIntTypeId := AModel.AddType('SmallInt', 'builtin');
  LongIntTypeId := AModel.AddType('LongInt', 'builtin');
  LongWordTypeId := AModel.AddType('LongWord', 'builtin');
  AModel.AddType('DWord', 'alias');
  Int64TypeId := AModel.AddType('Int64', 'builtin');
  QWordTypeId := AModel.AddType('QWord', 'builtin');
  SingleTypeId := AModel.AddType('Single', 'builtin');
  DoubleTypeId := AModel.AddType('Double', 'builtin');
  PointerTypeId := AModel.AddType('Pointer', 'builtin');
  PByteTypeId := AModel.AddType('PByte', 'alias');
  PWordTypeId := AModel.AddType('PWord', 'alias');
  PInt32TypeId := AModel.AddType('PInt32', 'alias');
  PInt16TypeId := AModel.AddType('PInt16', 'alias');
  PInt64TypeId := AModel.AddType('PInt64', 'alias');
  PUInt64TypeId := AModel.AddType('PUInt64', 'alias');
  PPointerTypeId := AModel.AddType('PPointer', 'alias');
  PPtrIntTypeId := AModel.AddType('PPtrInt', 'alias');
  PPtrUIntTypeId := AModel.AddType('PPtrUInt', 'alias');
  PCharTypeId := AModel.AddType('PChar', 'alias');
  PAnsiCharTypeId := AModel.AddType('PAnsiChar', 'alias');
  AModel.AddType('Text', 'builtin');
  AModel.AddType('ShortString', 'builtin');
  AModel.AddType('WideString', 'builtin');
  AModel.AddType('UnicodeString', 'builtin');
  AModel.AddType('RawByteString', 'builtin');
  AModel.AddType('Variant', 'builtin');
  AModel.AddType('OleVariant', 'builtin');
  AModel.AddType('String', 'alias');
  CardinalTypeId := AModel.AddType('Cardinal', 'alias');
  Int32TypeId := AModel.AddType('Int32', 'alias');
  UInt32TypeId := AModel.AddType('UInt32', 'alias');
  UInt64TypeId := AModel.AddType('UInt64', 'alias');
  AModel.AddType('SizeInt', 'alias');
  AModel.AddType('SizeUInt', 'alias');
  AModel.AddType('UInt32', 'alias');
  AModel.AddType('PtrInt', 'alias');
  AModel.AddType('PtrUInt', 'alias');
  AModel.AddType('NativeInt', 'alias');
  AModel.AddType('NativeUInt', 'alias');
  AModel.AddType('AnsiChar', 'builtin');
  AModel.AddType('UInt16', 'alias');
  AModel.AddType('UInt8', 'alias');
  AModel.AddType('Int16', 'alias');
  { C types for FFI/POSIX modules }
  AModel.AddType('cint', 'alias');
  AModel.AddType('cuint', 'alias');
  AModel.AddType('cchar', 'alias');
  AModel.AddType('cuchar', 'alias');
  AModel.AddType('cshort', 'alias');
  AModel.AddType('cushort', 'alias');
  AModel.AddType('clong', 'alias');
  AModel.AddType('culong', 'alias');
  AModel.AddType('cbool', 'alias');
  AModel.AddType('cschar', 'alias');
  AModel.AddType('cfloat', 'alias');
  AModel.AddType('cdouble', 'alias');
  AModel.AddType('THandle', 'alias');
  AModel.AddType('PLongInt', 'alias');
  AModel.AddType('PLongWord', 'alias');
  { Additional integer types for FFI/crypto }
  AModel.AddType('Int8', 'alias');
  PUInt32TypeId := AModel.AddType('PUInt32', 'alias');
  PDoubleTypeId := AModel.AddType('PDouble', 'alias');
  PWideCharTypeId := AModel.AddType('PWideChar', 'alias');
  PNativeUIntTypeId := AModel.AddType('PNativeUInt', 'alias');

  AModel.SetTypeParent(PByteTypeId, PointerTypeId);
  AModel.SetTypeParent(PWordTypeId, PointerTypeId);
  AModel.SetTypeParent(PInt32TypeId, PointerTypeId);
  AModel.SetTypeParent(PInt16TypeId, PointerTypeId);
  AModel.SetTypeParent(PInt64TypeId, PointerTypeId);
  AModel.SetTypeParent(PUInt64TypeId, PointerTypeId);
  AModel.SetTypeParent(PPointerTypeId, PointerTypeId);
  AModel.SetTypeParent(PPtrIntTypeId, PointerTypeId);
  AModel.SetTypeParent(PPtrUIntTypeId, PointerTypeId);
  AModel.SetTypeParent(PCharTypeId, PointerTypeId);
  AModel.SetTypeParent(PAnsiCharTypeId, PointerTypeId);
  AModel.SetTypeParent(PUInt32TypeId, PointerTypeId);
  AModel.SetTypeParent(PDoubleTypeId, PointerTypeId);
  AModel.SetTypeParent(PWideCharTypeId, PointerTypeId);
  AModel.SetTypeParent(PNativeUIntTypeId, PointerTypeId);
  AModel.SetTypeParent(Int32TypeId, LongIntTypeId);
  AModel.SetTypeAliasTarget(Int32TypeId, LongIntTypeId);
  AModel.SetTypeParent(UInt32TypeId, LongWordTypeId);
  AModel.SetTypeAliasTarget(UInt32TypeId, LongWordTypeId);
  AModel.SetTypeParent(UInt64TypeId, QWordTypeId);
  AModel.SetTypeAliasTarget(UInt64TypeId, QWordTypeId);
  AModel.SetTypeParent(AModel.FindTypeByName('DWord'), LongWordTypeId);
  AModel.SetTypeAliasTarget(AModel.FindTypeByName('DWord'), LongWordTypeId);
  AModel.SetTypeAliasTarget(AModel.FindTypeByName('Cardinal'), LongWordTypeId);

  AModel.SetTypeScalarFact(BooleanTypeId, sskBool, 1, False);
  AModel.SetTypeScalarFact(CharTypeId, sskInt, 8, False);
  AModel.SetTypeScalarFact(WideCharTypeId, sskInt, 16, False);
  AModel.SetTypeScalarFact(ByteTypeId, sskInt, 8, False);
  AModel.SetTypeScalarFact(WordTypeId, sskInt, 16, False);
  AModel.SetTypeScalarFact(ShortIntTypeId, sskInt, 8, True);
  AModel.SetTypeScalarFact(SmallIntTypeId, sskInt, 16, True);
  AModel.SetTypeScalarFact(IntegerTypeId, sskInt, 32, True);
  AModel.SetTypeScalarFact(LongIntTypeId, sskInt, 32, True);
  AModel.SetTypeScalarFact(LongWordTypeId, sskInt, 32, False);
  AModel.SetTypeScalarFact(AModel.FindTypeByName('DWord'), sskInt, 32, False);
  AModel.SetTypeScalarFact(CardinalTypeId, sskInt, 32, False);
  AModel.SetTypeScalarFact(Int32TypeId, sskInt, 32, True);
  AModel.SetTypeScalarFact(Int64TypeId, sskInt, 64, True);
  AModel.SetTypeScalarFact(QWordTypeId, sskInt, 64, False);
  AModel.SetTypeScalarFact(SingleTypeId, sskFloat, 32, False);
  AModel.SetTypeScalarFact(DoubleTypeId, sskFloat, 64, False);
  AModel.SetTypeScalarFact(PointerTypeId, sskPointer, 64, False);

  { System types — TObject as root class, TClass as class-of pointer }
  AModel.AddType('TObject', 'class');
  AModel.AddType('TClass', 'alias');
  AModel.AddType('TGUID', 'record');
  AModel.AddType('IInterface', 'interface');
  AModel.AddType('IUnknown', 'interface');
  AModel.AddType('PSingle', 'alias');
  { Exception hierarchy — commonly used across core modules }
  AModel.AddType('Exception', 'class');
  AModel.AddType('EOutOfRange', 'class');
  AModel.AddType('EInvalidCast', 'class');
  AModel.AddType('EArgumentNilException', 'class');
  AModel.AddType('EInvalidOpException', 'class');
  AModel.SetTypeScalarFact(UInt32TypeId, sskInt, 32, False);
  AModel.SetTypeScalarFact(Int64TypeId, sskInt, 64, True);
  AModel.SetTypeScalarFact(QWordTypeId, sskInt, 64, False);
  AModel.SetTypeScalarFact(UInt64TypeId, sskInt, 64, False);
  AModel.SetTypeScalarFact(SingleTypeId, sskFloat, 32, False);
  AModel.SetTypeScalarFact(DoubleTypeId, sskFloat, 64, False);
  AModel.SetTypeScalarFact(PointerTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PByteTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PWordTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PInt32TypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PInt16TypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PInt64TypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PUInt64TypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PPointerTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PPtrIntTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PPtrUIntTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PCharTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PAnsiCharTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PUInt32TypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PDoubleTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PWideCharTypeId, sskPointer, 64, False);
  AModel.SetTypeScalarFact(PNativeUIntTypeId, sskPointer, 64, False);
end;

end.
