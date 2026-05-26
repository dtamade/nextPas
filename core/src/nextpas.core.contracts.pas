unit nextpas.core.contracts;

{$I nextpas.core.settings.inc}

interface

procedure ContractsRequire(aCondition: Boolean; const aMessage: string); inline;
procedure ContractsRequireAssigned(aCondition: Boolean; const aName: string); inline;

implementation

{$IFDEF FAFAFA_CORE_CONTRACTS}
uses
  nextpas.core.base;
{$ENDIF}

procedure ContractsRequire(aCondition: Boolean; const aMessage: string); inline;
begin
  {$IFDEF FAFAFA_CORE_CONTRACTS}
  if not aCondition then
    raise EInvalidArgument.Create(aMessage);
  {$ELSE}
  if aCondition and (aMessage = '') then;
  {$ENDIF}
end;

procedure ContractsRequireAssigned(aCondition: Boolean; const aName: string); inline;
begin
  {$IFDEF FAFAFA_CORE_CONTRACTS}
  if not aCondition then
    raise EArgumentNil.Create(aName + ' is nil');
  {$ELSE}
  if aCondition and (aName = '') then;
  {$ENDIF}
end;

end.
