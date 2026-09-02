unit nextpas.compiler.ir.hir.printer;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  THirPrintLineVec = specialize TVec<string>;

  THIRPrinter = class
  private
    FModule: THIRModule;
    FAllocator: IAllocator;
    FLines: THirPrintLineVec;
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
    constructor Create(AModule: THIRModule;
      AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure Print;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.builder;

constructor THIRPrinter.Create(AModule: THIRModule;
  AAllocator: IAllocator);
begin
  inherited Create;
  FModule := AModule;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FLines := THirPrintLineVec.Create(0, FAllocator)
  else
    FLines := THirPrintLineVec.Create;
end;

destructor THIRPrinter.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure THIRPrinter.Emit(const S: string);
begin
  FLines.Push(S);
end;

procedure THIRPrinter.AppendLast(const S: string);
var
  P: ^string;
  LOld, LAdd: SizeUInt;
begin
  if FLines.Count = 0 then Exit;
  if S = '' then Exit;
  P := FLines.GetPtr(FLines.Count - 1);
  LOld := SizeUInt(Length(P^));
  LAdd := SizeUInt(Length(S));
  SetLength(P^, LOld + LAdd);
  if LAdd > 0 then
    Move(PAnsiChar(S)^, (PAnsiChar(P^) + LOld)^, LAdd);
end;

function THIRPrinter.LastLine: string;
begin
  if FLines.Count > 0 then
    Result := FLines[FLines.Count - 1]
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
  LB: TBufStringBuilder;
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
      begin
        LB.Init(8);
        try
          if T.Signed then LB.AppendChar('i') else LB.AppendChar('u');
          LB.AppendUInt(T.BitWidth);
          AppendLast(LB.ToString);
        finally
          LB.Done;
        end;
      end;
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
      begin
        LB.Init(16);
        try
          LB.AppendStr('ptr<');
          LB.AppendInt(T.PointeeTypeId);
          LB.AppendChar('>');
          AppendLast(LB.ToString);
        finally
          LB.Done;
        end;
      end;
    htkArray:
      begin
        LB.Init(40);
        try
          LB.AppendStr('array[');
          LB.AppendInt(T.LowBound);
          LB.AppendStr('..');
          LB.AppendInt(T.HighBound);
          LB.AppendStr(']<');
          LB.AppendInt(T.ElemTypeId);
          LB.AppendChar('>');
          AppendLast(LB.ToString);
        finally
          LB.Done;
        end;
      end;
    htkDynArray:
      begin
        LB.Init(24);
        try
          LB.AppendStr('dynarray<');
          LB.AppendInt(T.ElemTypeId);
          LB.AppendChar('>');
          AppendLast(LB.ToString);
        finally
          LB.Done;
        end;
      end;
    htkRecord:
      begin
        LB.Init(SizeUInt(Length(T.Name)) + 16);
        try
          LB.AppendStr('record(');
          LB.AppendStr(T.Name);
          LB.AppendChar(')');
          AppendLast(LB.ToString);
        finally
          LB.Done;
        end;
      end;
  else
    AppendLast(TypeKindStr(T.Kind));
  end;
end;

procedure THIRPrinter.PrintInstr(const AInstr: THIRInstr);
var
  Line: string;
  I: LongInt;
  LB: TBufStringBuilder;
begin
  LB.Init(64);
  try
    LB.AppendStr('    %');
    LB.AppendInt(AInstr.ResultId);
    LB.AppendStr(' = ');
    case AInstr.Kind of
      hikAlloca: LB.AppendStr('alloca ');
      hikLoad: LB.AppendStr('load ');
      hikStore: LB.AppendStr('store ');
      hikGetFieldPtr: LB.AppendStr('getfieldptr ');
      hikAdd: LB.AppendStr('add ');
      hikSub: LB.AppendStr('sub ');
      hikMul: LB.AppendStr('mul ');
      hikDiv: LB.AppendStr('div ');
      hikMod: LB.AppendStr('mod ');
      hikNeg: LB.AppendStr('neg ');
      hikNot: LB.AppendStr('not ');
      hikBitAnd: LB.AppendStr('and ');
      hikBitOr: LB.AppendStr('or ');
      hikBitXor: LB.AppendStr('xor ');
      hikShl: LB.AppendStr('shl ');
      hikShr: LB.AppendStr('shr ');
      hikCmpEq: LB.AppendStr('cmp.eq ');
      hikCmpNe: LB.AppendStr('cmp.ne ');
      hikCmpLt: LB.AppendStr('cmp.lt ');
      hikCmpLe: LB.AppendStr('cmp.le ');
      hikCmpGt: LB.AppendStr('cmp.gt ');
      hikCmpGe: LB.AppendStr('cmp.ge ');
      hikTrunc: LB.AppendStr('trunc ');
      hikZext: LB.AppendStr('zext ');
      hikSext: LB.AppendStr('sext ');
      hikBitcast: LB.AppendStr('bitcast ');
      hikIntToFloat: LB.AppendStr('int_to_float ');
      hikFloatToInt: LB.AppendStr('float_to_int ');
      hikCall:
        begin
          LB.AppendStr('call @');
          LB.AppendStr(AInstr.CallTarget);
          LB.AppendChar(' ');
        end;
      hikIndirectCall: LB.AppendStr('indirect_call ');
      hikIntrinsic:
        begin
          LB.AppendStr('intrinsic @');
          LB.AppendStr(AInstr.IntrinsicName);
          LB.AppendChar(' ');
        end;
      hikInsertField:
        begin
          LB.AppendStr('insertfield [');
          LB.AppendInt(AInstr.FieldIndex);
          LB.AppendStr('] ');
        end;
      hikExtractField:
        begin
          LB.AppendStr('extractfield [');
          LB.AppendInt(AInstr.FieldIndex);
          LB.AppendStr('] ');
        end;
      hikPhi: LB.AppendStr('phi ');
    end;
    Line := LB.ToString;
  finally
    LB.Done;
  end;

  Emit(Line);
  PrintType(AInstr.TypeId);

  if AInstr.Kind = hikPhi then
  begin
    for I := 0 to High(AInstr.PhiEntries) do
    begin
      if I > 0 then
        AppendLast(',');
      LB.Init(32);
      try
        LB.AppendStr(' [%');
        LB.AppendInt(AInstr.PhiEntries[I].ValueId);
        LB.AppendStr(', bb');
        LB.AppendInt(AInstr.PhiEntries[I].BlockId);
        LB.AppendChar(']');
        AppendLast(LB.ToString);
      finally
        LB.Done;
      end;
    end;
  end
  else
  begin
    for I := 0 to High(AInstr.Operands) do
    begin
      LB.Init(16);
      try
        LB.AppendStr(' %');
        LB.AppendInt(AInstr.Operands[I].ValueId);
        AppendLast(LB.ToString);
      finally
        LB.Done;
      end;
    end;
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
      if ATerm.SwitchCases <> nil then
        for I := 0 to LongInt(ATerm.SwitchCases.Count) - 1 do
          Emit('      ' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].Value) +
            ' -> bb' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].TargetBlock));
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
  LB: TBufStringBuilder;
  LPredBuilder: TBufStringBuilder;
begin
  LPredBuilder.Init(64);
  try
    if ABlock.Preds <> nil then
      for I := 0 to LongInt(ABlock.Preds.Count) - 1 do
      begin
        if I > 0 then LPredBuilder.AppendStr(', ');
        LPredBuilder.AppendStr('bb');
        LPredBuilder.AppendInt(ABlock.Preds[SizeUInt(I)]);
      end;
    PredStr := LPredBuilder.ToString;
  finally
    LPredBuilder.Done;
  end;
  LB.Init(64 + SizeUInt(Length(PredStr)) + SizeUInt(Length(ABlock.Name)));
  try
    LB.AppendStr('  bb');
    LB.AppendInt(ABlock.Id);
    LB.AppendStr(' (');
    LB.AppendStr(ABlock.Name);
    LB.AppendChar(')');
    if PredStr <> '' then
    begin
      LB.AppendStr('  ; preds: ');
      LB.AppendStr(PredStr);
    end
    else
      LB.AppendChar(':');
    Emit(LB.ToString);
  finally
    LB.Done;
  end;

  if ABlock.Instrs <> nil then
    for I := 0 to LongInt(ABlock.Instrs.Count) - 1 do
      PrintInstr(ABlock.Instrs[SizeUInt(I)]);

  PrintTerminator(ABlock.Terminator);
  Emit('');
end;

procedure THIRPrinter.PrintFunction(const AFunc: THIRFunction);
var
  I: LongInt;
  ParamStr: string;
  T: THIRTypeRec;
  PB: TBufStringBuilder;
  HB: TBufStringBuilder;
begin
  PB.Init(128);
  try
    if AFunc.Params <> nil then
      for I := 0 to LongInt(AFunc.Params.Count) - 1 do
      begin
        if I > 0 then PB.AppendStr(', ');
        T := FModule.Types.GetType(AFunc.Params[SizeUInt(I)].TypeId);
        if AFunc.Params[SizeUInt(I)].IsVar then
          PB.AppendStr('var ');
        if AFunc.Params[SizeUInt(I)].IsConst then
          PB.AppendStr('const ');
        PB.AppendChar('%');
        PB.AppendInt(AFunc.Params[SizeUInt(I)].ValueId);
        PB.AppendStr(': ');
        PB.AppendStr(TypeKindStr(T.Kind));
      end;
    ParamStr := PB.ToString;
  finally
    PB.Done;
  end;

  Emit('');
  if AFunc.IsExternal then
  begin
    HB.Init(SizeUInt(Length(AFunc.Name)) + SizeUInt(Length(ParamStr)) + 16);
    try
      HB.AppendStr('declare @');
      HB.AppendStr(AFunc.Name);
      HB.AppendChar('(');
      HB.AppendStr(ParamStr);
      HB.AppendChar(')');
      Emit(HB.ToString);
    finally
      HB.Done;
    end;
  end
  else
  begin
    HB.Init(SizeUInt(Length(AFunc.Name)) + SizeUInt(Length(ParamStr)) + 16);
    try
      HB.AppendStr('func @');
      HB.AppendStr(AFunc.Name);
      HB.AppendChar('(');
      HB.AppendStr(ParamStr);
      HB.AppendStr(') -> ');
      Emit(HB.ToString);
    finally
      HB.Done;
    end;
    PrintType(AFunc.ReturnTypeId);
    AppendLast(' {');
    if AFunc.Blocks <> nil then
      for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
        PrintBlock(AFunc.Blocks[SizeUInt(I)]);
    Emit('}');
  end;
end;

procedure THIRPrinter.PrintGlobal(const AGlobal: THIRGlobal);
var
  HB: TBufStringBuilder;
begin
  HB.Init(SizeUInt(Length(AGlobal.Name)) + 16);
  try
    HB.AppendStr('global @');
    HB.AppendStr(AGlobal.Name);
    HB.AppendStr(': ');
    Emit(HB.ToString);
  finally
    HB.Done;
  end;
  PrintType(AGlobal.TypeId);
  if AGlobal.HasInit then
  begin
    HB.Init(24);
    try
      HB.AppendStr(' = ');
      HB.AppendInt(AGlobal.InitValue);
      AppendLast(HB.ToString);
    finally
      HB.Done;
    end;
  end;
end;

procedure THIRPrinter.Print;
var
  I: LongInt;
begin
  FLines.Clear;
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
  LBuilder: TBufStringBuilder;
  LTotal: SizeUInt;
  LLineEndingLen: SizeUInt;
begin
  if FLines.Count = 0 then
    Exit('');
  LLineEndingLen := SizeUInt(Length(LineEnding));
  LTotal := 0;
  for I := 0 to FLines.Count - 1 do
    Inc(LTotal, SizeUInt(Length(FLines[I])) + LLineEndingLen);
  LBuilder.Init(LTotal);
  try
    for I := 0 to FLines.Count - 1 do
    begin
      LBuilder.AppendStr(FLines[I]);
      LBuilder.AppendStr(LineEnding);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure THIRPrinter.SaveToFile(const APath: string);
var
  F: TextFile;
  I: LongInt;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    if FLines.Count > 0 then
      for I := 0 to FLines.Count - 1 do
        WriteLn(F, FLines[I]);
  finally
    CloseFile(F);
  end;
end;

end.
