program test_unit_lifecycle_llvm_ordering;

{$mode objfpc}{$H+}

{ D3 narrow slice: prove multi-unit LLVM call-order shape only.
  process_init → unit_init (topo) → unit_fini (reverse) → process_fini.
  Does NOT elevate typed ledger past scelSemantic, and does NOT claim
  host-free executable multi-unit runtime success. }

uses
  nextpas.compiler.sema.semantic_model, np_hir_builder, np_hir_model, np_hir_types,
  np_hir_llvm_emitter;

function RequireOrder(const AText, AFirst, ASecond, ALabel: string): Boolean;
var
  P1, P2: SizeInt;
begin
  P1 := Pos(AFirst, AText);
  P2 := Pos(ASecond, AText);
  if (P1 = 0) or (P2 = 0) or (P1 >= P2) then
  begin
    WriteLn('FAIL: ', ALabel, ' order');
    WriteLn('  expected "', AFirst, '" before "', ASecond, '"');
    Exit(False);
  end;
  Result := True;
end;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmIr: string;
  Order: array[0..1] of string;
begin
  { Two units: Leaf before Mid in init order → Mid before Leaf in fini. }
  Model := TSemanticModel.Create;
  try
    Order[0] := 'Leaf';
    Order[1] := 'Mid';
    Model.SetUnitInitOrder(Order);
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        if Pos('call void @np_process_init()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call void @np_process_init()');
          Halt(1);
        end;
        if Pos('call i64 @np_unit_init_leaf()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call i64 @np_unit_init_leaf()');
          Halt(2);
        end;
        if Pos('call i64 @np_unit_init_mid()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call i64 @np_unit_init_mid()');
          Halt(3);
        end;
        if Pos('call i64 @np_unit_fini_mid()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call i64 @np_unit_fini_mid()');
          Halt(4);
        end;
        if Pos('call i64 @np_unit_fini_leaf()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call i64 @np_unit_fini_leaf()');
          Halt(5);
        end;
        if Pos('call void @np_process_fini()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call void @np_process_fini()');
          Halt(6);
        end;

        if not RequireOrder(LlvmIr,
          'call void @np_process_init()',
          'call i64 @np_unit_init_leaf()',
          'process_init before unit_init_leaf') then
          Halt(10);
        if not RequireOrder(LlvmIr,
          'call i64 @np_unit_init_leaf()',
          'call i64 @np_unit_init_mid()',
          'topo unit_init leaf before mid') then
          Halt(11);
        if not RequireOrder(LlvmIr,
          'call i64 @np_unit_init_mid()',
          'call i64 @np_unit_fini_mid()',
          'init before reverse fini') then
          Halt(12);
        if not RequireOrder(LlvmIr,
          'call i64 @np_unit_fini_mid()',
          'call i64 @np_unit_fini_leaf()',
          'reverse unit_fini mid before leaf') then
          Halt(13);
        if not RequireOrder(LlvmIr,
          'call i64 @np_unit_fini_leaf()',
          'call void @np_process_fini()',
          'unit_fini before process_fini') then
          Halt(14);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { Without UnitInitOrder, process lifecycle must not invent unit calls. }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');
    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;
        if Pos('np_unit_init_', LlvmIr) <> 0 then
        begin
          WriteLn('FAIL: unexpected np_unit_init_ without UnitInitOrder');
          Halt(20);
        end;
        if Pos('np_unit_fini_', LlvmIr) <> 0 then
        begin
          WriteLn('FAIL: unexpected np_unit_fini_ without UnitInitOrder');
          Halt(21);
        end;
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  WriteLn('unit lifecycle LLVM ordering tests passed');
end.