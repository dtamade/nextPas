{$mode objfpc}{$H+}
program test_raii_record_pass;

type
  { 含 string 字段的 record — RAII 应自动清理 }
  TNamedValue = record
    Name: string;
    Value: LongInt;
  end;

  { 含多个 string 字段的 record }
  TPerson = record
    FirstName: string;
    LastName: string;
    Age: LongInt;
  end;

function MakePerson(const AFirst, ALast: string; AAge: LongInt): TPerson;
begin
  Result.FirstName := AFirst;
  Result.LastName := ALast;
  Result.Age := AAge;
end;

var
  P: TPerson;
  NV: TNamedValue;
begin
  { 基本 record + string 字段赋值 }
  NV.Name := 'test';
  NV.Value := 42;
  if NV.Name <> 'test' then Halt(1);
  if NV.Value <> 42 then Halt(2);

  { 多字段 string record }
  P.FirstName := 'John';
  P.LastName := 'Doe';
  P.Age := 30;
  if P.FirstName <> 'John' then Halt(3);
  if P.LastName <> 'Doe' then Halt(4);

  { 函数返回含 string 的 record }
  P := MakePerson('Jane', 'Smith', 25);
  if P.FirstName <> 'Jane' then Halt(5);
  if P.LastName <> 'Smith' then Halt(6);
  if P.Age <> 25 then Halt(7);

  WriteLn('raii_record OK');
end.
