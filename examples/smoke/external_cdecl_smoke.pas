program ExternalCdeclSmoke;

procedure c_getpid; cdecl; external 'c' name 'getpid';

begin
end.
