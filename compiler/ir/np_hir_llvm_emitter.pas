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
    FNeedsWriteInt: Boolean;
    FNeedsStrConcat: Boolean;
    FNeedsStrCmp: Boolean;
    FNeedsIntToStr: Boolean;
    FStrConstants: array of string;
    FStrConstCount: LongInt;
    FCurrentReturnTypeId: THIRTypeId;
    FIsCheckCounter: LongInt;
    FObjectFreeCounter: LongInt;
    FPendingObjectFreeActive: Boolean;
    FPendingObjectFreeEndLabel: string;
    procedure Emit(const S: string);
    function ValueRef(AValueId: THIRValueId): string;
    function TypeToLlvm(ATypeId: THIRTypeId): string;
    function AddStrConstant(const AValue: string): LongInt;
    function EscapeLlvmStr(const AValue: string): string;
    function IsSretFunction(const AName: string): Boolean;
    procedure EmitFunction(const AFunc: THIRFunction);
    procedure EmitCallInstr(const AInstr: THIRInstr);
    procedure ClosePendingObjectFreeGuard;
    procedure EmitObjectFreeGuardStart(const AInstr: THIRInstr);
    procedure EmitObjectFreeOwnedDestroy(const AInstr: THIRInstr);
    procedure EmitInstr(const AInstr: THIRInstr);
    procedure EmitTerminator(const ATerm: THIRTerminator);
    procedure EmitWriteIntHelper;
    procedure EmitStrConstants;
    procedure EmitStrConcatHelper;
    procedure EmitVmtGlobals;
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
  FNeedsWriteInt := False;
  FNeedsStrConcat := False;
  FNeedsStrCmp := False;
  FNeedsIntToStr := False;
  FIsCheckCounter := 0;
  FObjectFreeCounter := 0;
  FPendingObjectFreeActive := False;
  FPendingObjectFreeEndLabel := '';
  SetLength(FLines, 0);
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
end;

function THIRLlvmEmitter.ValueRef(AValueId: THIRValueId): string;
begin
  Result := '%v' + IntToStr(AValueId);
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

procedure THIRLlvmEmitter.EmitCallInstr(const AInstr: THIRInstr);
var
  I: LongInt;
  LlvmType, Op: string;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
  if IsSretFunction(AInstr.CallTarget) then
    Op := '  call void @' + AInstr.CallTarget + '('
  else
    Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + LlvmType +
      ' @' + AInstr.CallTarget + '(';
  for I := 0 to High(AInstr.Operands) do
  begin
    if I > 0 then Op := Op + ', ';
    if AInstr.Operands[I].TypeId <> 0 then
      Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' ' +
        ValueRef(AInstr.Operands[I].ValueId)
    else
      Op := Op + 'i64 ' + ValueRef(AInstr.Operands[I].ValueId);
  end;
  Op := Op + ')';
  Emit(Op);
end;

procedure THIRLlvmEmitter.ClosePendingObjectFreeGuard;
begin
  if not FPendingObjectFreeActive then
    Exit;
  Emit('  br label %' + FPendingObjectFreeEndLabel);
  Emit(FPendingObjectFreeEndLabel + ':');
  FPendingObjectFreeActive := False;
  FPendingObjectFreeEndLabel := '';
end;

procedure THIRLlvmEmitter.EmitObjectFreeGuardStart(const AInstr: THIRInstr);
var
  CounterText: string;
  DestroyLabel: string;
begin
  if Length(AInstr.Operands) < 1 then
    Exit;

  Inc(FObjectFreeCounter);
  CounterText := IntToStr(FObjectFreeCounter);
  DestroyLabel := 'objectfree.destroy.' + CounterText;
  FPendingObjectFreeEndLabel := 'objectfree.end.' + CounterText;
  Emit('  %objectfree.isnull.' + CounterText + ' = icmp eq ptr ' +
    ValueRef(AInstr.Operands[0].ValueId) + ', null');
  Emit('  br i1 %objectfree.isnull.' + CounterText + ', label %' +
    FPendingObjectFreeEndLabel + ', label %' + DestroyLabel);
  Emit(DestroyLabel + ':');
  FPendingObjectFreeActive := True;
end;

procedure THIRLlvmEmitter.EmitObjectFreeOwnedDestroy(const AInstr: THIRInstr);
begin
  EmitCallInstr(AInstr);
  ClosePendingObjectFreeGuard;
end;

procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op: string;
  I: LongInt;
begin
  if FPendingObjectFreeActive and not ((AInstr.Kind = hikIntrinsic) and
    SameText(AInstr.IntrinsicName, 'np.system.object_free.destroy')) then
    ClosePendingObjectFreeGuard;

  LlvmType := TypeToLlvm(AInstr.TypeId);

  case AInstr.Kind of
    hikAlloca:
    begin
      if (AInstr.IntrinsicName <> '') and
        (Copy(AInstr.IntrinsicName, 1, 7) = 'record:') then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = alloca [' +
          Copy(AInstr.IntrinsicName, 8, Length(AInstr.IntrinsicName)) +
          ' x i64]')
      else
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = alloca ' + LlvmType);
    end;
    hikLoad:
    begin
      if AInstr.IntrinsicName <> '' then
      begin
        if Copy(AInstr.IntrinsicName, 1, 6) = 'const:' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
            ' ' + Copy(AInstr.IntrinsicName, 7, Length(AInstr.IntrinsicName)) + ', 0')
        else if AInstr.IntrinsicName = 'null' then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = inttoptr i64 0 to ptr')
        else if Length(AInstr.Operands) > 0 then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr ' + ValueRef(AInstr.Operands[0].ValueId))
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
      end
      else if Length(AInstr.Operands) > 0 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr ' + ValueRef(AInstr.Operands[0].ValueId))
      else
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
    end;
    hikStore:
      if Length(AInstr.Operands) >= 2 then
        Emit('  store ' + LlvmType + ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ptr ' + ValueRef(AInstr.Operands[1].ValueId));
    hikAdd:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikSub:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikMul:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = mul ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikDiv:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sdiv ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikMod:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = srem ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikNeg:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' 0, ' + ValueRef(AInstr.Operands[0].ValueId));
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
      begin
        if (AInstr.Operands[0].TypeId <> 0) and
          (FModule.Types.GetType(AInstr.Operands[0].TypeId).Kind = htkPointer) then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = icmp ' + Op + ' ptr' +
            ' ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + ValueRef(AInstr.Operands[1].ValueId))
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = icmp ' + Op + ' i64' +
            ' ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + ValueRef(AInstr.Operands[1].ValueId));
      end;
    end;
    hikZext:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = zext i1 ' + ValueRef(AInstr.Operands[0].ValueId) + ' to i64');
    hikCall:
      EmitCallInstr(AInstr);
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'halt' then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
            ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' + AInstr.CallTarget + ')')
        else if Length(AInstr.Operands) >= 1 then
          Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
            ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if SameText(AInstr.IntrinsicName, 'np.system.object_free') then
        EmitObjectFreeGuardStart(AInstr)
      else if SameText(AInstr.IntrinsicName, 'np.system.object_free.destroy') then
        EmitObjectFreeOwnedDestroy(AInstr)
      else if AInstr.IntrinsicName = 'write_int' then
      begin
        FNeedsWriteInt := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @write_i64_decimal(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str' then
      begin
        I := AddStrConstant(AInstr.CallTarget);
        Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
          ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.' +
          IntToStr(I) + ', i64 ' + IntToStr(Length(AInstr.CallTarget)) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str_var' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
            ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'store_str_lit' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          I := AddStrConstant(AInstr.CallTarget);
          Emit('  store ptr @.str.' + IntToStr(I) + ', ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 ' + IntToStr(Length(AInstr.CallTarget)) +
            ', ptr ' + ValueRef(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'call_str_func' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := '  %callstr.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @' + AInstr.CallTarget + '(';
          for I := 2 to High(AInstr.Operands) do
          begin
            if I > 2 then Op := Op + ', ';
            if AInstr.Operands[I].TypeId <> 0 then
              Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' ' + ValueRef(AInstr.Operands[I].ValueId)
            else
              Op := Op + 'i64 ' + ValueRef(AInstr.Operands[I].ValueId);
          end;
          Op := Op + ')';
          Emit(Op);
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %callstr.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 %callstr.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_concat' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 6 then
        begin
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @np_str_concat(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %concat.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[4].ValueId));
          Emit('  store i64 %concat.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[5].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'ret_str' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.1 = insertvalue {ptr, i64} undef, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.2 = insertvalue {ptr, i64} %retstr.' +
            IntToStr(AInstr.ResultId) + '.1, i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', 1');
          Emit('  ret {ptr, i64} %retstr.' + IntToStr(AInstr.ResultId) + '.2');
        end;
      end
      else if AInstr.IntrinsicName = 'global_ref' then
      begin
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = getelementptr i64, ptr @g_' + AInstr.CallTarget + ', i64 0');
      end
      else if AInstr.IntrinsicName = 'gep_i64' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i64, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId));
      end
      else if AInstr.IntrinsicName = 'gep_i8' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i8, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId));
      end
      else if AInstr.IntrinsicName = 'load_zext_i8' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %zext.' + IntToStr(AInstr.ResultId) +
            ' = load i8, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = zext i8 %zext.' + IntToStr(AInstr.ResultId) + ' to i64');
        end;
      end
      else if AInstr.IntrinsicName = 'abs' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %abs.neg.' + IntToStr(AInstr.ResultId) +
            ' = sub i64 0, ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  %abs.cmp.' + IntToStr(AInstr.ResultId) +
            ' = icmp sge i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = select i1 %abs.cmp.' + IntToStr(AInstr.ResultId) +
            ', i64 ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 %abs.neg.' + IntToStr(AInstr.ResultId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_const' then
      begin
        Op := Copy(AInstr.CallTarget, 2, Length(AInstr.CallTarget) - 2);
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = getelementptr i8, ptr @.str.' + IntToStr(
            AddStrConstant(Op)) + ', i64 0');
      end
      else if AInstr.IntrinsicName = 'int_to_str' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @np_int_to_str(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %its.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %its.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %its.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[1].ValueId));
          Emit('  store i64 %its.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[2].ValueId));
          FNeedsIntToStr := True;
        end;
      end
      else if AInstr.IntrinsicName = 'str_cmp' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          if AInstr.CallTarget = 'ne' then
          begin
            Emit('  %strcmp.' + IntToStr(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = xor i64 %strcmp.' + IntToStr(AInstr.ResultId) + ', 1');
          end
          else
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          FNeedsStrCmp := True;
        end;
      end
      else if AInstr.IntrinsicName = 'str_pos' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @np_str_pos(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          FNeedsStrCmp := True;
        end;
      end
      else if AInstr.IntrinsicName = 'arr_alloc' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %arralloc.' + IntToStr(AInstr.ResultId) +
            '.sz = mul i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 8');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 %arralloc.' +
            IntToStr(AInstr.ResultId) + '.sz)');
        end;
      end
      else if AInstr.IntrinsicName = 'arr_alloc_sized' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  %arralloc.' + IntToStr(AInstr.ResultId) +
            '.sz = mul i64 ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + ValueRef(AInstr.Operands[1].ValueId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 %arralloc.' +
            IntToStr(AInstr.ResultId) + '.sz)');
        end;
      end
      else if AInstr.IntrinsicName = 'class_alloc' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'vmt_store' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
          Emit('  store ptr @' + AInstr.CallTarget + '.vmt, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
      end
      else if AInstr.IntrinsicName = 'vcall' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := '  ' + ValueRef(AInstr.ResultId) +
            ' = call ' + TypeToLlvm(AInstr.TypeId) + ' ' + ValueRef(AInstr.Operands[0].ValueId) +
            '(ptr ' + ValueRef(AInstr.Operands[1].ValueId);
          for I := 2 to High(AInstr.Operands) do
          begin
            if AInstr.Operands[I].TypeId <> 0 then
              Op := Op + ', ' + TypeToLlvm(AInstr.Operands[I].TypeId) +
                ' ' + ValueRef(AInstr.Operands[I].ValueId)
            else
              Op := Op + ', i64 ' + ValueRef(AInstr.Operands[I].ValueId);
          end;
          Op := Op + ')';
          Emit(Op);
        end;
      end
      else if AInstr.IntrinsicName = 'vcall_str' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} ' + ValueRef(AInstr.Operands[0].ValueId) +
            '(ptr ' + ValueRef(AInstr.Operands[1].ValueId) + ')');
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %vcallstr.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %vcallstr.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[2].ValueId));
          Emit('  store i64 %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[3].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'is_instance' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
        begin
          Inc(FIsCheckCounter);
          Emit('  br label %is.pre.' + IntToStr(FIsCheckCounter));
          Emit('is.pre.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.loop.' + IntToStr(FIsCheckCounter));
          Emit('is.loop.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  %is.cur.' + IntToStr(FIsCheckCounter) +
            ' = phi ptr [ ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', %is.pre.' + IntToStr(FIsCheckCounter) +
            ' ], [ %is.parent.' + IntToStr(FIsCheckCounter) +
            ', %is.next.' + IntToStr(FIsCheckCounter) + ' ]');
          Emit('  %is.eq.' + IntToStr(FIsCheckCounter) +
            ' = icmp eq ptr %is.cur.' + IntToStr(FIsCheckCounter) +
            ', @' + AInstr.CallTarget + '.vmt');
          Emit('  br i1 %is.eq.' + IntToStr(FIsCheckCounter) +
            ', label %is.true.' + IntToStr(FIsCheckCounter) +
            ', label %is.next.' + IntToStr(FIsCheckCounter));
          Emit('is.next.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  %is.parent.' + IntToStr(FIsCheckCounter) +
            ' = load ptr, ptr %is.cur.' + IntToStr(FIsCheckCounter));
          Emit('  %is.done.' + IntToStr(FIsCheckCounter) +
            ' = icmp eq ptr %is.parent.' + IntToStr(FIsCheckCounter) +
            ', null');
          Emit('  br i1 %is.done.' + IntToStr(FIsCheckCounter) +
            ', label %is.false.' + IntToStr(FIsCheckCounter) +
            ', label %is.loop.' + IntToStr(FIsCheckCounter));
          Emit('is.true.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.end.' + IntToStr(FIsCheckCounter));
          Emit('is.false.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.end.' + IntToStr(FIsCheckCounter));
          Emit('is.end.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = phi i64 [ 1, %is.true.' + IntToStr(FIsCheckCounter) +
            ' ], [ 0, %is.false.' + IntToStr(FIsCheckCounter) + ' ]');
        end;
      end;
    end;
  end;
end;

procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
var
  I: LongInt;
  RetTy: string;
  T: THIRTypeRec;
begin
  ClosePendingObjectFreeGuard;
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else begin
        T := FModule.Types.GetType(FCurrentReturnTypeId);
        if T.Kind = htkString then
          RetTy := '{ptr, i64}'
        else
          RetTy := TypeToLlvm(FCurrentReturnTypeId);
        Emit('  ret ' + RetTy + ' ' + ValueRef(ATerm.ReturnValue));
      end;
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkSwitch:
    begin
      Emit('  switch i64 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.DefaultBlock) + ' [');
      for I := 0 to High(ATerm.SwitchCases) do
        Emit('    i64 ' + IntToStr(ATerm.SwitchCases[I].Value) +
          ', label %bb' + IntToStr(ATerm.SwitchCases[I].TargetBlock));
      Emit('  ]');
    end;
    htkUnreachable:
      Emit('  unreachable');
  end;
end;

function THIRLlvmEmitter.IsSretFunction(const AName: string): Boolean;
var
  I: LongInt;
  F: THIRFunction;
begin
  for I := 0 to FModule.FunctionCount - 1 do
  begin
    F := FModule.FunctionAt(I);
    if SameText(F.Name, AName) and (Length(F.Params) > 0) and
      (F.Params[0].Name = 'sret_ptr') then
      Exit(True);
  end;
  Result := False;
end;

procedure THIRLlvmEmitter.EmitFunction(const AFunc: THIRFunction);
var
  I, J: LongInt;
  ParamStr, RetStr: string;
  T: THIRTypeRec;
begin
  if AFunc.IsExternal then Exit;

  ParamStr := '';
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then ParamStr := ParamStr + ', ';
    ParamStr := ParamStr + TypeToLlvm(AFunc.Params[I].TypeId) +
      ' ' + ValueRef(AFunc.Params[I].ValueId);
  end;

  T := FModule.Types.GetType(AFunc.ReturnTypeId);
  if (Length(AFunc.Params) > 0) and (AFunc.Params[0].Name = 'sret_ptr') then
    RetStr := 'void'
  else if T.Kind = htkString then
    RetStr := '{ptr, i64}'
  else
    RetStr := TypeToLlvm(AFunc.ReturnTypeId);

  FCurrentReturnTypeId := AFunc.ReturnTypeId;

  Emit('');
  Emit('define ' + RetStr + ' @' + AFunc.Name +
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
  G: THIRGlobal;
begin
  FLineCount := 0;
  FStrConstCount := 0;
  FNeedsWriteInt := False;
  FNeedsStrConcat := False;
  FNeedsStrCmp := False;
  FNeedsIntToStr := False;
  FObjectFreeCounter := 0;
  FPendingObjectFreeActive := False;
  FPendingObjectFreeEndLabel := '';
  Emit('; ModuleID = ''' + FModule.ModuleName + '''');
  Emit('target triple = "x86_64-unknown-linux-gnu"');
  Emit('target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64"');

  for I := 0 to FModule.GlobalCount - 1 do
  begin
    G := FModule.GlobalAt(I);
    Emit('');
    if FModule.Types.GetType(G.TypeId).Kind = htkPointer then
      Emit('@g_' + G.Name + ' = internal global ptr null')
    else
      Emit('@g_' + G.Name + ' = internal global i64 0');
  end;

  for I := 0 to FModule.FunctionCount - 1 do
    EmitFunction(FModule.FunctionAt(I));

  if FStrConstCount > 0 then
  begin
    Emit('');
    EmitStrConstants;
  end;

  EmitVmtGlobals;

  if FNeedsWriteInt then
    EmitWriteIntHelper;

  if FNeedsStrConcat or FNeedsIntToStr then
    EmitStrConcatHelper;

  if FNeedsStrCmp then
  begin
    Emit('');
    Emit('define internal i64 @np_str_cmp(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
    Emit('entry:');
    Emit('  %len_eq = icmp eq i64 %a_len, %b_len');
    Emit('  br i1 %len_eq, label %check_content, label %not_equal');
    Emit('check_content:');
    Emit('  %cmp0 = icmp eq i64 %a_len, 0');
    Emit('  br i1 %cmp0, label %equal, label %loop');
    Emit('loop:');
    Emit('  %i = phi i64 [ 0, %check_content ], [ %i_next, %loop_cont ]');
    Emit('  %ap = getelementptr i8, ptr %a_ptr, i64 %i');
    Emit('  %bp = getelementptr i8, ptr %b_ptr, i64 %i');
    Emit('  %ac = load i8, ptr %ap');
    Emit('  %bc = load i8, ptr %bp');
    Emit('  %eq = icmp eq i8 %ac, %bc');
    Emit('  br i1 %eq, label %loop_cont, label %not_equal');
    Emit('loop_cont:');
    Emit('  %i_next = add i64 %i, 1');
    Emit('  %done = icmp eq i64 %i_next, %a_len');
    Emit('  br i1 %done, label %equal, label %loop');
    Emit('equal:');
    Emit('  ret i64 1');
    Emit('not_equal:');
    Emit('  ret i64 0');
    Emit('}');
    Emit('');
    Emit('define internal i64 @np_str_pos(ptr %sub_ptr, i64 %sub_len, ptr %s_ptr, i64 %s_len) {');
    Emit('entry:');
    Emit('  %max = sub i64 %s_len, %sub_len');
    Emit('  %can = icmp sge i64 %max, 0');
    Emit('  br i1 %can, label %outer_loop, label %not_found');
    Emit('outer_loop:');
    Emit('  %oi = phi i64 [ 0, %entry ], [ %oi_next, %outer_cont ]');
    Emit('  br label %inner_loop');
    Emit('inner_loop:');
    Emit('  %ii = phi i64 [ 0, %outer_loop ], [ %ii_next, %inner_cont ]');
    Emit('  %sp = getelementptr i8, ptr %s_ptr, i64 %oi');
    Emit('  %spi = getelementptr i8, ptr %sp, i64 %ii');
    Emit('  %subp = getelementptr i8, ptr %sub_ptr, i64 %ii');
    Emit('  %sc = load i8, ptr %spi');
    Emit('  %subc = load i8, ptr %subp');
    Emit('  %match = icmp eq i8 %sc, %subc');
    Emit('  br i1 %match, label %inner_cont, label %outer_cont');
    Emit('inner_cont:');
    Emit('  %ii_next = add i64 %ii, 1');
    Emit('  %idone = icmp eq i64 %ii_next, %sub_len');
    Emit('  br i1 %idone, label %found, label %inner_loop');
    Emit('outer_cont:');
    Emit('  %oi_next = add i64 %oi, 1');
    Emit('  %odone = icmp sgt i64 %oi_next, %max');
    Emit('  br i1 %odone, label %not_found, label %outer_loop');
    Emit('found:');
    Emit('  %result = add i64 %oi, 1');
    Emit('  ret i64 %result');
    Emit('not_found:');
    Emit('  ret i64 0');
    Emit('}');
  end;

  if FNeedsIntToStr then
  begin
    Emit('');
    Emit('define internal {ptr, i64} @np_int_to_str(i64 %val) {');
    Emit('entry:');
    Emit('  %buf = call ptr @np_alloc(i64 21)');
    Emit('  %is_neg = icmp slt i64 %val, 0');
    Emit('  %abs_val = select i1 %is_neg, i64 0, i64 %val');
    Emit('  %neg_val = sub i64 0, %val');
    Emit('  %work = select i1 %is_neg, i64 %neg_val, i64 %val');
    Emit('  br label %digit_loop');
    Emit('digit_loop:');
    Emit('  %n = phi i64 [ %work, %entry ], [ %n_next, %digit_loop ]');
    Emit('  %pos = phi i64 [ 20, %entry ], [ %pos_next, %digit_loop ]');
    Emit('  %d = urem i64 %n, 10');
    Emit('  %c = add i64 %d, 48');
    Emit('  %ct = trunc i64 %c to i8');
    Emit('  %pos_next = sub i64 %pos, 1');
    Emit('  %dp = getelementptr i8, ptr %buf, i64 %pos_next');
    Emit('  store i8 %ct, ptr %dp');
    Emit('  %n_next = udiv i64 %n, 10');
    Emit('  %done = icmp eq i64 %n_next, 0');
    Emit('  br i1 %done, label %finish, label %digit_loop');
    Emit('finish:');
    Emit('  %start = select i1 %is_neg, i64 1, i64 0');
    Emit('  %final_pos = sub i64 %pos_next, %start');
    Emit('  br i1 %is_neg, label %add_sign, label %calc_result');
    Emit('add_sign:');
    Emit('  %sign_pos = sub i64 %pos_next, 1');
    Emit('  %sp = getelementptr i8, ptr %buf, i64 %sign_pos');
    Emit('  store i8 45, ptr %sp');
    Emit('  br label %calc_result');
    Emit('calc_result:');
    Emit('  %result_pos = phi i64 [ %pos_next, %finish ], [ %sign_pos, %add_sign ]');
    Emit('  %result_ptr = getelementptr i8, ptr %buf, i64 %result_pos');
    Emit('  %result_len = sub i64 21, %result_pos');
    Emit('  %r1 = insertvalue {ptr, i64} undef, ptr %result_ptr, 0');
    Emit('  %r2 = insertvalue {ptr, i64} %r1, i64 %result_len, 1');
    Emit('  ret {ptr, i64} %r2');
    Emit('}');
  end;
end;

procedure THIRLlvmEmitter.EmitWriteIntHelper;
begin
  Emit('');
  Emit('define internal void @write_i64_decimal(i64 %v) {');
  Emit('entry:');
  Emit('  %buf = alloca [24 x i8]');
  Emit('  %is_neg = icmp slt i64 %v, 0');
  Emit('  %neg_v = sub i64 0, %v');
  Emit('  %abs_v = select i1 %is_neg, i64 %neg_v, i64 %v');
  Emit('  %end_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 24');
  Emit('  %first_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 23');
  Emit('  br label %loop');
  Emit('loop:');
  Emit('  %cur = phi i64 [ %abs_v, %entry ], [ %nxt, %loop ]');
  Emit('  %ptr = phi ptr [ %first_ptr, %entry ], [ %ptr_prev, %loop ]');
  Emit('  %digit = urem i64 %cur, 10');
  Emit('  %digit_i8 = trunc i64 %digit to i8');
  Emit('  %digit_ascii = add i8 %digit_i8, 48');
  Emit('  store i8 %digit_ascii, ptr %ptr');
  Emit('  %nxt = udiv i64 %cur, 10');
  Emit('  %ptr_prev = getelementptr i8, ptr %ptr, i64 -1');
  Emit('  %done = icmp eq i64 %nxt, 0');
  Emit('  br i1 %done, label %neg_check, label %loop');
  Emit('neg_check:');
  Emit('  br i1 %is_neg, label %put_minus, label %finish');
  Emit('put_minus:');
  Emit('  store i8 45, ptr %ptr_prev');
  Emit('  %ptr_minus_prev = getelementptr i8, ptr %ptr_prev, i64 -1');
  Emit('  br label %finish');
  Emit('finish:');
  Emit('  %start_ptr = phi ptr [ %ptr_prev, %neg_check ], [ %ptr_minus_prev, %put_minus ]');
  Emit('  %start_next = getelementptr i8, ptr %start_ptr, i64 1');
  Emit('  %len = ptrtoint ptr %end_ptr to i64');
  Emit('  %start_int = ptrtoint ptr %start_next to i64');
  Emit('  %write_len = sub i64 %len, %start_int');
  Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
    ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %start_next, i64 %write_len)');
  Emit('  ret void');
  Emit('}');
end;

function THIRLlvmEmitter.AddStrConstant(const AValue: string): LongInt;
begin
  Result := FStrConstCount;
  if FStrConstCount >= Length(FStrConstants) then
    SetLength(FStrConstants, FStrConstCount + 16);
  FStrConstants[FStrConstCount] := AValue;
  Inc(FStrConstCount);
end;

function THIRLlvmEmitter.EscapeLlvmStr(const AValue: string): string;
var
  I: LongInt;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    if (Ord(C) < 32) or (Ord(C) > 126) or (C = '"') or (C = '\') then
      Result := Result + '\' + LowerCase(IntToHex(Ord(C), 2))
    else
      Result := Result + C;
  end;
end;

procedure THIRLlvmEmitter.EmitStrConstants;
var
  I, Len: LongInt;
begin
  for I := 0 to FStrConstCount - 1 do
  begin
    Len := Length(FStrConstants[I]);
    Emit('@.str.' + IntToStr(I) + ' = private constant [' + IntToStr(Len) +
      ' x i8] c"' + EscapeLlvmStr(FStrConstants[I]) + '"');
  end;
end;

procedure THIRLlvmEmitter.EmitStrConcatHelper;
begin
  Emit('');
  Emit('@__heap_cur = internal global ptr null');
  Emit('');
  Emit('define internal ptr @np_alloc(i64 %size) {');
  Emit('entry:');
  Emit('  %cur = load ptr, ptr @__heap_cur');
  Emit('  %is_null = icmp eq ptr %cur, null');
  Emit('  br i1 %is_null, label %init, label %alloc');
  Emit('init:');
  Emit('  %brk0 = call i64 asm sideeffect "movq $$12, %rax\0Axorq %rdi, %rdi\0Asyscall", "={rax},~{rcx},~{r11},~{rdi}"()');
  Emit('  %brk0p = inttoptr i64 %brk0 to ptr');
  Emit('  store ptr %brk0p, ptr @__heap_cur');
  Emit('  br label %alloc');
  Emit('alloc:');
  Emit('  %base = load ptr, ptr @__heap_cur');
  Emit('  %next = getelementptr i8, ptr %base, i64 %size');
  Emit('  %nexti = ptrtoint ptr %next to i64');
  Emit('  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %nexti)');
  Emit('  store ptr %next, ptr @__heap_cur');
  Emit('  ret ptr %base');
  Emit('}');
  Emit('');
  Emit('define internal void @np_memcpy(ptr %dst, ptr %src, i64 %n) {');
  Emit('entry:');
  Emit('  %cmp0 = icmp eq i64 %n, 0');
  Emit('  br i1 %cmp0, label %done, label %loop');
  Emit('loop:');
  Emit('  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]');
  Emit('  %sp = getelementptr i8, ptr %src, i64 %i');
  Emit('  %b = load i8, ptr %sp');
  Emit('  %dp = getelementptr i8, ptr %dst, i64 %i');
  Emit('  store i8 %b, ptr %dp');
  Emit('  %i_next = add i64 %i, 1');
  Emit('  %cond = icmp eq i64 %i_next, %n');
  Emit('  br i1 %cond, label %done, label %loop');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
  Emit('entry:');
  Emit('  %total = add i64 %a_len, %b_len');
  Emit('  %buf = call ptr @np_alloc(i64 %total)');
  Emit('  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)');
  Emit('  %dst2 = getelementptr i8, ptr %buf, i64 %a_len');
  Emit('  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)');
  Emit('  %r1 = insertvalue {ptr, i64} undef, ptr %buf, 0');
  Emit('  %r2 = insertvalue {ptr, i64} %r1, i64 %total, 1');
  Emit('  ret {ptr, i64} %r2');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitVmtGlobals;
var
  I, J: LongInt;
  Vmt: THIRVmtGlobal;
  Line: string;
begin
  for I := 0 to FModule.VmtGlobalCount - 1 do
  begin
    Vmt := FModule.VmtGlobalAt(I);
    if Length(Vmt.Funcs) = 0 then Continue;
    Line := '@' + Vmt.ClassName + '.vmt = internal constant [' +
      IntToStr(Length(Vmt.Funcs)) + ' x ptr] [';
    for J := 0 to High(Vmt.Funcs) do
    begin
      if J > 0 then Line := Line + ', ';
      if Vmt.Funcs[J] = '' then
        Line := Line + 'ptr null'
      else
        Line := Line + 'ptr @' + Vmt.Funcs[J];
    end;
    Line := Line + ']';
    Emit('');
    Emit(Line);
  end;
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
