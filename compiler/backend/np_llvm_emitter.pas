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

function TLlvmEmitter.EmitToFile(const APath: string): Boolean;
var
  IrFile: Text;
  ExitCode: LongInt;
  WriteLines: TLLvmStringArray;
  Index: LongInt;
  StrLen: LongInt;
begin
  Assign(IrFile, APath);
  {$I-}
  Rewrite(IrFile);
  {$I+}
  if IOResult <> 0 then
    Exit(False);

  ExitCode := ResolveExitCode;
  WriteLines := CollectWriteLines;

  try
    if FTargetFacts.LlvmTriple <> '' then
      WriteLn(IrFile, 'target triple = "', FTargetFacts.LlvmTriple, '"');
    if FTargetFacts.LlvmDataLayout <> '' then
      WriteLn(IrFile, 'target datalayout = "', FTargetFacts.LlvmDataLayout, '"');
    WriteLn(IrFile);

    for Index := 0 to High(WriteLines) do
    begin
      StrLen := Length(WriteLines[Index]);
      WriteLn(IrFile, '@.str.', Index, ' = private constant [',
        StrLen + 1, ' x i8] c"', EscapeLLVMString(WriteLines[Index]),
        '\00"');
    end;

    WriteLn(IrFile);
    WriteLn(IrFile, 'define void @_start() noreturn {');
    WriteLn(IrFile, 'entry:');

    for Index := 0 to High(WriteLines) do
    begin
      StrLen := Length(WriteLines[Index]);
      WriteLn(IrFile,
        '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.',
        Index, ', i64 ', StrLen, ')');
    end;

    WriteLn(IrFile,
      '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 ',
      ExitCode, ')');
    WriteLn(IrFile, '  unreachable');
    WriteLn(IrFile, '}');
  finally
    Close(IrFile);
  end;

  Result := IOResult = 0;
end;

end.
