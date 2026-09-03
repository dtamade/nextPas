program test_reflect;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.reflect,
  nextpas.core.test, nextpas.core.math;

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
begin FloatSum := FloatSum + APtr^; end;

procedure TCollectorVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
begin IntSum := IntSum + APtr^; end;

procedure TCollectorVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
begin IntSum := IntSum + APtr^; end;

procedure TCollectorVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
begin if APtr^ then Inc(BoolCount); end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('reflect');

  LSuite.Test('register and find', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LDef: PTypeDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
    CheckTrue(LID > 0);
    CheckEqual(1, LReg.GetTypeCount);
    CheckTrue(LReg.HasType('Vector2'));
    CheckTrue(not LReg.HasType('Unknown'));
    LDef := LReg.FindType('Vector2');
    CheckTrue(LDef <> nil);
    CheckEqual('Vector2', LDef^.Name);
    CheckEqual(SizeOf(TVector2), LDef^.Size);
  end);

  LSuite.Test('add fields', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LDef: PTypeDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
    CheckTrue(LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32));
    CheckTrue(LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32));
    LDef := LReg.FindTypeByID(LID);
    CheckEqual(2, LDef^.FieldCount);
    CheckEqual('X', LDef^.Fields[0].Name);
    CheckEqual('Y', LDef^.Fields[1].Name);
  end);

  LSuite.Test('get field def', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LField: PFieldDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Health', SizeOf(THealth));
    LReg.AddField(LID, 'HP', PtrUInt(@THealth(nil^).HP), fkInt32);
    LReg.AddField(LID, 'MaxHP', PtrUInt(@THealth(nil^).MaxHP), fkInt32);
    LReg.AddField(LID, 'Alive', PtrUInt(@THealth(nil^).Alive), fkBool);
    LField := LReg.GetFieldDef('Health', 'HP');
    CheckTrue(LField <> nil);
    CheckEqual(0, LField^.Offset);
    LField := LReg.GetFieldDef('Health', 'Alive');
    CheckTrue(LField <> nil);
    CheckTrue(LField^.Kind = fkBool);
    LField := LReg.GetFieldDef('Health', 'Missing');
    CheckTrue(LField = nil);
  end);

  LSuite.Test('get field ptr', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LData: TVector2; LPtr: PSingle;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
    LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32);
    LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32);
    LData.X := 3.14; LData.Y := 2.71;
    LPtr := PSingle(LReg.GetFieldPtr('Vector2', 'X', @LData));
    CheckTrue(LPtr <> nil);
    CheckTrue(Abs(LPtr^ - 3.14) < 0.01);
    LPtr := PSingle(LReg.GetFieldPtr('Vector2', 'Y', @LData));
    CheckTrue(Abs(LPtr^ - 2.71) < 0.01);
  end);

  LSuite.Test('visitor', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LData: TVector2;
    LVisitor: ITypeVisitor; LCollector: TCollectorVisitor; LDef: PTypeDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Vector2', SizeOf(TVector2));
    LReg.AddField(LID, 'X', PtrUInt(@TVector2(nil^).X), fkFloat32);
    LReg.AddField(LID, 'Y', PtrUInt(@TVector2(nil^).Y), fkFloat32);
    LData.X := 10.0; LData.Y := 20.0;
    LCollector := TCollectorVisitor.Create;
    LVisitor := LCollector;
    LDef := LReg.FindType('Vector2');
    LReg.Visit(LDef, @LData, LVisitor);
    CheckTrue(Abs(LCollector.FloatSum - 30.0) < 0.01);
    LVisitor := nil;
  end);

  LSuite.Test('visitor multi-type', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LData: THealth;
    LVisitor: ITypeVisitor; LCollector: TCollectorVisitor; LDef: PTypeDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Health', SizeOf(THealth));
    LReg.AddField(LID, 'HP', PtrUInt(@THealth(nil^).HP), fkInt32);
    LReg.AddField(LID, 'MaxHP', PtrUInt(@THealth(nil^).MaxHP), fkInt32);
    LReg.AddField(LID, 'Alive', PtrUInt(@THealth(nil^).Alive), fkBool);
    LData.HP := 75; LData.MaxHP := 100; LData.Alive := True;
    LCollector := TCollectorVisitor.Create;
    LVisitor := LCollector;
    LDef := LReg.FindType('Health');
    LReg.Visit(LDef, @LData, LVisitor);
    CheckEqual(Int64(175), LCollector.IntSum);
    CheckEqual(1, LCollector.BoolCount);
    LVisitor := nil;
  end);

  LSuite.Test('duplicate register', procedure
  var LReg: ITypeRegistry; LID1, LID2: TTypeID;
  begin
    LReg := CreateTypeRegistry;
    LID1 := LReg.RegisterType('Vec2', 8);
    LID2 := LReg.RegisterType('Vec2', 8);
    CheckTrue(LID1 = LID2);
    CheckEqual(1, LReg.GetTypeCount);
  end);

  LSuite.Test('field flags', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LField: PFieldDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Flagged', 4);
    LReg.AddField(LID, 'F1', 0, fkInt32, 0, [ffReadOnly, ffNetSync]);
    LField := LReg.GetFieldDef('Flagged', 'F1');
    CheckTrue(ffReadOnly in LField^.Flags);
    CheckTrue(ffNetSync in LField^.Flags);
    CheckTrue(not (ffTransient in LField^.Flags));
  end);

  LSuite.Test('auto size', procedure
  var LReg: ITypeRegistry; LID: TTypeID; LDef: PTypeDef;
  begin
    LReg := CreateTypeRegistry;
    LID := LReg.RegisterType('Sizes', 32);
    LReg.AddField(LID, 'b', 0, fkBool);
    LReg.AddField(LID, 'i32', 1, fkInt32);
    LReg.AddField(LID, 'f64', 5, fkFloat64);
    LDef := LReg.FindTypeByID(LID);
    CheckEqual(1, LDef^.Fields[0].Size);
    CheckEqual(4, LDef^.Fields[1].Size);
    CheckEqual(8, LDef^.Fields[2].Size);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.reflect');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
