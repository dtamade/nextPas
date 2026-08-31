unit nextpas.core.gpu.gl;

{$I nextpas.core.settings.inc}

// OpenGL 3.3 Core runtime loader.
//
// Resolves all GL function pointers via platform.dl abstraction.
// Opens libGL.so.1 (Linux) / opengl32.dll (Windows) with
// platform_dl_open and resolves glXGetProcAddress/wglGetProcAddress
// via platform_dl_sym. GL symbols are then resolved through that
// proc-address helper with dlsym fallback for core exports.
// No direct dependency on nextpas.core.platform.x11.

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.gpu.gl.ffi;

const
  GL_ERR_NOT_LOADED  = -20;
  GL_ERR_LOAD_FAILED = -21;

{ Load all GL function pointers via platform.dl. Returns 0 on success. }
function gl_load: Int32;
procedure gl_unload;
function gl_is_loaded: Boolean;

implementation

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;
  GGetProc: Pointer = nil;

type
  TGLGetProcAddress = function(AProcName: PAnsiChar): Pointer; cdecl;

{ Helper: resolve a single GL function via proc-address helper. }
function ResolveGL(var APtr: Pointer; AName: PAnsiChar): Boolean;
var
  F: TGLGetProcAddress;
  Tmp: Pointer;
begin
  APtr := nil;
  if GGetProc <> nil then
  begin
    F := TGLGetProcAddress(GGetProc);
    APtr := F(AName);
  end;
  if APtr = nil then
  begin
    if platform_dl_sym(GLib, AName, Tmp) = 0 then
      APtr := Tmp;
  end;
  Result := APtr <> nil;
end;

function TryOpenGLLib: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  if platform_dl_open('opengl32.dll', PLATFORM_DL_NOW, GLib) = 0 then
    Exit(True);
  Result := False;
{$ELSE}
  if platform_dl_open('libGL.so.1', PLATFORM_DL_NOW, GLib) = 0 then
    Exit(True);
  if platform_dl_open('libGL.so', PLATFORM_DL_NOW, GLib) = 0 then
    Exit(True);
  Result := False;
{$ENDIF}
end;

function gl_load: Int32;
var
  LAddr: Pointer;
  procedure FailClose;
  begin
    GGetProc := nil;
    platform_dl_close(GLib);
  end;
begin
  if GLoaded then
  begin
    Inc(GRefCount);
    Exit(0);
  end;

  if not TryOpenGLLib then
    Exit(GL_ERR_NOT_LOADED);

{$IFDEF NEXTPAS_WINDOWS}
  if platform_dl_sym(GLib, 'wglGetProcAddress', LAddr) = 0 then
    GGetProc := LAddr
  else
    GGetProc := nil;
{$ELSE}
  if platform_dl_sym(GLib, 'glXGetProcAddress', LAddr) = 0 then
    GGetProc := LAddr
  else
    GGetProc := nil;
  if (GGetProc = nil) and (platform_dl_sym(GLib, 'glXGetProcAddressARB', LAddr) = 0) then
    GGetProc := LAddr;
  if GGetProc = nil then
  begin
    platform_dl_close(GLib);
    Exit(GL_ERR_NOT_LOADED);
  end;
{$ENDIF}

  { State management }
  if not ResolveGL(Pointer(glEnable), 'glEnable') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDisable), 'glDisable') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBlendFunc), 'glBlendFunc') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glViewport), 'glViewport') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glScissor), 'glScissor') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glClear), 'glClear') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glClearColor), 'glClearColor') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Textures }
  if not ResolveGL(Pointer(glActiveTexture), 'glActiveTexture') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGenTextures), 'glGenTextures') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDeleteTextures), 'glDeleteTextures') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBindTexture), 'glBindTexture') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glTexImage2D), 'glTexImage2D') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glTexSubImage2D), 'glTexSubImage2D') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glTexParameteri), 'glTexParameteri') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glPixelStorei), 'glPixelStorei') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGenerateMipmap), 'glGenerateMipmap') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Buffers }
  if not ResolveGL(Pointer(glGenBuffers), 'glGenBuffers') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDeleteBuffers), 'glDeleteBuffers') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBindBuffer), 'glBindBuffer') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBufferData), 'glBufferData') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBufferSubData), 'glBufferSubData') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glMapBuffer), 'glMapBuffer') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUnmapBuffer), 'glUnmapBuffer') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { VAO }
  if not ResolveGL(Pointer(glGenVertexArrays), 'glGenVertexArrays') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDeleteVertexArrays), 'glDeleteVertexArrays') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glBindVertexArray), 'glBindVertexArray') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Shaders }
  if not ResolveGL(Pointer(glCreateShader), 'glCreateShader') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDeleteShader), 'glDeleteShader') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glShaderSource), 'glShaderSource') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glCompileShader), 'glCompileShader') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGetShaderiv), 'glGetShaderiv') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGetShaderInfoLog), 'glGetShaderInfoLog') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Programs }
  if not ResolveGL(Pointer(glCreateProgram), 'glCreateProgram') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDeleteProgram), 'glDeleteProgram') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glAttachShader), 'glAttachShader') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glLinkProgram), 'glLinkProgram') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGetProgramiv), 'glGetProgramiv') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGetProgramInfoLog), 'glGetProgramInfoLog') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUseProgram), 'glUseProgram') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Vertex attributes }
  if not ResolveGL(Pointer(glVertexAttribPointer), 'glVertexAttribPointer') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glEnableVertexAttribArray), 'glEnableVertexAttribArray') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glDisableVertexAttribArray), 'glDisableVertexAttribArray') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Uniforms }
  if not ResolveGL(Pointer(glGetUniformLocation), 'glGetUniformLocation') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniform1i), 'glUniform1i') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniform1f), 'glUniform1f') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniform2f), 'glUniform2f') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniform3f), 'glUniform3f') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniform4f), 'glUniform4f') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glUniformMatrix4fv), 'glUniformMatrix4fv') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Draw }
  if not ResolveGL(Pointer(glDrawArrays), 'glDrawArrays') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  { Get string / errors }
  if not ResolveGL(Pointer(glGetString), 'glGetString') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;
  if not ResolveGL(Pointer(glGetError), 'glGetError') then
    begin FailClose; Exit(GL_ERR_LOAD_FAILED); end;

  GLoaded := True;
  GRefCount := 1;
  Result := 0;
end;

procedure gl_unload;
begin
  if not GLoaded then
    Exit;
  Dec(GRefCount);
  if GRefCount > 0 then
    Exit;

  { State management }
  Pointer(glEnable) := nil;
  Pointer(glDisable) := nil;
  Pointer(glBlendFunc) := nil;
  Pointer(glViewport) := nil;
  Pointer(glScissor) := nil;
  Pointer(glClear) := nil;
  Pointer(glClearColor) := nil;

  { Textures }
  Pointer(glActiveTexture) := nil;
  Pointer(glGenTextures) := nil;
  Pointer(glDeleteTextures) := nil;
  Pointer(glBindTexture) := nil;
  Pointer(glTexImage2D) := nil;
  Pointer(glTexSubImage2D) := nil;
  Pointer(glTexParameteri) := nil;
  Pointer(glPixelStorei) := nil;
  Pointer(glGenerateMipmap) := nil;

  { Buffers }
  Pointer(glGenBuffers) := nil;
  Pointer(glDeleteBuffers) := nil;
  Pointer(glBindBuffer) := nil;
  Pointer(glBufferData) := nil;
  Pointer(glBufferSubData) := nil;
  Pointer(glMapBuffer) := nil;
  Pointer(glUnmapBuffer) := nil;

  { VAO }
  Pointer(glGenVertexArrays) := nil;
  Pointer(glDeleteVertexArrays) := nil;
  Pointer(glBindVertexArray) := nil;

  { Shaders }
  Pointer(glCreateShader) := nil;
  Pointer(glDeleteShader) := nil;
  Pointer(glShaderSource) := nil;
  Pointer(glCompileShader) := nil;
  Pointer(glGetShaderiv) := nil;
  Pointer(glGetShaderInfoLog) := nil;

  { Programs }
  Pointer(glCreateProgram) := nil;
  Pointer(glDeleteProgram) := nil;
  Pointer(glAttachShader) := nil;
  Pointer(glLinkProgram) := nil;
  Pointer(glGetProgramiv) := nil;
  Pointer(glGetProgramInfoLog) := nil;
  Pointer(glUseProgram) := nil;

  { Vertex attributes }
  Pointer(glVertexAttribPointer) := nil;
  Pointer(glEnableVertexAttribArray) := nil;
  Pointer(glDisableVertexAttribArray) := nil;

  { Uniforms }
  Pointer(glGetUniformLocation) := nil;
  Pointer(glUniform1i) := nil;
  Pointer(glUniform1f) := nil;
  Pointer(glUniform2f) := nil;
  Pointer(glUniform3f) := nil;
  Pointer(glUniform4f) := nil;
  Pointer(glUniformMatrix4fv) := nil;

  { Draw }
  Pointer(glDrawArrays) := nil;

  { Get string / errors }
  Pointer(glGetString) := nil;
  Pointer(glGetError) := nil;

  GGetProc := nil;
  platform_dl_close(GLib);
  GLoaded := False;
end;

function gl_is_loaded: Boolean;
begin
  Result := GLoaded;
end;

end.
