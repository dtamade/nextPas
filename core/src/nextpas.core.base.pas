unit nextpas.core.base;
{**
 * @desc 框架根类型：基础类型定义、编译器设置。
 *}

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.exception;

{ ============================================================ }
{ Framework identity                                           }
{ ============================================================ }

const
  NEXTPAS_CORE_NAME = 'nextpas.core';
  NEXTPAS_CORE_VERSION_MAJOR = 0;
  NEXTPAS_CORE_VERSION_MINOR = 1;
  NEXTPAS_CORE_VERSION_PATCH = 0;
  NEXTPAS_CORE_VERSION = '0.1.0';

  MAX_SIZE_INT = High(SizeInt);
  MAX_SIZE_UINT = High(SizeUInt);
  MIN_SIZE_INT = Low(SizeInt);
  SIZE_PTR = SizeOf(Pointer);
  SIZE_8 = SizeOf(UInt8);
  SIZE_16 = SizeOf(UInt16);
  SIZE_32 = SizeOf(UInt32);
  SIZE_64 = SizeOf(UInt64);

{ ============================================================ }
{ Canonical type aliases                                       }
{ ============================================================ }

type
  TBytes = array of Byte;
  TStringArray = array of string;
  ECore = nextpas.core.exception.ENextPasError;
  EInvariantViolation = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EWow = EInvariantViolation;
  EArgumentNil = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EEmptyCollection = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EInvalidArgument = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EInvalidResult = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  ETimeoutError = nextpas.core.exception.ETimeoutError;
  EInvalidState = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EOutOfRange = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  ENotSupported = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  ENotCompatible = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EInvalidOperation = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;
  EOutOfMemoryError = nextpas.core.exception.EOutOfMemoryError;
  EOutOfMemory = nextpas.core.exception.EOutOfMemory;
  EOverflow = class(ECore)
  protected
    class function DefaultCategory: nextpas.core.exception.TErrorCategory; override;
  end;

  THashCode = UInt32;

{ ============================================================ }
{ Generic callback types                                       }
{ ============================================================ }

type
  TProc = reference to procedure;
  generic TProc1<T> = reference to procedure(const A: T);
  generic TProc2<T1, T2> = reference to procedure(const A1: T1; const A2: T2);
  generic TFunc0<TResult> = reference to function: TResult;
  generic TFunc1<T, TResult> = reference to function(const A: T): TResult;
  generic TFunc2<T1, T2, TResult> = reference to function(const A1: T1; const A2: T2): TResult;
  generic TPredicate<T> = reference to function(const A: T): Boolean;

{ ============================================================ }
{ Generic utility types                                        }
{ ============================================================ }

type
  generic TPair<TKey, TValue> = record
    Key: TKey;
    Value: TValue;
    class function Create(const AKey: TKey; const AValue: TValue): specialize TPair<TKey, TValue>; static; inline;
  end;

  generic TComparer<T> = reference to function(const A, B: T): Int32;
  generic TEqualityCheck<T> = reference to function(const A, B: T): Boolean;
  generic THasher<T> = reference to function(const A: T): THashCode;
  TRandomGeneratorFunc = function(ARange: Int64; AData: Pointer): Int64;
  TRandomGeneratorMethod = function(ARange: Int64; AData: Pointer): Int64 of object;
  TRandomGeneratorRefFunc = reference to function(ARange: Int64): Int64;

{ ============================================================ }
{ Generic value semantics                                      }
{ ============================================================ }

type
  generic TNullable<T> = record
  private
    FHasValue: Boolean;
    FValue: T;
    function GetHasValue: Boolean; inline;
    function GetIsNone: Boolean; inline;
    function GetValue: T;
  public
    class function Some(const AValue: T): specialize TNullable<T>; static;
    class function None: specialize TNullable<T>; static;
    function ValueOr(const ADefault: T): T; inline;
    property HasValue: Boolean read GetHasValue;
    property IsNone: Boolean read GetIsNone;
    property Value: T read GetValue;
  end;

  generic TOption<T> = record
  private
    FHasValue: Boolean;
    FValue: T;
    function GetIsSome: Boolean; inline;
    function GetIsNone: Boolean; inline;
    function GetUnwrap: T;
  public
    class function Some(const AValue: T): specialize TOption<T>; static;
    class function None: specialize TOption<T>; static;
    function UnwrapOr(const ADefault: T): T; inline;
    property IsSome: Boolean read GetIsSome;
    property IsNone: Boolean read GetIsNone;
    property Unwrap: T read GetUnwrap;
  end;

  generic TResult<T, E> = record
  private
    FIsOk: Boolean;
    FValue: T;
    FError: E;
    function GetIsOk: Boolean; inline;
    function GetIsErr: Boolean; inline;
    function GetUnwrap: T;
    function GetUnwrapErr: E;
  public
    class function Ok(const AValue: T): specialize TResult<T, E>; static;
    class function Err(const AError: E): specialize TResult<T, E>; static;
    function UnwrapOr(const ADefault: T): T; inline;
    property IsOk: Boolean read GetIsOk;
    property IsErr: Boolean read GetIsErr;
    property Unwrap: T read GetUnwrap;
    property UnwrapErr: E read GetUnwrapErr;
  end;

{ ============================================================ }
{ Non-owning byte span (view into existing memory)             }
{ ============================================================ }

type
  TByteSpan = record
    Data: PByte;
    Len: SizeUInt;
    class function Create(const AData: PByte; const ALen: SizeUInt): TByteSpan; static; inline;
    class function FromBytes(const ABytes: TBytes): TByteSpan; static; inline;
    class function Empty: TByteSpan; static; inline;
    function IsEmpty: Boolean; inline;
    function Slice(const AOffset, ALength: SizeUInt): TByteSpan;
    function GetByte(const AIndex: SizeUInt): Byte; inline;
    property Items[const AIndex: SizeUInt]: Byte read GetByte; default;
  end;

{ ============================================================ }
{ Contract assertions (design-by-contract)                     }
{ ============================================================ }

procedure Require(const ACondition: Boolean; const AMessage: string = 'precondition violated');
procedure Ensure(const ACondition: Boolean; const AMessage: string = 'postcondition violated');
procedure CheckState(const ACondition: Boolean; const AMessage: string = 'invalid state');
procedure Unreachable(const AMessage: string = 'unreachable code reached');

{ ============================================================ }
{ Common hash functions                                        }
{ ============================================================ }

function HashBytes(const AData: PByte; const ALen: SizeUInt): THashCode;
function HashString(const AValue: string): THashCode;
function HashString(const AValue: UnicodeString): THashCode; overload;
function HashInteger(const AValue: Int64): THashCode;
function HashPointer(const AValue: Pointer): THashCode;

implementation

{ Base validation exceptions }

class function EInvariantViolation.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInternal;
end;

class function EArgumentNil.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidArgument;
end;

class function EInvalidArgument.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidArgument;
end;

class function EInvalidResult.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInternal;
end;

class function EEmptyCollection.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidOperation;
end;

class function EInvalidState.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidOperation;
end;

class function EOutOfRange.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidArgument;
end;

class function ENotSupported.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecNotSupported;
end;

class function ENotCompatible.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidArgument;
end;

class function EInvalidOperation.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidOperation;
end;

class function EOverflow.DefaultCategory: nextpas.core.exception.TErrorCategory;
begin
  Result := nextpas.core.exception.ecInvalidArgument;
end;

{ TPair<TKey, TValue> }

class function TPair.Create(const AKey: TKey; const AValue: TValue): specialize TPair<TKey, TValue>;
begin
  Result.Key := AKey;
  Result.Value := AValue;
end;

{ TNullable<T> }

function TNullable.GetHasValue: Boolean;
begin
  Result := FHasValue;
end;

function TNullable.GetIsNone: Boolean;
begin
  Result := not FHasValue;
end;

function TNullable.GetValue: T;
begin
  if not FHasValue then
    raise EInvalidState.Create('TNullable has no value');
  Result := FValue;
end;

class function TNullable.Some(const AValue: T): specialize TNullable<T>;
begin
  Result := Default(specialize TNullable<T>);
  Result.FHasValue := True;
  Result.FValue := AValue;
end;

class function TNullable.None: specialize TNullable<T>;
begin
  Result := Default(specialize TNullable<T>);
end;

function TNullable.ValueOr(const ADefault: T): T;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

{ TOption<T> }

function TOption.GetIsSome: Boolean;
begin
  Result := FHasValue;
end;

function TOption.GetIsNone: Boolean;
begin
  Result := not FHasValue;
end;

function TOption.GetUnwrap: T;
begin
  if not FHasValue then
    raise EInvalidState.Create('TOption has no value');
  Result := FValue;
end;

class function TOption.Some(const AValue: T): specialize TOption<T>;
begin
  Result := Default(specialize TOption<T>);
  Result.FHasValue := True;
  Result.FValue := AValue;
end;

class function TOption.None: specialize TOption<T>;
begin
  Result := Default(specialize TOption<T>);
end;

function TOption.UnwrapOr(const ADefault: T): T;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

{ TResult<T, E> }

function TResult.GetIsOk: Boolean;
begin
  Result := FIsOk;
end;

function TResult.GetIsErr: Boolean;
begin
  Result := not FIsOk;
end;

function TResult.GetUnwrap: T;
begin
  if not FIsOk then
    raise EInvalidState.Create('TResult has no value');
  Result := FValue;
end;

function TResult.GetUnwrapErr: E;
begin
  if FIsOk then
    raise EInvalidState.Create('TResult has no error');
  Result := FError;
end;

class function TResult.Ok(const AValue: T): specialize TResult<T, E>;
begin
  Result := Default(specialize TResult<T, E>);
  Result.FIsOk := True;
  Result.FValue := AValue;
end;

class function TResult.Err(const AError: E): specialize TResult<T, E>;
begin
  Result := Default(specialize TResult<T, E>);
  Result.FError := AError;
end;

function TResult.UnwrapOr(const ADefault: T): T;
begin
  if FIsOk then
    Result := FValue
  else
    Result := ADefault;
end;

{ TByteSpan }

procedure RequireNonEmptyPointer(const AData: Pointer; const ALen: SizeUInt; const AContext: string);
begin
  if (ALen > 0) and (AData = nil) then
    raise EArgumentNil.Create(AContext + ': data is nil');
end;

class function TByteSpan.Create(const AData: PByte; const ALen: SizeUInt): TByteSpan;
begin
  RequireNonEmptyPointer(AData, ALen, 'TByteSpan.Create');
  Result.Data := AData;
  Result.Len := ALen;
end;

class function TByteSpan.FromBytes(const ABytes: TBytes): TByteSpan;
begin
  if Length(ABytes) > 0 then
  begin
    Result.Data := @ABytes[0];
    Result.Len := SizeUInt(Length(ABytes));
  end
  else
  begin
    Result.Data := nil;
    Result.Len := 0;
  end;
end;

class function TByteSpan.Empty: TByteSpan;
begin
  Result.Data := nil;
  Result.Len := 0;
end;

function TByteSpan.IsEmpty: Boolean;
begin
  Result := Len = 0;
end;

function TByteSpan.Slice(const AOffset, ALength: SizeUInt): TByteSpan;
begin
  RequireNonEmptyPointer(Data, Len, 'TByteSpan.Slice');
  if (AOffset > Len) or (ALength > Len - AOffset) then
    raise EOutOfRange.CreateFmt('TByteSpan.Slice: offset %d + length %d > span length %d',
      [AOffset, ALength, Len]);
  if ALength = 0 then
    Exit(TByteSpan.Empty);
  Result.Data := Data + AOffset;
  Result.Len := ALength;
end;

function TByteSpan.GetByte(const AIndex: SizeUInt): Byte;
begin
  RequireNonEmptyPointer(Data, Len, 'TByteSpan.GetByte');
  if AIndex >= Len then
  begin
    if Len = 0 then
      raise EOutOfRange.CreateFmt('TByteSpan: index %d out of range for empty span', [AIndex]);
    raise EOutOfRange.CreateFmt('TByteSpan: index %d out of range [0..%d]', [AIndex, Len - 1]);
  end;
  Result := (Data + AIndex)^;
end;

{ Contract assertions }

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EInvalidArgument.Create(AMessage);
end;

procedure Ensure(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EInvariantViolation.Create(AMessage);
end;

procedure CheckState(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EInvalidState.Create(AMessage);
end;

procedure Unreachable(const AMessage: string);
begin
  raise EInvariantViolation.Create(AMessage);
end;

{ Hash functions - FNV-1a }

const
  FNV_OFFSET_BASIS_32 = THashCode(2166136261);
  FNV_PRIME_32        = THashCode(16777619);

function FnvStep(const AHash: THashCode; const AByte: Byte): THashCode; inline;
begin
  {$PUSH}
  {$R-}
  {$Q-}
  Result := (AHash xor THashCode(AByte)) * FNV_PRIME_32;
  {$POP}
end;

function HashBytes(const AData: PByte; const ALen: SizeUInt): THashCode;
var
  LI: SizeUInt;
begin
  Result := FNV_OFFSET_BASIS_32;
  if ALen = 0 then
    Exit;
  RequireNonEmptyPointer(AData, ALen, 'HashBytes');
  for LI := 0 to ALen - 1 do
    Result := FnvStep(Result, (AData + LI)^);
end;

function HashString(const AValue: string): THashCode;
begin
  if Length(AValue) > 0 then
    Result := HashBytes(@AValue[1],
      SizeUInt(Length(AValue)) * SizeUInt(SizeOf(AValue[1])))
  else
    Result := FNV_OFFSET_BASIS_32;
end;

function HashString(const AValue: UnicodeString): THashCode;
begin
  if Length(AValue) > 0 then
    Result := HashBytes(PByte(@AValue[1]),
      SizeUInt(Length(AValue)) * SizeUInt(SizeOf(AValue[1])))
  else
    Result := FNV_OFFSET_BASIS_32;
end;

function HashInteger(const AValue: Int64): THashCode;
begin
  Result := HashBytes(@AValue, SizeOf(AValue));
end;

function HashPointer(const AValue: Pointer): THashCode;
begin
  Result := HashBytes(@AValue, SizeOf(AValue));
end;

end.
