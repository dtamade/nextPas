{**
 * np_mir_pass_escape.pas — MIR Escape Analysis Pass
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
 * 对标：Go escape analysis, rustc mir::transform::escape
 *}

unit np_mir_pass_escape;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  { Per-value escape flags }
  TEscapeFlags = set of (efNone, efStored, efPassed, efReturned);
  TEscapeMap = array of record
    ValueId: TMirValueId;
    Flags: TEscapeFlags;
  end;

  TMirEscapePass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirEscapePass.Name: string;
begin
  Result := 'escape-analysis';
end;

{ Record escape flag for a value }
procedure MarkEscape(var AMap: TEscapeMap; AValueId: TMirValueId; AFlag: TEscapeFlags);
var
  I: LongInt;
begin
  if AValueId = 0 then
    Exit;
  for I := 0 to High(AMap) do
    if AMap[I].ValueId = AValueId then
    begin
      AMap[I].Flags := AMap[I].Flags + AFlag;
      Exit;
    end;
  { Not found — add entry }
  I := Length(AMap);
  SetLength(AMap, I + 1);
  AMap[I].ValueId := AValueId;
  AMap[I].Flags := AFlag;
end;

{ Check if value escapes (requires heap allocation) }
function ValueEscapes(const AMap: TEscapeMap; AValueId: TMirValueId): Boolean;
var
  I: LongInt;
begin
  for I := 0 to High(AMap) do
    if AMap[I].ValueId = AValueId then
      Exit(AMap[I].Flags <> [efNone]);
  Result := False;
end;

function TMirEscapePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, I: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  EscapeMap: TEscapeMap;
  AnalyzedCount, NoEscapeCount: LongInt;
begin
  Result := True;
  AnalyzedCount := 0;
  NoEscapeCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);
    SetLength(EscapeMap, 0);

    { Phase 1: Collect escape information }
    for BlkIdx := 0 to High(Fn.Blocks) do
      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        Stmt := Fn.Blocks[BlkIdx].Stmts[StmtIdx];

        case Stmt.Kind of
          mskStore:
            { Value stored through pointer → escapes }
            MarkEscape(EscapeMap, Stmt.Src.Value, [efStored]);

          mskCall:
            { Values passed as args may escape through callee }
            for I := 0 to High(Stmt.Args) do
              if Stmt.Args[I].Kind in [mokLocal, mokMove] then
                MarkEscape(EscapeMap, Stmt.Args[I].Value, [efPassed]);

          mskGetFieldPtr:
            { Address of field computed — may be used for store }
            MarkEscape(EscapeMap, Stmt.Src.Value, [efStored]);
        end;
      end;

    { Phase 2: Check return values for escaping }
    for BlkIdx := 0 to High(Fn.Blocks) do
      if Fn.Blocks[BlkIdx].Terminator.Kind = mtkReturn then
        MarkEscape(EscapeMap, Fn.Blocks[BlkIdx].Terminator.ReturnValue, [efReturned]);

    { Phase 3: Mark allocas that can stay on stack }
    for BlkIdx := 0 to High(Fn.Blocks) do
      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        Stmt := Fn.Blocks[BlkIdx].Stmts[StmtIdx];

        if Stmt.Kind = mskAlloca then
        begin
          Inc(AnalyzedCount);
          if not ValueEscapes(EscapeMap, Stmt.Dst) then
            Inc(NoEscapeCount);
          { Future: annotate the alloca as stack-only }
        end;
      end;
  end;

  Result := True;
end;

end.
