{ advapi32.dll FFI declarations
  Registry, Security/Token, Service APIs
  Ported from FPC rtl/win/wininc }

{ Registry }
function RegOpenKeyExA(hKey: HKEY; lpSubKey: LPCSTR; ulOptions: DWORD; samDesired: REGSAM; phkResult: PHKEY): LongInt; stdcall; external 'advapi32' name 'RegOpenKeyExA';
function RegOpenKeyExW(hKey: HKEY; lpSubKey: LPCWSTR; ulOptions: DWORD; samDesired: REGSAM; phkResult: PHKEY): LongInt; stdcall; external 'advapi32' name 'RegOpenKeyExW';
function RegCreateKeyExA(hKey: HKEY; lpSubKey: LPCSTR; Reserved: DWORD; lpClass: LPSTR; dwOptions: DWORD; samDesired: REGSAM; lpSecurityAttributes: LPSECURITY_ATTRIBUTES; phkResult: PHKEY; lpdwDisposition: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegCreateKeyExA';
function RegCreateKeyExW(hKey: HKEY; lpSubKey: LPCWSTR; Reserved: DWORD; lpClass: LPWSTR; dwOptions: DWORD; samDesired: REGSAM; lpSecurityAttributes: LPSECURITY_ATTRIBUTES; phkResult: PHKEY; lpdwDisposition: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegCreateKeyExW';
function RegCloseKey(hKey: HKEY): LongInt; stdcall; external 'advapi32' name 'RegCloseKey';
function RegDeleteKeyA(hKey: HKEY; lpSubKey: LPCSTR): LongInt; stdcall; external 'advapi32' name 'RegDeleteKeyA';
function RegDeleteKeyW(hKey: HKEY; lpSubKey: LPCWSTR): LongInt; stdcall; external 'advapi32' name 'RegDeleteKeyW';
function RegDeleteValueA(hKey: HKEY; lpValueName: LPCSTR): LongInt; stdcall; external 'advapi32' name 'RegDeleteValueA';
function RegDeleteValueW(hKey: HKEY; lpValueName: LPCWSTR): LongInt; stdcall; external 'advapi32' name 'RegDeleteValueW';
function RegQueryValueExA(hKey: HKEY; lpValueName: LPCSTR; lpReserved: LPDWORD; lpType: LPDWORD; lpData: Pointer; lpcbData: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegQueryValueExA';
function RegQueryValueExW(hKey: HKEY; lpValueName: LPCWSTR; lpReserved: LPDWORD; lpType: LPDWORD; lpData: Pointer; lpcbData: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegQueryValueExW';
function RegSetValueExA(hKey: HKEY; lpValueName: LPCSTR; Reserved: DWORD; dwType: DWORD; lpData: Pointer; cbData: DWORD): LongInt; stdcall; external 'advapi32' name 'RegSetValueExA';
function RegSetValueExW(hKey: HKEY; lpValueName: LPCWSTR; Reserved: DWORD; dwType: DWORD; lpData: Pointer; cbData: DWORD): LongInt; stdcall; external 'advapi32' name 'RegSetValueExW';
function RegEnumKeyExA(hKey: HKEY; dwIndex: DWORD; lpName: LPSTR; lpcName: LPDWORD; lpReserved: LPDWORD; lpClass: LPSTR; lpcClass: LPDWORD; lpftLastWriteTime: Pointer): LongInt; stdcall; external 'advapi32' name 'RegEnumKeyExA';
function RegEnumKeyExW(hKey: HKEY; dwIndex: DWORD; lpName: LPWSTR; lpcName: LPDWORD; lpReserved: LPDWORD; lpClass: LPWSTR; lpcClass: LPDWORD; lpftLastWriteTime: Pointer): LongInt; stdcall; external 'advapi32' name 'RegEnumKeyExW';
function RegEnumValueA(hKey: HKEY; dwIndex: DWORD; lpValueName: LPSTR; lpcchValueName: LPDWORD; lpReserved: LPDWORD; lpType: LPDWORD; lpData: Pointer; lpcbData: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegEnumValueA';
function RegEnumValueW(hKey: HKEY; dwIndex: DWORD; lpValueName: LPWSTR; lpcchValueName: LPDWORD; lpReserved: LPDWORD; lpType: LPDWORD; lpData: Pointer; lpcbData: LPDWORD): LongInt; stdcall; external 'advapi32' name 'RegEnumValueW';

{ Security / Token }
function OpenProcessToken(ProcessHandle: HANDLE; DesiredAccess: DWORD; TokenHandle: PHANDLE): WINBOOL; stdcall; external 'advapi32' name 'OpenProcessToken';
function OpenThreadToken(ThreadHandle: HANDLE; DesiredAccess: DWORD; OpenAsSelf: WINBOOL; TokenHandle: PHANDLE): WINBOOL; stdcall; external 'advapi32' name 'OpenThreadToken';
function GetTokenInformation(TokenHandle: HANDLE; TokenInformationClass: TOKEN_INFORMATION_CLASS; TokenInformation: Pointer; TokenInformationLength: DWORD; ReturnLength: LPDWORD): WINBOOL; stdcall; external 'advapi32' name 'GetTokenInformation';
function AdjustTokenPrivileges(TokenHandle: HANDLE; DisableAllPrivileges: WINBOOL; NewState: PTOKEN_PRIVILEGES; BufferLength: DWORD; PreviousState: PTOKEN_PRIVILEGES; ReturnLength: LPDWORD): WINBOOL; stdcall; external 'advapi32' name 'AdjustTokenPrivileges';
function LookupPrivilegeValueA(lpSystemName: LPCSTR; lpName: LPCSTR; lpLuid: PLUID): WINBOOL; stdcall; external 'advapi32' name 'LookupPrivilegeValueA';
function LookupPrivilegeValueW(lpSystemName: LPCWSTR; lpName: LPCWSTR; lpLuid: PLUID): WINBOOL; stdcall; external 'advapi32' name 'LookupPrivilegeValueW';
function ImpersonateLoggedOnUser(hToken: HANDLE): WINBOOL; stdcall; external 'advapi32' name 'ImpersonateLoggedOnUser';
function RevertToSelf: WINBOOL; stdcall; external 'advapi32' name 'RevertToSelf';
function GetUserNameA(lpBuffer: LPSTR; nSize: LPDWORD): WINBOOL; stdcall; external 'advapi32' name 'GetUserNameA';
function GetUserNameW(lpBuffer: LPWSTR; nSize: LPDWORD): WINBOOL; stdcall; external 'advapi32' name 'GetUserNameW';

{ Service Control Manager }
function OpenSCManagerA(lpMachineName: LPCSTR; lpDatabaseName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external 'advapi32' name 'OpenSCManagerA';
function OpenSCManagerW(lpMachineName: LPCWSTR; lpDatabaseName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external 'advapi32' name 'OpenSCManagerW';
function OpenServiceA(hSCManager: SC_HANDLE; lpServiceName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external 'advapi32' name 'OpenServiceA';
function OpenServiceW(hSCManager: SC_HANDLE; lpServiceName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external 'advapi32' name 'OpenServiceW';
function CloseServiceHandle(hSCObject: SC_HANDLE): WINBOOL; stdcall; external 'advapi32' name 'CloseServiceHandle';
function StartServiceA(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: Pointer): WINBOOL; stdcall; external 'advapi32' name 'StartServiceA';
function StartServiceW(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: Pointer): WINBOOL; stdcall; external 'advapi32' name 'StartServiceW';
function ControlService(hService: SC_HANDLE; dwControl: DWORD; lpServiceStatus: LPSERVICE_STATUS): WINBOOL; stdcall; external 'advapi32' name 'ControlService';
function QueryServiceStatus(hService: SC_HANDLE; lpServiceStatus: LPSERVICE_STATUS): WINBOOL; stdcall; external 'advapi32' name 'QueryServiceStatus';
