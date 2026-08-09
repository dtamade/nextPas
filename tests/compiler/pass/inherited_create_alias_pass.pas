{$mode objfpc}{$H+}
program test_inherited_create_alias_pass;

{ B5d — ECore-shaped regression: EAliasCore is a unit-qualified alias of an
  imported class; TChild subclasses the alias and its constructor calls
  inherited Create. The encoder's inherited ancestor walk must not emit the
  alias station as callee (EAliasCore.Create has no body); it has to
  canonicalize through ResolveClassMethodCalleeName to TAliasBase.Create.
  The runtime check proves the message actually reached the base field. }

uses
  inherited_create_alias_parent;

type
  EAliasCore = inherited_create_alias_parent.TAliasBase;

  TChild = class(EAliasCore)
  public
    constructor Create(const AMessage: string);
  end;

constructor TChild.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

var
  LC: TChild;
begin
  LC := TChild.Create('canonical');
  try
    if LC.GetMessage <> 'canonical' then
    begin
      WriteLn('FAIL: expected canonical, got ', LC.GetMessage);
      Halt(1);
    end;
  finally
    LC.Free;
  end;
  WriteLn('inherited_create_alias OK');
end.
