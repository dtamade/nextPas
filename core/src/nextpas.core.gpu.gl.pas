unit nextpas.core.gpu.gl;

{$I nextpas.core.settings.inc}

// OpenGL 3.3 Core runtime loader.
//
// Resolves all GL function pointers via glXGetProcAddress from libGL.so.1.
// Requires glx_load (nextpas.core.platform.x11) to have succeeded first
// so that glXGetProcAddress is available.
//
// glXGetProcAddress is the correct way to resolve GL extension functions;
// dlsym cannot resolve them on GLVND systems. This is the loader pattern
// recommended by Khronos and all major GPU vendors.

interface

uses
  nextpas.core.platform.x11.ffi,
  nextpas.core.gpu.gl.ffi;

const
  GL_ERR_NOT_LOADED  = -20;
  GL_ERR_LOAD_FAILED = -21;

{ Load all GL function pointers via glXGetProcAddress. Returns 0 on success.
  Requires glx_is_loaded = True. }
function gl_load: Int32;
procedure gl_unload;
function gl_is_loaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;

{ Helper: resolve a single GL function via glXGetProcAddress.
  Returns True on success, False if the symbol is not found. }
function ResolveGL(var APtr: Pointer; AName: PAnsiChar): Boolean;
begin
  APtr := glXGetProcAddress(AName);
  Result := APtr <> nil;
end;

function gl_load: Int32;
begin
  if GLoaded then
  begin
    Inc(GRefCount);
    Exit(X11_SUCCESS);
  end;

  if @glXGetProcAddress = nil then
    Exit(GL_ERR_NOT_LOADED);

  { State management }
  if not ResolveGL(Pointer(glEnable), 'glEnable') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDisable), 'glDisable') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBlendFunc), 'glBlendFunc') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glViewport), 'glViewport') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glScissor), 'glScissor') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glClear), 'glClear') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glClearColor), 'glClearColor') then
    Exit(GL_ERR_LOAD_FAILED);

  { Textures }
  if not ResolveGL(Pointer(glActiveTexture), 'glActiveTexture') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGenTextures), 'glGenTextures') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDeleteTextures), 'glDeleteTextures') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBindTexture), 'glBindTexture') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glTexImage2D), 'glTexImage2D') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glTexSubImage2D), 'glTexSubImage2D') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glTexParameteri), 'glTexParameteri') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glPixelStorei), 'glPixelStorei') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGenerateMipmap), 'glGenerateMipmap') then
    Exit(GL_ERR_LOAD_FAILED);

  { Buffers }
  if not ResolveGL(Pointer(glGenBuffers), 'glGenBuffers') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDeleteBuffers), 'glDeleteBuffers') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBindBuffer), 'glBindBuffer') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBufferData), 'glBufferData') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBufferSubData), 'glBufferSubData') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glMapBuffer), 'glMapBuffer') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUnmapBuffer), 'glUnmapBuffer') then
    Exit(GL_ERR_LOAD_FAILED);

  { VAO }
  if not ResolveGL(Pointer(glGenVertexArrays), 'glGenVertexArrays') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDeleteVertexArrays), 'glDeleteVertexArrays') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glBindVertexArray), 'glBindVertexArray') then
    Exit(GL_ERR_LOAD_FAILED);

  { Shaders }
  if not ResolveGL(Pointer(glCreateShader), 'glCreateShader') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDeleteShader), 'glDeleteShader') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glShaderSource), 'glShaderSource') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glCompileShader), 'glCompileShader') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGetShaderiv), 'glGetShaderiv') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGetShaderInfoLog), 'glGetShaderInfoLog') then
    Exit(GL_ERR_LOAD_FAILED);

  { Programs }
  if not ResolveGL(Pointer(glCreateProgram), 'glCreateProgram') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDeleteProgram), 'glDeleteProgram') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glAttachShader), 'glAttachShader') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glLinkProgram), 'glLinkProgram') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGetProgramiv), 'glGetProgramiv') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGetProgramInfoLog), 'glGetProgramInfoLog') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUseProgram), 'glUseProgram') then
    Exit(GL_ERR_LOAD_FAILED);

  { Vertex attributes }
  if not ResolveGL(Pointer(glVertexAttribPointer), 'glVertexAttribPointer') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glEnableVertexAttribArray), 'glEnableVertexAttribArray') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glDisableVertexAttribArray), 'glDisableVertexAttribArray') then
    Exit(GL_ERR_LOAD_FAILED);

  { Uniforms }
  if not ResolveGL(Pointer(glGetUniformLocation), 'glGetUniformLocation') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniform1i), 'glUniform1i') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniform1f), 'glUniform1f') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniform2f), 'glUniform2f') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniform3f), 'glUniform3f') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniform4f), 'glUniform4f') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glUniformMatrix4fv), 'glUniformMatrix4fv') then
    Exit(GL_ERR_LOAD_FAILED);

  { Draw }
  if not ResolveGL(Pointer(glDrawArrays), 'glDrawArrays') then
    Exit(GL_ERR_LOAD_FAILED);

  { Get string / errors }
  if not ResolveGL(Pointer(glGetString), 'glGetString') then
    Exit(GL_ERR_LOAD_FAILED);
  if not ResolveGL(Pointer(glGetError), 'glGetError') then
    Exit(GL_ERR_LOAD_FAILED);

  GLoaded := True;
  GRefCount := 1;
  Result := X11_SUCCESS;
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

  GLoaded := False;
end;

function gl_is_loaded: Boolean;
begin
  Result := GLoaded;
end;

end.
