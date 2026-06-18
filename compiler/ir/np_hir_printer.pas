unit np_hir_printer;

{$mode objfpc}{$H+}

interface

uses
  np_hir_types, np_hir_model;

type
  THIRPrinter = class
  private
    FModule: THIRModule;
    FLines: array of string;
    FLineCount: LongInt;
    procedure Emit(const S: string);
    procedure AppendLast(const S: string);
    function LastLine: string;
    procedure PrintType(AId: THIRTypeId);
    procedure PrintInstr(const AInstr: THIRInstr);
    procedure PrintTerminator(const ATerm: THIRTerminator);
    procedure PrintBlock(const ABlock: THIRBlock);
    procedure PrintFunction(const AFunc: THIRFunction);
    procedure PrintGlobal(const AGlobal: THIRGlobal);
  public
    constructor Create(AModule: THIRModule);
    procedure Print;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

uses
  nextpas.core.text.conv;

constructor THIRPrinter.Create(AModule: THIRModule);
begin
  inherited Create;
  FModule := AModule;
  FLineCount := 0;
  SetLength(FLines, 0);
end;

procedure THIRPrinter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
end;

procedure THIRPrinter.AppendLast(const S: string);
begin
  if FLineCount > 0 then
    FLines[FLineCount - 1] := FLines[FLineCount - 1] + S;
end;

function THIRPrinter.LastLine: string;
begin
  if FLineCount > 0 then
    Result := FLines[FLineCount - 1]
  else
    Result := '';
end;

function TypeKindStr(AKind: THIRTypeKind): string;
begin
  case AKind of
    htkVoid: Result := 'void';
    htkBool: Result := 'bool';
    htkInt: Result := 'int';
    htkFloat: Result := 'float';
    htkChar: Result := 'char';
    htkArray: Result := 'array';
    htkDynArray: Result := 'dynarray';
    htkString: Result := 'string';
    htkSet: Result := 'set';
    htkRecord: Result := 'record';
    htkClass: Result := 'class';
    htkInterface: Result := 'interface';
    htkClassRef: Result := 'classref';
    htkFunc: Result := 'func';
    htkPointer: Result := 'ptr';
    htkUntypedPtr: Result := 'rawptr';
  end;
end;

procedure THIRPrinter.PrintType(AId: THIRTypeId);
var
  T: THIRTypeRec;
begin
  if AId = 0 then
  begin
    AppendLast('void');
    Exit;
  end;
  T := FModule.Types.GetType(AId);
  case T.Kind of
    htkVoid: AppendLast('void');
    htkBool: AppendLast('bool');
    htkInt:
      if T.Signed then
        AppendLast('i' + IntToStr(T.BitWidth))
      else
        AppendLast('u' + IntToStr(T.BitWidth));
    htkFloat:
      case T.FloatWidth of
        fwF32: AppendLast('f32');
        fwF64: AppendLast('f64');
        fwF80: AppendLast('f80');
      end;
    htkChar:
      if T.CharWidth = 2 then
        AppendLast('widechar')
      else
        AppendLast('char');
    htkString:
      case T.StringKind of
        skShort: AppendLast('shortstring');
        skAnsi: AppendLast('ansistring');
        skUnicode: AppendLast('unicodestring');
      end;
    htkPointer:
      AppendLast('ptr<' + IntToStr(T.PointeeTypeId) + '>');
    htkArray:
      AppendLast('array[' + IntToStr(T.LowBound) + '..' + IntToStr(T.HighBound) + ']<' + IntToStr(T.ElemTypeId) + '>');
    htkDynArray:
      AppendLast('dynarray<' + IntToStr(T.ElemTypeId) + '>');
    htkRecord:
      AppendLast('record(' + T.Name + ')');
  else
    AppendLast(TypeKindStr(T.Kind));
  end;
end;

procedure THIRPrinter.PrintInstr(const AInstr: THIRInstr);
var
  Line: string;
  I: LongInt;
begin
  Line := '    %' + IntToStr(AInstr.ResultId) + ' = ';
  case AInstr.Kind of
    hikAlloca: Line := Line + 'alloca ';
    hikLoad: Line := Line + 'load ';
    hikStore: Line := Line + 'store ';
    hikGetFieldPtr: Line := Line + 'getfieldptr ';
    hikAdd: Line := Line + 'add ';
    hikSub: Line := Line + 'sub ';
    hikMul: Line := Line + 'mul ';
    hikDiv: Line := Line + 'div ';
    hikMod: Line := Line + 'mod ';
    hikNeg: Line := Line + 'neg ';
    hikNot: Line := Line + 'not ';
    hikBitAnd: Line := Line + 'and ';
    hikBitOr: Line := Line + 'or ';
    hikBitXor: Line := Line + 'xor ';
    hikShl: Line := Line + 'shl ';
    hikShr: Line := Line + 'shr ';
    hikCmpEq: Line := Line + 'cmp.eq ';
    hikCmpNe: Line := Line + 'cmp.ne ';
    hikCmpLt: Line := Line + 'cmp.lt ';
    hikCmpLe: Line := Line + 'cmp.le ';
    hikCmpGt: Line := Line + 'cmp.gt ';
    hikCmpGe: Line := Line + 'cmp.ge ';
    hikTrunc: Line := Line + 'trunc ';
    hikZext: Line := Line + 'zext ';
    hikSext: Line := Line + 'sext ';
    hikBitcast: Line := Line + 'bitcast ';
    hikIntToFloat: Line := Line + 'int_to_float ';
    hikFloatToInt: Line := Line + 'float_to_int ';
    hikCall: Line := Line + 'call @' + AInstr.CallTarget + ' ';
    hikIndirectCall: Line := Line + 'indirect_call ';
    hikIntrinsic: Line := Line + 'intrinsic @' + AInstr.IntrinsicName + ' ';
    hikInsertField: Line := Line + 'insertfield [' + IntToStr(AInstr.FieldIndex) + '] ';
    hikExtractField: Line := Line + 'extractfield [' + IntToStr(AInstr.FieldIndex) + '] ';
    hikPhi: Line := Line + 'phi ';
  end;

  Emit(Line);
  PrintType(AInstr.TypeId);

  if AInstr.Kind = hikPhi then
  begin
    for I := 0 to High(AInstr.PhiEntries) do
    begin
      if I > 0 then
        AppendLast(',');
      AppendLast(' [%' + IntToStr(AInstr.PhiEntries[I].ValueId) +
        ', bb' + IntToStr(AInstr.PhiEntries[I].BlockId) + ']');
    end;
  end
  else
  begin
    for I := 0 to High(AInstr.Operands) do
      AppendLast(' %' + IntToStr(AInstr.Operands[I].ValueId));
  end;
end;

procedure THIRPrinter.PrintTerminator(const ATerm: THIRTerminator);
var
  I: LongInt;
begin
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('    ret void')
      else
        Emit('    ret %' + IntToStr(ATerm.ReturnValue));
    htkBranch:
      Emit('    br bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('    br %' + IntToStr(ATerm.Condition) +
        ', bb' + IntToStr(ATerm.TrueBlock) +
        ', bb' + IntToStr(ATerm.FalseBlock));
    htkSwitch:
    begin
      Emit('    switch %' + IntToStr(ATerm.Condition) + ' [');
      for I := 0 to High(ATerm.SwitchCases) do
        Emit('      ' + IntToStr(ATerm.SwitchCases[I].Value) +
          ' -> bb' + IntToStr(ATerm.SwitchCases[I].TargetBlock));
      Emit('      default -> bb' + IntToStr(ATerm.DefaultBlock));
      Emit('    ]');
    end;
    htkUnreachable:
      Emit('    unreachable');
  end;
end;

procedure THIRPrinter.PrintBlock(const ABlock: THIRBlock);
var
  I: LongInt;
  PredStr: string;
begin
  PredStr := '';
  for I := 0 to High(ABlock.Preds) do
  begin
    if I > 0 then PredStr := PredStr + ', ';
    PredStr := PredStr + 'bb' + IntToStr(ABlock.Preds[I]);
  end;
  if PredStr <> '' then
    Emit('  bb' + IntToStr(ABlock.Id) + ' (' + ABlock.Name + ')  ; preds: ' + PredStr)
  else
    Emit('  bb' + IntToStr(ABlock.Id) + ' (' + ABlock.Name + '):');

  for I := 0 to High(ABlock.Instrs) do
    PrintInstr(ABlock.Instrs[I]);

  PrintTerminator(ABlock.Terminator);
  Emit('');
end;

procedure THIRPrinter.PrintFunction(const AFunc: THIRFunction);
var
  I: LongInt;
  ParamStr: string;
  T: THIRTypeRec;
begin
  ParamStr := '';
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then ParamStr := ParamStr + ', ';
    T := FModule.Types.GetType(AFunc.Params[I].TypeId);
    if AFunc.Params[I].IsVar then
      ParamStr := ParamStr + 'var ';
    if AFunc.Params[I].IsConst then
      ParamStr := ParamStr + 'const ';
    ParamStr := ParamStr + '%' + IntToStr(AFunc.Params[I].ValueId) + ': ';
    ParamStr := ParamStr + TypeKindStr(T.Kind);
  end;

  Emit('');
  if AFunc.IsExternal then
    Emit('declare @' + AFunc.Name + '(' + ParamStr + ')')
  else
  begin
    Emit('func @' + AFunc.Name + '(' + ParamStr + ') -> ');
    PrintType(AFunc.ReturnTypeId);
    AppendLast(' {');
    for I := 0 to High(AFunc.Blocks) do
      PrintBlock(AFunc.Blocks[I]);
    Emit('}');
  end;
end;

procedure THIRPrinter.PrintGlobal(const AGlobal: THIRGlobal);
begin
  Emit('global @' + AGlobal.Name + ': ');
  PrintType(AGlobal.TypeId);
  if AGlobal.HasInit then
    AppendLast(' = ' + IntToStr(AGlobal.InitValue));
end;

procedure THIRPrinter.Print;
var
  I: LongInt;
begin
  FLineCount := 0;
  Emit('; HIR Module: ' + FModule.ModuleName);
  Emit('; Types: ' + IntToStr(FModule.Types.Count));
  Emit('; Functions: ' + IntToStr(FModule.FunctionCount));
  Emit('; Globals: ' + IntToStr(FModule.GlobalCount));
  Emit('');

  for I := 0 to FModule.GlobalCount - 1 do
    PrintGlobal(FModule.GlobalAt(I));

  for I := 0 to FModule.FunctionCount - 1 do
    PrintFunction(FModule.FunctionAt(I));
end;

function THIRPrinter.AsText: string;
var
  I: LongInt;
begin
  Result := '';
  for I := 0 to FLineCount - 1 do
    Result := Result + FLines[I] + LineEnding;
end;

procedure THIRPrinter.SaveToFile(const APath: string);
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
