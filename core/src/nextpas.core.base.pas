unit nextpas.core.base;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

{ ============================================================ }
{ Framework identity                                           }
{ ============================================================ }

const
  NEXTPAS_CORE_NAME = 'nextpas.core';
  NEXTPAS_CORE_VERSION_MAJOR = 0;
  NEXTPAS_CORE_VERSION_MINOR = 1;
  NEXTPAS_CORE_VERSION_PATCH = 0;
  NEXTPAS_CORE_VERSION = '0.1.0';

{ ============================================================ }
{ Canonical type aliases                                       }
{ ============================================================ }

type
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
function HashInteger(const AValue: Int64): THashCode;
function HashPointer(const AValue: Pointer): THashCode;

implementation

{ TPair<TKey, TValue> }

class function TPair.Create(const AKey: TKey; const AValue: TValue): specialize TPair<TKey, TValue>;
begin
  Result.Key := AKey;
  Result.Value := AValue;
end;

{ TByteSpan }

class function TByteSpan.Create(const AData: PByte; const ALen: SizeUInt): TByteSpan;
begin
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
  if AOffset + ALength > Len then
    raise ERangeError.CreateFmt('TByteSpan.Slice: offset %d + length %d > span length %d',
      [AOffset, ALength, Len]);
  Result.Data := Data + AOffset;
  Result.Len := ALength;
end;

function TByteSpan.GetByte(const AIndex: SizeUInt): Byte;
begin
  if AIndex >= Len then
    raise ERangeError.CreateFmt('TByteSpan: index %d out of range [0..%d]', [AIndex, Len - 1]);
  Result := (Data + AIndex)^;
end;

{ Contract assertions }

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EArgumentException.Create(AMessage);
end;

procedure Ensure(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EAssertionFailed.Create(AMessage);
end;

procedure CheckState(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise EInvalidOpException.Create(AMessage);
end;

procedure Unreachable(const AMessage: string);
begin
  raise EAssertionFailed.Create(AMessage);
end;

{ Hash functions - FNV-1a }

const
  FNV_OFFSET_BASIS_32 = THashCode(2166136261);
  FNV_PRIME_32        = THashCode(16777619);

function HashBytes(const AData: PByte; const ALen: SizeUInt): THashCode;
var
  LI: SizeUInt;
begin
  Result := FNV_OFFSET_BASIS_32;
  for LI := 0 to ALen - 1 do
  begin
    Result := Result xor THashCode((AData + LI)^);
    Result := Result * FNV_PRIME_32;
  end;
end;

function HashString(const AValue: string): THashCode;
begin
  if Length(AValue) > 0 then
    Result := HashBytes(@AValue[1], SizeUInt(Length(AValue)))
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
