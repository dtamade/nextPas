unit np_hir_llvm_emitter;

{$mode objfpc}{$H+}

interface

uses
  np_hir_types, np_hir_model;

type
  THIRLlvmEmitter = class
  private
    FModule: THIRModule;
    FLines: array of string;
    FLineCount: LongInt;
    procedure Emit(const S: string);
    function TypeToLlvm(ATypeId: THIRTypeId): string;
    procedure EmitFunction(const AFunc: THIRFunction);
    procedure EmitInstr(const AInstr: THIRInstr);
    procedure EmitTerminator(const ATerm: THIRTerminator);
  public
    constructor Create(AModule: THIRModule);
    procedure EmitModule;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

uses
  SysUtils;

constructor THIRLlvmEmitter.Create(AModule: THIRModule);
begin
  inherited Create;
  FModule := AModule;
  FLineCount := 0;
  SetLength(FLines, 0);
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
end;

function THIRLlvmEmitter.TypeToLlvm(ATypeId: THIRTypeId): string;
var
  T: THIRTypeRec;
begin
  if ATypeId = 0 then Exit('void');
  T := FModule.Types.GetType(ATypeId);
  case T.Kind of
    htkVoid: Result := 'void';
    htkBool: Result := 'i1';
    htkInt: Result := 'i' + IntToStr(T.BitWidth);
    htkFloat:
      case T.FloatWidth of
        fwF32: Result := 'float';
        fwF64: Result := 'double';
        fwF80: Result := 'x86_fp80';
      end;
    htkPointer, htkUntypedPtr: Result := 'ptr';
    htkString: Result := 'ptr';
  else
    Result := 'i64';
  end;
end;

procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op: string;
  I: LongInt;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);

  case AInstr.Kind of
    hikAlloca:
      Emit('  %' + IntToStr(AInstr.ResultId) + ' = alloca ' + LlvmType);
    hikLoad:
    begin
      if AInstr.IntrinsicName <> '' then
      begin
        if Copy(AInstr.IntrinsicName, 1, 6) = 'const:' then
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = add ' + LlvmType +
            ' ' + Copy(AInstr.IntrinsicName, 7, Length(AInstr.IntrinsicName)) + ', 0')
        else if Length(AInstr.Operands) > 0 then
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr %' + IntToStr(AInstr.Operands[0].ValueId))
        else
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
      end
      else if Length(AInstr.Operands) > 0 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr %' + IntToStr(AInstr.Operands[0].ValueId))
      else
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
    end;
    hikStore:
      if Length(AInstr.Operands) >= 2 then
        Emit('  store ' + LlvmType + ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', ptr %' + IntToStr(AInstr.Operands[1].ValueId));
    hikAdd:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = add ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikSub:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikMul:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = mul ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikDiv:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sdiv ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikMod:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = srem ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikNeg:
      if Length(AInstr.Operands) >= 1 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' 0, %' + IntToStr(AInstr.Operands[0].ValueId));
    hikCmpEq, hikCmpNe, hikCmpLt, hikCmpLe, hikCmpGt, hikCmpGe:
    begin
      case AInstr.Kind of
        hikCmpEq: Op := 'eq';
        hikCmpNe: Op := 'ne';
        hikCmpLt: Op := 'slt';
        hikCmpLe: Op := 'sle';
        hikCmpGt: Op := 'sgt';
        hikCmpGe: Op := 'sge';
      end;
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = icmp ' + Op + ' i64' +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    end;
    hikZext:
      if Length(AInstr.Operands) >= 1 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = zext i1 %' +
          IntToStr(AInstr.Operands[0].ValueId) + ' to i64');
    hikCall:
    begin
      Op := '  %' + IntToStr(AInstr.ResultId) + ' = call ' + LlvmType +
        ' @' + AInstr.CallTarget + '(';
      for I := 0 to High(AInstr.Operands) do
      begin
        if I > 0 then Op := Op + ', ';
        Op := Op + 'i64 %' + IntToStr(AInstr.Operands[I].ValueId);
      end;
      Op := Op + ')';
      Emit(Op);
    end;
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'halt' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %exit_trunc_' + IntToStr(AInstr.ResultId) +
            ' = trunc i64 %' + IntToStr(AInstr.Operands[0].ValueId) + ' to i32');
          Emit('  %exit_and_' + IntToStr(AInstr.ResultId) +
            ' = and i32 %exit_trunc_' + IntToStr(AInstr.ResultId) + ', 255');
          Emit('  call void asm sideeffect "movl $0, %edi\0Amovl $$60, %eax\0Asyscall",' +
            ' "r"(i32 %exit_and_' + IntToStr(AInstr.ResultId) + ')');
        end;
      end;
    end;
  end;
end;

procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
begin
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else
        Emit('  ret i64 %' + IntToStr(ATerm.ReturnValue));
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 %' + IntToStr(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkUnreachable:
      Emit('  unreachable');
  end;
end;

procedure THIRLlvmEmitter.EmitFunction(const AFunc: THIRFunction);
var
  I, J: LongInt;
  ParamStr: string;
begin
  if AFunc.IsExternal then Exit;

  ParamStr := '';
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then ParamStr := ParamStr + ', ';
    ParamStr := ParamStr + TypeToLlvm(AFunc.Params[I].TypeId) +
      ' %' + IntToStr(AFunc.Params[I].ValueId);
  end;

  Emit('');
  Emit('define ' + TypeToLlvm(AFunc.ReturnTypeId) + ' @' + AFunc.Name +
    '(' + ParamStr + ') {');

  for I := 0 to High(AFunc.Blocks) do
  begin
    Emit('bb' + IntToStr(AFunc.Blocks[I].Id) + ':');
    for J := 0 to High(AFunc.Blocks[I].Instrs) do
      EmitInstr(AFunc.Blocks[I].Instrs[J]);
    EmitTerminator(AFunc.Blocks[I].Terminator);
  end;

  Emit('}');
end;

procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
begin
  FLineCount := 0;
  Emit('; ModuleID = ''' + FModule.ModuleName + '''');
  Emit('target triple = "x86_64-unknown-linux-gnu"');
  Emit('target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64"');

  for I := 0 to FModule.FunctionCount - 1 do
    EmitFunction(FModule.FunctionAt(I));
end;

function THIRLlvmEmitter.AsText: string;
var
  I: LongInt;
begin
  Result := '';
  for I := 0 to FLineCount - 1 do
    Result := Result + FLines[I] + LineEnding;
end;

procedure THIRLlvmEmitter.SaveToFile(const APath: string);
var
  F: TextFile;
  I: LongInt;
begin
  AssignFile(F, APath);
  Rewrite(F);
  for I := 0 to FLineCount - 1 do
    WriteLn(F, FLines[I]);
  CloseFile(F);
end;

end.
