unit ManifestGreeter;

interface

procedure EmitManifestGreeting;

implementation

procedure EmitManifestGreeting;
begin
  WriteLn('hello from package manifest source root');
end;

end.
