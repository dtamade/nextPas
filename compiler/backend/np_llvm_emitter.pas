unit np_llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_mir_model, np_target_facts;

type
  TLLvmStringArray = array of string;

  TLlvmEmitter = class
  private
    FMirModel: TMirModel;
    FTargetFacts: TTargetFactsView;
    function ResolveExitCode: LongInt;
    function CollectWriteLines: TLLvmStringArray;
    function EscapeLLVMString(const AValue: string): string;
    procedure EmitTargetHeader(var AIrFile: Text);
    procedure EmitGlobalConstStrings(
      var AIrFile: Text;
      const AWriteLines: TLLvmStringArray
    );
    procedure EmitLegacyMain(var AIrFile: Text);
    procedure EmitRuntimeMain(var AIrFile: Text);
  public
    constructor Create(
      const AMirModel: TMirModel;
      const ATargetFacts: TTargetFactsView
    );
    function EmitToFile(const APath: string): Boolean;
  end;

implementation

const
  LegacyExitAsmFmt =
    '  call void asm sideeffect "movq $$60, %%rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 %d)';
  LegacyWriteAsmFmt =
    '  call void asm sideeffect "movq $$1, %%rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.%d, i64 %d)';

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

function TLlvmEmitter.CollectWriteLines: TLLvmStringArray;
var
  Index: LongInt;
  Op: TMirOperation;
begin
  Result := nil;
  if FMirModel = nil then
    Exit;
  for Index := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(Index);
    if Op.Kind = 'write-line' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Op.Operand;
    end;
  end;
end;

function TLlvmEmitter.EscapeLLVMString(const AValue: string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(AValue) do
  begin
    case AValue[Index] of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #10: Result := Result + '\0A';
      #13: Result := Result + '\0D';
      #9: Result := Result + '\09';
      #0: Result := Result + '\00';
    else
      if Ord(AValue[Index]) < 32 then
        Result := Result + '\0' + LowerCase(IntToHex(Ord(AValue[Index]), 1))
      else
        Result := Result + AValue[Index];
    end;
  end;
end;

procedure TLlvmEmitter.EmitTargetHeader(var AIrFile: Text);
begin
  if FTargetFacts.LlvmTriple <> '' then
    WriteLn(AIrFile, 'target triple = "', FTargetFacts.LlvmTriple, '"');
  if FTargetFacts.LlvmDataLayout <> '' then
    WriteLn(AIrFile, 'target datalayout = "', FTargetFacts.LlvmDataLayout, '"');
  WriteLn(AIrFile);
end;

procedure TLlvmEmitter.EmitGlobalConstStrings(
  var AIrFile: Text;
  const AWriteLines: TLLvmStringArray
);
var
  Index: LongInt;
  StrLen: LongInt;
begin
  for Index := 0 to High(AWriteLines) do
  begin
    StrLen := Length(AWriteLines[Index]);
    WriteLn(AIrFile, '@.str.', Index, ' = private constant [',
      StrLen + 1, ' x i8] c"', EscapeLLVMString(AWriteLines[Index]),
      '\00"');
  end;
end;

procedure TLlvmEmitter.EmitLegacyMain(var AIrFile: Text);
var
  ExitCode: LongInt;
  WriteLines: TLLvmStringArray;
  Index: LongInt;
  StrLen: LongInt;
begin
  ExitCode := ResolveExitCode;
  WriteLines := CollectWriteLines;

  EmitTargetHeader(AIrFile);
  EmitGlobalConstStrings(AIrFile, WriteLines);

  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define void @_start() noreturn {');
  WriteLn(AIrFile, 'entry:');

  for Index := 0 to High(WriteLines) do
  begin
    StrLen := Length(WriteLines[Index]);
    WriteLn(AIrFile,
      '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.',
      Index, ', i64 ', StrLen, ')');
  end;

  WriteLn(AIrFile,
    '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 ',
    ExitCode, ')');
  WriteLn(AIrFile, '  unreachable');
  WriteLn(AIrFile, '}');
end;

procedure TLlvmEmitter.EmitRuntimeMain(var AIrFile: Text);
begin
  EmitTargetHeader(AIrFile);
  WriteLn(AIrFile, '; nextpas runtime emitter stub - Batch B');
  WriteLn(AIrFile, '; runtime ops not yet implemented in this batch');
  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define void @_start() noreturn {');
  WriteLn(AIrFile, 'entry:');
  WriteLn(AIrFile,
    '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 0)');
  WriteLn(AIrFile, '  unreachable');
  WriteLn(AIrFile, '}');
end;

function TLlvmEmitter.EmitToFile(const APath: string): Boolean;
var
  IrFile: Text;
begin
  Assign(IrFile, APath);
  {$I-}
  Rewrite(IrFile);
  {$I+}
  if IOResult <> 0 then
    Exit(False);

  try
    if (FMirModel <> nil) and FMirModel.HasRuntimeKinds then
      EmitRuntimeMain(IrFile)
    else
      EmitLegacyMain(IrFile);
  finally
    Close(IrFile);
  end;

  Result := IOResult = 0;
end;

end.
