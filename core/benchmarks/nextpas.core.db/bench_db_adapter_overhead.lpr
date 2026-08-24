program db_bench;
{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}
uses SysUtils, Classes, nextpas.core.base, nextpas.core.sqlite, nextpas.core.db;
var
  T0, T1: QWord;
  GK: Int64;   { 匿名方法内禁捕获循环计数器，借用全局 }

procedure BenchNativeInsertSelect(const N: Integer);
var
  Db: TSqliteDb; Q: TSqliteQuery; I: Int64; S: Int64;
begin
  Db := TSqliteDb.Create(':memory:');
  Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
  Db.Exec('BEGIN');
  T0 := GetTickCount64;
  for I := 1 to N do
  begin
    Q := Db.Query('INSERT INTO t (v) VALUES (?)');
    Q.BindInt64(1, I);
    Q.Step; Q.Free;
  end;
  Db.Exec('COMMIT');
  Q := Db.Query('SELECT SUM(id) FROM t');
  Q.Step; S := Q.GetInt64(0); Q.Free;
  T1 := GetTickCount64;
  WriteLn(Format('native  insert%8d + select: %6d ms (sum=%d)', [N, T1-T0, S]));
  Db.Free;
end;

procedure BenchUnifiedInsertSelect(const N: Integer);
var
  Conn: IDbConnection; Q: IDbQuery; I: Int64; S: Int64;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
  WithTransaction(Conn, procedure
  begin
    T0 := GetTickCount64;
    for GK := 1 to N do
    begin
      Q := Conn.Query('INSERT INTO t (v) VALUES (?)');
      Q.BindInt64(1, GK);
      Q.Step;
    end;
    T1 := GetTickCount64;
  end);
  Q := Conn.Query('SELECT SUM(id) FROM t');
  Q.Step; S := Q.GetInt64(0);
  WriteLn(Format('adapter insert%8d + select: %6d ms (sum=%d)', [N, T1-T0, S]));
end;

var
  N: Integer;
  Sizes: array[0..1] of Integer = (1000, 10000);
  K: Integer;
begin
  WriteLn('== insert/select 往返（含适配层开销） ==');
  for K := 0 to High(Sizes) do
  begin
    BenchNativeInsertSelect(Sizes[K]);
    BenchUnifiedInsertSelect(Sizes[K]);
  end;
end.
