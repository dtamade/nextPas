{$mode objfpc}{$H+}
program test_llvm_struct;

{ LLVM emitter struct type 单元测试
  验证:
  1. EmitStructTypes 生成正确的 %TName = type {...} 声明
  2. mskAlloca 对 struct 类型使用 %TName
  3. mskExtractField/mskInsertField 使用 extractvalue/insertvalue
  4. mskGetFieldPtr 对 struct 类型使用 getelementptr + %TName
}

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.to_llvm;

function Contains(const Haystack, Needle: string): Boolean;
begin
  Result := Pos(Needle, Haystack) > 0;
end;

var
  Module: TMirModule;
  Trans: TMirToLlvmTranslator;
  Ir: string;
  FuncId: TMirFuncId;
  BlockId: TMirBlockId;
  Stmt: TMirStmt;
  V1, V2, V3, V4: TMirValueId;
  Fields: array[0..1] of TMirStructField;
  Term: TMirTerminator;
begin
  { 1. 注册 struct 类型 }
  Module := TMirModule.Create('test_struct');
  
  Fields[0].Name := 'x';
  Fields[0].BitWidth := 32;
  Fields[0].IsSigned := True;
  Fields[1].Name := 'y';
  Fields[1].BitWidth := 32;
  Fields[1].IsSigned := True;
  
  if Module.AddStructType('Point', Fields) <> 0 then
    Halt(1);  { 第一个 struct 类型索引应为 0 }

  { 2. 创建函数 }
  FuncId := Module.AddFunction('make_point', 0, False);
  Module.AddParam(FuncId, 'px', 32, True);
  Module.AddParam(FuncId, 'py', 32, True);
  
  BlockId := Module.AddBlock(FuncId, 'entry');
  Module.SetEntryBlock(FuncId, BlockId);

  { 3. 分配 struct 变量 (mskAlloca with struct type) }
  V1 := Module.NewValue;
  FillChar(Stmt, SizeOf(Stmt), 0);
  Stmt.Kind := mskAlloca;
  Stmt.Dst := V1;
  Stmt.StructTypeName := 'Point';
  Module.AddStmt(FuncId, BlockId, Stmt);

  { 4. getelementptr 获取字段指针 (mskGetFieldPtr with struct type) }
  V2 := Module.NewValue;
  FillChar(Stmt, SizeOf(Stmt), 0);
  Stmt.Kind := mskGetFieldPtr;
  Stmt.Dst := V2;
  Stmt.Src := MirLocal(V1, 0, False);
  Stmt.Src.StructTypeName := 'Point';
  Stmt.FieldIndex := 0;  { field 'x' }
  Module.AddStmt(FuncId, BlockId, Stmt);

  { 5. extractvalue (mskExtractField) }
  V3 := Module.NewValue;
  FillChar(Stmt, SizeOf(Stmt), 0);
  Stmt.Kind := mskExtractField;
  Stmt.Dst := V3;
  Stmt.Src := MirLocal(V1, 0, False);
  Stmt.Src.StructTypeName := 'Point';
  Stmt.FieldIndex := 0;
  Module.AddStmt(FuncId, BlockId, Stmt);

  { 6. insertvalue (mskInsertField) }
  V4 := Module.NewValue;
  FillChar(Stmt, SizeOf(Stmt), 0);
  Stmt.Kind := mskInsertField;
  Stmt.Dst := V4;
  Stmt.Src := MirLocal(V1, 0, False);
  Stmt.Src.StructTypeName := 'Point';
  Stmt.Rhs := MirIntConst(42, 32);
  Stmt.FieldIndex := 0;
  Module.AddStmt(FuncId, BlockId, Stmt);

  { 7. 设置终结符 }
  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := mtkReturn;
  Term.ReturnValue := 0;
  Module.SetTerminator(FuncId, BlockId, Term);

  { 8. 翻译并验证 }
  Trans := TMirToLlvmTranslator.Create(Module);
  Ir := Trans.Translate;

  { 验证 struct 类型声明 }
  if not Contains(Ir, '%Point = type {i32, i32}') then
    Halt(2);

  { 验证 alloca 使用 struct 类型 }
  if not Contains(Ir, 'alloca %Point') then
    Halt(3);

  { 验证 getelementptr 使用 struct 类型 }
  if not Contains(Ir, 'getelementptr %Point, %Point*') then
    Halt(4);

  { 验证 extractvalue }
  if not Contains(Ir, 'extractvalue %Point') then
    Halt(5);

  { 验证 insertvalue }
  if not Contains(Ir, 'insertvalue %Point') then
    Halt(6);

  Trans.Free;
  Module.Free;
end.
