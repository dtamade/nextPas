unit nextpas.core.reflect.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.reflect.base;

type
  {**
   * ITypeVisitor - 类型字段访问者接口
   *
   * @desc
   *   visitor 模式遍历类型的所有字段，按类型分派到对应方法。
   *   用于序列化、JSON 导出、diff/patch、调试检查等场景。
   *}
  ITypeVisitor = interface
    ['{C1D2E3F4-5A6B-7C8D-9E0F-1A2B3C4D5E6F}']
    procedure BeginType(ATypeDef: PTypeDef; AData: Pointer);
    procedure EndType(ATypeDef: PTypeDef; AData: Pointer);
    function ShouldVisit(const AField: TFieldDef): Boolean;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean);
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32);
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64);
    procedure VisitUInt32(const AField: TFieldDef; APtr: PDWord);
    procedure VisitFloat32(const AField: TFieldDef; APtr: PSingle);
    procedure VisitFloat64(const AField: TFieldDef; APtr: PDouble);
    procedure VisitString(const AField: TFieldDef; APtr: PString);
    procedure VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef);
    procedure VisitPointer(const AField: TFieldDef; APtr: PPointer);
  end;

  {**
   * ITypeRegistry - 类型注册表接口
   *
   * @desc
   *   运行时类型注册、查找、字段访问。
   *   支持 builder 模式注册类型字段。
   *}
  ITypeRegistry = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function RegisterType(const AName: string; ASize: Integer): TTypeID;
    function AddField(ATypeID: TTypeID; const AName: string;
      AOffset: PtrUInt; AKind: TFieldKind; ASize: Integer = 0;
      AFlags: TFieldFlags = []): Boolean;
    function FindType(const AName: string): PTypeDef;
    function FindTypeByID(AID: TTypeID): PTypeDef;
    function GetTypeID(const AName: string): TTypeID;
    function HasType(const AName: string): Boolean;
    function GetFieldDef(const ATypeName, AFieldName: string): PFieldDef;
    function GetFieldPtr(const ATypeName, AFieldName: string; AData: Pointer): Pointer;
    procedure Visit(ATypeDef: PTypeDef; AData: Pointer; AVisitor: ITypeVisitor);
    function GetTypeCount: Integer;
  end;

implementation

end.
