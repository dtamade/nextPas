unit ManifestPriorityGreeter;

interface

procedure EmitManifestPriorityGreeting;

implementation

procedure EmitManifestPriorityGreeting;
begin
  WriteLn('hello from package source root precedence');
end;

end.
