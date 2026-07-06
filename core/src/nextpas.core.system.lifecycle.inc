{**
 * @desc Program lifecycle for the nextPas system kernel.
 *
 * Defines unit initialization/finalization order contracts
 * and program lifecycle functions.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are provided by FPC System.
 *}

{ Program lifecycle functions }
procedure InitModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);
procedure FinalizeModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);

{ Unit initialization/finalization order contracts }
{ np.system.unit_init  — called when unit is loaded }
{ np.system.unit_fini  — called when unit is unloaded }
{ np.system.process_init  — called at program start }
{ np.system.process_fini  — called at program end }

implementation

{ Program lifecycle stubs — real implementations provided by runtime }
procedure InitModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure FinalizeModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);
begin
  { Stub — runtime provides real implementation }
end;
