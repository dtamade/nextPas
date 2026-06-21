unit nextpas.core.tls.pkcs11.utils;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 Utility Functions                                     }
{                                                                              }
{  Purpose: Helper functions for PKCS#11 operations                           }
{                                                                              }
{  Features:                                                                   }
{    - Token enumeration and discovery                                        }
{    - Key enumeration within tokens                                          }
{    - PKCS#11 module loading and initialization                              }
{    - Slot and token information retrieval                                   }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.text.conv, nextpas.core.system.classes,
  nextpas.core.collections.vec,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.pkcs11.api,
  nextpas.core.tls.pkcs11.loader;

type
  { TPKCS11Utils - Utility functions for PKCS#11 operations }
  TPKCS11Utils = class
  public
    { Enumerate all available slots
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        ATokenPresent: If True, only return slots with tokens present
        
      Returns:
        List of slot information
    }
    class function EnumerateSlots(const AModulePath: string; ATokenPresent: Boolean = True): specialize TArray<TPKCS11SlotInfo>;
    
    { Enumerate all tokens
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        
      Returns:
        List of token information
    }
    class function EnumerateTokens(const AModulePath: string): specialize TArray<TPKCS11TokenInfo>;
    
    { Find token by label
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        ATokenLabel: Token label to search for
        
      Returns:
        Token information if found
        
      Raises:
        EPKCS11Exception if token not found
    }
    class function FindTokenByLabel(const AModulePath: string; const ATokenLabel: string): TPKCS11TokenInfo;
    
    { Find slot by ID
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        ASlotID: Slot ID to search for
        
      Returns:
        Slot information if found
        
      Raises:
        EPKCS11Exception if slot not found
    }
    class function FindSlotByID(const AModulePath: string; ASlotID: CK_SLOT_ID): TPKCS11SlotInfo;
    
    { Enumerate keys in token
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        ASlotID: Slot ID containing the token
        APIN: PIN for token access (optional)
        
      Returns:
        List of key information
    }
    class function EnumerateKeys(const AModulePath: string; ASlotID: CK_SLOT_ID; const APIN: string = ''): specialize TArray<TPKCS11KeyInfo>;
    
    { Find key by label
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        ASlotID: Slot ID containing the token
        AKeyLabel: Key label to search for
        APIN: PIN for token access (optional)
        
      Returns:
        Key information if found
        
      Raises:
        EPKCS11Exception if key not found
    }
    class function FindKeyByLabel(const AModulePath: string; ASlotID: CK_SLOT_ID; const AKeyLabel: string; const APIN: string = ''): TPKCS11KeyInfo;
    
    { Get PKCS#11 module information
      
      Parameters:
        AModulePath: Path to PKCS#11 module
        
      Returns:
        Module information string
    }
    class function GetModuleInfo(const AModulePath: string): string;
  end;

implementation

type
  TC_GetSlotList = function(tokenPresent: CK_BBOOL; pSlotList: CK_SLOT_ID_PTR; pulCount: CK_ULONG_PTR): CK_RV; cdecl;
  TC_GetSlotInfo = function(slotID: CK_SLOT_ID; pInfo: CK_SLOT_INFO_PTR): CK_RV; cdecl;
  TC_GetTokenInfo = function(slotID: CK_SLOT_ID; pInfo: CK_TOKEN_INFO_PTR): CK_RV; cdecl;
  TC_OpenSession = function(slotID: CK_SLOT_ID; flags: CK_FLAGS; pApplication: CK_VOID_PTR; notify: CK_NOTIFY;
    phSession: CK_SESSION_HANDLE_PTR): CK_RV; cdecl;
  TC_CloseSession = function(hSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_Login = function(hSession: CK_SESSION_HANDLE; userType: CK_ULONG; pPin: CK_UTF8CHAR_PTR; ulPinLen: CK_ULONG): CK_RV; cdecl;
  TC_FindObjectsInit = function(hSession: CK_SESSION_HANDLE; pTemplate: CK_ATTRIBUTE_PTR; ulCount: CK_ULONG): CK_RV; cdecl;
  TC_FindObjects = function(hSession: CK_SESSION_HANDLE; phObject: CK_OBJECT_HANDLE_PTR; ulMaxObjectCount: CK_ULONG;
    pulObjectCount: CK_ULONG_PTR): CK_RV; cdecl;
  TC_FindObjectsFinal = function(hSession: CK_SESSION_HANDLE): CK_RV; cdecl;
  TC_GetAttributeValue = function(hSession: CK_SESSION_HANDLE; hObject: CK_OBJECT_HANDLE; pTemplate: CK_ATTRIBUTE_PTR;
    ulCount: CK_ULONG): CK_RV; cdecl;
  TC_GetInfo = function(pInfo: CK_INFO_PTR): CK_RV; cdecl;

{ TPKCS11Utils }

class function TPKCS11Utils.EnumerateSlots(const AModulePath: string; ATokenPresent: Boolean): specialize TArray<TPKCS11SlotInfo>;
var
  Loader: TPKCS11Loader;
  C_GetSlotList: TC_GetSlotList;
  C_GetSlotInfo: TC_GetSlotInfo;
  SlotCount: CK_ULONG;
  SlotIDs: array of CK_SLOT_ID;
  SlotInfo: CK_SLOT_INFO;
  I: Integer;
  RV: CK_RV;
  ResultList: specialize TVec<TPKCS11SlotInfo>;
begin
  SetLength(Result, 0);
  ResultList := specialize TVec<TPKCS11SlotInfo>.Create;
  try
    Loader := TPKCS11Loader.Create;
    try
      if not Loader.LoadLibrary(AModulePath) then
        raise EPKCS11Exception.Create('Failed to load PKCS#11 module: ' + AModulePath, CKR_GENERAL_ERROR);

      if not Loader.Initialize then
        raise EPKCS11Exception.Create('Failed to initialize PKCS#11 module', CKR_GENERAL_ERROR);

      if Loader.FunctionList = nil then
        raise EPKCS11Exception.Create('PKCS#11 function list not available', CKR_GENERAL_ERROR);

      C_GetSlotList := TC_GetSlotList(Loader.FunctionList^.C_GetSlotList);
      C_GetSlotInfo := TC_GetSlotInfo(Loader.FunctionList^.C_GetSlotInfo);
      if (not Assigned(C_GetSlotList)) or (not Assigned(C_GetSlotInfo)) then
        raise EPKCS11Exception.Create('Required PKCS#11 functions not available', CKR_FUNCTION_NOT_SUPPORTED);

      // Get slot count
      SlotCount := 0;
      RV := C_GetSlotList(CK_BBOOL(ATokenPresent), nil, @SlotCount);
      if RV <> CKR_OK then
        raise EPKCS11Exception.Create('Failed to get slot count', RV);
      
      if SlotCount = 0 then
        Exit;
      
      // Get slot list
      SetLength(SlotIDs, Integer(SlotCount));
      RV := C_GetSlotList(CK_BBOOL(ATokenPresent), @SlotIDs[0], @SlotCount);
      if RV <> CKR_OK then
        raise EPKCS11Exception.Create('Failed to get slot list', RV);

      // Get slot information
      for I := 0 to Integer(SlotCount) - 1 do
      begin
        RV := C_GetSlotInfo(SlotIDs[I], @SlotInfo);
        if RV = CKR_OK then
          ResultList.Push(TPKCS11SlotInfo.FromCK(SlotInfo, SlotIDs[I]));
      end;
      
      Result := ResultList.ToArray;
    finally
      Loader.Free;
    end;
  finally
    ResultList.Free;
  end;
end;

class function TPKCS11Utils.EnumerateTokens(const AModulePath: string): specialize TArray<TPKCS11TokenInfo>;
var
  Slots: specialize TArray<TPKCS11SlotInfo>;
  Loader: TPKCS11Loader;
  C_GetTokenInfo: TC_GetTokenInfo;
  TokenInfo: CK_TOKEN_INFO;
  I: Integer;
  RV: CK_RV;
  ResultList: specialize TVec<TPKCS11TokenInfo>;
begin
  SetLength(Result, 0);
  ResultList := specialize TVec<TPKCS11TokenInfo>.Create;
  try
    // Get all slots with tokens present
    Slots := EnumerateSlots(AModulePath, True);
    
    if Length(Slots) = 0 then
      Exit;
    
    Loader := TPKCS11Loader.Create;
    try
      if not Loader.LoadLibrary(AModulePath) then
        raise EPKCS11Exception.Create('Failed to load PKCS#11 module: ' + AModulePath, CKR_GENERAL_ERROR);

      if not Loader.Initialize then
        raise EPKCS11Exception.Create('Failed to initialize PKCS#11 module', CKR_GENERAL_ERROR);

      if Loader.FunctionList = nil then
        raise EPKCS11Exception.Create('PKCS#11 function list not available', CKR_GENERAL_ERROR);

      C_GetTokenInfo := TC_GetTokenInfo(Loader.FunctionList^.C_GetTokenInfo);
      if not Assigned(C_GetTokenInfo) then
        raise EPKCS11Exception.Create('Required PKCS#11 functions not available', CKR_FUNCTION_NOT_SUPPORTED);

      // Get token information for each slot
      for I := 0 to High(Slots) do
      begin
        RV := C_GetTokenInfo(Slots[I].SlotID, @TokenInfo);
        if RV = CKR_OK then
          ResultList.Push(TPKCS11TokenInfo.FromCK(TokenInfo, Slots[I].SlotID));
      end;
      
      Result := ResultList.ToArray;
    finally
      Loader.Free;
    end;
  finally
    ResultList.Free;
  end;
end;

class function TPKCS11Utils.FindTokenByLabel(const AModulePath: string; const ATokenLabel: string): TPKCS11TokenInfo;
var
  Tokens: specialize TArray<TPKCS11TokenInfo>;
  I: Integer;
begin
  Tokens := EnumerateTokens(AModulePath);
  
  for I := 0 to High(Tokens) do
  begin
    if Tokens[I].TokenLabel = ATokenLabel then
    begin
      Result := Tokens[I];
      Exit;
    end;
  end;
  
  raise EPKCS11Exception.Create(
    Format('Token not found: %s', [ATokenLabel]),
    CKR_TOKEN_NOT_PRESENT);
end;

class function TPKCS11Utils.FindSlotByID(const AModulePath: string; ASlotID: CK_SLOT_ID): TPKCS11SlotInfo;
var
  Slots: specialize TArray<TPKCS11SlotInfo>;
  I: Integer;
begin
  Slots := EnumerateSlots(AModulePath, False);
  
  for I := 0 to High(Slots) do
  begin
    if Slots[I].SlotID = ASlotID then
    begin
      Result := Slots[I];
      Exit;
    end;
  end;
  
  raise EPKCS11Exception.Create(
    Format('Slot not found: %d', [ASlotID]),
    CKR_SLOT_ID_INVALID);
end;

class function TPKCS11Utils.EnumerateKeys(const AModulePath: string; ASlotID: CK_SLOT_ID; const APIN: string): specialize TArray<TPKCS11KeyInfo>;
var
  Loader: TPKCS11Loader;
  C_OpenSession: TC_OpenSession;
  C_CloseSession: TC_CloseSession;
  C_Login: TC_Login;
  C_FindObjectsInit: TC_FindObjectsInit;
  C_FindObjects: TC_FindObjects;
  C_FindObjectsFinal: TC_FindObjectsFinal;
  C_GetAttributeValue: TC_GetAttributeValue;
  Session: CK_SESSION_HANDLE;
  Template: array[0..0] of CK_ATTRIBUTE;
  ObjectCount: CK_ULONG;
  ObjectHandle: CK_OBJECT_HANDLE;
  ObjectClass: CK_ULONG;
  KeyInfo: TPKCS11KeyInfo;
  RV: CK_RV;
  ResultList: specialize TVec<TPKCS11KeyInfo>;
  KeyType: CK_ULONG;
  KeyLabel: array[0..255] of AnsiChar;
  KeyLabelLen: CK_ULONG;
  PINAnsi: AnsiString;
begin
  SetLength(Result, 0);
  ResultList := specialize TVec<TPKCS11KeyInfo>.Create;
  try
    Loader := TPKCS11Loader.Create;
    try
      if not Loader.LoadLibrary(AModulePath) then
        raise EPKCS11Exception.Create('Failed to load PKCS#11 module: ' + AModulePath, CKR_GENERAL_ERROR);

      if not Loader.Initialize then
        raise EPKCS11Exception.Create('Failed to initialize PKCS#11 module', CKR_GENERAL_ERROR);

      if Loader.FunctionList = nil then
        raise EPKCS11Exception.Create('PKCS#11 function list not available', CKR_GENERAL_ERROR);

      C_OpenSession := TC_OpenSession(Loader.FunctionList^.C_OpenSession);
      C_CloseSession := TC_CloseSession(Loader.FunctionList^.C_CloseSession);
      C_Login := TC_Login(Loader.FunctionList^.C_Login);
      C_FindObjectsInit := TC_FindObjectsInit(Loader.FunctionList^.C_FindObjectsInit);
      C_FindObjects := TC_FindObjects(Loader.FunctionList^.C_FindObjects);
      C_FindObjectsFinal := TC_FindObjectsFinal(Loader.FunctionList^.C_FindObjectsFinal);
      C_GetAttributeValue := TC_GetAttributeValue(Loader.FunctionList^.C_GetAttributeValue);

      if (not Assigned(C_OpenSession)) or (not Assigned(C_CloseSession)) or (not Assigned(C_FindObjectsInit)) or
        (not Assigned(C_FindObjects)) or (not Assigned(C_FindObjectsFinal)) or (not Assigned(C_GetAttributeValue)) then
        raise EPKCS11Exception.Create('Required PKCS#11 functions not available', CKR_FUNCTION_NOT_SUPPORTED);

      if (APIN <> '') and (not Assigned(C_Login)) then
        raise EPKCS11Exception.Create('Required PKCS#11 functions not available', CKR_FUNCTION_NOT_SUPPORTED);

      // Open session
      RV := C_OpenSession(ASlotID, CKF_SERIAL_SESSION, nil, nil, @Session);
      if RV <> CKR_OK then
        raise EPKCS11Exception.Create('Failed to open session', RV);
      
      try
        // Login if PIN provided
        if APIN <> '' then
        begin
          PINAnsi := AnsiString(APIN);
          RV := C_Login(Session, CKU_USER, CK_UTF8CHAR_PTR(PAnsiChar(PINAnsi)), CK_ULONG(Length(PINAnsi)));
          if (RV <> CKR_OK) and (RV <> CKR_USER_ALREADY_LOGGED_IN) then
            raise EPKCS11Exception.Create('Failed to login', RV);
        end;
        
        // Find all private key objects
        ObjectClass := CKO_PRIVATE_KEY;
        Template[0].attrType := CKA_CLASS;
        Template[0].pValue := @ObjectClass;
        Template[0].ulValueLen := SizeOf(ObjectClass);
        
        RV := C_FindObjectsInit(Session, @Template[0], 1);
        if RV <> CKR_OK then
          raise EPKCS11Exception.Create('Failed to initialize object search', RV);
        
        try
          // Enumerate all private keys
          while True do
          begin
            ObjectCount := 0;
            RV := C_FindObjects(Session, @ObjectHandle, 1, @ObjectCount);
            if (RV <> CKR_OK) or (ObjectCount = 0) then
              Break;
            
            // Get key information
            FillChar(KeyInfo, SizeOf(KeyInfo), 0);
            KeyInfo.Handle := ObjectHandle;
            
            // Get key type
            Template[0].attrType := CKA_KEY_TYPE;
            Template[0].pValue := @KeyType;
            Template[0].ulValueLen := SizeOf(KeyType);
            RV := C_GetAttributeValue(Session, ObjectHandle, @Template[0], 1);
            if RV = CKR_OK then
              KeyInfo.KeyType := PKCS11KeyTypeFromCK(KeyType);
            
            // Get key label
            FillChar(KeyLabel, SizeOf(KeyLabel), 0);
            KeyLabelLen := SizeOf(KeyLabel);
            Template[0].attrType := CKA_LABEL;
            Template[0].pValue := @KeyLabel[0];
            Template[0].ulValueLen := KeyLabelLen;
            RV := C_GetAttributeValue(Session, ObjectHandle, @Template[0], 1);
            if RV = CKR_OK then
              KeyInfo.KeyLabel := TrimPKCS11String(KeyLabel);
            
            ResultList.Push(KeyInfo);
          end;
        finally
          C_FindObjectsFinal(Session);
        end;
      finally
        C_CloseSession(Session);
      end;
      
      Result := ResultList.ToArray;
    finally
      Loader.Free;
    end;
  finally
    ResultList.Free;
  end;
end;

class function TPKCS11Utils.FindKeyByLabel(const AModulePath: string; ASlotID: CK_SLOT_ID; const AKeyLabel: string; const APIN: string): TPKCS11KeyInfo;
var
  Keys: specialize TArray<TPKCS11KeyInfo>;
  I: Integer;
begin
  Keys := EnumerateKeys(AModulePath, ASlotID, APIN);
  
  for I := 0 to High(Keys) do
  begin
    if Keys[I].KeyLabel = AKeyLabel then
    begin
      Result := Keys[I];
      Exit;
    end;
  end;
  
  raise EPKCS11Exception.Create(
    Format('Key not found: %s', [AKeyLabel]),
    CKR_KEY_HANDLE_INVALID);
end;

class function TPKCS11Utils.GetModuleInfo(const AModulePath: string): string;
var
  Loader: TPKCS11Loader;
  C_GetInfo: TC_GetInfo;
  Info: CK_INFO;
  RV: CK_RV;
begin
  Loader := TPKCS11Loader.Create;
  try
    if not Loader.LoadLibrary(AModulePath) then
      raise EPKCS11Exception.Create('Failed to load PKCS#11 module: ' + AModulePath, CKR_GENERAL_ERROR);

    if not Loader.Initialize then
      raise EPKCS11Exception.Create('Failed to initialize PKCS#11 module', CKR_GENERAL_ERROR);

    if Loader.FunctionList = nil then
      raise EPKCS11Exception.Create('PKCS#11 function list not available', CKR_GENERAL_ERROR);

    C_GetInfo := TC_GetInfo(Loader.FunctionList^.C_GetInfo);
    if not Assigned(C_GetInfo) then
      raise EPKCS11Exception.Create('Required PKCS#11 functions not available', CKR_FUNCTION_NOT_SUPPORTED);

    RV := C_GetInfo(@Info);
    if RV <> CKR_OK then
      raise EPKCS11Exception.Create('Failed to get module info', RV);
    
    Result := Format(
      'PKCS#11 Module Information:'#13#10 +
      '  Cryptoki Version: %d.%d'#13#10 +
      '  Manufacturer: %s'#13#10 +
      '  Library Description: %s'#13#10 +
      '  Library Version: %d.%d',
      [
        Info.cryptokiVersion.major, Info.cryptokiVersion.minor,
        TrimPKCS11String(Info.manufacturerID),
        TrimPKCS11String(Info.libraryDescription),
        Info.libraryVersion.major, Info.libraryVersion.minor
      ]
    );
  finally
    Loader.Free;
  end;
end;

end.
