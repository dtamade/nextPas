{$mode objfpc}{$H+}
program test_inherited_create_shadow_no_fallback_fail;

{ P2-2 edge regression A — same-name Create shadow must NOT fall back to parent.

  TChild declares its own Create(string, string). The caller invokes
  Create with a single integer argument. Per FPC semantics this is a
  wrong-argument-count error: a class that declares a member under a
  given name stops the ancestor walk at that class. stage0 must reject
  the call rather than silently resolving it to TParent.Create(int).

  Cross-checked against FPC 3.3.1: rejects "Wrong number of parameters". }

type
  TParent = class
    constructor Create(A: LongInt);
  end;

  TChild = class(TParent)
    constructor Create(const AS1, AS2: string);
  end;

constructor TParent.Create(A: LongInt);
begin
end;

constructor TChild.Create(const AS1, AS2: string);
begin
  inherited Create(0);
end;

var
  C: TChild;
begin
  C := TChild.Create(42);  { wrong arg count — must not fallback to TParent.Create }
  C.Free;
end.
