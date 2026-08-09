unit System;

{$mode objfpc}{$H+}

{ Canonical compiler-root source. Refresh target projections with
  `make system-projection-sync`; do not edit installed copies directly. }

{$IFNDEF FPC}
interface

type
  { Basic ordinal types compatible with the stage0 surface. }
  Boolean = Boolean;
  ByteBool = Boolean;
  WordBool = Boolean;
  LongBool = Boolean;

  Byte = Byte;
  ShortInt = ShortInt;
  Word = Word;
  SmallInt = SmallInt;
  LongWord = LongWord;
  Cardinal = Cardinal;
  LongInt = LongInt;
  Integer = Integer;
  Int64 = Int64;
  QWord = QWord;

  { Pointer-sized types. }
  NativeInt = NativeInt;
  NativeUInt = NativeUInt;
  SizeInt = SizeInt;
  SizeUInt = SizeUInt;
  PtrInt = PtrInt;
  PtrUInt = PtrUInt;

  { Floating-point types. }
  Single = Single;
  Double = Double;
  Extended = Extended;
  Real = Real;
  Comp = Comp;
  Currency = Currency;

  { Character types. }
  Char = Char;
  AnsiChar = AnsiChar;
  WideChar = WideChar;

  { String types. }
  ShortString = ShortString;
  AnsiString = AnsiString;
  WideString = WideString;

  { Pointer types. }
  PChar = ^Char;
  PAnsiChar = ^AnsiChar;
  PByte = ^Byte;
  PWord = ^Word;
  PLongInt = ^LongInt;
  PLongWord = ^LongWord;
  PInt64 = ^Int64;
  PQWord = ^QWord;
  PPointer = ^Pointer;

  ByteSet = set of Byte;

  { Stage0 variant placeholder. }
  Variant = record end;

  { Minimum RTTI kind surface. }
  TTypeKind = (
    tkUnknown, tkInteger, tkChar, tkEnumeration, tkFloat,
    tkString, tkSet, tkClass, tkMethod, tkWChar, tkLString,
    tkWString, tkVariant, tkArray, tkRecord, tkInterface,
    tkInt64, tkQWord, tkBool, tkUChar, tkUString
  );

  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
    function ClassType: TClass;
    function ClassName: ShortString;
    function InheritsFrom(AClass: TClass): Boolean;
    function GetInterface(AIID: PtrUInt; out AObj: Pointer): Boolean;
    class function InstanceSize: SizeInt;
  end;

  TClass = class of TObject;

  TInterfacedObject = class(TObject)
    constructor Create;
    function _AddRef: LongInt; virtual;
    function _Release: LongInt; virtual;
  end;

  Exception = class(TObject)
    constructor Create;
    destructor Destroy; override;
  end;

  EAbort = class(Exception);
  ERangeError = class(Exception);
  EDivByZero = class(Exception);

  { Compiler intrinsic; no Pascal body is required. }
  procedure FreeAndNil(var Obj);

procedure np_process_init; cdecl;
procedure np_process_fini; cdecl;

const
  MaxInt = High(Integer);
  MaxLongint = High(LongInt);
  MaxSmallint = High(SmallInt);
  MaxLongWord = High(LongWord);
  MaxInt64 = High(Int64);
  MaxQWord = High(QWord);

  True = Boolean(1);
  False = Boolean(0);

  PathDelim = '/';
  DriveDelim = '';
  PathSep = ':';
  DirectorySeparator = '/';
  AllowDirectorySeparators = ['/'];
  AllowDriveSeparators = [];
  LineEnding = #10;
  LF = #10;
  CR = #13;
  sLineBreak = #10;

implementation

constructor TObject.Create;
begin
end;

destructor TObject.Destroy;
begin
end;

procedure TObject.Free;
begin
  if Self <> nil then
    Destroy;
end;

function TObject.ClassType: TClass;
begin
  { The first field of a TObject instance is its VMT pointer. }
  Result := TClass(PPointer(Self)^);
end;

function TObject.ClassName: ShortString;
begin
  Result := 'TObject';
end;

function TObject.InheritsFrom(AClass: TClass): Boolean;
var
  Cur: TClass;
begin
  Cur := TClass(ClassType);
  while Cur <> nil do
  begin
    if Cur = AClass then
      Exit(True);
    Cur := TClass(Pointer(PByte(Pointer(Cur))^));
  end;
  Result := False;
end;

function TObject.GetInterface(AIID: PtrUInt; out AObj: Pointer): Boolean;
begin
  { Interface query needs GUID/imt lookup (M2 B5f); until that lands report
    "not supported" — Supports() clears the out param on False itself. }
  Result := False;
end;

class function TObject.InstanceSize: SizeInt;
begin
  Result := 0;
end;

constructor TInterfacedObject.Create;
begin
end;

function TInterfacedObject._AddRef: LongInt;
begin
  Result := 1;
end;

function TInterfacedObject._Release: LongInt;
begin
  Result := 0;
end;

constructor Exception.Create;
begin
end;

destructor Exception.Destroy;
begin
  inherited Destroy;
end;

function InterlockedCompareExchange(var Target: Pointer; NewValue: Pointer;
  Comperand: Pointer): Pointer;
begin
  Result := Target;
  Target := NewValue;
end;

procedure np_process_init; cdecl; external name 'np_process_init';
procedure np_process_fini; cdecl; external name 'np_process_fini';

{$ELSE}
interface
implementation
{$ENDIF}

end.
