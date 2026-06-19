{$mode objfpc}{$H+}
program test_advanced_pass;
uses SysUtils;

type
  TValueKind = (vkInt, vkStr, vkFloat);

  TValue = record
    Kind: TValueKind;
    IntVal: LongInt;
    StrVal: string;
    FloatVal: Double;
  end;

function MakeInt(V: LongInt): TValue;
begin
  Result.Kind := vkInt;
  Result.IntVal := V;
  Result.StrVal := '';
  Result.FloatVal := 0.0;
end;

function MakeStr(const S: string): TValue;
begin
  Result.Kind := vkStr;
  Result.IntVal := 0;
  Result.StrVal := S;
  Result.FloatVal := 0.0;
end;

function ValueToStr(const V: TValue): string;
begin
  case V.Kind of
    vkInt: Result := IntToStr(V.IntVal);
    vkStr: Result := V.StrVal;
  else
    Result := '?';
  end;
end;

type
  PListNode = ^TListNode;
  TListNode = record
    Data: TValue;
    Next: PListNode;
  end;

var
  Head: PListNode;

procedure ListAdd(const V: TValue);
var
  Node: PListNode;
begin
  New(Node);
  Node^.Data := V;
  Node^.Next := Head;
  Head := Node;
end;

procedure ListClear;
var
  Node, Next: PListNode;
begin
  Node := Head;
  while Node <> nil do
  begin
    Next := Node^.Next;
    Dispose(Node);
    Node := Next;
  end;
  Head := nil;
end;

var
  I: LongInt;
  Node: PListNode;
begin
  Head := nil;
  for I := 0 to 9 do
    ListAdd(MakeInt(I * I));

  Node := Head;
  if ValueToStr(Node^.Data) <> '81' then Halt(1);

  ListAdd(MakeStr('hello'));
  if ValueToStr(Head^.Data) <> 'hello' then Halt(2);

  ListClear;
  if Head <> nil then Halt(3);

  WriteLn('advanced OK');
end.
