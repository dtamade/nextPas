program core_text_smoke;

{$mode objfpc}{$H+}

uses
  SysUtils, np_base_types, np_text_primitives;

var
  CanonicalPath: string;
  SourceText: string;
  ReadResult: TCoreResult;
begin
  if NormalizeCoreIdentity('  Stage0Greeter  ') <> 'stage0greeter' then
    Halt(1);

  if not CorePathStartsWith(
    'units/linux-x86_64/Stage0Greeter.pas',
    'units/linux-x86_64'
  ) then
    Halt(1);

  ReadResult := TryReadCoreTextFile(
    'examples/smoke/hello.pas',
    CanonicalPath,
    SourceText
  );
  if not CoreResultIsOk(ReadResult) then
    Halt(1);

  if Pos('program Hello;', SourceText) = 0 then
    Halt(1);

  WriteLn('identity=', NormalizeCoreIdentity('  Stage0Greeter  '));
  WriteLn('canonical-path=', CanonicalPath);
  WriteLn('text-length=', Length(SourceText));
end.
