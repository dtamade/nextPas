{**
 * nextpas.compiler.ir.mir.pass.escape.pas — MIR Escape Analysis Pass
 *
 * 分析哪些局部变量的地址逃逸到堆或全局作用域。
 * 未逃逸的变量可以栈分配（alloca → stack slot）。
 *
 * 算法：
 *   1. 扫描所有 store 语句，标记被存储到指针的值
 *   2. 扫描所有 call 语句，标记作为参数传递的地址
 *   3. 扫描所有 return 语句，标记返回的地址
 *   4. 未标记的值 → 可以栈分配
 *
 * EscapeMap 可挂 phase-scratch IAllocator。
 *
 * 对标：Go escape analysis, rustc mir::transform::escape
 *}

unit nextpas.compiler.ir.mir.pass.escape;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  { Per-value escape flags }
  TEscapeFlags = set of (efNone, efStored, efPassed, efReturned);

  TEscapeEntry = record
    ValueId: TMirValueId;
    Flags: TEscapeFlags;
  end;

  TMirEscapeMapVec = specialize TVec<TEscapeEntry>;

  TMirEscapePass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

constructor TMirEscapePass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

function TMirEscapePass.Name: string;
begin
  Result := 'escape-analysis';
end;

{ Record escape flag for a value }
procedure MarkEscape(AMap: TMirEscapeMapVec; AValueId: TMirValueId;
  AFlag: TEscapeFlags);
var
  I: LongInt;
  Entry: TEscapeEntry;
begin
  if AValueId = 0 then
    Exit;
  for I := 0 to LongInt(AMap.Count) - 1 do
    if AMap[I].ValueId = AValueId then
    begin
      Entry := AMap[I];
      Entry.Flags := Entry.Flags + AFlag;
      AMap[I] := Entry;
      Exit;
    end;
  { Not found — add entry }
  Entry.ValueId := AValueId;
  Entry.Flags := AFlag;
  AMap.Push(Entry);
end;

{ Check if value escapes (requires heap allocation) }
function ValueEscapes(AMap: TMirEscapeMapVec; AValueId: TMirValueId): Boolean;
var
  I: LongInt;
begin
  for I := 0 to LongInt(AMap.Count) - 1 do
    if AMap[I].ValueId = AValueId then
      Exit(AMap[I].Flags <> [efNone]);
  Result := False;
end;

function TMirEscapePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, I: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  EscapeMap: TMirEscapeMapVec;
  AnalyzedCount, NoEscapeCount: LongInt;
begin
  Result := True;
  AnalyzedCount := 0;
  NoEscapeCount := 0;

  if FAllocator <> nil then
    EscapeMap := TMirEscapeMapVec.Create(0, FAllocator)
  else
    EscapeMap := TMirEscapeMapVec.Create;
  try
    for FuncIdx := 0 to AModule.FunctionCount - 1 do
    begin
      Fn := AModule.FunctionAt(FuncIdx);
      EscapeMap.Clear;

      { Phase 1: Collect escape information }
      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
        if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
        begin
          Stmt := Fn.Blocks[SizeUInt(BlkIdx)].Stmts[SizeUInt(StmtIdx)];

          case Stmt.Kind of
            mskStore:
              { Value stored through pointer → escapes }
              MarkEscape(EscapeMap, Stmt.Src.Value, [efStored]);

            mskCall:
              { Values passed as args may escape through callee }
              if Stmt.Args <> nil then
                for I := 0 to LongInt(Stmt.Args.Count) - 1 do
                  if Stmt.Args[SizeUInt(I)].Kind in [mokLocal, mokMove] then
                    MarkEscape(EscapeMap, Stmt.Args[SizeUInt(I)].Value,
                      [efPassed]);

            mskGetFieldPtr:
              { Address of field computed — may be used for store }
              MarkEscape(EscapeMap, Stmt.Src.Value, [efStored]);
          end;
        end;

      { Phase 2: Check return values for escaping }
      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
        if Fn.Blocks[SizeUInt(BlkIdx)].Terminator.Kind = mtkReturn then
          MarkEscape(EscapeMap, Fn.Blocks[SizeUInt(BlkIdx)].Terminator.ReturnValue,
            [efReturned]);

      { Phase 3: Mark allocas that can stay on stack }
      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
        if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
        begin
          Stmt := Fn.Blocks[SizeUInt(BlkIdx)].Stmts[SizeUInt(StmtIdx)];

          if Stmt.Kind = mskAlloca then
          begin
            Inc(AnalyzedCount);
            if not ValueEscapes(EscapeMap, Stmt.Dst) then
              Inc(NoEscapeCount);
            { Future: annotate the alloca as stack-only }
          end;
        end;
    end;
  finally
    EscapeMap.Free;
  end;

  Result := True;
end;

end.
