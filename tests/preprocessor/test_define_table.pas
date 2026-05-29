program test_define_table;

{$mode objfpc}{$H+}

uses
  np_preprocessor;

var
  Failures: LongInt = 0;

procedure Check(ACond: Boolean; const AMsg: string);
begin
  if not ACond then
  begin
    WriteLn('FAIL: ', AMsg);
    Inc(Failures);
  end;
end;

procedure TestDefineIsDefined;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    Check(not T.IsDefined('FOO'), 'undefined initially');
    T.Define('FOO');
    Check(T.IsDefined('FOO'), 'defined after Define');
    Check(T.Count = 1, 'count=1 after one define');
  finally
    T.Free;
  end;
end;

procedure TestCaseInsensitive;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    T.Define('Foo');
    Check(T.IsDefined('FOO'), 'case-insensitive upper');
    Check(T.IsDefined('foo'), 'case-insensitive lower');
    Check(T.IsDefined('fOo'), 'case-insensitive mixed');
  finally
    T.Free;
  end;
end;

procedure TestUndef;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    T.Define('A');
    T.Define('B');
    T.Define('C');
    Check(T.Count = 3, 'count=3');
    T.Undef('B');
    Check(not T.IsDefined('B'), 'B undefined');
    Check(T.IsDefined('A'), 'A still defined');
    Check(T.IsDefined('C'), 'C still defined');
    Check(T.Count = 2, 'count=2 after undef');
    T.Undef('NOPE');
    Check(T.Count = 2, 'undef nonexistent is no-op');
  finally
    T.Free;
  end;
end;

procedure TestRedefine;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    T.Define('X');
    T.Define('X');
    Check(T.Count = 1, 'redefine does not duplicate');
  finally
    T.Free;
  end;
end;

procedure TestValues;
var
  T: TDefineTable;
  V: string;
begin
  T := TDefineTable.Create;
  try
    T.DefineValue('VER', '30301');
    Check(T.IsDefined('VER'), 'value define is defined');
    Check(T.TryGetValue('VER', V), 'TryGetValue succeeds');
    Check(V = '30301', 'value is 30301');
    Check(T.ValueOf('VER') = '30301', 'ValueOf returns value');
    Check(T.ValueOf('ver') = '30301', 'ValueOf case-insensitive');

    T.Define('NOVAL');
    Check(not T.TryGetValue('NOVAL', V), 'plain define has no value');
    Check(T.ValueOf('NOVAL') = '', 'ValueOf empty for valueless');
    Check(not T.TryGetValue('MISSING', V), 'TryGetValue false for missing');
  finally
    T.Free;
  end;
end;

procedure TestDefineThenValue;
var
  T: TDefineTable;
  V: string;
begin
  T := TDefineTable.Create;
  try
    T.Define('K');
    Check(not T.TryGetValue('K', V), 'no value initially');
    T.DefineValue('K', '7');
    Check(T.TryGetValue('K', V) and (V = '7'), 'value upgraded in place');
    Check(T.Count = 1, 'no dup after value upgrade');
    { redefining without value clears the value }
    T.Define('K');
    Check(not T.TryGetValue('K', V), 'plain redefine clears value');
  finally
    T.Free;
  end;
end;

procedure TestClear;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    T.Define('A');
    T.Define('B');
    T.Clear;
    Check(T.Count = 0, 'count=0 after clear');
    Check(not T.IsDefined('A'), 'A gone after clear');
  finally
    T.Free;
  end;
end;

procedure TestEmptyName;
var
  T: TDefineTable;
begin
  T := TDefineTable.Create;
  try
    T.Define('');
    Check(T.Count = 0, 'empty name not defined');
  finally
    T.Free;
  end;
end;

begin
  TestDefineIsDefined;
  TestCaseInsensitive;
  TestUndef;
  TestRedefine;
  TestValues;
  TestDefineThenValue;
  TestClear;
  TestEmptyName;
  if Failures = 0 then
    WriteLn('define-table-status=pass')
  else
    WriteLn('define-table-status=fail count=', Failures);
  if Failures > 0 then Halt(1);
end.
