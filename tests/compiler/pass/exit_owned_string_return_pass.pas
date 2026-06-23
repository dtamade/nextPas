{$mode objfpc}{$H+}
program test_exit_owned_string_return_pass;

{ C6-H4 task #90 regression: Exit(ownedStringReturnFunc()) must NOT trigger
  sema.c6h4-owned-string-return-deferred-consumer. The owned-string temporary
  lives for the entire function scope (Exit is equivalent to Result := Expr).
  Depends on the gnkExitStatement handler in
  compiler/sema/np_semantic_analyzer.pas (NodeConsumesOwnedStringReturnDeferred).

  Producer registration: the program-level warmup assignments (GWarmup := F())
  run through ScanTopLevelOwnedStringReturnConsumers ->
  AssignmentOwnsTopLevelStringReturn, which only requires the lhs to be a consumer
  target node and does NOT depend on local-variable type resolution. This route
  robustly registers MakeGreeting (local) and ExpandFileName (imported from
  SysUtils) into FOwnedStringReturnFuncNames.

  Without that registration the deferred-consumer check would never recognise the
  producers and the test would pass as an empty no-op. Thanks to registration,
  deleting the gnkExitStatement handler makes Exit(producer()) fall through to the
  generic for-loop with AInsideDirectOwnedAssignmentRhs=False, hitting the
  deferred branch at np_semantic_analyzer.pas:1832 and emitting a C6-H4 error at
  build time (failing this fixture).

  Pattern 1/2 (hard guard): removing the handler regressess the build.
  Pattern 3/4 (family coverage): pin the broader safe-context family (concat
  arg / nested call arg); the handler alone may not regress them because concat
  and function-call-argument branches already mark operands as safe. }

uses
  SysUtils;

function MakeGreeting(const AName: string): string;
begin
  Result := 'hello ' + AName;
end;

{ Pattern 1 (hard guard): Exit(local owned-string-return func) }
function Greet(const AName: string): string;
begin
  Exit(MakeGreeting(AName));
end;

{ Pattern 2 (hard guard): Exit(imported owned-string-return func) }
function ResolveAbs(const APath: string): string;
begin
  Exit(ExpandFileName(APath));
end;

{ Pattern 3 (family coverage): Exit(concat with owned-string-return func) }
function GreetBang(const AName: string): string;
begin
  Exit(MakeGreeting(AName) + '!');
end;

{ Pattern 4 (family coverage): Exit(nested call wrapping owned-string-return func) }
function GreetUpper(const AName: string): string;
begin
  Exit(UpperCase(MakeGreeting(AName)));
end;

var
  GWarmup: string;
  S: string;
begin
  { Top-level warmup: registers producers via the robust top-level scan route.
    GWarmup is a plain string global; both lhs targets are valid consumer nodes,
    so MakeGreeting and ExpandFileName are registered before the function bodies
    below are checked. }
  GWarmup := MakeGreeting('warm');
  if GWarmup = '' then Halt(99);
  GWarmup := ExpandFileName('/a/b');
  if (Length(GWarmup) = 0) or (GWarmup[1] <> '/') then Halt(99);

  S := Greet('world');
  if S <> 'hello world' then Halt(1);

  { ExpandFileName of an absolute path is unchanged; it must start with '/' }
  S := ResolveAbs('/a/b/c.txt');
  if (Length(S) = 0) or (S[1] <> '/') then Halt(2);

  S := GreetBang('x');
  if S <> 'hello x!' then Halt(3);

  S := GreetUpper('y');
  if S <> 'HELLO Y' then Halt(4);

  WriteLn('exit_owned_string_return OK');
end.
