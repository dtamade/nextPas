{$mode objfpc}{$H+}
program test_string_concat_owned_pass;

{ C6-B regression: string assignment with owned string returns.
  Tests that direct assignment from owned-return functions works
  without C6-H4 errors. }

uses
  SysUtils;

function MakeName(const AFirst, ALast: string): string;
begin
  Result := AFirst + ' ' + ALast;
end;

function Greet(const AName: string): string;
begin
  Result := 'Hello, ' + AName + '!';
end;

var
  S: string;
  Warmup: string;

begin
  { Warmup: register producers via top-level scan }
  Warmup := MakeName('John', 'Doe');
  if Warmup <> 'John Doe' then Halt(1);

  Warmup := Greet('World');
  if Warmup <> 'Hello, World!' then Halt(2);

  { Pattern 1: assign owned return to local }
  S := MakeName('Alice', 'Smith');
  if S <> 'Alice Smith' then Halt(3);

  { Pattern 2: assign owned return from another function }
  S := Greet('Bob');
  if S <> 'Hello, Bob!' then Halt(4);

  { Pattern 3: assign imported owned return (SysUtils) }
  S := IntToStr(42);
  if S <> '42' then Halt(5);

  { Pattern 4: assign UpperCase of string literal }
  S := UpperCase('hello');
  if S <> 'HELLO' then Halt(6);

  { Pattern 5: concat after assigning to local }
  S := MakeName('Carol', 'White');
  S := S + ' Jr.';
  if S <> 'Carol White Jr.' then Halt(7);

  WriteLn('string_concat_owned OK');
end.
