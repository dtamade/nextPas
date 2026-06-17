unit nextpas.core.tls.pkcs11.loader;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 Dynamic Library Loader                                }
{                                                                              }
{  Purpose: Load PKCS#11 modules dynamically and manage function pointers     }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses nextpas.core.platform.dl, nextpas.core.tls.pkcs11.api; type TPKCS11Loader = class private FLibHandle: TPlatformLibrary;
    FLibraryPath: string;
    FFunctionList: CK_FUNCTION_LIST_PTR;
    FInitialized: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Load PKCS#11 library
    function LoadLibrary(const APath: string): Boolean;
    procedure UnloadLibrary;
    
    // Initialize/Finalize
    function Initialize: Boolean;
    function Finalize: Boolean;
    
    // Properties
    property LibraryPath: string read FLibraryPath;
    property FunctionList: CK_FUNCTION_LIST_PTR read FFunctionList;
    property Initialized: Boolean read FInitialized;
    
    // Helper functions
    function GetInfo(out Info: CK_INFO): CK_RV;
    function GetSlotList(tokenPresent: Boolean; out SlotList: array of CK_SLOT_ID): CK_RV;
    function GetTokenInfo(SlotID: CK_SLOT_ID; out TokenInfo: CK_TOKEN_INFO): CK_RV;
  end;

implementation

type
  // C_GetFunctionList function pointer
  TC_GetFunctionList = function(ppFunctionList: CK_FUNCTION_LIST_PTR_PTR): CK_RV; cdecl;

{ TPKCS11Loader }

function LibLoaded(const ALib: TPlatformLibrary): Boolean; inline;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := ALib.Handle <> 0;
  {$ELSE}
  Result := ALib.Handle <> nil;
  {$ENDIF}
end;

function GetProcSym(const ALib: TPlatformLibrary; const AName: PAnsiChar): Pointer;
begin
  Result := nil;
  platform_dl_sym(ALib, AName, Result);
end;

constructor TPKCS11Loader.Create;
begin
  inherited Create;
  FillChar(FLibHandle, SizeOf(FLibHandle), 0);
  FLibraryPath := '';
  FFunctionList := nil;
  FInitialized := False;
end;

destructor TPKCS11Loader.Destroy;
begin
  if FInitialized then
    Finalize;
  UnloadLibrary;
  inherited Destroy;
end;

function TPKCS11Loader.LoadLibrary(const APath: string): Boolean;
var
  GetFunctionList: TC_GetFunctionList;
  rv: CK_RV;
  LAddr: Pointer;
begin
  Result := False;

  // Unload existing library
  if LibLoaded(FLibHandle) then
    UnloadLibrary;

  // Load library
  if platform_dl_open(PAnsiChar(AnsiString(APath)), PLATFORM_DL_NOW, FLibHandle) <> 0 then
    Exit;

  FLibraryPath := APath;

  // Get C_GetFunctionList
  LAddr := GetProcSym(FLibHandle, 'C_GetFunctionList');
  if LAddr = nil then
  begin
    UnloadLibrary;
    Exit;
  end;
  GetFunctionList := TC_GetFunctionList(LAddr);

  // Get function list
  rv := GetFunctionList(@FFunctionList);
  if rv <> CKR_OK then
  begin
    UnloadLibrary;
    Exit;
  end;

  Result := True;
end;

procedure TPKCS11Loader.UnloadLibrary;
begin
  if FInitialized then
    Finalize;

  platform_dl_close(FLibHandle);

  FFunctionList := nil;
  FLibraryPath := '';
end;

function TPKCS11Loader.Initialize: Boolean;
type
  TC_Initialize = function(pInitArgs: Pointer): CK_RV; cdecl;
var
  C_Initialize: TC_Initialize;
  rv: CK_RV;
begin
  Result := False;
  
  if FInitialized then
    Exit(True);
    
  if not Assigned(FFunctionList) then
    Exit;
  
  C_Initialize := TC_Initialize(FFunctionList^.C_Initialize);
  if not Assigned(C_Initialize) then
    Exit;
  
  rv := C_Initialize(nil);
  if (rv <> CKR_OK) and (rv <> CKR_CRYPTOKI_ALREADY_INITIALIZED) then
    Exit;
  
  FInitialized := True;
  Result := True;
end;

function TPKCS11Loader.Finalize: Boolean;
type
  TC_Finalize = function(pReserved: Pointer): CK_RV; cdecl;
var
  C_Finalize: TC_Finalize;
  rv: CK_RV;
begin
  Result := False;
  
  if not FInitialized then
    Exit(True);
    
  if not Assigned(FFunctionList) then
    Exit;
  
  C_Finalize := TC_Finalize(FFunctionList^.C_Finalize);
  if not Assigned(C_Finalize) then
    Exit;
  
  rv := C_Finalize(nil);
  if rv <> CKR_OK then
    Exit;
  
  FInitialized := False;
  Result := True;
end;

function TPKCS11Loader.GetInfo(out Info: CK_INFO): CK_RV;
type
  TC_GetInfo = function(pInfo: CK_INFO_PTR): CK_RV; cdecl;
var
  C_GetInfo: TC_GetInfo;
begin
  Result := CKR_GENERAL_ERROR;
  
  if not Assigned(FFunctionList) then
    Exit;
  
  C_GetInfo := TC_GetInfo(FFunctionList^.C_GetInfo);
  if not Assigned(C_GetInfo) then
    Exit;
  
  Result := C_GetInfo(@Info);
end;

function TPKCS11Loader.GetSlotList(tokenPresent: Boolean; out SlotList: array of CK_SLOT_ID): CK_RV;
type
  TC_GetSlotList = function(tokenPresent: CK_BBOOL; pSlotList: CK_SLOT_ID_PTR; pulCount: CK_ULONG_PTR): CK_RV; cdecl;
var
  C_GetSlotList: TC_GetSlotList;
  count: CK_ULONG;
begin
  Result := CKR_GENERAL_ERROR;
  
  if not Assigned(FFunctionList) then
    Exit;
  
  C_GetSlotList := TC_GetSlotList(FFunctionList^.C_GetSlotList);
  if not Assigned(C_GetSlotList) then
    Exit;
  
  count := Length(SlotList);
  Result := C_GetSlotList(Ord(tokenPresent), @SlotList[0], @count);
end;

function TPKCS11Loader.GetTokenInfo(SlotID: CK_SLOT_ID; out TokenInfo: CK_TOKEN_INFO): CK_RV;
type
  TC_GetTokenInfo = function(slotID: CK_SLOT_ID; pInfo: CK_TOKEN_INFO_PTR): CK_RV; cdecl;
var
  C_GetTokenInfo: TC_GetTokenInfo;
begin
  Result := CKR_GENERAL_ERROR;
  
  if not Assigned(FFunctionList) then
    Exit;
  
  C_GetTokenInfo := TC_GetTokenInfo(FFunctionList^.C_GetTokenInfo);
  if not Assigned(C_GetTokenInfo) then
    Exit;
  
  Result := C_GetTokenInfo(SlotID, @TokenInfo);
end;

end.
