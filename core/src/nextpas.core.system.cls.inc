{**
 * @desc Class types for the nextPas system kernel.
 *
 * Defines VMT constants, TVmt record, TObject, TClass.
 * Contains {$compiler_root} directive for TObject.
 * Depends on base.inc, str.inc, intf.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

const
  { VMT layout constants — must match FPC layout }
  vmtInstanceSize = 0;
  vmtParent = SizeOf(SizeInt) * 2;
  vmtClassName = SizeOf(SizeInt) * 3;
  vmtDynamicTable = SizeOf(SizeInt) * 4;
  vmtMethodTable = SizeOf(SizeInt) * 5;
  vmtFieldTable = SizeOf(SizeInt) * 6;
  vmtTypeInfo = SizeOf(SizeInt) * 7;
  vmtInitTable = SizeOf(SizeInt) * 8;
  vmtAutoTable = SizeOf(SizeInt) * 9;
  vmtIntfTable = SizeOf(SizeInt) * 10;
  vmtMsgStrPtr = SizeOf(SizeInt) * 11;
  vmtDestroy = SizeOf(SizeInt) * 12;
  vmtNewInstance = SizeOf(SizeInt) * 13;
  vmtFreeInstance = SizeOf(SizeInt) * 14;
  vmtDefaultHandler = SizeOf(SizeInt) * 15;
  vmtAfterConstruction = SizeOf(SizeInt) * 16;
  vmtBeforeDestruction = SizeOf(SizeInt) * 17;
  vmtDefaultHandlerStr = SizeOf(SizeInt) * 18;
  vmtDispatch = SizeOf(SizeInt) * 19;
  vmtDispatchStr = SizeOf(SizeInt) * 20;
  vmtEquals = SizeOf(SizeInt) * 21;
  vmtGetHashCode = SizeOf(SizeInt) * 22;
  vmtToString = SizeOf(SizeInt) * 23;
  vmtSafeCallException = SizeOf(SizeInt) * 24;
  vmtGetInterface = SizeOf(SizeInt) * 25;
  vmtGetInterfaceWeak = SizeOf(SizeInt) * 26;
  vmtGetInterfaceStrong = SizeOf(SizeInt) * 27;

type
  { Forward declarations }
  TObject = class;
  TClass = class of TObject;

  { VMT record }
  PVmt = ^TVmt;
  TVmt = record
    InstanceSize: SizeInt;
    Parent: TClass;
    ClassName: PShortString;
    DynamicTable: Pointer;
    MethodTable: Pointer;
    FieldTable: Pointer;
    TypeInfo: Pointer;
    InitTable: Pointer;
    AutoTable: Pointer;
    IntfTable: PInterfaceTable;
    MsgStrPtr: Pointer;
    Destroy: procedure(Self: TObject);
    NewInstance: function(Self: TClass): TObject;
    FreeInstance: procedure(Self: TObject);
    DefaultHandler: procedure(Self: TObject; var Message);
    AfterConstruction: procedure(Self: TObject);
    BeforeDestruction: procedure(Self: TObject);
    DefaultHandlerStr: procedure(Self: TObject; var Message);
    Dispatch: procedure(Self: TObject; var Message);
    DispatchStr: procedure(Self: TObject; var Message);
    Equals: function(Self: TObject; Obj: TObject): Boolean;
    GetHashCode: function(Self: TObject): SizeInt;
    ToString: function(Self: TObject): AnsiString;
    SafeCallException: function(Self: TObject; ExceptObject: TObject; ExceptAddr: Pointer): LongInt;
    GetInterface: function(Self: TObject; const IID: TGUID; out Obj): Boolean;
    GetInterfaceWeak: function(Self: TObject; const IID: TGUID; out Obj): Boolean;
    GetInterfaceStrong: function(Self: TObject; const IID: TGUID; out Obj): Boolean;
  end;

  { TObject — compiler root class }
{$compiler_root}
  TObject = class
  private
    function GetClassType: TClass;
  public
    constructor Create;
    procedure Free;
    procedure Destroy;
    class function InitInstance(Self: Pointer): TObject;
    procedure CleanupInstance;
    class function ClassType: TClass;
    class function ClassName: ShortString;
    class function ClassNameIs(const Name: string): Boolean;
    class function ClassParent: TClass;
    class function InstanceSize: SizeInt;
    class function InheritsFrom(AClass: TClass): Boolean;
    class function StringMessageTable: Pointer;
    class function GetInterfaceEntry(const IID: TGUID): PInterfaceEntry;
    class function GetInterfaceTable: PInterfaceTable;
    class function GetInterfaceCount: SizeInt;
    class function GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
    class function GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;
    function GetInterface(const IID: TGUID; out Obj): Boolean;
    function GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
    function GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;
    function Equals(Obj: TObject): Boolean; virtual;
    function GetHashCode: SizeInt; virtual;
    function ToString: AnsiString; virtual;
    function SafeCallException(ExceptObject: TObject; ExceptAddr: Pointer): LongInt; virtual;
    procedure Dispatch(var Message); virtual;
    procedure DispatchStr(var Message); virtual;
    procedure DefaultHandler(var Message); virtual;
    procedure DefaultHandlerStr(var Message); virtual;
    procedure AfterConstruction; virtual;
    procedure BeforeDestruction; virtual;
    procedure Initialize; virtual;
    procedure Finalize; virtual;
    property ClassType: TClass read GetClassType;
  end;

  { TClass — class of TObject }
  TClass = class of TObject;

implementation

{ TObject implementation }

function TObject.GetClassType: TClass;
begin
  Result := TClass(PPointer(Self)^);
end;

constructor TObject.Create;
begin
end;

procedure TObject.Free;
begin
  if Self <> nil then
    Destroy;
end;

procedure TObject.Destroy;
begin
  BeforeDestruction;
  CleanupInstance;
end;

class function TObject.InitInstance(Self: Pointer): TObject;
begin
  FillChar(Self^, InstanceSize, 0);
  PPointer(Self)^ := Pointer(Self);
  Result := TObject(Self);
end;

procedure TObject.CleanupInstance;
begin
end;

class function TObject.ClassType: TClass;
begin
  Result := Self;
end;

class function TObject.ClassName: ShortString;
begin
  Result := PShortString(PPointer(Pointer(Self) + vmtClassName)^)^;
end;

class function TObject.ClassNameIs(const Name: string): Boolean;
begin
  Result := SameText(ClassName, Name);
end;

class function TObject.ClassParent: TClass;
begin
  Result := TClass(PPointer(Pointer(Self) + vmtParent)^);
end;

class function TObject.InstanceSize: SizeInt;
begin
  Result := PSizeInt(Pointer(Self) + vmtInstanceSize)^;
end;

class function TObject.InheritsFrom(AClass: TClass): Boolean;
var
  LClass: TClass;
begin
  LClass := Self;
  while (LClass <> nil) and (LClass <> AClass) do
    LClass := LClass.ClassParent;
  Result := LClass = AClass;
end;

class function TObject.StringMessageTable: Pointer;
begin
  Result := PPointer(Pointer(Self) + vmtMsgStrPtr)^;
end;

class function TObject.GetInterfaceEntry(const IID: TGUID): PInterfaceEntry;
var
  LTable: PInterfaceTable;
  I: SizeInt;
begin
  Result := nil;
  LTable := GetInterfaceTable;
  if LTable <> nil then
    for I := 0 to LTable.EntryCount - 1 do
      if LTable.Entries[I].IID = IID then
        Exit(@LTable.Entries[I]);
end;

class function TObject.GetInterfaceTable: PInterfaceTable;
begin
  Result := PInterfaceTable(PPointer(Pointer(Self) + vmtIntfTable)^);
end;

class function TObject.GetInterfaceCount: SizeInt;
var
  LTable: PInterfaceTable;
begin
  LTable := GetInterfaceTable;
  if LTable <> nil then
    Result := LTable.EntryCount
  else
    Result := 0;
end;

class function TObject.GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
var
  LEntry: PInterfaceEntry;
begin
  Result := False;
  LEntry := GetInterfaceEntry(IID);
  if LEntry <> nil then
  begin
    Pointer(Obj) := Pointer(Self) + LEntry.IOffset;
    Result := True;
  end;
end;

class function TObject.GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;
begin
  Result := GetInterfaceWeak(IID, Obj);
  if Result then
    IUnknown(Obj)._AddRef;
end;

function TObject.GetInterface(const IID: TGUID; out Obj): Boolean;
begin
  Result := GetClassType.GetInterfaceWeak(IID, Obj);
end;

function TObject.GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
begin
  Result := GetClassType.GetInterfaceWeak(IID, Obj);
end;

function TObject.GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;
begin
  Result := GetClassType.GetInterfaceStrong(IID, Obj);
end;

function TObject.Equals(Obj: TObject): Boolean;
begin
  Result := Self = Obj;
end;

function TObject.GetHashCode: SizeInt;
begin
  Result := SizeInt(Self);
end;

function TObject.ToString: AnsiString;
begin
  Result := ClassName;
end;

function TObject.SafeCallException(ExceptObject: TObject; ExceptAddr: Pointer): LongInt;
begin
  Result := 0;
end;

procedure TObject.Dispatch(var Message);
begin
  DefaultHandler(Message);
end;

procedure TObject.DispatchStr(var Message);
begin
  DefaultHandlerStr(Message);
end;

procedure TObject.DefaultHandler(var Message);
begin
end;

procedure TObject.DefaultHandlerStr(var Message);
begin
end;

procedure TObject.AfterConstruction;
begin
end;

procedure TObject.BeforeDestruction;
begin
end;

procedure TObject.Initialize;
begin
end;

procedure TObject.Finalize;
begin
end;
