{
  np_lower_query.pas — Lower Query Interface (D 分层)

  D 层级下沉查询抽象：lower 层定义契约，前端 QueryDatabase 适配，
  实现 interface 去 uses 耦合（lower 不直接 uses 前端）。
}
unit np_lower_query;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.mem.intf,
  np_ast_facade,
  np_diagnostics_sink,
  np_source_database,
  np_semantic_model,
  np_mir_model,
  np_unit_graph;

type
  ILowerQuery = interface
    ['{A7F3C2E1-8B4D-4E9A-9F2C-1D3E5A6B7C8D}']
    function QueryGet(const AKey: string; ADefault: TObject): TObject;
    procedure QueryStore(const AKey: string; AValue: TObject);
  end;

function LowerAnalyzeSemantics(
  const AFacade: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean;
  const AAllocator: IAllocator
): TSemanticModel;

function LowerBuildMirModule(
  const ASemanticModel: TSemanticModel;
  const ASourceDatabase: TSourceDatabase;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator;
  const ADiagnostics: TDiagnosticsSink;
  out AMirStatus: string
): TMirModule;

implementation

uses
  SysUtils,
  np_semantic_analyzer,
  np_hir_builder,
  np_hir_printer,
  np_hir_to_mir,
  np_mir_to_llvm;

function LowerAnalyzeSemantics(
  const AFacade: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean;
  const AAllocator: IAllocator
): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
begin
  Result := nil;
  Analyzer := TSemanticAnalyzer.Create(
    AFacade, AUnitGraph, ADiagnostics, ARootFileId, ANoFold, AAllocator);
  try
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
  end;
end;

function LowerBuildMirModule(
  const ASemanticModel: TSemanticModel;
  const ASourceDatabase: TSourceDatabase;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator;
  const ADiagnostics: TDiagnosticsSink;
  out AMirStatus: string
): TMirModule;
var
  HirBuilder: THIRBuilder;
  Lowering: THirToMirLowering;
  HirPrinter: THIRPrinter;
  HirPath: string;
  LlvmTranslator: TMirToLlvmTranslator;
  LlvmOutput: string;
begin
  Result := nil;
  AMirStatus := 'ready';
  if GetEnvironmentVariable('NEXTPAS_MIR') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(
      ASemanticModel, ASourceDatabase, ARootFileId, AAllocator);
    try
      HirBuilder.Build;
      Lowering := THirToMirLowering.Create(HirBuilder.Module, AAllocator);
      try
        Lowering.Lower;
        Result := Lowering.DetachModule;
      finally
        Lowering.Free;
      end;
      if GetEnvironmentVariable('NEXTPAS_MIR_DUMP') = '1' then
      begin
        LlvmTranslator := TMirToLlvmTranslator.Create(Result, AAllocator);
        try
          LlvmOutput := LlvmTranslator.Translate;
        finally
          LlvmTranslator.Free;
        end;
      end;
    finally
      HirBuilder.Free;
    end;
  end
  else if GetEnvironmentVariable('NEXTPAS_HIR_DUMP') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(
      ASemanticModel, ASourceDatabase, ARootFileId, AAllocator, ADiagnostics);
    try
      if not HirBuilder.Build then
      begin
        AMirStatus := 'failure';
        Exit;
      end;
      HirPath := ChangeFileExt(ASourceDatabase.RootSourceCanonicalPath, '.hir');
      HirPrinter := THIRPrinter.Create(HirBuilder.Module, AAllocator);
      try
        HirPrinter.Print;
        HirPrinter.SaveToFile(HirPath);
      finally
        HirPrinter.Free;
      end;
    finally
      HirBuilder.Free;
    end;
  end;
end;

end.
