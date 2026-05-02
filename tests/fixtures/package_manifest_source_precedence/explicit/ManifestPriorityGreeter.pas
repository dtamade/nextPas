unit ManifestPriorityGreeter;

interface

procedure EmitManifestPriorityGreeting;

implementation

procedure EmitManifestPriorityGreeting;
begin
  WriteLn('hello from explicit unit root fallback');
end;

end.
