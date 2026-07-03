{$mode objfpc}{$H+}
program test_class_inherited_dispatch_pass;

{ Tests for class method dispatch, inherited calls, and polymorphism.
  Covers: virtual method dispatch, inherited keyword, class hierarchies. }

type
  TAnimal = class
    function Speak: string; virtual;
    function Kind: string;
  end;

  TDog = class(TAnimal)
    function Speak: string; override;
    function Fetch: string;
  end;

  TCat = class(TAnimal)
    function Speak: string; override;
  end;

function TAnimal.Speak: string;
begin
  Result := '...';
end;

function TAnimal.Kind: string;
begin
  Result := 'animal';
end;

function TDog.Speak: string;
begin
  Result := 'Woof!';
end;

function TDog.Fetch: string;
begin
  Result := 'fetching';
end;

function TCat.Speak: string;
begin
  Result := 'Meow!';
end;

var
  A: TAnimal;
  D: TDog;
  C: TCat;
  S: string;

begin
  { Direct call }
  D := TDog.Create;
  S := D.Speak;
  if S <> 'Woof!' then Halt(1);

  { Polymorphic dispatch }
  A := D;
  S := A.Speak;
  if S <> 'Woof!' then Halt(2);

  { Inherited method }
  S := D.Kind;
  if S <> 'animal' then Halt(3);

  { Different class }
  C := TCat.Create;
  S := C.Speak;
  if S <> 'Meow!' then Halt(4);

  A := C;
  S := A.Speak;
  if S <> 'Meow!' then Halt(5);

  { Cleanup }
  D.Free;
  C.Free;

  WriteLn('class_inherited_dispatch OK');
end.
