program test_reflect;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.reflect;

var
  GTestPassed: Integer = 0;
  GTestFailed: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    Inc(GTestPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GTestFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

type
  TVector2 = packed record
    X, Y: Single;
  end;

  THealth = packed record
    HP: Int32;
    MaxHP: Int32;
    Alive: Boolean;
  end;

  TCollectorVisitor = class(TBaseTypeVisitor)
  public
    FloatSum: Double;
    IntSum: Int64;
    BoolCount: Integer;
    procedure VisitFloat32(const AField: TFieldDef; APtr: PSingle); override;
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32); override;
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64); override;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean); override;
  end;

procedure TCollectorVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle);
begin
  FloatSum := FloatSum + APtr^;
end;

procedure TCollectorVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
begin
  IntSum := IntSum + APtr^;
end;

procedure TCollectorVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
begin
  IntSum := IntSum + APtr^;
end;

procedure TCollectorVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
begin
  if APtr^ then Inc(BoolCount);
end;

procedure TestRegisterAndFind;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LDef: PTypeDef;
begin
  WriteLn('--- TestRegisterAndFind ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
  Check('ID > 0', LID > 0);
  Check('TypeCount=1', LReg.GetTypeCount = 1);
  Check('HasType', LReg.HasType('Vector2'));
  Check('Not has', not LReg.HasType('Unknown'));
  LDef := LReg.FindType('Vector2');
  Check('FindType not nil', LDef <> nil);
  Check('Name match', LDef^.Name = 'Vector2');
  Check('Size match', LDef^.Size = SizeOf(TVector2));
end;

procedure TestAddFields;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LDef: PTypeDef;
begin
  WriteLn('--- TestAddFields ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
  Check('AddField X', LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32));
  Check('AddField Y', LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32));
  LDef := LReg.FindTypeByID(LID);
  Check('FieldCount=2', LDef^.FieldCount = 2);
  Check('Field[0].Name=X', LDef^.Fields[0].Name = 'X');
  Check('Field[1].Name=Y', LDef^.Fields[1].Name = 'Y');
end;

procedure TestGetFieldDef;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LField: PFieldDef;
begin
  WriteLn('--- TestGetFieldDef ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Health', SizeOf(THealth));
  LReg.AddField(LID, 'HP', PtrUInt(@THealth(nil^).HP), fkInt32);
  LReg.AddField(LID, 'MaxHP', PtrUInt(@THealth(nil^).MaxHP), fkInt32);
  LReg.AddField(LID, 'Alive', PtrUInt(@THealth(nil^).Alive), fkBool);
  LField := LReg.GetFieldDef('Health', 'HP');
  Check('Found HP', LField <> nil);
  Check('HP offset=0', LField^.Offset = 0);
  LField := LReg.GetFieldDef('Health', 'Alive');
  Check('Found Alive', LField <> nil);
  Check('Alive kind=fkBool', LField^.Kind = fkBool);
  LField := LReg.GetFieldDef('Health', 'Missing');
  Check('Missing=nil', LField = nil);
end;

procedure TestGetFieldPtr;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LData: TVector2;
  LPtr: PSingle;
begin
  WriteLn('--- TestGetFieldPtr ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
  LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32);
  LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32);
  LData.X := 3.14;
  LData.Y := 2.71;
  LPtr := PSingle(LReg.GetFieldPtr('Vector2', 'X', @LData));
  Check('X ptr valid', LPtr <> nil);
  Check('X value', Abs(LPtr^ - 3.14) < 0.01);
  LPtr := PSingle(LReg.GetFieldPtr('Vector2', 'Y', @LData));
  Check('Y value', Abs(LPtr^ - 2.71) < 0.01);
end;

procedure TestVisitor;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LData: TVector2;
  LVisitor: ITypeVisitor;
  LCollector: TCollectorVisitor;
  LDef: PTypeDef;
begin
  WriteLn('--- TestVisitor ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
  LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32);
  LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32);
  LData.X := 10.0;
  LData.Y := 20.0;
  LCollector := TCollectorVisitor.Create;
  LVisitor := LCollector;
  LDef := LReg.FindType('Vector2');
  LReg.Visit(LDef, @LData, LVisitor);
  Check('FloatSum=30', Abs(LCollector.FloatSum - 30.0) < 0.01);
  LVisitor := nil;
end;

procedure TestVisitorMultiType;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LData: THealth;
  LVisitor: ITypeVisitor;
  LCollector: TCollectorVisitor;
  LDef: PTypeDef;
begin
  WriteLn('--- TestVisitorMultiType ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Health', SizeOf(THealth));
  LReg.AddField(LID, 'HP', PtrUInt(@THealth(nil^).HP), fkInt32);
  LReg.AddField(LID, 'MaxHP', PtrUInt(@THealth(nil^).MaxHP), fkInt32);
  LReg.AddField(LID, 'Alive', PtrUInt(@THealth(nil^).Alive), fkBool);
  LData.HP := 75;
  LData.MaxHP := 100;
  LData.Alive := True;
  LCollector := TCollectorVisitor.Create;
  LVisitor := LCollector;
  LDef := LReg.FindType('Health');
  LReg.Visit(LDef, @LData, LVisitor);
  Check('IntSum=175', LCollector.IntSum = 175);
  Check('BoolCount=1', LCollector.BoolCount = 1);
  LVisitor := nil;
end;

procedure TestDuplicateRegister;
var
  LReg: ITypeRegistry;
  LID1, LID2: TTypeID;
begin
  WriteLn('--- TestDuplicateRegister ---');
  LReg := CreateTypeRegistry;
  LID1 := LReg.RegisterType('Vec2', 8);
  LID2 := LReg.RegisterType('Vec2', 8);
  Check('Same ID', LID1 = LID2);
  Check('TypeCount=1', LReg.GetTypeCount = 1);
end;

procedure TestFieldFlags;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LField: PFieldDef;
begin
  WriteLn('--- TestFieldFlags ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Flagged', 4);
  LReg.AddField(LID, 'F1', 0, fkInt32, 0, [ffReadOnly, ffNetSync]);
  LField := LReg.GetFieldDef('Flagged', 'F1');
  Check('Has ReadOnly', ffReadOnly in LField^.Flags);
  Check('Has NetSync', ffNetSync in LField^.Flags);
  Check('No Transient', not (ffTransient in LField^.Flags));
end;

procedure TestAutoSize;
var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LDef: PTypeDef;
begin
  WriteLn('--- TestAutoSize ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Sizes', 32);
  LReg.AddField(LID, 'b', 0, fkBool);
  LReg.AddField(LID, 'i32', 1, fkInt32);
  LReg.AddField(LID, 'f64', 5, fkFloat64);
  LDef := LReg.FindTypeByID(LID);
  Check('Bool size=1', LDef^.Fields[0].Size = 1);
  Check('Int32 size=4', LDef^.Fields[1].Size = 4);
  Check('Float64 size=8', LDef^.Fields[2].Size = 8);
end;

begin
  WriteLn('=== nextpas.core.reflect tests ===');
  WriteLn;
  TestRegisterAndFind;
  TestAddFields;
  TestGetFieldDef;
  TestGetFieldPtr;
  TestVisitor;
  TestVisitorMultiType;
  TestDuplicateRegister;
  TestFieldFlags;
  TestAutoSize;
  WriteLn;
  WriteLn('=== Results: ', GTestPassed, ' passed, ', GTestFailed, ' failed ===');
  if GTestFailed > 0 then
    Halt(1);
end.
