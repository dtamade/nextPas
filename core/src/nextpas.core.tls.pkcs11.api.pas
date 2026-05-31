unit nextpas.core.tls.pkcs11.api;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 (Cryptoki) API Bindings                               }
{                                                                              }
{  Purpose: PKCS#11 v2.40 API bindings for hardware security modules (HSM),   }
{           smart cards, and cryptographic tokens                              }
{                                                                              }
{  Standard: OASIS PKCS#11 v2.40                                               }
{  Reference: http://docs.oasis-open.org/pkcs11/pkcs11-base/v2.40/            }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  SysUtils, Classes, DynLibs;

const
  // PKCS#11 version
  CRYPTOKI_VERSION_MAJOR = 2;
  CRYPTOKI_VERSION_MINOR = 40;

type
  // Basic types
  CK_BYTE = Byte;
  CK_CHAR = AnsiChar;
  CK_UTF8CHAR = AnsiChar;
  CK_BBOOL = Byte;
  CK_ULONG = Cardinal;
  CK_LONG = Integer;
  CK_FLAGS = CK_ULONG;
  CK_VOID_PTR = Pointer;
  
  // Pointers
  CK_BYTE_PTR = ^CK_BYTE;
  CK_CHAR_PTR = ^CK_CHAR;
  CK_UTF8CHAR_PTR = ^CK_UTF8CHAR;
  CK_ULONG_PTR = ^CK_ULONG;
  CK_VOID_PTR_PTR = ^CK_VOID_PTR;

  // Object handles
  CK_SLOT_ID = CK_ULONG;
  CK_SLOT_ID_PTR = ^CK_SLOT_ID;
  
  CK_SESSION_HANDLE = CK_ULONG;
  CK_SESSION_HANDLE_PTR = ^CK_SESSION_HANDLE;
  
  CK_OBJECT_HANDLE = CK_ULONG;
  CK_OBJECT_HANDLE_PTR = ^CK_OBJECT_HANDLE;

  // Return values
  CK_RV = CK_ULONG;

  // Notification callback
  CK_NOTIFY = function(
    hSession: CK_SESSION_HANDLE;
    event: CK_ULONG;
    pApplication: CK_VOID_PTR
  ): CK_RV; cdecl;

const
  // Boolean values
  CK_TRUE = 1;
  CK_FALSE = 0;

  // Return value constants
  CKR_OK                                = $00000000;
  CKR_CANCEL                            = $00000001;
  CKR_HOST_MEMORY                       = $00000002;
  CKR_SLOT_ID_INVALID                   = $00000003;
  CKR_GENERAL_ERROR                     = $00000005;
  CKR_FUNCTION_FAILED                   = $00000006;
  CKR_ARGUMENTS_BAD                     = $00000007;
  CKR_NO_EVENT                          = $00000008;
  CKR_NEED_TO_CREATE_THREADS            = $00000009;
  CKR_CANT_LOCK                         = $0000000A;
  
  CKR_ATTRIBUTE_READ_ONLY               = $00000010;
  CKR_ATTRIBUTE_SENSITIVE               = $00000011;
  CKR_ATTRIBUTE_TYPE_INVALID            = $00000012;
  CKR_ATTRIBUTE_VALUE_INVALID           = $00000013;
  
  CKR_DATA_INVALID                      = $00000020;
  CKR_DATA_LEN_RANGE                    = $00000021;
  CKR_DEVICE_ERROR                      = $00000030;
  CKR_DEVICE_MEMORY                     = $00000031;
  CKR_DEVICE_REMOVED                    = $00000032;
  
  CKR_ENCRYPTED_DATA_INVALID            = $00000040;
  CKR_ENCRYPTED_DATA_LEN_RANGE          = $00000041;
  CKR_FUNCTION_CANCELED                 = $00000050;
  CKR_FUNCTION_NOT_PARALLEL             = $00000051;
  
  CKR_FUNCTION_NOT_SUPPORTED            = $00000054;
  
  CKR_KEY_HANDLE_INVALID                = $00000060;
  CKR_KEY_SIZE_RANGE                    = $00000062;
  CKR_KEY_TYPE_INCONSISTENT             = $00000063;
  
  CKR_KEY_NOT_NEEDED                    = $00000064;
  CKR_KEY_CHANGED                       = $00000065;
  CKR_KEY_NEEDED                        = $00000066;
  CKR_KEY_INDIGESTIBLE                  = $00000067;
  CKR_KEY_FUNCTION_NOT_PERMITTED        = $00000068;
  CKR_KEY_NOT_WRAPPABLE                 = $00000069;
  CKR_KEY_UNEXTRACTABLE                 = $0000006A;
  
  CKR_MECHANISM_INVALID                 = $00000070;
  CKR_MECHANISM_PARAM_INVALID           = $00000071;
  
  CKR_OBJECT_HANDLE_INVALID             = $00000082;
  CKR_OPERATION_ACTIVE                  = $00000090;
  CKR_OPERATION_NOT_INITIALIZED         = $00000091;
  
  CKR_PIN_INCORRECT                     = $000000A0;
  CKR_PIN_INVALID                       = $000000A1;
  CKR_PIN_LEN_RANGE                     = $000000A2;
  
  CKR_PIN_EXPIRED                       = $000000A3;
  CKR_PIN_LOCKED                        = $000000A4;
  
  CKR_SESSION_CLOSED                    = $000000B0;
  CKR_SESSION_COUNT                     = $000000B1;
  CKR_SESSION_HANDLE_INVALID            = $000000B3;
  CKR_SESSION_PARALLEL_NOT_SUPPORTED    = $000000B4;
  CKR_SESSION_READ_ONLY                 = $000000B5;
  CKR_SESSION_EXISTS                    = $000000B6;
  
  CKR_SESSION_READ_ONLY_EXISTS          = $000000B7;
  CKR_SESSION_READ_WRITE_SO_EXISTS      = $000000B8;
  
  CKR_SIGNATURE_INVALID                 = $000000C0;
  CKR_SIGNATURE_LEN_RANGE               = $000000C1;
  CKR_TEMPLATE_INCOMPLETE               = $000000D0;
  CKR_TEMPLATE_INCONSISTENT             = $000000D1;
  
  CKR_TOKEN_NOT_PRESENT                 = $000000E0;
  CKR_TOKEN_NOT_RECOGNIZED              = $000000E1;
  CKR_TOKEN_WRITE_PROTECTED             = $000000E2;
  
  CKR_UNWRAPPING_KEY_HANDLE_INVALID     = $000000F0;
  CKR_UNWRAPPING_KEY_SIZE_RANGE         = $000000F1;
  CKR_UNWRAPPING_KEY_TYPE_INCONSISTENT  = $000000F2;
  
  CKR_USER_ALREADY_LOGGED_IN            = $00000100;
  CKR_USER_NOT_LOGGED_IN                = $00000101;
  CKR_USER_PIN_NOT_INITIALIZED          = $00000102;
  CKR_USER_TYPE_INVALID                 = $00000103;
  
  CKR_USER_ANOTHER_ALREADY_LOGGED_IN    = $00000104;
  CKR_USER_TOO_MANY_TYPES               = $00000105;
  
  CKR_WRAPPED_KEY_INVALID               = $00000110;
  CKR_WRAPPED_KEY_LEN_RANGE             = $00000112;
  CKR_WRAPPING_KEY_HANDLE_INVALID       = $00000113;
  CKR_WRAPPING_KEY_SIZE_RANGE           = $00000114;
  CKR_WRAPPING_KEY_TYPE_INCONSISTENT    = $00000115;
  
  CKR_RANDOM_SEED_NOT_SUPPORTED         = $00000120;
  CKR_RANDOM_NO_RNG                     = $00000121;
  
  CKR_DOMAIN_PARAMS_INVALID             = $00000130;
  CKR_BUFFER_TOO_SMALL                  = $00000150;
  CKR_SAVED_STATE_INVALID               = $00000160;
  CKR_INFORMATION_SENSITIVE             = $00000170;
  CKR_STATE_UNSAVEABLE                  = $00000180;
  
  CKR_CRYPTOKI_NOT_INITIALIZED          = $00000190;
  CKR_CRYPTOKI_ALREADY_INITIALIZED      = $00000191;
  CKR_MUTEX_BAD                         = $000001A0;
  CKR_MUTEX_NOT_LOCKED                  = $000001A1;
  
  CKR_FUNCTION_REJECTED                 = $00000200;

type
  // Version structure
  CK_VERSION = packed record
    major: CK_BYTE;
    minor: CK_BYTE;
  end;
  CK_VERSION_PTR = ^CK_VERSION;

  // Info structure
  CK_INFO = packed record
    cryptokiVersion: CK_VERSION;
    manufacturerID: array[0..31] of CK_UTF8CHAR;
    flags: CK_FLAGS;
    libraryDescription: array[0..31] of CK_UTF8CHAR;
    libraryVersion: CK_VERSION;
  end;
  CK_INFO_PTR = ^CK_INFO;

  // Slot info
  CK_SLOT_INFO = packed record
    slotDescription: array[0..63] of CK_UTF8CHAR;
    manufacturerID: array[0..31] of CK_UTF8CHAR;
    flags: CK_FLAGS;
    hardwareVersion: CK_VERSION;
    firmwareVersion: CK_VERSION;
  end;
  CK_SLOT_INFO_PTR = ^CK_SLOT_INFO;

  // Token info
  CK_TOKEN_INFO = packed record
    tokenLabel: array[0..31] of CK_UTF8CHAR;
    manufacturerID: array[0..31] of CK_UTF8CHAR;
    model: array[0..15] of CK_UTF8CHAR;
    serialNumber: array[0..15] of CK_CHAR;
    flags: CK_FLAGS;
    ulMaxSessionCount: CK_ULONG;
    ulSessionCount: CK_ULONG;
    ulMaxRwSessionCount: CK_ULONG;
    ulRwSessionCount: CK_ULONG;
    ulMaxPinLen: CK_ULONG;
    ulMinPinLen: CK_ULONG;
    ulTotalPublicMemory: CK_ULONG;
    ulFreePublicMemory: CK_ULONG;
    ulTotalPrivateMemory: CK_ULONG;
    ulFreePrivateMemory: CK_ULONG;
    hardwareVersion: CK_VERSION;
    firmwareVersion: CK_VERSION;
    utcTime: array[0..15] of CK_CHAR;
  end;
  CK_TOKEN_INFO_PTR = ^CK_TOKEN_INFO;

  // Session info
  CK_SESSION_INFO = packed record
    slotID: CK_SLOT_ID;
    state: CK_ULONG;
    flags: CK_FLAGS;
    ulDeviceError: CK_ULONG;
  end;
  CK_SESSION_INFO_PTR = ^CK_SESSION_INFO;

  // Attribute
  CK_ATTRIBUTE_TYPE = CK_ULONG;
  
  CK_ATTRIBUTE = packed record
    attrType: CK_ATTRIBUTE_TYPE;
    pValue: CK_VOID_PTR;
    ulValueLen: CK_ULONG;
  end;
  CK_ATTRIBUTE_PTR = ^CK_ATTRIBUTE;

  // Mechanism
  CK_MECHANISM_TYPE = CK_ULONG;
  
  CK_MECHANISM = packed record
    mechanism: CK_MECHANISM_TYPE;
    pParameter: CK_VOID_PTR;
    ulParameterLen: CK_ULONG;
  end;
  CK_MECHANISM_PTR = ^CK_MECHANISM;

  CK_MECHANISM_INFO = packed record
    ulMinKeySize: CK_ULONG;
    ulMaxKeySize: CK_ULONG;
    flags: CK_FLAGS;
  end;
  CK_MECHANISM_INFO_PTR = ^CK_MECHANISM_INFO;

const
  // Session flags
  CKF_RW_SESSION = $00000002;
  CKF_SERIAL_SESSION = $00000004;

  // Token flags
  CKF_RNG = $00000001;
  CKF_WRITE_PROTECTED = $00000002;
  CKF_LOGIN_REQUIRED = $00000004;
  CKF_USER_PIN_INITIALIZED = $00000008;
  CKF_PROTECTED_AUTHENTICATION_PATH = $00000100;
  CKF_TOKEN_INITIALIZED = $00000400;

  // User types
  CKU_SO = 0;
  CKU_USER = 1;
  CKU_CONTEXT_SPECIFIC = 2;

  // Object classes
  CKO_DATA = $00000000;
  CKO_CERTIFICATE = $00000001;
  CKO_PUBLIC_KEY = $00000002;
  CKO_PRIVATE_KEY = $00000003;
  CKO_SECRET_KEY = $00000004;

  // Key types
  CKK_RSA = $00000000;
  CKK_DSA = $00000001;
  CKK_DH = $00000002;
  CKK_EC = $00000003;
  CKK_AES = $0000001F;

  // Attribute types
  CKA_CLASS = $00000000;
  CKA_TOKEN = $00000001;
  CKA_PRIVATE = $00000002;
  CKA_LABEL = $00000003;
  CKA_VALUE = $00000011;
  CKA_CERTIFICATE_TYPE = $00000080;
  CKA_ISSUER = $00000081;
  CKA_SERIAL_NUMBER = $00000082;
  CKA_KEY_TYPE = $00000100;
  CKA_ID = $00000102;
  CKA_SENSITIVE = $00000103;
  CKA_ENCRYPT = $00000104;
  CKA_DECRYPT = $00000105;
  CKA_SIGN = $00000108;
  CKA_VERIFY = $0000010A;
  CKA_MODULUS = $00000120;
  CKA_PUBLIC_EXPONENT = $00000122;
  CKA_PRIVATE_EXPONENT = $00000123;

  // Mechanism types
  CKM_RSA_PKCS = $00000001;
  CKM_RSA_PKCS_KEY_PAIR_GEN = $00000000;
  CKM_SHA1_RSA_PKCS = $00000006;
  CKM_SHA256_RSA_PKCS = $00000040;
  CKM_SHA384_RSA_PKCS = $00000041;
  CKM_SHA512_RSA_PKCS = $00000042;
  CKM_AES_KEY_GEN = $00001080;
  CKM_AES_ECB = $00001081;
  CKM_AES_CBC = $00001082;
  CKM_AES_GCM = $00001087;

type
  // Function list structure
  CK_FUNCTION_LIST = packed record
    version: CK_VERSION;
    // General purpose functions (will be defined later)
    C_Initialize: Pointer;
    C_Finalize: Pointer;
    C_GetInfo: Pointer;
    C_GetFunctionList: Pointer;
    // Slot and token management
    C_GetSlotList: Pointer;
    C_GetSlotInfo: Pointer;
    C_GetTokenInfo: Pointer;
    C_GetMechanismList: Pointer;
    C_GetMechanismInfo: Pointer;
    C_InitToken: Pointer;
    C_InitPIN: Pointer;
    C_SetPIN: Pointer;
    // Session management
    C_OpenSession: Pointer;
    C_CloseSession: Pointer;
    C_CloseAllSessions: Pointer;
    C_GetSessionInfo: Pointer;
    C_GetOperationState: Pointer;
    C_SetOperationState: Pointer;
    C_Login: Pointer;
    C_Logout: Pointer;
    // Object management
    C_CreateObject: Pointer;
    C_CopyObject: Pointer;
    C_DestroyObject: Pointer;
    C_GetObjectSize: Pointer;
    C_GetAttributeValue: Pointer;
    C_SetAttributeValue: Pointer;
    C_FindObjectsInit: Pointer;
    C_FindObjects: Pointer;
    C_FindObjectsFinal: Pointer;
    // Encryption
    C_EncryptInit: Pointer;
    C_Encrypt: Pointer;
    C_EncryptUpdate: Pointer;
    C_EncryptFinal: Pointer;
    // Decryption
    C_DecryptInit: Pointer;
    C_Decrypt: Pointer;
    C_DecryptUpdate: Pointer;
    C_DecryptFinal: Pointer;
    // Message digesting
    C_DigestInit: Pointer;
    C_Digest: Pointer;
    C_DigestUpdate: Pointer;
    C_DigestKey: Pointer;
    C_DigestFinal: Pointer;
    // Signing
    C_SignInit: Pointer;
    C_Sign: Pointer;
    C_SignUpdate: Pointer;
    C_SignFinal: Pointer;
    C_SignRecoverInit: Pointer;
    C_SignRecover: Pointer;
    // Verifying
    C_VerifyInit: Pointer;
    C_Verify: Pointer;
    C_VerifyUpdate: Pointer;
    C_VerifyFinal: Pointer;
    C_VerifyRecoverInit: Pointer;
    C_VerifyRecover: Pointer;
    // Dual-function cryptographic operations
    C_DigestEncryptUpdate: Pointer;
    C_DecryptDigestUpdate: Pointer;
    C_SignEncryptUpdate: Pointer;
    C_DecryptVerifyUpdate: Pointer;
    // Key management
    C_GenerateKey: Pointer;
    C_GenerateKeyPair: Pointer;
    C_WrapKey: Pointer;
    C_UnwrapKey: Pointer;
    C_DeriveKey: Pointer;
    // Random number generation
    C_SeedRandom: Pointer;
    C_GenerateRandom: Pointer;
    // Parallel function management
    C_GetFunctionStatus: Pointer;
    C_CancelFunction: Pointer;
    C_WaitForSlotEvent: Pointer;
  end;
  CK_FUNCTION_LIST_PTR = ^CK_FUNCTION_LIST;
  CK_FUNCTION_LIST_PTR_PTR = ^CK_FUNCTION_LIST_PTR;

implementation

end.
