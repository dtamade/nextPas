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
  TPoint = record
    X: Int32;
    Y: Int32;
  end;

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

var
  PointTypeID, UserTypeID, AddrTypeID, PersonTypeID: TTypeID;

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
  T.Summary;
end.
