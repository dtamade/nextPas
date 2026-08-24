function THIRLlvmEmitter.RenderAllocaLine(const AInstr: THIRInstr): string;
var
  LlvmType: string;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
  if (AInstr.IntrinsicName <> '') and
    (Copy(AInstr.IntrinsicName, 1, 7) = 'record:') then
    Result := '  ' + ValueRef(AInstr.ResultId) + ' = alloca [' +
      Copy(AInstr.IntrinsicName, 8, Length(AInstr.IntrinsicName)) +
      ' x i64]'
  else if AInstr.IntrinsicName = 'tstring' then
  begin
    FNeedsTStringRuntime := True;
    Result := '  ' + ValueRef(AInstr.ResultId) + ' = alloca [24 x i8], align 8';
  end
  else
    Result := '  ' + ValueRef(AInstr.ResultId) + ' = alloca ' + LlvmType;
  if AInstr.CallTarget <> '' then
    Result := Result + ' ; ' + AInstr.CallTarget;
  { Alloca result is always ptr — note so icmp/load casts can see it. }
  NoteValueLlvmType(AInstr.ResultId, 'ptr');
end;

procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op, LTruncVal: string;
  I, LDbgIdx: LongInt;
begin
  if AInstr.HasSystemContract then
  begin
    if not EmitSystemContractInstr(AInstr) then
      raise Exception.Create('system-contract-dispatch-not-handled');
    Exit;
  end;

  if FPendingObjectFreeActive and not IsObjectFreeGuardContinuation(AInstr) then
    ClosePendingObjectFreeGuard;

  LlvmType := TypeToLlvm(AInstr.TypeId);

  case AInstr.Kind of
    hikAlloca:
      { Already rendered into the entry prologue by EmitFunction's pre-pass;
        emitting here would land after the exception setjmp split and break
        dominance for except-block loads. }
      ;
    hikLoad:
    begin
      { TypeId 0 maps to void; cannot load void. Prefer i64 for scalar residual. }
      if (LlvmType = '') or (LlvmType = 'void') then
        LlvmType := 'i64';
      if AInstr.IntrinsicName <> '' then
      begin
        if Copy(AInstr.IntrinsicName, 1, 6) = 'const:' then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
            ' ' + Copy(AInstr.IntrinsicName, 7, Length(AInstr.IntrinsicName)) + ', 0');
          NoteValueLlvmType(AInstr.ResultId, LlvmType);
        end
        else if AInstr.IntrinsicName = 'null' then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = inttoptr i64 0 to ptr');
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end
        else if Length(AInstr.Operands) > 0 then
        begin
          { Addr may be i64 (PPointer/PUInt64 results); cast to ptr for load. }
          Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'ldaddr.' + IntToStr(AInstr.ResultId));
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr ' + Op);
          NoteValueLlvmType(AInstr.ResultId, LlvmType);
        end
        else
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr null');
          NoteValueLlvmType(AInstr.ResultId, LlvmType);
        end;
      end
      else if Length(AInstr.Operands) > 0 then
      begin
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
          'ldaddr.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr ' + Op);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end
      else
      begin
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr null');
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    end;
    hikStore:
      if Length(AInstr.Operands) >= 2 then
      begin
        { Value SSA may be wider/narrower than store TypeId (e.g. call i64 →
          store i32 for Integer unit vars). Reuse B25 cast helper. }
        if (LlvmType = '') or (LlvmType = 'void') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'st.' + IntToStr(AInstr.Operands[0].ValueId) + '.' +
          IntToStr(AInstr.Operands[1].ValueId));
        { Dest may be i64 pointer handle. }
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'ptr',
          'staddr.' + IntToStr(AInstr.Operands[1].ValueId));
        Emit('  store ' + LlvmType + ' ' + Op +
          ', ptr ' + LTruncVal);
      end;
    hikAdd:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikSub:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikMul:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = mul ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikDiv:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ' +
          DivOpcodeToLlvm(AInstr) + ' ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikMod:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ' +
          ModOpcodeToLlvm(AInstr) + ' ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikShl:
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = shl ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikShr:
      { Arithmetic shift right (SarLongint): 'ashr' keeps the sign bit —
        SarLongint bodies ran into this missing render and left a dangling
        SSA (opt: use of undefined value %v…). }
      if Length(AInstr.Operands) >= 2 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bin0.' + IntToStr(AInstr.ResultId));
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'bin1.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ashr ' + LlvmType +
          ' ' + Op + ', ' + LTruncVal);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikNeg:
      if Length(AInstr.Operands) >= 1 then
      begin
        if (LlvmType = '') or (LlvmType = 'void') or (LlvmType = 'ptr') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'neg.' + IntToStr(AInstr.ResultId));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' 0, ' + Op);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikCmpEq, hikCmpNe, hikCmpLt, hikCmpLe, hikCmpGt, hikCmpGe:
    begin
      if Length(AInstr.Operands) >= 2 then
      begin
        { Prefer noted SSA types so residual recvar/nil never becomes
          `icmp i64 0, %alloca` without ptrtoint. If either side is ptr,
          unify on ptr (inttoptr 0) rather than i64. }
        LlvmType := OperandTypeToLlvm(AInstr.Operands[0], 'i64');
        if ValueLlvmType(AInstr.Operands[0].ValueId, '') <> '' then
          LlvmType := ValueLlvmType(AInstr.Operands[0].ValueId, LlvmType);
        if ValueLlvmType(AInstr.Operands[1].ValueId, '') = 'ptr' then
          LlvmType := 'ptr'
        else if (LlvmType <> 'ptr') and
          (OperandTypeToLlvm(AInstr.Operands[1], '') = 'ptr') then
          LlvmType := 'ptr';
        LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'cmp0.' + IntToStr(AInstr.ResultId),
          OperandTypeToLlvm(AInstr.Operands[0], ''));
        Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, LlvmType,
          'cmp1.' + IntToStr(AInstr.ResultId),
          OperandTypeToLlvm(AInstr.Operands[1], ''));
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = icmp ' +
          CompareOpcodeToLlvm(AInstr) + ' ' + LlvmType + ' ' + LTruncVal +
          ', ' + Op);
        NoteValueLlvmType(AInstr.ResultId, 'i1');
      end;
    end;
    hikTrunc:
      if Length(AInstr.Operands) >= 1 then
      begin
        { Prefer noted SSA type: HIR TypeId may still say i32 after i64 load/call. }
        Op := ValueLlvmType(AInstr.Operands[0].ValueId,
          OperandTypeToLlvm(AInstr.Operands[0], 'i64'));
        LlvmType := TypeToLlvm(AInstr.TypeId);
        if Op = LlvmType then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = trunc ' + Op + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ' to ' + LlvmType);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikZext:
      if Length(AInstr.Operands) >= 1 then
      begin
        Op := ValueLlvmType(AInstr.Operands[0].ValueId,
          OperandTypeToLlvm(AInstr.Operands[0], 'i1'));
        LlvmType := TypeToLlvm(AInstr.TypeId);
        if Op = LlvmType then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = zext ' + Op + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ' to ' + LlvmType);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikSext:
      if Length(AInstr.Operands) >= 1 then
      begin
        Op := ValueLlvmType(AInstr.Operands[0].ValueId,
          OperandTypeToLlvm(AInstr.Operands[0], 'i64'));
        LlvmType := TypeToLlvm(AInstr.TypeId);
        if Op = LlvmType then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = sext ' + Op + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ' to ' + LlvmType);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikBitcast:
      if Length(AInstr.Operands) >= 1 then
      begin
        { int↔ptr / ptr↔ptr. Helper may emit %cast.*; rebind onto ResultId. }
        LlvmType := TypeToLlvm(AInstr.TypeId);
        if (LlvmType = '') or (LlvmType = 'void') then
          LlvmType := 'i64';
        Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, LlvmType,
          'bitcast.' + IntToStr(AInstr.ResultId),
          OperandTypeToLlvm(AInstr.Operands[0], ''));
        if Copy(LlvmType, 1, 1) = 'i' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType + ' ' +
            Op + ', 0')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = bitcast ' + LlvmType +
            ' ' + Op + ' to ' + LlvmType);
        NoteValueLlvmType(AInstr.ResultId, LlvmType);
      end;
    hikCall:
    begin
      if AInstr.CallTarget = 'np_process_init' then
      begin
        FNeedsProcessLifecycle := True;
        EmitCallInstr(AInstr);
        // After process_init, emit unit init calls in topological order
        if not FUnitInitCallsEmitted then
        begin
          EmitUnitInitCalls;
          FUnitInitCallsEmitted := True;
        end;
      end
      else if AInstr.CallTarget = 'np_process_fini' then
      begin
        FNeedsProcessLifecycle := True;
        if FProcessFiniEmitted then
          Exit; // already emitted (HIR node or halt-path inject)
        // Before process_fini, emit unit fini calls in reverse order
        if not FUnitFiniCallsEmitted then
        begin
          EmitUnitFiniCalls;
          FUnitFiniCallsEmitted := True;
        end;
        EmitCallInstr(AInstr);
        FProcessFiniEmitted := True;
      end
      else
        EmitCallInstr(AInstr);
    end;
    hikIndirectCall:
    begin
      { Operands[0]=callee (ptr or i64 fnptr); Operands[1..]=args. }
      EmitIndirectCallInstr(AInstr);
    end;
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'write_int' then
      begin
        { Batch 29: Operands[0]=value, optional [1]=fd (default 1).
          Cast to i64: global loads may be i32; mis-lowered string temps are ptr. }
        FNeedsWriteInt := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @write_i64_decimal(i64 ' +
            EmitCastValueToLlvmType(
              AInstr.Operands[0].ValueId, 'i64',
              'writeint.v.' + IntToStr(AInstr.Operands[0].ValueId),
              ValueLlvmType(AInstr.Operands[0].ValueId, '')) + ', i64 ' +
            EmitCastValueToLlvmType(
              AInstr.Operands[1].ValueId, 'i64',
              'writeint.fd.' + IntToStr(AInstr.Operands[1].ValueId),
              ValueLlvmType(AInstr.Operands[1].ValueId, '')) + ')')
        else if Length(AInstr.Operands) >= 1 then
          Emit('  call void @write_i64_decimal(i64 ' +
            EmitCastValueToLlvmType(
              AInstr.Operands[0].ValueId, 'i64',
              'writeint.v.' + IntToStr(AInstr.Operands[0].ValueId),
              ValueLlvmType(AInstr.Operands[0].ValueId, '')) + ', i64 1)');
      end
      else if AInstr.IntrinsicName = 'write_str' then
      begin
        { Batch 27: optional Operands[0] = fd (default 1). }
        I := AddStrConstant(AInstr.CallTarget);
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
            ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr @.str.' +
            IntToStr(I) + ', i64 ' + IntToStr(Length(AInstr.CallTarget)) + ')')
        else
          Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
            ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.' +
            IntToStr(I) + ', i64 ' + IntToStr(Length(AInstr.CallTarget)) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str_var' then
      begin
        { Batch 27: Operands[0]=data, [1]=len, optional [2]=fd (default 1). }
        if Length(AInstr.Operands) >= 2 then
        begin
          if Length(AInstr.Operands) >= 3 then
            Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
              ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 ' +
              ValueRef(AInstr.Operands[2].ValueId) + ', ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')')
          else
            Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
              ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_ptr' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_len' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 1');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_owner' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 2');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_alloc_size' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 3');
      end
      else if AInstr.IntrinsicName = 'string_release' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsStringOwnership := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_string_release(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'string_owner_clear' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  store ptr null, ptr ' +
            ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 0, ptr ' +
            ValueRef(AInstr.Operands[1].ValueId));
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
      else if AInstr.IntrinsicName = 'ret_str_owned' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.1 = insertvalue {ptr, i64, ptr, i64} undef, ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.2 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.1, i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', 1');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.3 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.2, ptr ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', 2');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.4 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.3, i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ', 3');
          Emit('  ret {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.4');
        end;
      end
      else if AInstr.IntrinsicName = 'global_ref' then
      begin
        { Materialize a real SSA def in this block. Silent ResultId→@g_ maps
          break when the global_ref instr is emitted after a use (block order). }
        Emit('  %v' + IntToStr(AInstr.ResultId) + ' = bitcast ptr @g_' +
          AInstr.CallTarget + ' to ptr');
        NoteValueLlvmType(AInstr.ResultId, 'ptr');
        FGlobalRefNames.Push(AInstr.CallTarget);
        FGlobalRefIds.Push(AInstr.ResultId);
      end
      else if AInstr.IntrinsicName = 'func_ref' then
      begin
        { Procedural pointer: materialize @Name as i64 for i64 formals. }
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ptrtoint ptr ' +
          LlvmGlobalRef(AInstr.CallTarget) + ' to i64');
        NoteValueLlvmType(AInstr.ResultId, 'i64');
      end
      else if AInstr.IntrinsicName = 'gep_i64' then
      begin
        { GEP index is always i64 in LLVM; small int consts (i8/i32 Byte/Integer)
          must be cast — otherwise opt rejects "defined with type 'i8' but expected 'i64'". }
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
            'gep64.' + IntToStr(AInstr.ResultId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'gep64.base.' + IntToStr(AInstr.ResultId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i64, ptr ' + LTruncVal + ', i64 ' + Op);
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end;
      end
      else if AInstr.IntrinsicName = 'gep_i8' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
            'gep8.' + IntToStr(AInstr.ResultId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'gep8.base.' + IntToStr(AInstr.ResultId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i8, ptr ' + LTruncVal + ', i64 ' + Op);
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end;
      end
      else if AInstr.IntrinsicName = 'gep_i16' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
            'gep16.' + IntToStr(AInstr.ResultId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'gep16.base.' + IntToStr(AInstr.ResultId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i16, ptr ' + LTruncVal + ', i64 ' + Op);
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end;
      end
      else if AInstr.IntrinsicName = 'gep_i32' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
            'gep32.' + IntToStr(AInstr.ResultId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'gep32.base.' + IntToStr(AInstr.ResultId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i32, ptr ' + LTruncVal + ', i64 ' + Op);
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end;
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
      else if AInstr.IntrinsicName = 'upcase' then
      begin
        { UpCase(char): ['a'..'z'] → c-32, branchless select. }
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %upc.ge.' + IntToStr(AInstr.ResultId) +
            ' = icmp sge i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 97');
          Emit('  %upc.le.' + IntToStr(AInstr.ResultId) +
            ' = icmp sle i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 122');
          Emit('  %upc.in.' + IntToStr(AInstr.ResultId) +
            ' = and i1 %upc.ge.' + IntToStr(AInstr.ResultId) +
            ', %upc.le.' + IntToStr(AInstr.ResultId));
          Emit('  %upc.sub.' + IntToStr(AInstr.ResultId) +
            ' = sub i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 32');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = select i1 %upc.in.' + IntToStr(AInstr.ResultId) +
            ', i64 %upc.sub.' + IntToStr(AInstr.ResultId) +
            ', i64 ' + ValueRef(AInstr.Operands[0].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'bsf' then
      begin
        { FPC Bsf*: index of least-significant set bit → llvm.cttz (zero undef). }
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @llvm.cttz.i64(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i1 true)');
      end
      else if AInstr.IntrinsicName = 'bsr' then
      begin
        { FPC Bsr*: index of most-significant set bit → 63 - llvm.ctlz. }
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %bsr.lz.' + IntToStr(AInstr.ResultId) +
            ' = call i64 @llvm.ctlz.i64(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i1 true)');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = sub i64 63, %bsr.lz.' + IntToStr(AInstr.ResultId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_const' then
      begin
        { CallTarget may be decoded content (assign-tstring-literal) or a
          quoted token from older paths. Only strip one surrounding quote pair. }
        Op := AInstr.CallTarget;
        if (Length(Op) >= 2) and
          (((Op[1] = '''') and (Op[Length(Op)] = '''')) or
           ((Op[1] = '"') and (Op[Length(Op)] = '"'))) then
          Op := Copy(Op, 2, Length(Op) - 2);
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = getelementptr i8, ptr @.str.' + IntToStr(
            AddStrConstant(Op)) + ', i64 0');
      end
      else if AInstr.IntrinsicName = 'str_cmp' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          { Lengths may still be typed i32 in HIR while SSA is i64 (tstring_len). }
          Op := EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
            'strcmp.a.' + IntToStr(AInstr.ResultId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[3].ValueId, 'i64',
            'strcmp.b.' + IntToStr(AInstr.ResultId));
          if AInstr.CallTarget = 'ne' then
          begin
            Emit('  %strcmp.' + IntToStr(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + Op +
              ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) +
              ', i64 ' + LTruncVal + ')');
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = xor i64 %strcmp.' + IntToStr(AInstr.ResultId) + ', 1');
          end
          else
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + Op +
              ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) +
              ', i64 ' + LTruncVal + ')');
          NoteValueLlvmType(AInstr.ResultId, 'i64');
          FNeedsStrCmp := True;
        end;
      end
      else if AInstr.IntrinsicName = 'str_pos' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @np_str_pos(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          FNeedsStrCmp := True;  // 复用标志：str_cmp/str_pos 一起声明（linker 忽略未引用的 declare）
        end;
      end
      else if AInstr.IntrinsicName = 'arr_alloc' then
      begin
        { Legacy bare path; production field setlength uses typed sckHeapAlloc. }
        FNeedsAlloc := True;
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
        { Legacy bare path; no production builder site. }
        FNeedsAlloc := True;
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
        { Legacy bare path; production uses typed sckObjectAlloc. }
        FNeedsAlloc := True;
        FNeedsObjectAlloc := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_object_alloc(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'vmt_store' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
          Emit('  store ptr ' + LlvmGlobalRef(AInstr.CallTarget + '.vmt') +
            ', ptr ' + ValueRef(AInstr.Operands[0].ValueId));
      end
      else if AInstr.IntrinsicName = 'imt_store' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
          Emit('  store ptr ' + LlvmGlobalRef(AInstr.CallTarget) +
            ', ptr ' + ValueRef(AInstr.Operands[0].ValueId));
      end
      else if AInstr.IntrinsicName = 'exc_store' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  store ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ptr @__np_exc_object');
      end
      else if AInstr.IntrinsicName = 'exc_load' then
      begin
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = load ptr, ptr @__np_exc_object');
      end
      else if AInstr.IntrinsicName = 'vcall' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          if TypeToLlvm(AInstr.TypeId) = 'void' then
            Op := '  call void '
          else
            Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + TypeToLlvm(AInstr.TypeId) + ' ';
          Op := Op + ValueRef(AInstr.Operands[0].ValueId) +
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
            ', ' + LlvmGlobalRef(AInstr.CallTarget + '.vmt'));
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
      end
      else if AInstr.IntrinsicName = 'fillchar' then
      begin
        { FillChar(dst, count, value) → np_memset(ptr, i8 val, i64 n).
          Count/value often land as i8/i32 constants; cast instead of bare trunc i64. }
        if Length(AInstr.Operands) >= 3 then
        begin
          Op := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
            'fill.dst.' + IntToStr(AInstr.Operands[0].ValueId));
          LTruncVal := EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i8',
            'fill.val.' + IntToStr(AInstr.Operands[2].ValueId));
          if AInstr.ResultId > 0 then
          begin
            Emit('  ' + ValueRef(AInstr.ResultId) + ' = add i8 ' + LTruncVal + ', 0');
            NoteValueLlvmType(AInstr.ResultId, 'i8');
            LTruncVal := ValueRef(AInstr.ResultId);
          end;
          Emit('  call void @np_memset(ptr ' + Op + ', i8 ' + LTruncVal +
            ', i64 ' + EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
              'fill.len.' + IntToStr(AInstr.Operands[1].ValueId)) + ')');
          FNeedsMemset := True;
        end;
      end
      else if AInstr.IntrinsicName = 'move' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  call void @np_memmove(ptr ' +
            EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'ptr',
              'mv.dst.' + IntToStr(AInstr.Operands[1].ValueId)) + ', ptr ' +
            EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
              'mv.src.' + IntToStr(AInstr.Operands[0].ValueId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'mv.len.' + IntToStr(AInstr.Operands[2].ValueId)) + ')');
          FNeedsMemmove := True;
        end;
      end
      else if AInstr.IntrinsicName = 'interlocked-cas' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  %cas.pair.' + IntToStr(AInstr.ResultId) +
            ' = cmpxchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
            ' seq_cst seq_cst');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue { i64, i1 } %cas.pair.' +
            IntToStr(AInstr.ResultId) + ', 0');
        end;
      end
      else if AInstr.IntrinsicName = 'interlocked-cas64' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  %cas64.pair.' + IntToStr(AInstr.ResultId) +
            ' = cmpxchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
            ' seq_cst seq_cst');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue { i64, i1 } %cas64.pair.' +
            IntToStr(AInstr.ResultId) + ', 0');
        end;
      end
      else if AInstr.IntrinsicName = 'interlocked-xchg' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw xchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
      end
      else if AInstr.IntrinsicName = 'interlocked-fetch-add' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw add ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
      end
      else if AInstr.IntrinsicName = 'interlocked-fetch-add64' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw add ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
      end
      else if AInstr.IntrinsicName = 'tstring_init' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_init(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_fini' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_fini(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_assign' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_assign(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_ret_move' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
        begin
          { Use %agg.result for TString sret functions (sret_ptr is skipped) }
          if FCurrentFuncIsTStringSret then
            Emit('  call void @np_tstring_ret_move(ptr %agg.result, ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')')
          else
            Emit('  call void @np_tstring_ret_move(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'tstring_ret_copy' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
        begin
          if FCurrentFuncIsTStringSret then
            Emit('  call void @np_tstring_ret_copy(ptr %agg.result, ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')')
          else
            Emit('  call void @np_tstring_ret_copy(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'tstring_from_literal' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 3 then
          Emit('  call void @np_tstring_from_literal(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'tslit.len.' + IntToStr(AInstr.Operands[2].ValueId),
              OperandTypeToLlvm(AInstr.Operands[2], 'i64')) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_copy' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 4 then
          Emit('  call void @np_tstring_copy(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'tscopy.start.' + IntToStr(AInstr.Operands[2].ValueId),
              OperandTypeToLlvm(AInstr.Operands[2],
                ValueLlvmType(AInstr.Operands[2].ValueId, 'i64'))) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[3].ValueId, 'i64',
              'tscopy.count.' + IntToStr(AInstr.Operands[3].ValueId),
              OperandTypeToLlvm(AInstr.Operands[3],
                ValueLlvmType(AInstr.Operands[3].ValueId, 'i64'))) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_concat' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 3 then
          Emit('  call void @np_tstring_concat(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[2].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_field_assign' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_field_assign(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_field_fini' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_field_fini(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_len' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @np_tstring_len(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
          NoteValueLlvmType(AInstr.ResultId, 'i64');
        end;
      end
      else if AInstr.IntrinsicName = 'tstring_from_int' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_from_int(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(
              AInstr.Operands[1].ValueId, 'i64',
              'tsfromint.' + IntToStr(AInstr.Operands[0].ValueId) + '.' +
                IntToStr(AInstr.Operands[1].ValueId),
              ValueLlvmType(AInstr.Operands[1].ValueId, '')) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_data' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_tstring_data(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
          NoteValueLlvmType(AInstr.ResultId, 'ptr');
        end;
      end
    end;
    hikTryBegin:
    begin
      { Legacy bare path; production uses typed sckExceptionTryPush. }
      FNeedsExceptionRuntime := True;
      Inc(FTryCounter);
      Emit('  ; --- try begin ---');
      Emit('  %jmpbuf.' + IntToStr(FTryCounter) + ' = alloca [9 x ptr]');
      Emit('  call void @np_try_push(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %setjmp.' + IntToStr(FTryCounter) + ' = call i32 @setjmp(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %is_exc.' + IntToStr(FTryCounter) + ' = icmp ne i32 %setjmp.' + IntToStr(FTryCounter) + ', 0');
      if AInstr.IntrinsicName <> '' then
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) + ', label %' +
          Trim(AInstr.IntrinsicName) + ', label %try.body.' + IntToStr(FTryCounter))
      else
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) + ', label %try.exc.' +
          IntToStr(FTryCounter) + ', label %try.body.' + IntToStr(FTryCounter));
      Emit('try.body.' + IntToStr(FTryCounter) + ':');
    end;
    hikTryEnd:
    begin
      Emit('  ; --- try end ---');
      Emit('  call void @np_try_pop()');
    end;
    hikFinallyBegin:
    begin
      Emit('  ; --- finally begin ---');
    end;
    hikFinallyEnd:
    begin
      Emit('  ; --- finally end ---');
      Emit('  call void @np_finally_end()');
    end;
    hikExceptBegin:
    begin
      Emit('  ; --- except begin ---');
    end;
    hikExceptEnd:
    begin
      Emit('  ; --- except end ---');
      Emit('  call void @np_except_end()');
    end;
    hikRaise:
    begin
      FNeedsExceptionRuntime := True;
      Emit('  call void @np_raise()');
      Emit('  unreachable');
    end;
    hikConstFloat:
    begin
      { Emit float constant as hex-encoded double for LLVM IR }
      Emit('  ' + ValueRef(AInstr.ResultId) + ' = fadd double 0.0, ' +
        FormatFloat('0.0################', AInstr.FloatValue));
    end;

    hikGetFieldPtr:
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = getelementptr %' +
            AInstr.StructTypeName + ', %' + AInstr.StructTypeName + '* ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', i32 0, i32 ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = getelementptr ' +
            LlvmType + ', ' + LlvmType + '* ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', i32 0, i32 ' + IntToStr(AInstr.FieldIndex));
      end;

    hikExtractField:
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = extractvalue %' +
            AInstr.StructTypeName + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ; hikExtractField: no struct type name');
      end;

    hikInsertField:
      if Length(AInstr.Operands) >= 2 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = insertvalue %' +
            AInstr.StructTypeName + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ' +
            LlvmType + ' ' + ValueRef(AInstr.Operands[1].ValueId) +
            ', ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ; hikInsertField: no struct type name');
      end;
  end;

  { Append debug location metadata if available }
  if FDebugInfoEnabled and (FCurrentDISubprogram >= 0) and
    (AInstr.SourceLine > 0) and (FLines.Count > 0) then
  begin
    LDbgIdx := EmitDILocation(AInstr.SourceLine, AInstr.SourceCol);
    if LDbgIdx >= 0 then
      FLines.GetPtr(FLines.Count - 1)^ :=
        FLines[FLines.Count - 1] + ', !dbg !' + IntToStr(LDbgIdx);
  end;
end;
