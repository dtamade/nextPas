{$mode objfpc}{$H+}
program type_check_generic_pass;

{ 类型检查：泛型 }

type
  generic TPair<T1, T2> = record
    First: T1;
    Second: T2;
  end;

  TIntPair = specialize TPair<Integer, Integer>;
  TStrIntPair = specialize TPair<string, Integer>;

var
  IP: TIntPair;
  SP: TStrIntPair;
begin
  IP.First := 10;
  IP.Second := 20;
  if IP.First <> 10 then Halt(1);
  if IP.Second <> 20 then Halt(2);

  SP.First := 'hello';
  SP.Second := 42;
  if SP.First <> 'hello' then Halt(3);
  if SP.Second <> 42 then Halt(4);
end.
