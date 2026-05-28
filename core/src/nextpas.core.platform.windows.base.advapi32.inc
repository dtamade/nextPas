{ advapi32 types and constants
  Registry, Security/Token, Service APIs
  Ported from FPC rtl/win/wininc }

type
  HKEY = HANDLE;
  PHKEY = ^HKEY;
  REGSAM = DWORD;
  SECURITY_INFORMATION = DWORD;
  PSECURITY_DESCRIPTOR = Pointer;
  PSID = Pointer;
  ACCESS_MASK = DWORD;
  LUID = record
    LowPart: DWORD;
    HighPart: LongInt;
  end;
  PLUID = ^LUID;
  LUID_AND_ATTRIBUTES = record
    Luid: LUID;
    Attributes: DWORD;
  end;
  TOKEN_PRIVILEGES = record
    PrivilegeCount: DWORD;
    Privileges: array[0..0] of LUID_AND_ATTRIBUTES;
  end;
  PTOKEN_PRIVILEGES = ^TOKEN_PRIVILEGES;
  TOKEN_INFORMATION_CLASS = DWORD;
  SC_HANDLE = HANDLE;
  SERVICE_STATUS = record
    dwServiceType: DWORD;
    dwCurrentState: DWORD;
    dwControlsAccepted: DWORD;
    dwWin32ExitCode: DWORD;
    dwServiceSpecificExitCode: DWORD;
    dwCheckPoint: DWORD;
    dwWaitHint: DWORD;
  end;
  LPSERVICE_STATUS = ^SERVICE_STATUS;

const
  { Registry root keys }
  HKEY_CLASSES_ROOT     = HKEY($80000000);
  HKEY_CURRENT_USER     = HKEY($80000001);
  HKEY_LOCAL_MACHINE    = HKEY($80000002);
  HKEY_USERS            = HKEY($80000003);
  HKEY_PERFORMANCE_DATA = HKEY($80000004);
  HKEY_CURRENT_CONFIG   = HKEY($80000005);

  { Registry access rights }
  KEY_QUERY_VALUE        = $0001;
  KEY_SET_VALUE          = $0002;
  KEY_CREATE_SUB_KEY     = $0004;
  KEY_ENUMERATE_SUB_KEYS = $0008;
  KEY_NOTIFY             = $0010;
  KEY_CREATE_LINK        = $0020;
  KEY_WOW64_64KEY        = $0100;
  KEY_WOW64_32KEY        = $0200;
  KEY_READ               = $20019;
  KEY_WRITE              = $20006;
  KEY_ALL_ACCESS         = $F003F;

  { Registry value types }
  REG_NONE                = 0;
  REG_SZ                  = 1;
  REG_EXPAND_SZ           = 2;
  REG_BINARY              = 3;
  REG_DWORD               = 4;
  REG_DWORD_LITTLE_ENDIAN = 4;
  REG_DWORD_BIG_ENDIAN    = 5;
  REG_LINK                = 6;
  REG_MULTI_SZ            = 7;
  REG_QWORD               = 11;

  { Token access rights }
  TOKEN_ASSIGN_PRIMARY    = $0001;
  TOKEN_DUPLICATE         = $0002;
  TOKEN_IMPERSONATE       = $0004;
  TOKEN_QUERY             = $0008;
  TOKEN_QUERY_SOURCE      = $0010;
  TOKEN_ADJUST_PRIVILEGES = $0020;
  TOKEN_ADJUST_GROUPS     = $0040;
  TOKEN_ADJUST_DEFAULT    = $0080;
  TOKEN_ADJUST_SESSIONID  = $0100;
  TOKEN_ALL_ACCESS        = $F01FF;
  TOKEN_READ              = $20008;

  { Token information classes }
  TokenUser                  = 1;
  TokenGroups                = 2;
  TokenPrivileges            = 3;
  TokenOwner                 = 4;
  TokenPrimaryGroup          = 5;
  TokenDefaultDacl           = 6;
  TokenSource                = 7;
  TokenType                  = 8;
  TokenImpersonationLevel    = 9;
  TokenStatistics            = 10;
  TokenRestrictedSids        = 11;
  TokenSessionId             = 12;
  TokenElevation             = 20;
  TokenElevationType         = 18;
  TokenIntegrityLevel        = 25;

  { Service control manager access }
  SC_MANAGER_ALL_ACCESS     = $F003F;
  SC_MANAGER_CONNECT        = $0001;
  SC_MANAGER_CREATE_SERVICE = $0002;
  SC_MANAGER_ENUMERATE_SERVICE = $0004;

  { Service types }
  SERVICE_KERNEL_DRIVER       = $00000001;
  SERVICE_FILE_SYSTEM_DRIVER  = $00000002;
  SERVICE_WIN32_OWN_PROCESS   = $00000010;
  SERVICE_WIN32_SHARE_PROCESS = $00000020;
  SERVICE_INTERACTIVE_PROCESS = $00000100;

  { Service states }
  SERVICE_STOPPED          = $00000001;
  SERVICE_START_PENDING    = $00000002;
  SERVICE_STOP_PENDING     = $00000003;
  SERVICE_RUNNING          = $00000004;
  SERVICE_CONTINUE_PENDING = $00000005;
  SERVICE_PAUSE_PENDING    = $00000006;
  SERVICE_PAUSED           = $00000007;

  { Service control codes }
  SERVICE_CONTROL_STOP         = $00000001;
  SERVICE_CONTROL_PAUSE        = $00000002;
  SERVICE_CONTROL_CONTINUE     = $00000003;
  SERVICE_CONTROL_INTERROGATE  = $00000004;

  { Privilege constants }
  SE_PRIVILEGE_ENABLED_BY_DEFAULT = $00000001;
  SE_PRIVILEGE_ENABLED            = $00000002;
  SE_PRIVILEGE_REMOVED            = $00000004;
  SE_PRIVILEGE_USED_FOR_ACCESS    = $80000000;
