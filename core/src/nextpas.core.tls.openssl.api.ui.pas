{
  OpenSSL UI (用户交互) API 模块
  提供密码输入、确认等用户交互功能
}
unit nextpas.core.tls.openssl.api.ui;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.base;

const
  // UI 字符串类型
  UIT_NONE = 0;
  UIT_PROMPT = 1;
  UIT_VERIFY = 2;
  UIT_BOOLEAN = 3;
  UIT_INFO = 4;
  UIT_ERROR = 5;
  
  // UI 输入标志
  UI_INPUT_FLAG_ECHO = $01;
  UI_INPUT_FLAG_DEFAULT_PWD = $02;
  UI_INPUT_FLAG_USER_BASE = 16;
  
  // UI 控制命令
  UI_CTRL_PRINT_ERRORS = 1;
  UI_CTRL_IS_REDOABLE = 2;
  
  // UI 方法标志
  UI_METHOD_FLAG_REDOABLE = $0001;
  UI_METHOD_FLAG_NO_ECHO = $0002;
  
  // UI 结果值
  UI_OK = 0;
  UI_ERR = -1;

type
  // 前向声明
  PUI = ^UI;
  PUI_METHOD = ^UI_METHOD;
  PUI_STRING = ^UI_STRING;
  
  // 不透明结构体
  UI = record end;
  UI_METHOD = record end;
  UI_STRING = record end;
  
  // 回调函数类型
  TUI_opener = function(ui: PUI): Integer; cdecl;
  TUI_writer = function(ui: PUI; uis: PUI_STRING): Integer; cdecl;
  TUI_flusher = function(ui: PUI): Integer; cdecl;
  TUI_reader = function(ui: PUI; uis: PUI_STRING): Integer; cdecl;
  TUI_closer = function(ui: PUI): Integer; cdecl;
  TUI_prompt_constructor = function(ui: PUI; prompt: PAnsiChar; 
                                    object_desc: PAnsiChar): PAnsiChar; cdecl;
  TUI_duplicator = function(ui: PUI; ui_data: Pointer; ex_data: Pointer): Pointer; cdecl;
  TUI_destructor = procedure(ui: PUI; ui_data: Pointer); cdecl;
  
  // 函数指针类型
  
  // UI 基本函数
  TUI_new = function(): PUI; cdecl;
  TUI_new_method = function(method: PUI_METHOD): PUI; cdecl;
  TUI_free = procedure(ui: PUI); cdecl;
  TUI_add_input_string = function(ui: PUI; prompt: PAnsiChar; flags: Integer;
                                result_buf: PAnsiChar; minsize: Integer; 
                                maxsize: Integer): Integer; cdecl;
  TUI_dup_input_string = function(ui: PUI; prompt: PAnsiChar; flags: Integer;
                                  result_buf: PAnsiChar; minsize: Integer;
                                  maxsize: Integer): Integer; cdecl;
  TUI_add_verify_string = function(ui: PUI; prompt: PAnsiChar; flags: Integer;
                                  result_buf: PAnsiChar; minsize: Integer; 
                                  maxsize: Integer; test_buf: PAnsiChar): Integer; cdecl;
  TUI_dup_verify_string = function(ui: PUI; prompt: PAnsiChar; flags: Integer;
                                  result_buf: PAnsiChar; minsize: Integer;
                                  maxsize: Integer; test_buf: PAnsiChar): Integer; cdecl;
  TUI_add_input_boolean = function(ui: PUI; prompt: PAnsiChar; action_desc: PAnsiChar;
                                  ok_chars: PAnsiChar; cancel_chars: PAnsiChar;
                                  flags: Integer; result_buf: PAnsiChar): Integer; cdecl;
  TUI_dup_input_boolean = function(ui: PUI; prompt: PAnsiChar; action_desc: PAnsiChar;
                                  ok_chars: PAnsiChar; cancel_chars: PAnsiChar;
                                  flags: Integer; result_buf: PAnsiChar): Integer; cdecl;
  TUI_add_info_string = function(ui: PUI; text: PAnsiChar): Integer; cdecl;
  TUI_dup_info_string = function(ui: PUI; text: PAnsiChar): Integer; cdecl;
  TUI_add_error_string = function(ui: PUI; text: PAnsiChar): Integer; cdecl;
  TUI_dup_error_string = function(ui: PUI; text: PAnsiChar): Integer; cdecl;
  
  // UI 构造函数
  TUI_construct_prompt = function(ui_method: PUI_METHOD; object_desc: PAnsiChar;
                                object_name: PAnsiChar): PAnsiChar; cdecl;
  
  // UI 用户数据函数
  TUI_add_user_data = function(ui: PUI; user_data: Pointer): Pointer; cdecl;
  TUI_dup_user_data = function(ui: PUI; user_data: Pointer): Pointer; cdecl;
  TUI_get0_user_data = function(ui: PUI): Pointer; cdecl;
  
  // UI 结果函数
  TUI_get0_result = function(ui: PUI; i: Integer): PAnsiChar; cdecl;
  TUI_get_result_length = function(ui: PUI; i: Integer): Integer; cdecl;
  TUI_get0_result_string = function(uis: PUI_STRING): PAnsiChar; cdecl;
  TUI_get_result_string_length = function(uis: PUI_STRING): Integer; cdecl;
  
  // UI 处理函数
  TUI_process = function(ui: PUI): Integer; cdecl;
  TUI_ctrl = function(ui: PUI; cmd: Integer; i: LongInt; p: Pointer; f: Pointer): Integer; cdecl;
  
  // UI 工具函数
  TUI_set_ex_data = function(ui: PUI; idx: Integer; data: Pointer): Integer; cdecl;
  TUI_get_ex_data = function(ui: PUI; idx: Integer): Pointer; cdecl;
  
  // UI_METHOD 函数
  TUI_METHOD_get_default_method = function(): PUI_METHOD; cdecl;
  TUI_METHOD_get_openssl = function(): PUI_METHOD; cdecl;
  TUI_METHOD_new = function(): PUI_METHOD; cdecl;
  TUI_METHOD_free = procedure(method: PUI_METHOD); cdecl;
  TUI_METHOD_set_opener = function(method: PUI_METHOD; opener: TUI_opener): Integer; cdecl;
  TUI_METHOD_set_writer = function(method: PUI_METHOD; writer: TUI_writer): Integer; cdecl;
  TUI_METHOD_set_flusher = function(method: PUI_METHOD; flusher: TUI_flusher): Integer; cdecl;
  TUI_METHOD_set_reader = function(method: PUI_METHOD; reader: TUI_reader): Integer; cdecl;
  TUI_METHOD_set_closer = function(method: PUI_METHOD; closer: TUI_closer): Integer; cdecl;
  TUI_METHOD_set_data_duplicator = function(method: PUI_METHOD; 
                                          duplicator: TUI_duplicator;
                                          destructor_: TUI_destructor): Integer; cdecl;
  TUI_METHOD_set_prompt_constructor = function(method: PUI_METHOD;
                                              prompt_constructor: TUI_prompt_constructor): Integer; cdecl;
  TUI_METHOD_set_ex_data = function(method: PUI_METHOD; idx: Integer; 
                                  data: Pointer): Integer; cdecl;
  TUI_METHOD_get_ex_data = function(method: PUI_METHOD; idx: Integer): Pointer; cdecl;
  TUI_METHOD_get_opener = function(method: PUI_METHOD): TUI_opener; cdecl;
  TUI_METHOD_get_writer = function(method: PUI_METHOD): TUI_writer; cdecl;
  TUI_METHOD_get_flusher = function(method: PUI_METHOD): TUI_flusher; cdecl;
  TUI_METHOD_get_reader = function(method: PUI_METHOD): TUI_reader; cdecl;
  TUI_METHOD_get_closer = function(method: PUI_METHOD): TUI_closer; cdecl;
  TUI_METHOD_get_prompt_constructor = function(method: PUI_METHOD): TUI_prompt_constructor; cdecl;
  TUI_METHOD_get_data_duplicator = function(method: PUI_METHOD): TUI_duplicator; cdecl;
  TUI_METHOD_get_data_destructor = function(method: PUI_METHOD): TUI_destructor; cdecl;
  
  // UI_STRING 函数
  TUI_get_string_type = function(uis: PUI_STRING): Integer; cdecl;
  TUI_get_input_flags = function(uis: PUI_STRING): Integer; cdecl;
  TUI_get0_output_string = function(uis: PUI_STRING): PAnsiChar; cdecl;
  TUI_get0_action_string = function(uis: PUI_STRING): PAnsiChar; cdecl;
  TUI_get0_result_string_str = function(uis: PUI_STRING): PAnsiChar; cdecl;  // Renamed to avoid conflict
  TUI_get0_test_string = function(uis: PUI_STRING): PAnsiChar; cdecl;
  TUI_get_result_min_size = function(uis: PUI_STRING): Integer; cdecl;
  TUI_get_result_max_size = function(uis: PUI_STRING): Integer; cdecl;
  TUI_set_result = function(ui: PUI; uis: PUI_STRING; 
                          const result_: PAnsiChar): Integer; cdecl;
  TUI_set_result_ex = function(ui: PUI; uis: PUI_STRING;
                              const result_: PAnsiChar; len: Integer): Integer; cdecl;
  
  // UI 实用函数
  TUI_UTIL_read_pw_string = function(buf: PAnsiChar; length: Integer;
                                    const prompt: PAnsiChar;
                                    verify: Integer): Integer; cdecl;
  TUI_UTIL_read_pw = function(buf: PAnsiChar; buff: PAnsiChar;
                            size: Integer; const prompt: PAnsiChar;
                            verify: Integer): Integer; cdecl;
  TUI_UTIL_wrap_read_pem_callback = function(cb: Pointer; rwflag: Integer): PUI_METHOD; cdecl;

var
  // UI 基本函数
  UI_new: TUI_new;
  UI_new_method: TUI_new_method;
  UI_free: TUI_free;
  UI_add_input_string: TUI_add_input_string;
  UI_dup_input_string: TUI_dup_input_string;
  UI_add_verify_string: TUI_add_verify_string;
  UI_dup_verify_string: TUI_dup_verify_string;
  UI_add_input_boolean: TUI_add_input_boolean;
  UI_dup_input_boolean: TUI_dup_input_boolean;
  UI_add_info_string: TUI_add_info_string;
  UI_dup_info_string: TUI_dup_info_string;
  UI_add_error_string: TUI_add_error_string;
  UI_dup_error_string: TUI_dup_error_string;
  
  // UI 构造函数
  UI_construct_prompt: TUI_construct_prompt;
  
  // UI 用户数据函数
  UI_add_user_data: TUI_add_user_data;
  UI_dup_user_data: TUI_dup_user_data;
  UI_get0_user_data: TUI_get0_user_data;
  
  // UI 结果函数
  UI_get0_result: TUI_get0_result;
  UI_get_result_length: TUI_get_result_length;
  UI_get0_result_string: TUI_get0_result_string;
  UI_get_result_string_length: TUI_get_result_string_length;
  
  // UI 处理函数
  UI_process: TUI_process;
  UI_ctrl: TUI_ctrl;
  
  // UI 工具函数
  UI_set_ex_data: TUI_set_ex_data;
  UI_get_ex_data: TUI_get_ex_data;
  
  // UI_METHOD 函数
  UI_METHOD_get_default_method: TUI_METHOD_get_default_method;
  UI_METHOD_get_openssl: TUI_METHOD_get_openssl;
  UI_METHOD_new: TUI_METHOD_new;
  UI_METHOD_free: TUI_METHOD_free;
  UI_METHOD_set_opener: TUI_METHOD_set_opener;
  UI_METHOD_set_writer: TUI_METHOD_set_writer;
  UI_METHOD_set_flusher: TUI_METHOD_set_flusher;
  UI_METHOD_set_reader: TUI_METHOD_set_reader;
  UI_METHOD_set_closer: TUI_METHOD_set_closer;
  UI_METHOD_set_data_duplicator: TUI_METHOD_set_data_duplicator;
  UI_METHOD_set_prompt_constructor: TUI_METHOD_set_prompt_constructor;
  UI_METHOD_set_ex_data: TUI_METHOD_set_ex_data;
  UI_METHOD_get_ex_data: TUI_METHOD_get_ex_data;
  UI_METHOD_get_opener: TUI_METHOD_get_opener;
  UI_METHOD_get_writer: TUI_METHOD_get_writer;
  UI_METHOD_get_flusher: TUI_METHOD_get_flusher;
  UI_METHOD_get_reader: TUI_METHOD_get_reader;
  UI_METHOD_get_closer: TUI_METHOD_get_closer;
  UI_METHOD_get_prompt_constructor: TUI_METHOD_get_prompt_constructor;
  UI_METHOD_get_data_duplicator: TUI_METHOD_get_data_duplicator;
  UI_METHOD_get_data_destructor: TUI_METHOD_get_data_destructor;
  
  // UI_STRING 函数
  UI_get_string_type: TUI_get_string_type;
  UI_get_input_flags: TUI_get_input_flags;
  UI_get0_output_string: TUI_get0_output_string;
  UI_get0_action_string: TUI_get0_action_string;
  UI_get0_result_string_str: TUI_get0_result_string_str;  // Renamed variable
  UI_get0_test_string: TUI_get0_test_string;
  UI_get_result_min_size: TUI_get_result_min_size;
  UI_get_result_max_size: TUI_get_result_max_size;
  UI_set_result: TUI_set_result;
  UI_set_result_ex: TUI_set_result_ex;
  
  // UI 实用函数
  UI_UTIL_read_pw_string: TUI_UTIL_read_pw_string;
  UI_UTIL_read_pw: TUI_UTIL_read_pw;
  UI_UTIL_wrap_read_pem_callback: TUI_UTIL_wrap_read_pem_callback;

procedure LoadUIFunctions;
procedure UnloadUIFunctions;

// 辅助函数
function CreateSimplePasswordUI(const Prompt: string): PUI_METHOD;
function ReadPasswordWithUI(const Prompt: string; MinLen: Integer = 0; MaxLen: Integer = 256): string;
function CreateConsoleUI: PUI_METHOD;

implementation

uses
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader;

var
  SimplePasswordUIMethod: PUI_METHOD = nil;
  ConsoleUIMethod: PUI_METHOD = nil;

procedure LoadUIFunctions;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then Exit;
  
  // UI 基本函数
  UI_new := TUI_new(GetCryptoProcAddress('UI_new'));
  UI_new_method := TUI_new_method(GetCryptoProcAddress('UI_new_method'));
  UI_free := TUI_free(GetCryptoProcAddress('UI_free'));
  UI_add_input_string := TUI_add_input_string(GetCryptoProcAddress('UI_add_input_string'));
  UI_dup_input_string := TUI_dup_input_string(GetCryptoProcAddress('UI_dup_input_string'));
  UI_add_verify_string := TUI_add_verify_string(GetCryptoProcAddress('UI_add_verify_string'));
  UI_dup_verify_string := TUI_dup_verify_string(GetCryptoProcAddress('UI_dup_verify_string'));
  UI_add_input_boolean := TUI_add_input_boolean(GetCryptoProcAddress('UI_add_input_boolean'));
  UI_dup_input_boolean := TUI_dup_input_boolean(GetCryptoProcAddress('UI_dup_input_boolean'));
  UI_add_info_string := TUI_add_info_string(GetCryptoProcAddress('UI_add_info_string'));
  UI_dup_info_string := TUI_dup_info_string(GetCryptoProcAddress('UI_dup_info_string'));
  UI_add_error_string := TUI_add_error_string(GetCryptoProcAddress('UI_add_error_string'));
  UI_dup_error_string := TUI_dup_error_string(GetCryptoProcAddress('UI_dup_error_string'));
  
  // UI 构造函数
  UI_construct_prompt := TUI_construct_prompt(GetCryptoProcAddress('UI_construct_prompt'));
  
  // UI 用户数据函数
  UI_add_user_data := TUI_add_user_data(GetCryptoProcAddress('UI_add_user_data'));
  UI_dup_user_data := TUI_dup_user_data(GetCryptoProcAddress('UI_dup_user_data'));
  UI_get0_user_data := TUI_get0_user_data(GetCryptoProcAddress('UI_get0_user_data'));
  
  // UI 结果函数
  UI_get0_result := TUI_get0_result(GetCryptoProcAddress('UI_get0_result'));
  UI_get_result_length := TUI_get_result_length(GetCryptoProcAddress('UI_get_result_length'));
  UI_get0_result_string := TUI_get0_result_string(GetCryptoProcAddress('UI_get0_result_string'));
  UI_get_result_string_length := TUI_get_result_string_length(GetCryptoProcAddress('UI_get_result_string_length'));
  
  // UI 处理函数
  UI_process := TUI_process(GetCryptoProcAddress('UI_process'));
  UI_ctrl := TUI_ctrl(GetCryptoProcAddress('UI_ctrl'));
  
  // UI 工具函数
  UI_set_ex_data := TUI_set_ex_data(GetCryptoProcAddress('UI_set_ex_data'));
  UI_get_ex_data := TUI_get_ex_data(GetCryptoProcAddress('UI_get_ex_data'));
  
  // UI_METHOD 函数
  UI_METHOD_get_default_method := TUI_METHOD_get_default_method(GetCryptoProcAddress('UI_METHOD_get_default_method'));
  UI_METHOD_get_openssl := TUI_METHOD_get_openssl(GetCryptoProcAddress('UI_METHOD_get_openssl'));
  UI_METHOD_new := TUI_METHOD_new(GetCryptoProcAddress('UI_METHOD_new'));
  UI_METHOD_free := TUI_METHOD_free(GetCryptoProcAddress('UI_METHOD_free'));
  UI_METHOD_set_opener := TUI_METHOD_set_opener(GetCryptoProcAddress('UI_METHOD_set_opener'));
  UI_METHOD_set_writer := TUI_METHOD_set_writer(GetCryptoProcAddress('UI_METHOD_set_writer'));
  UI_METHOD_set_flusher := TUI_METHOD_set_flusher(GetCryptoProcAddress('UI_METHOD_set_flusher'));
  UI_METHOD_set_reader := TUI_METHOD_set_reader(GetCryptoProcAddress('UI_METHOD_set_reader'));
  UI_METHOD_set_closer := TUI_METHOD_set_closer(GetCryptoProcAddress('UI_METHOD_set_closer'));
  UI_METHOD_set_data_duplicator := TUI_METHOD_set_data_duplicator(GetCryptoProcAddress('UI_METHOD_set_data_duplicator'));
  UI_METHOD_set_prompt_constructor := TUI_METHOD_set_prompt_constructor(GetCryptoProcAddress('UI_METHOD_set_prompt_constructor'));
  UI_METHOD_set_ex_data := TUI_METHOD_set_ex_data(GetCryptoProcAddress('UI_METHOD_set_ex_data'));
  UI_METHOD_get_ex_data := TUI_METHOD_get_ex_data(GetCryptoProcAddress('UI_METHOD_get_ex_data'));
  
  // UI_STRING 函数
  UI_get_string_type := TUI_get_string_type(GetCryptoProcAddress('UI_get_string_type'));
  UI_get_input_flags := TUI_get_input_flags(GetCryptoProcAddress('UI_get_input_flags'));
  UI_get0_output_string := TUI_get0_output_string(GetCryptoProcAddress('UI_get0_output_string'));
  UI_get0_action_string := TUI_get0_action_string(GetCryptoProcAddress('UI_get0_action_string'));
  UI_get0_result_string_str := TUI_get0_result_string_str(GetCryptoProcAddress('UI_get0_result_string'));
  UI_get0_test_string := TUI_get0_test_string(GetCryptoProcAddress('UI_get0_test_string'));
  UI_get_result_min_size := TUI_get_result_min_size(GetCryptoProcAddress('UI_get_result_min_size'));
  UI_get_result_max_size := TUI_get_result_max_size(GetCryptoProcAddress('UI_get_result_max_size'));
  UI_set_result := TUI_set_result(GetCryptoProcAddress('UI_set_result'));
  UI_set_result_ex := TUI_set_result_ex(GetCryptoProcAddress('UI_set_result_ex'));
  
  // UI 实用函数
  UI_UTIL_read_pw_string := TUI_UTIL_read_pw_string(GetCryptoProcAddress('UI_UTIL_read_pw_string'));
  UI_UTIL_read_pw := TUI_UTIL_read_pw(GetCryptoProcAddress('UI_UTIL_read_pw'));
  UI_UTIL_wrap_read_pem_callback := TUI_UTIL_wrap_read_pem_callback(GetCryptoProcAddress('UI_UTIL_wrap_read_pem_callback'));
end;

procedure UnloadUIFunctions;
begin
  // 清理创建的 UI 方法
  if SimplePasswordUIMethod <> nil then
  begin
    if Assigned(UI_METHOD_free) then
      UI_METHOD_free(SimplePasswordUIMethod);
    SimplePasswordUIMethod := nil;
  end;
  
  if ConsoleUIMethod <> nil then
  begin
    if Assigned(UI_METHOD_free) then
      UI_METHOD_free(ConsoleUIMethod);
    ConsoleUIMethod := nil;
  end;
  
  // 重置所有函数指针
  UI_new := nil;
  UI_new_method := nil;
  UI_free := nil;
  UI_add_input_string := nil;
  UI_dup_input_string := nil;
  UI_add_verify_string := nil;
  UI_dup_verify_string := nil;
  UI_add_input_boolean := nil;
  UI_dup_input_boolean := nil;
  UI_add_info_string := nil;
  UI_dup_info_string := nil;
  UI_add_error_string := nil;
  UI_dup_error_string := nil;
  UI_process := nil;
  UI_ctrl := nil;
  UI_METHOD_get_default_method := nil;
  UI_METHOD_new := nil;
  UI_METHOD_free := nil;
  UI_UTIL_read_pw_string := nil;
end;

function SimplePasswordReader(ui: PUI; uis: PUI_STRING): Integer; cdecl;
var
  StrType: Integer;
  Input: string;
  MinSize, MaxSize: Integer;
begin
  Result := UI_OK;
  
  if not Assigned(UI_get_string_type) or not Assigned(UI_set_result) then
  begin
    Result := UI_ERR;
    Exit;
  end;
  
  StrType := UI_get_string_type(uis);
  
  case StrType of
    UIT_PROMPT, UIT_VERIFY:
    begin
      // 获取大小限制
      if Assigned(UI_get_result_min_size) and Assigned(UI_get_result_max_size) then
      begin
        MinSize := UI_get_result_min_size(uis);
        MaxSize := UI_get_result_max_size(uis);
      end
      else
      begin
        MinSize := 0;
        MaxSize := 256;
      end;
      
      // 这里简单地使用控制台输入
      // 实际应用中应该使用更安全的密码输入方法
      Write('Password: ');
      ReadLn(Input);
      
      // 检查长度
      if (Length(Input) < MinSize) or (Length(Input) > MaxSize) then
      begin
        Result := UI_ERR;
        Exit;
      end;
      
      // 设置结果
      if UI_set_result(ui, uis, PAnsiChar(AnsiString(Input))) <> 0 then
        Result := UI_ERR;
    end;
  end;
end;

function SimplePasswordWriter(ui: PUI; uis: PUI_STRING): Integer; cdecl;
var
  StrType: Integer;
  OutputStr: PAnsiChar;
begin
  Result := UI_OK;
  
  if not Assigned(UI_get_string_type) then
  begin
    Result := UI_ERR;
    Exit;
  end;
  
  StrType := UI_get_string_type(uis);
  
  case StrType of
    UIT_PROMPT, UIT_VERIFY:
    begin
      if Assigned(UI_get0_output_string) then
      begin
        OutputStr := UI_get0_output_string(uis);
        if OutputStr <> nil then
          Write(string(OutputStr));
      end;
    end;
    UIT_INFO:
    begin
      if Assigned(UI_get0_output_string) then
      begin
        OutputStr := UI_get0_output_string(uis);
        if OutputStr <> nil then
          WriteLn('Info: ' + string(OutputStr));
      end;
    end;
    UIT_ERROR:
    begin
      if Assigned(UI_get0_output_string) then
      begin
        OutputStr := UI_get0_output_string(uis);
        if OutputStr <> nil then
          WriteLn('Error: ' + string(OutputStr));
      end;
    end;
  end;
end;

function CreateSimplePasswordUI(const Prompt: string): PUI_METHOD;
begin
  if SimplePasswordUIMethod <> nil then
  begin
    Result := SimplePasswordUIMethod;
    Exit;
  end;
  
  if not Assigned(UI_METHOD_new) then
  begin
    Result := nil;
    Exit;
  end;
  
  SimplePasswordUIMethod := UI_METHOD_new();
  if SimplePasswordUIMethod = nil then
  begin
    Result := nil;
    Exit;
  end;
  
  // 设置回调函数
  if Assigned(UI_METHOD_set_writer) then
    UI_METHOD_set_writer(SimplePasswordUIMethod, @SimplePasswordWriter);
    
  if Assigned(UI_METHOD_set_reader) then
    UI_METHOD_set_reader(SimplePasswordUIMethod, @SimplePasswordReader);
  
  Result := SimplePasswordUIMethod;
end;

function ReadPasswordWithUI(const Prompt: string; MinLen: Integer; MaxLen: Integer): string;
var
  UI: PUI;
  UIMethod: PUI_METHOD;
  PromptAnsi: AnsiString;
  ResultBuf: array[0..1023] of AnsiChar;
  ResultPtr: PAnsiChar;
begin
  Result := '';
  
  if not Assigned(UI_new_method) or not Assigned(UI_add_input_string) or
    not Assigned(UI_process) or not Assigned(UI_free) then
    Exit;
  
  // 获取或创建 UI 方法
  UIMethod := CreateSimplePasswordUI(Prompt);
  if UIMethod = nil then
  begin
    // 尝试使用默认方法
    if Assigned(UI_METHOD_get_default_method) then
      UIMethod := UI_METHOD_get_default_method();
  end;
  
  if UIMethod = nil then Exit;
  
  // 创建 UI
  UI := UI_new_method(UIMethod);
  if UI = nil then Exit;
  
  try
    PromptAnsi := AnsiString(Prompt);
    FillChar(ResultBuf, SizeOf(ResultBuf), 0);
    
    // 添加输入字符串
    if UI_add_input_string(UI, PAnsiChar(PromptAnsi), UI_INPUT_FLAG_DEFAULT_PWD,
                          @ResultBuf[0], MinLen, MaxLen) <> 0 then
      Exit;
    
    // 处理 UI
    if UI_process(UI) <> 0 then
      Exit;
    
    // 获取结果
    if Assigned(UI_get0_result) then
    begin
      ResultPtr := UI_get0_result(UI, 0);
      if ResultPtr <> nil then
        Result := string(ResultPtr);
    end
    else
      Result := string(PAnsiChar(@ResultBuf[0]));
    
  finally
    UI_free(UI);
  end;
end;

function CreateConsoleUI: PUI_METHOD;
begin
  if ConsoleUIMethod <> nil then
  begin
    Result := ConsoleUIMethod;
    Exit;
  end;
  
  // 尝试获取 OpenSSL 默认的控制台 UI
  if Assigned(UI_METHOD_get_openssl) then
  begin
    ConsoleUIMethod := UI_METHOD_get_openssl();
    Result := ConsoleUIMethod;
  end
  else
  begin
    // 如果没有，创建一个简单的
    Result := CreateSimplePasswordUI('');
  end;
end;

initialization
  
finalization
  UnloadUIFunctions;
  
end.