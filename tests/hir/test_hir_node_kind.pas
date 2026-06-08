program test_hir_node_kind;

{$mode objfpc}{$H+}

uses
  np_hir_types;

procedure Fail(const AMsg: string);
begin
  WriteLn('FAIL: ', AMsg);
  Halt(1);
end;

procedure TestAllMappings;
begin
  if ParseHirNodeKind('var-decl-runtime') <> hnkVarDeclRuntime then Fail('var-decl-runtime');
  if ParseHirNodeKind('var-decl-str-runtime') <> hnkVarDeclStrRuntime then Fail('var-decl-str-runtime');
  if ParseHirNodeKind('var-decl-str-owned-runtime') = hnkUnknown then Fail('var-decl-str-owned-runtime');
  if ParseHirNodeKind('var-decl-str-borrowed-runtime') = hnkUnknown then Fail('var-decl-str-borrowed-runtime');
  if ParseHirNodeKind('var-decl-arr-runtime') <> hnkVarDeclArrRuntime then Fail('var-decl-arr-runtime');
  if ParseHirNodeKind('var-decl-ptr-runtime') <> hnkVarDeclPtrRuntime then Fail('var-decl-ptr-runtime');
  if ParseHirNodeKind('var-decl-varref-runtime') <> hnkVarDeclVarrefRuntime then Fail('var-decl-varref-runtime');
  if ParseHirNodeKind('var-decl-record-runtime') <> hnkVarDeclRecordRuntime then Fail('var-decl-record-runtime');
  if ParseHirNodeKind('assign-runtime') <> hnkAssignRuntime then Fail('assign-runtime');
  if ParseHirNodeKind('assign-str-runtime') <> hnkAssignStrRuntime then Fail('assign-str-runtime');
  if ParseHirNodeKind('assign-str-literal-runtime') <> hnkAssignStrLiteralRuntime then Fail('assign-str-literal-runtime');
  if ParseHirNodeKind('assign-str-copy-runtime') <> hnkAssignStrCopyRuntime then Fail('assign-str-copy-runtime');
  if ParseHirNodeKind('assign-str-call-runtime') <> hnkAssignStrCallRuntime then Fail('assign-str-call-runtime');
  if ParseHirNodeKind('assign-str-owned-call-runtime') <> hnkAssignStrOwnedCallRuntime then Fail('assign-str-owned-call-runtime');
  if ParseHirNodeKind('assign-str-vcall-runtime') <> hnkAssignStrVcallRuntime then Fail('assign-str-vcall-runtime');
  if ParseHirNodeKind('assign-str-concat-runtime') <> hnkAssignStrConcatRuntime then Fail('assign-str-concat-runtime');
  if ParseHirNodeKind('assign-str-owned-concat-runtime') = hnkUnknown then Fail('assign-str-owned-concat-runtime');
  if ParseHirNodeKind('assign-str-move-to-result-runtime') <> hnkAssignStrMoveToResultRuntime then Fail('assign-str-move-to-result-runtime');
  if ParseHirNodeKind('halt-call-runtime') <> hnkHaltCallRuntime then Fail('halt-call-runtime');
  if ParseHirNodeKind('halt-call') <> hnkHaltCall then Fail('halt-call');
  if ParseHirNodeKind('cond-br-runtime') <> hnkCondBrRuntime then Fail('cond-br-runtime');
  if ParseHirNodeKind('switch-runtime') <> hnkSwitchRuntime then Fail('switch-runtime');
  if ParseHirNodeKind('br-runtime') <> hnkBrRuntime then Fail('br-runtime');
  if ParseHirNodeKind('block-label-runtime') <> hnkBlockLabelRuntime then Fail('block-label-runtime');
  if ParseHirNodeKind('function-body-begin') <> hnkFunctionBodyBegin then Fail('function-body-begin');
  if ParseHirNodeKind('function-body-end') <> hnkFunctionBodyEnd then Fail('function-body-end');
  if ParseHirNodeKind('ret-runtime') <> hnkRetRuntime then Fail('ret-runtime');
  if ParseHirNodeKind('ret-str-runtime') <> hnkRetStrRuntime then Fail('ret-str-runtime');
  if ParseHirNodeKind('ret-str-owned-runtime') <> hnkRetStrOwnedRuntime then Fail('ret-str-owned-runtime');
  if ParseHirNodeKind('call-runtime') <> hnkCallRuntime then Fail('call-runtime');
  if ParseHirNodeKind('string-temp-owned-runtime') <> hnkStringTempOwnedRuntime then Fail('string-temp-owned-runtime');
  if ParseHirNodeKind('string-temp-borrow-arg-runtime') <> hnkStringTempBorrowArgRuntime then Fail('string-temp-borrow-arg-runtime');
  if ParseHirNodeKind('string-temp-release-runtime') <> hnkStringTempReleaseRuntime then Fail('string-temp-release-runtime');
  if ParseHirNodeKind('object-free-runtime') <> hnkObjectFreeRuntime then Fail('object-free-runtime');
  if ParseHirNodeKind('int-to-str-runtime') <> hnkIntToStrRuntime then Fail('int-to-str-runtime');
  if ParseHirNodeKind('int-to-str-owned-runtime') = hnkUnknown then Fail('int-to-str-owned-runtime');
  if ParseHirNodeKind('copy-str-runtime') <> hnkCopyStrRuntime then Fail('copy-str-runtime');
  if ParseHirNodeKind('write-int-runtime') <> hnkWriteIntRuntime then Fail('write-int-runtime');
  if ParseHirNodeKind('write-string-runtime') <> hnkWriteStringRuntime then Fail('write-string-runtime');
  if ParseHirNodeKind('write-str-var-runtime') <> hnkWriteStrVarRuntime then Fail('write-str-var-runtime');
  if ParseHirNodeKind('write-call') <> hnkWriteCall then Fail('write-call');
  if ParseHirNodeKind('setlength-arr-runtime') <> hnkSetLengthArrRuntime then Fail('setlength-arr-runtime');
  if ParseHirNodeKind('setlength-field-arr-runtime') = hnkUnknown then Fail('setlength-field-arr-runtime');
  if ParseHirNodeKind('var-decl-arr-borrowed-runtime') = hnkUnknown then Fail('var-decl-arr-borrowed-runtime');
  if ParseHirNodeKind('dynarray-cleanup-runtime') = hnkUnknown then Fail('dynarray-cleanup-runtime');
  if ParseHirNodeKind('string-cleanup-runtime') = hnkUnknown then Fail('string-cleanup-runtime');
  if ParseHirNodeKind('assign-arr-elem-runtime') <> hnkAssignArrElemRuntime then Fail('assign-arr-elem-runtime');
  if ParseHirNodeKind('method-body-begin') <> hnkMethodBodyBegin then Fail('method-body-begin');
  if ParseHirNodeKind('class-new-runtime') <> hnkClassNewRuntime then Fail('class-new-runtime');
  if ParseHirNodeKind('field-store-runtime') <> hnkFieldStoreRuntime then Fail('field-store-runtime');
  if ParseHirNodeKind('record-field-store-runtime') <> hnkRecordFieldStoreRuntime then Fail('record-field-store-runtime');
  if ParseHirNodeKind('record-copy-runtime') <> hnkRecordCopyRuntime then Fail('record-copy-runtime');
  if ParseHirNodeKind('field-store-str-runtime') <> hnkFieldStoreStrRuntime then Fail('field-store-str-runtime');
  if ParseHirNodeKind('assign-str-field-load-runtime') <> hnkAssignStrFieldLoadRuntime then Fail('assign-str-field-load-runtime');
  if ParseHirNodeKind('vmt-store-runtime') <> hnkVmtStoreRuntime then Fail('vmt-store-runtime');
end;

procedure TestUnknown;
begin
  if ParseHirNodeKind('') <> hnkUnknown then Fail('empty');
  if ParseHirNodeKind('typo-garbage') <> hnkUnknown then Fail('typo');
  if ParseHirNodeKind('var-decl-runtim') <> hnkUnknown then Fail('truncated');
end;

begin
  TestAllMappings;
  TestUnknown;
  WriteLn('hir-node-kind-status=pass');
end.
