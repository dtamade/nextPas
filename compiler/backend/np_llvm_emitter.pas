unit np_llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_mir_model, np_target_facts;

type
  TLlvmEmitter = class
  private
    FMirModel: TMirModel;
    FTargetFacts: TTargetFactsView;
    function ResolveExitCode: LongInt;
  public
    constructor Create(
      const AMirModel: TMirModel;
      const ATargetFacts: TTargetFactsView
    );
    function EmitToFile(const APath: string): Boolean;
  end;

implementation

constructor TLlvmEmitter.Create(
  const AMirModel: TMirModel;
  const ATargetFacts: TTargetFactsView
);
begin
  inherited Create;
  FMirModel := AMirModel;
  FTargetFacts := ATargetFacts;
end;

function TLlvmEmitter.ResolveExitCode: LongInt;
var
  Index: LongInt;
  Op: TMirOperation;
  Parsed: LongInt;
  ParseCode: Word;
begin
  Result := 0;
  if FMirModel = nil then
    Exit;
  for Index := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(Index);
    if Op.Kind <> 'halt' then
      Continue;
    if Trim(Op.Operand) = '' then
      Exit(0);
    Val(Op.Operand, Parsed, ParseCode);
    if ParseCode = 0 then
      Exit(Parsed);
    Exit(0);
  end;
end;

function TLlvmEmitter.EmitToFile(const APath: string): Boolean;
var
  IrFile: Text;
  ExitCode: LongInt;
begin
  Assign(IrFile, APath);
  {$I-}
  Rewrite(IrFile);
  {$I+}
  if IOResult <> 0 then
    Exit(False);

  ExitCode := ResolveExitCode;

  try
    if FTargetFacts.LlvmTriple <> '' then
      WriteLn(IrFile, 'target triple = "', FTargetFacts.LlvmTriple, '"');
    if FTargetFacts.LlvmDataLayout <> '' then
      WriteLn(IrFile, 'target datalayout = "', FTargetFacts.LlvmDataLayout, '"');
    WriteLn(IrFile);
    WriteLn(IrFile, '; nextPas LLVM emitter: program shell driven by MIR halt');
    if (FMirModel <> nil) and (FMirModel.RootName <> '') then
      WriteLn(IrFile, '; root: ', FMirModel.RootName);
    WriteLn(IrFile, '; exit-code: ', ExitCode);
    WriteLn(IrFile);
    WriteLn(IrFile, 'define void @_start() noreturn {');
    WriteLn(IrFile, 'entry:');
    WriteLn(IrFile,
      '  call void asm sideeffect "movq $$60, %rax; movl $$',
      ExitCode,
      ', %edi; syscall", "~{rax},~{rdi}"()');
    WriteLn(IrFile, '  unreachable');
    WriteLn(IrFile, '}');
  finally
    Close(IrFile);
  end;

  Result := IOResult = 0;
end;

end.
