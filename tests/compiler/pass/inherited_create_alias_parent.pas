{$mode objfpc}{$H+}
unit inherited_create_alias_parent;

{ B5d — parent class for the alias-parent inherited-Create fixture.
  The consumer program declares an ECore-style unit-qualified alias of
  TAliasBase and subclasses the ALIAS; inherited Create must land on
  TAliasBase.Create (the only real body), not on the alias station name. }

interface

type
  TAliasBase = class
  private
    FMessage: string;
  public
    constructor Create(const AMessage: string);
    function GetMessage: string;
  end;

implementation

constructor TAliasBase.Create(const AMessage: string);
begin
  FMessage := AMessage;
end;

function TAliasBase.GetMessage: string;
begin
  Result := FMessage;
end;

end.
