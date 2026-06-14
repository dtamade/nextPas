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

uses Classes, DynLibs, nextpas.core.tls.pkcs11.api;

type
  { TPKCS11Loader }
  TPKCS11Loader = class
  private
    FLibHandle: TLibHandle;
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

constructor TPKCS11Loader.Create;
begin
  inherited Create;
  FLibHandle := NilHandle;
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
begin
  Result := False;
  
  // Unload existing library
  if FLibHandle <> NilHandle then
    UnloadLibrary;
  
  // Load library
  FLibHandle := DynLibs.LoadLibrary(APath);
  if FLibHandle = NilHandle then
    Exit;
  
  FLibraryPath := APath;
  
  // Get C_GetFunctionList
  GetFunctionList := TC_GetFunctionList(GetProcAddress(FLibHandle, 'C_GetFunctionList'));
  if not Assigned(GetFunctionList) then
  begin
    UnloadLibrary;
    Exit;
  end;
  
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
    
  if FLibHandle <> NilHandle then
  begin
    DynLibs.UnloadLibrary(FLibHandle);
    FLibHandle := NilHandle;
  end;
  
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
