program test_json_marshal;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.reflect,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.marshal;

var
  T: TTestRunner;
  Reg: ITypeRegistry;

type
  TIntArray = array of Int32;
  TStrArray = array of string;

  TPoint = record
    X: Int32;
    Y: Int32;
  end;

  TPointArray = array of TPoint;

  TUser = record
    Id: Int64;
    Name: string;
    Email: string;
    Active: Boolean;
    Score: Double;
  end;

  TAddress = record
    City: string;
    Zip: Int32;
  end;

  TPerson = record
    Name: string;
    Age: Int32;
    Addr: TAddress;
  end;

  TData = record
    Name: string;
    Numbers: TIntArray;
    Tags: TStrArray;
    Points: TPointArray;
  end;

var
  PointTypeID, UserTypeID, AddrTypeID, PersonTypeID, DataTypeID: TTypeID;

procedure RegisterTypes;
begin
  Reg := CreateTypeRegistry;

  PointTypeID := Reg.RegisterType('Point', SizeOf(TPoint));
  Reg.AddField(PointTypeID, 'x', PtrUInt(@TPoint(nil^).X), fkInt32);
  Reg.AddField(PointTypeID, 'y', PtrUInt(@TPoint(nil^).Y), fkInt32);

  UserTypeID := Reg.RegisterType('User', SizeOf(TUser));
  Reg.AddField(UserTypeID, 'id', PtrUInt(@TUser(nil^).Id), fkInt64);
  Reg.AddField(UserTypeID, 'name', PtrUInt(@TUser(nil^).Name), fkString);
  Reg.AddField(UserTypeID, 'email', PtrUInt(@TUser(nil^).Email), fkString);
  Reg.AddField(UserTypeID, 'active', PtrUInt(@TUser(nil^).Active), fkBool);
  Reg.AddField(UserTypeID, 'score', PtrUInt(@TUser(nil^).Score), fkFloat64);

  AddrTypeID := Reg.RegisterType('Address', SizeOf(TAddress));
  Reg.AddField(AddrTypeID, 'city', PtrUInt(@TAddress(nil^).City), fkString);
  Reg.AddField(AddrTypeID, 'zip', PtrUInt(@TAddress(nil^).Zip), fkInt32);

  PersonTypeID := Reg.RegisterType('Person', SizeOf(TPerson));
  Reg.AddField(PersonTypeID, 'name', PtrUInt(@TPerson(nil^).Name), fkString);
  Reg.AddField(PersonTypeID, 'age', PtrUInt(@TPerson(nil^).Age), fkInt32);
  Reg.AddField(PersonTypeID, 'addr', PtrUInt(@TPerson(nil^).Addr), fkRecord,
    SizeOf(TAddress));
  Reg.GetFieldDef('Person', 'addr')^.SubTypeID := AddrTypeID;

  DataTypeID := Reg.RegisterType('Data', SizeOf(TData));
  Reg.AddField(DataTypeID, 'name', PtrUInt(@TData(nil^).Name), fkString);
  Reg.AddDynArrayField(DataTypeID, 'numbers', PtrUInt(@TData(nil^).Numbers),
    fkInt32, SizeOf(Int32), TypeInfo(TIntArray));
  Reg.AddDynArrayField(DataTypeID, 'tags', PtrUInt(@TData(nil^).Tags),
    fkString, SizeOf(string), TypeInfo(TStrArray));
  Reg.AddDynArrayField(DataTypeID, 'points', PtrUInt(@TData(nil^).Points),
    fkRecord, SizeOf(TPoint), TypeInfo(TPointArray), PointTypeID);
end;

procedure TestMarshalSimple;
var P: TPoint; S: string;
begin
  P.X := 10; P.Y := 20;
  S := JsonMarshal(Reg, Reg.FindType('Point'), @P);
  Check(Pos('"x":10', S) > 0, 'has x:10');
  Check(Pos('"y":20', S) > 0, 'has y:20');
end;

procedure TestMarshalAllTypes;
var U: TUser; S: string;
begin
  U.Id := 42;
  U.Name := 'Alice';
  U.Email := 'alice@example.com';
  U.Active := True;
  U.Score := 3.14;
  S := JsonMarshal(Reg, Reg.FindType('User'), @U);
  Check(Pos('"id":42', S) > 0, 'has id');
  Check(Pos('"name":"Alice"', S) > 0, 'has name');
  Check(Pos('"email":"alice@example.com"', S) > 0, 'has email');
  Check(Pos('"active":true', S) > 0, 'has active');
  Check(Pos('"score":', S) > 0, 'has score');
end;

procedure TestMarshalNested;
var P: TPerson; S: string;
begin
  P.Name := 'Bob';
  P.Age := 30;
  P.Addr.City := 'NYC';
  P.Addr.Zip := 10001;
  S := JsonMarshal(Reg, Reg.FindType('Person'), @P);
  Check(Pos('"name":"Bob"', S) > 0, 'has name');
  Check(Pos('"age":30', S) > 0, 'has age');
  Check(Pos('"addr":{', S) > 0, 'has nested addr');
  Check(Pos('"city":"NYC"', S) > 0, 'has city');
  Check(Pos('"zip":10001', S) > 0, 'has zip');
end;

procedure TestMarshalEscape;
var U: TUser; S: string;
begin
  U.Id := 1;
  U.Name := 'He said "hello"';
  U.Email := 'a\b';
  U.Active := False;
  U.Score := 0;
  S := JsonMarshal(Reg, Reg.FindType('User'), @U);
  Check(Pos('\"hello\"', S) > 0, 'quotes escaped');
  Check(Pos('a\\b', S) > 0, 'backslash escaped');
end;

procedure TestUnmarshalSimple;
var P: TPoint; Ok: Boolean;
begin
  P.X := 0; P.Y := 0;
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Point'), '{"x":99,"y":-5}', @P);
  Check(Ok, 'unmarshal ok');
  CheckEqual(Int64(99), Int64(P.X), 'x=99');
  CheckEqual(Int64(-5), Int64(P.Y), 'y=-5');
end;

procedure TestUnmarshalAllTypes;
var U: TUser; Ok: Boolean;
begin
  FillChar(U, SizeOf(U), 0);
  U.Name := ''; U.Email := '';
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('User'),
    '{"id":100,"name":"Eve","email":"eve@x.com","active":true,"score":2.5}', @U);
  Check(Ok, 'unmarshal ok');
  CheckEqual(Int64(100), U.Id, 'id');
  CheckEqual('Eve', U.Name, 'name');
  CheckEqual('eve@x.com', U.Email, 'email');
  Check(U.Active, 'active');
end;

procedure TestUnmarshalNested;
var P: TPerson; Ok: Boolean;
begin
  FillChar(P, SizeOf(P), 0);
  P.Name := ''; P.Addr.City := '';
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Person'),
    '{"name":"Carol","age":25,"addr":{"city":"LA","zip":90001}}', @P);
  Check(Ok, 'unmarshal ok');
  CheckEqual('Carol', P.Name, 'name');
  CheckEqual(Int64(25), Int64(P.Age), 'age');
  CheckEqual('LA', P.Addr.City, 'city');
  CheckEqual(Int64(90001), Int64(P.Addr.Zip), 'zip');
end;

procedure TestUnmarshalMissing;
var P: TPoint; Ok: Boolean;
begin
  P.X := 77; P.Y := 88;
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Point'), '{"x":5}', @P);
  Check(Ok, 'unmarshal ok');
  CheckEqual(Int64(5), Int64(P.X), 'x=5');
  CheckEqual(Int64(88), Int64(P.Y), 'y unchanged');
end;

procedure TestRoundTrip;
var U, U2: TUser; S: string; Ok: Boolean;
begin
  U.Id := 999;
  U.Name := 'RoundTrip';
  U.Email := 'rt@test.io';
  U.Active := True;
  U.Score := 1.5;
  S := JsonMarshal(Reg, Reg.FindType('User'), @U);
  FillChar(U2, SizeOf(U2), 0);
  U2.Name := ''; U2.Email := '';
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('User'), S, @U2);
  Check(Ok, 'roundtrip ok');
  CheckEqual(Int64(999), U2.Id, 'id');
  CheckEqual('RoundTrip', U2.Name, 'name');
  CheckEqual('rt@test.io', U2.Email, 'email');
  Check(U2.Active, 'active');
end;

procedure TestMarshalIntArray;
var D: TData; S: string;
begin
  D.Name := 'ints';
  D.Tags := nil;
  D.Points := nil;
  SetLength(D.Numbers, 3);
  D.Numbers[0] := 1;
  D.Numbers[1] := 2;
  D.Numbers[2] := 3;

  S := JsonMarshal(Reg, Reg.FindType('Data'), @D);

  Check(Pos('"numbers":[1,2,3]', S) > 0, 'marshal int array');
end;

procedure TestUnmarshalIntArray;
var D: TData; Ok: Boolean;
begin
  D.Name := '';
  D.Numbers := nil;
  D.Tags := nil;
  D.Points := nil;

  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"numbers":[1,2,3]}', @D);

  Check(Ok, 'unmarshal int array ok');
  CheckEqual(Int64(3), Int64(Length(D.Numbers)), 'numbers len');
  CheckEqual(Int64(1), Int64(D.Numbers[0]), 'numbers[0]');
  CheckEqual(Int64(2), Int64(D.Numbers[1]), 'numbers[1]');
  CheckEqual(Int64(3), Int64(D.Numbers[2]), 'numbers[2]');
end;

procedure TestStringArray;
var D: TData; S: string; Ok: Boolean;
begin
  D.Name := 'strings';
  D.Numbers := nil;
  D.Points := nil;
  SetLength(D.Tags, 2);
  D.Tags[0] := 'red';
  D.Tags[1] := 'blue';

  S := JsonMarshal(Reg, Reg.FindType('Data'), @D);
  Check(Pos('"tags":["red","blue"]', S) > 0, 'marshal string array');

  D.Tags := nil;
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"tags":["alpha","beta"]}', @D);
  Check(Ok, 'unmarshal string array ok');
  CheckEqual(Int64(2), Int64(Length(D.Tags)), 'tags len');
  CheckEqual('alpha', D.Tags[0], 'tags[0]');
  CheckEqual('beta', D.Tags[1], 'tags[1]');
end;

procedure TestRecordArray;
var D: TData; S: string; Ok: Boolean;
begin
  D.Name := 'points';
  D.Numbers := nil;
  D.Tags := nil;
  SetLength(D.Points, 2);
  D.Points[0].X := 1;
  D.Points[0].Y := 2;
  D.Points[1].X := 3;
  D.Points[1].Y := 4;

  S := JsonMarshal(Reg, Reg.FindType('Data'), @D);
  Check(Pos('"points":[{"x":1,"y":2},{"x":3,"y":4}]', S) > 0, 'marshal record array');

  D.Points := nil;
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'),
    '{"points":[{"x":10,"y":20},{"x":30,"y":40}]}', @D);
  Check(Ok, 'unmarshal record array ok');
  CheckEqual(Int64(2), Int64(Length(D.Points)), 'points len');
  CheckEqual(Int64(10), Int64(D.Points[0].X), 'points[0].x');
  CheckEqual(Int64(20), Int64(D.Points[0].Y), 'points[0].y');
  CheckEqual(Int64(30), Int64(D.Points[1].X), 'points[1].x');
  CheckEqual(Int64(40), Int64(D.Points[1].Y), 'points[1].y');
end;

procedure TestEmptyArray;
var D: TData; Ok: Boolean; S: string;
begin
  D.Name := 'empty';
  D.Tags := nil;
  D.Points := nil;
  SetLength(D.Numbers, 0);

  S := JsonMarshal(Reg, Reg.FindType('Data'), @D);
  Check(Pos('"numbers":[]', S) > 0, 'marshal empty array');

  SetLength(D.Numbers, 1);
  D.Numbers[0] := 42;
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"numbers":[]}', @D);
  Check(Ok, 'unmarshal empty array ok');
  CheckEqual(Int64(0), Int64(Length(D.Numbers)), 'empty len');
end;

procedure TestNullArray;
var D: TData; Ok: Boolean;
begin
  D.Name := 'null';
  D.Tags := nil;
  D.Points := nil;
  SetLength(D.Numbers, 2);
  D.Numbers[0] := 7;
  D.Numbers[1] := 8;

  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"numbers":null}', @D);

  Check(Ok, 'unmarshal null array ok');
  Check(D.Numbers = nil, 'numbers nil after null');
end;

procedure TestArrayReplacement;
var D: TData; Ok: Boolean;
begin
  D.Name := 'replace';
  D.Tags := nil;
  D.Points := nil;
  SetLength(D.Numbers, 3);
  D.Numbers[0] := 9;
  D.Numbers[1] := 8;
  D.Numbers[2] := 7;

  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"numbers":[5,6]}', @D);

  Check(Ok, 'replace array ok');
  CheckEqual(Int64(2), Int64(Length(D.Numbers)), 'replacement len');
  CheckEqual(Int64(5), Int64(D.Numbers[0]), 'replacement[0]');
  CheckEqual(Int64(6), Int64(D.Numbers[1]), 'replacement[1]');
end;

procedure TestArrayRollbackOnInvalidElement;
var D: TData; Ok: Boolean;
begin
  D.Name := 'rollback';
  D.Tags := nil;
  D.Points := nil;
  SetLength(D.Numbers, 3);
  D.Numbers[0] := 9;
  D.Numbers[1] := 8;
  D.Numbers[2] := 7;

  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), '{"numbers":[1,"bad"]}', @D);

  Check(not Ok, 'invalid array element fails');
  CheckEqual(Int64(3), Int64(Length(D.Numbers)), 'rollback len');
  CheckEqual(Int64(9), Int64(D.Numbers[0]), 'rollback[0]');
  CheckEqual(Int64(8), Int64(D.Numbers[1]), 'rollback[1]');
  CheckEqual(Int64(7), Int64(D.Numbers[2]), 'rollback[2]');
end;

procedure TestArrayRoundTrip;
var D, D2: TData; S: string; Ok: Boolean;
begin
  D.Name := 'round arrays';
  SetLength(D.Numbers, 2);
  D.Numbers[0] := 11;
  D.Numbers[1] := 22;
  SetLength(D.Tags, 2);
  D.Tags[0] := 'north';
  D.Tags[1] := 'south';
  SetLength(D.Points, 1);
  D.Points[0].X := 33;
  D.Points[0].Y := 44;

  D2.Name := '';
  D2.Numbers := nil;
  D2.Tags := nil;
  D2.Points := nil;
  S := JsonMarshal(Reg, Reg.FindType('Data'), @D);
  Ok := JsonUnmarshalStr(Reg, Reg.FindType('Data'), S, @D2);

  Check(Ok, 'array roundtrip ok');
  CheckEqual('round arrays', D2.Name, 'name');
  CheckEqual(Int64(2), Int64(Length(D2.Numbers)), 'numbers len');
  CheckEqual(Int64(11), Int64(D2.Numbers[0]), 'numbers[0]');
  CheckEqual(Int64(22), Int64(D2.Numbers[1]), 'numbers[1]');
  CheckEqual(Int64(2), Int64(Length(D2.Tags)), 'tags len');
  CheckEqual('north', D2.Tags[0], 'tags[0]');
  CheckEqual('south', D2.Tags[1], 'tags[1]');
  CheckEqual(Int64(1), Int64(Length(D2.Points)), 'points len');
  CheckEqual(Int64(33), Int64(D2.Points[0].X), 'point x');
  CheckEqual(Int64(44), Int64(D2.Points[0].Y), 'point y');
end;

begin
  RegisterTypes;
  T := TTestRunner.Create('nextpas.core.json.marshal');
  T.Run('marshal simple', @TestMarshalSimple);
  T.Run('marshal all types', @TestMarshalAllTypes);
  T.Run('marshal nested', @TestMarshalNested);
  T.Run('marshal escape', @TestMarshalEscape);
  T.Run('unmarshal simple', @TestUnmarshalSimple);
  T.Run('unmarshal all types', @TestUnmarshalAllTypes);
  T.Run('unmarshal nested', @TestUnmarshalNested);
  T.Run('unmarshal missing field', @TestUnmarshalMissing);
  T.Run('round trip', @TestRoundTrip);
  T.Run('marshal int array', @TestMarshalIntArray);
  T.Run('unmarshal int array', @TestUnmarshalIntArray);
  T.Run('string array', @TestStringArray);
  T.Run('record array', @TestRecordArray);
  T.Run('empty array', @TestEmptyArray);
  T.Run('null array', @TestNullArray);
  T.Run('array replacement', @TestArrayReplacement);
  T.Run('array rollback on invalid element', @TestArrayRollbackOnInvalidElement);
  T.Run('array round trip', @TestArrayRoundTrip);
  T.Summary;
end.
