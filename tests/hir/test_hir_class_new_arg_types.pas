program test_hir_class_new_arg_types;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Verifier: THIRVerifier;
  LlvmText: string;
  CallPos, LineEndPos: LongInt;
  CallLine: string;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-class-new-arg-types-failure=', AMessage);
  Halt(1);
end;

begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  Verifier := nil;
  try
    SemaModel.AddTypedHirNode('var-decl-ptr-runtime', 'P', 0, 0, 'P');
    SemaModel.AddTypedHirNode(
      'class-new-runtime',
      '24',
      0,
      0,
      'R' + #9 + 'TRect.Create' + #9 +
      'var P' + #10 + 'vcall 0 0' + #10 + #9 +
      'var P' + #10 + 'vcall 1 0' + #10
    );

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    CallPos := Pos('@TRect.Create(', LlvmText);
    if CallPos = 0 then
      Fail('missing-constructor-call');
    LineEndPos := Pos(LineEnding, Copy(LlvmText, CallPos, MaxInt));
    if LineEndPos = 0 then
      CallLine := Copy(LlvmText, CallPos, MaxInt)
    else
      CallLine := Copy(LlvmText, CallPos, LineEndPos - 1);

    if Pos('@TRect.Create(ptr ', CallLine) = 0 then
      Fail('missing-self-pointer-arg');
    if Pos(', i64 ', CallLine) = 0 then
      Fail('missing-first-integer-constructor-arg');
    if Pos(', i64 ', Copy(CallLine, Pos(', i64 ', CallLine) + 1, MaxInt)) = 0 then
      Fail('missing-second-integer-constructor-arg');
    if Pos('@TRect.Create(ptr %', CallLine) = 0 then
      Fail('unexpected-constructor-call-shape');
    if Pos(', ptr %', Copy(CallLine, Pos('@TRect.Create(ptr ', CallLine) + 1, MaxInt)) <> 0 then
      Fail('constructor-method-result-typed-as-pointer');

    WriteLn('hir-class-new-arg-types-status=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.
