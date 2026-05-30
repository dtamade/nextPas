program test_reflect_edge;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.reflect;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure TestFindNonExistent;
var LReg: ITypeRegistry;
begin
  WriteLn('--- TestFindNonExistent ---');
  LReg := CreateTypeRegistry;
  Check('FindType nil', LReg.FindType('NoSuch') = nil);
  Check('FindByID nil', LReg.FindTypeByID(9999) = nil);
  Check('GetTypeID=0', LReg.GetTypeID('NoSuch') = TYPE_ID_NONE);
  Check('GetFieldDef nil', LReg.GetFieldDef('NoSuch', 'X') = nil);
  Check('GetFieldPtr nil', LReg.GetFieldPtr('NoSuch', 'X', nil) = nil);
end;

procedure TestNilDataFieldPtr;
var LReg: ITypeRegistry; LID: TTypeID;
begin
  WriteLn('--- TestNilDataFieldPtr ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('T', 4);
  LReg.AddField(LID, 'F', 0, fkInt32);
  Check('Nil data returns nil', LReg.GetFieldPtr('T', 'F', nil) = nil);
end;

procedure TestMaxFields;
var LReg: ITypeRegistry; LID: TTypeID; LIdx: Integer; LOk: Boolean;
begin
  WriteLn('--- TestMaxFields ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Big', 256);
  for LIdx := 0 to REFLECT_MAX_FIELDS - 1 do
    LReg.AddField(LID, 'f' + IntToStr(LIdx), LIdx, fkInt32);
  LOk := LReg.AddField(LID, 'overflow', 0, fkInt32);
  Check('Max fields overflow returns false', not LOk);
  Check('FieldCount=32', LReg.FindType('Big')^.FieldCount = REFLECT_MAX_FIELDS);
end;

procedure TestVisitNilParams;
var LReg: ITypeRegistry;
begin
  WriteLn('--- TestVisitNilParams ---');
  LReg := CreateTypeRegistry;
  LReg.Visit(nil, nil, nil);
  Check('No crash on nil visit', True);
end;

procedure TestEmptyTypeName;
var LReg: ITypeRegistry; LID: TTypeID;
begin
  WriteLn('--- TestEmptyTypeName ---');
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('', 4);
  Check('Empty name registers', LID > 0);
  Check('Can find empty', LReg.HasType(''));
end;

procedure TestAddFieldToInvalidType;
var LReg: ITypeRegistry; LOk: Boolean;
begin
  WriteLn('--- TestAddFieldToInvalidType ---');
  LReg := CreateTypeRegistry;
  LOk := LReg.AddField(9999, 'X', 0, fkFloat32);
  Check('Invalid type returns false', not LOk);
end;

begin
  WriteLn('=== nextpas.core.reflect edge tests ===');
  WriteLn;
  TestFindNonExistent;
  TestNilDataFieldPtr;
  TestMaxFields;
  TestVisitNilParams;
  TestEmptyTypeName;
  TestAddFieldToInvalidType;
  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
