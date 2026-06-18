unit System;

{$mode objfpc}{$H+}

interface

type
  { 基础 ordinal 类型 — 与 FPC 兼容 }
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

  { 指针大小类型 }
  NativeInt = NativeInt;
  NativeUInt = NativeUInt;
  SizeInt = SizeInt;
  SizeUInt = SizeUInt;
  PtrInt = PtrInt;
  PtrUInt = PtrUInt;

  { 浮点类型 }
  Single = Single;
  Double = Double;
  Extended = Extended;
  Real = Real;
  Comp = Comp;
  Currency = Currency;

  { 字符类型 }
  Char = Char;
  AnsiChar = AnsiChar;
  WideChar = WideChar;

  { 字符串类型 }
  ShortString = ShortString;
  AnsiString = AnsiString;
  WideString = WideString;

  { 指针类型 }
  PChar = ^Char;
  PAnsiChar = ^AnsiChar;
  PByte = ^Byte;
  PWord = ^Word;
  PLongInt = ^LongInt;
  PLongWord = ^LongWord;
  PInt64 = ^Int64;
  PQWord = ^QWord;
  PPointer = ^Pointer;

  { 集合类型 }
  ByteSet = set of Byte;

  { 变体类型 — stage0 stub }
  Variant = record end;

  { TTypeKind — 最小 RTTI 支持 }
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

  { FreeAndNil — compiler inline, no body needed }
  procedure FreeAndNil(var Obj);

const
  { Ordinal 常量 }
  MaxInt = High(Integer);
  MaxLongint = High(LongInt);
  MaxSmallint = High(SmallInt);
  MaxLongWord = High(LongWord);
  MaxInt64 = High(Int64);
  MaxQWord = High(QWord);

  { 布尔常量 }
  True = Boolean(1);
  False = Boolean(0);

  { 路径分隔符 }
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
  { First field of any TObject instance is the VMT pointer }
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

end.
