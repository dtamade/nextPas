program test_glx_gl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.x11,
  nextpas.core.platform.x11.ffi,
  nextpas.core.gpu.gl.ffi,
  nextpas.core.gpu.gl,
  nextpas.core.testing;

var
  T: TTestRunner;

{ Compile-time size assertions for GLX types. }
procedure TestGLXTypeSizes;
begin
  Check(SizeOf(TGLXContext) = SizeOf(Pointer),
    'GLXContext is pointer-sized (8 bytes on x86_64)');
  Check(SizeOf(TGLXFBConfig) = SizeOf(Pointer),
    'GLXFBConfig is pointer-sized (8 bytes on x86_64)');
  Check(SizeOf(TXVisualInfo) = 64,
    'XVisualInfo is 64 bytes (matches C XVisualInfo on x86_64)');
end;

{ Compile-time assertions for GL type sizes. }
procedure TestGLTypeSizes;
begin
  Check(SizeOf(GLenum) = 4, 'GLenum is 4 bytes');
  Check(SizeOf(GLboolean) = 1, 'GLboolean is 1 byte');
  Check(SizeOf(GLint) = 4, 'GLint is 4 bytes');
  Check(SizeOf(GLuint) = 4, 'GLuint is 4 bytes');
  Check(SizeOf(GLsizei) = 4, 'GLsizei is 4 bytes');
  Check(SizeOf(GLfloat) = 4, 'GLfloat is 4 bytes');
  Check(SizeOf(GLsizeiptr) = 8, 'GLsizeiptr is 8 bytes on x86_64');
end;

{ Verify GLX constant values match Khronos/GLX headers. }
procedure TestGLXConstants;
begin
  Check(GLX_RGBA = 4, 'GLX_RGBA = 4');
  Check(GLX_DOUBLEBUFFER = 5, 'GLX_DOUBLEBUFFER = 5');
  Check(GLX_RED_SIZE = 8, 'GLX_RED_SIZE = 8');
  Check(GLX_GREEN_SIZE = 9, 'GLX_GREEN_SIZE = 9');
  Check(GLX_BLUE_SIZE = 10, 'GLX_BLUE_SIZE = 10');
  Check(GLX_ALPHA_SIZE = 11, 'GLX_ALPHA_SIZE = 11');
  Check(GLX_DEPTH_SIZE = 12, 'GLX_DEPTH_SIZE = 12');
  Check(GLX_STENCIL_SIZE = 13, 'GLX_STENCIL_SIZE = 13');
  Check(GLX_SAMPLE_BUFFERS = $186A0, 'GLX_SAMPLE_BUFFERS = $186A0');
  Check(GLX_SAMPLES = $186A1, 'GLX_SAMPLES = $186A1');
  Check(GLX_CONTEXT_MAJOR_VERSION_ARB = $2091,
    'GLX_CONTEXT_MAJOR_VERSION_ARB = $2091');
  Check(GLX_CONTEXT_MINOR_VERSION_ARB = $2092,
    'GLX_CONTEXT_MINOR_VERSION_ARB = $2092');
  Check(GLX_CONTEXT_PROFILE_MASK_ARB = $9126,
    'GLX_CONTEXT_PROFILE_MASK_ARB = $9126');
  Check(GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 1,
    'GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 1');
  Check(GLX_CONTEXT_FLAGS_ARB = $2094,
    'GLX_CONTEXT_FLAGS_ARB = $2094');
  Check(GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 2,
    'GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 2');
  Check(GLX_RENDER_TYPE = $8011, 'GLX_RENDER_TYPE = $8011');
  Check(GLX_RGBA_BIT = 1, 'GLX_RGBA_BIT = 1');
  Check(GLX_DRAWABLE_TYPE = $8010, 'GLX_DRAWABLE_TYPE = $8010');
  Check(GLX_WINDOW_BIT = 1, 'GLX_WINDOW_BIT = 1');
  Check(GLX_TRUE_COLOR = $8002, 'GLX_TRUE_COLOR = $8002');
  Check(GLX_NONE = $8000, 'GLX_NONE = $8000');
  Check(GLX_MAX_SWAP_INTERVAL_EXT = $20F2,
    'GLX_MAX_SWAP_INTERVAL_EXT = $20F2');
end;

{ Verify GL constant values match Khronos GL/glcorearb.h. }
procedure TestGLConstants;
begin
  Check(GL_FALSE = 0, 'GL_FALSE = 0');
  Check(GL_TRUE = 1, 'GL_TRUE = 1');
  Check(GL_NO_ERROR = 0, 'GL_NO_ERROR = 0');
  Check(GL_INVALID_ENUM = $0500, 'GL_INVALID_ENUM = $0500');
  Check(GL_INVALID_VALUE = $0501, 'GL_INVALID_VALUE = $0501');
  Check(GL_INVALID_OPERATION = $0502, 'GL_INVALID_OPERATION = $0502');
  Check(GL_OUT_OF_MEMORY = $0505, 'GL_OUT_OF_MEMORY = $0505');
  Check(GL_BLEND = $0BE2, 'GL_BLEND = $0BE2');
  Check(GL_SCISSOR_TEST = $0C11, 'GL_SCISSOR_TEST = $0C11');
  Check(GL_SRC_ALPHA = $0302, 'GL_SRC_ALPHA = $0302');
  Check(GL_ONE_MINUS_SRC_ALPHA = $0303, 'GL_ONE_MINUS_SRC_ALPHA = $0303');
  Check(GL_COLOR_BUFFER_BIT = $4000, 'GL_COLOR_BUFFER_BIT = $4000');
  Check(GL_TEXTURE_2D = $0DE1, 'GL_TEXTURE_2D = $0DE1');
  Check(GL_TEXTURE_MIN_FILTER = $2800, 'GL_TEXTURE_MIN_FILTER = $2800');
  Check(GL_TEXTURE_MAG_FILTER = $2801, 'GL_TEXTURE_MAG_FILTER = $2801');
  Check(GL_TEXTURE_WRAP_S = $2802, 'GL_TEXTURE_WRAP_S = $2802');
  Check(GL_TEXTURE_WRAP_T = $2803, 'GL_TEXTURE_WRAP_T = $2803');
  Check(GL_LINEAR = $2601, 'GL_LINEAR = $2601');
  Check(GL_NEAREST = $2600, 'GL_NEAREST = $2600');
  Check(GL_CLAMP_TO_EDGE = $812F, 'GL_CLAMP_TO_EDGE = $812F');
  Check(GL_R8 = $8229, 'GL_R8 = $8229');
  Check(GL_RED = $1903, 'GL_RED = $1903');
  Check(GL_RGBA8 = $8058, 'GL_RGBA8 = $8058');
  Check(GL_RGBA = $1908, 'GL_RGBA = $1908');
  Check(GL_UNSIGNED_BYTE = $1401, 'GL_UNSIGNED_BYTE = $1401');
  Check(GL_FLOAT = $1406, 'GL_FLOAT = $1406');
  Check(GL_ARRAY_BUFFER = $8892, 'GL_ARRAY_BUFFER = $8892');
  Check(GL_STATIC_DRAW = $88E4, 'GL_STATIC_DRAW = $88E4');
  Check(GL_DYNAMIC_DRAW = $88E8, 'GL_DYNAMIC_DRAW = $88E8');
  Check(GL_STREAM_DRAW = $88E0, 'GL_STREAM_DRAW = $88E0');
  Check(GL_FRAGMENT_SHADER = $8B30, 'GL_FRAGMENT_SHADER = $8B30');
  Check(GL_VERTEX_SHADER = $8B31, 'GL_VERTEX_SHADER = $8B31');
  Check(GL_COMPILE_STATUS = $8B81, 'GL_COMPILE_STATUS = $8B81');
  Check(GL_LINK_STATUS = $8B82, 'GL_LINK_STATUS = $8B82');
  Check(GL_TRIANGLES = $0004, 'GL_TRIANGLES = $0004');
end;

{ Verify GLX not loaded by default. }
procedure TestGLXNotLoadedByDefault;
begin
  glx_unload; { Safe even if not loaded. }
  Check(not glx_is_loaded, 'GLX not loaded by default');
end;

{ Verify GL not loaded by default. }
procedure TestGLNotLoadedByDefault;
begin
  gl_unload;
  Check(not gl_is_loaded, 'GL not loaded by default');
end;

{ Load libGL.so.1 and verify all core GLX symbols resolve. }
procedure TestGLXLoad;
var
  LResult: Int32;
begin
  { Need libX11 loaded first for display operations. }
  if x11_load <> 0 then
  begin
    T.Run('TestGLXLoad [SKIP: no libX11]',
      procedure begin end);
    Exit;
  end;

  LResult := glx_load;
  if LResult <> 0 then
  begin
    T.Run('TestGLXLoad [SKIP: no libGL]',
      procedure begin end);
    x11_unload;
    Exit;
  end;
  Check(glx_is_loaded, 'GLX loaded after glx_load');

  { Core GLX symbols -- all must be resolved. }
  Check(@glXChooseFBConfig <> nil, 'glXChooseFBConfig resolved');
  Check(@glXGetVisualFromFBConfig <> nil, 'glXGetVisualFromFBConfig resolved');
  Check(@glXMakeCurrent <> nil, 'glXMakeCurrent resolved');
  Check(@glXSwapBuffers <> nil, 'glXSwapBuffers resolved');
  Check(@glXDestroyContext <> nil, 'glXDestroyContext resolved');
  Check(@glXQueryExtension <> nil, 'glXQueryExtension resolved');
  Check(@glXGetProcAddress <> nil, 'glXGetProcAddress resolved');

  { Extensions -- may or may not be present. Just verify they exist. }
  if @glXCreateContextAttribsARB <> nil then
    Check(True, 'glXCreateContextAttribsARB resolved (ARB extension)')
  else
    Check(True, 'glXCreateContextAttribsARB not available (extension absent)');

  if @glXSwapIntervalEXT <> nil then
    Check(True, 'glXSwapIntervalEXT resolved (EXT extension)')
  else
    Check(True, 'glXSwapIntervalEXT not available (extension absent)');

  glx_unload;
  Check(not glx_is_loaded, 'GLX unloaded after glx_unload');
  x11_unload;
end;

{ Load all GL function pointers and verify every one resolves. }
procedure TestGLLoad;
var
  LResult: Int32;
begin
  if x11_load <> 0 then Exit;
  if glx_load <> 0 then
  begin
    T.Run('TestGLLoad [SKIP: no libGL]',
      procedure begin end);
    x11_unload;
    Exit;
  end;

  LResult := gl_load;
  if LResult <> 0 then
  begin
    T.Run('TestGLLoad [SKIP: gl_load failed]',
      procedure begin end);
    glx_unload;
    x11_unload;
    Exit;
  end;
  Check(gl_is_loaded, 'GL loaded after gl_load');

  { State management -- 7 symbols }
  Check(@glEnable <> nil, 'glEnable resolved');
  Check(@glDisable <> nil, 'glDisable resolved');
  Check(@glBlendFunc <> nil, 'glBlendFunc resolved');
  Check(@glViewport <> nil, 'glViewport resolved');
  Check(@glScissor <> nil, 'glScissor resolved');
  Check(@glClear <> nil, 'glClear resolved');
  Check(@glClearColor <> nil, 'glClearColor resolved');

  { Textures -- 8 symbols }
  Check(@glGenTextures <> nil, 'glGenTextures resolved');
  Check(@glDeleteTextures <> nil, 'glDeleteTextures resolved');
  Check(@glBindTexture <> nil, 'glBindTexture resolved');
  Check(@glTexImage2D <> nil, 'glTexImage2D resolved');
  Check(@glTexSubImage2D <> nil, 'glTexSubImage2D resolved');
  Check(@glTexParameteri <> nil, 'glTexParameteri resolved');
  Check(@glPixelStorei <> nil, 'glPixelStorei resolved');
  Check(@glGenerateMipmap <> nil, 'glGenerateMipmap resolved');

  { Buffers -- 7 symbols }
  Check(@glGenBuffers <> nil, 'glGenBuffers resolved');
  Check(@glDeleteBuffers <> nil, 'glDeleteBuffers resolved');
  Check(@glBindBuffer <> nil, 'glBindBuffer resolved');
  Check(@glBufferData <> nil, 'glBufferData resolved');
  Check(@glBufferSubData <> nil, 'glBufferSubData resolved');
  Check(@glMapBuffer <> nil, 'glMapBuffer resolved');
  Check(@glUnmapBuffer <> nil, 'glUnmapBuffer resolved');

  { VAO -- 3 symbols }
  Check(@glGenVertexArrays <> nil, 'glGenVertexArrays resolved');
  Check(@glDeleteVertexArrays <> nil, 'glDeleteVertexArrays resolved');
  Check(@glBindVertexArray <> nil, 'glBindVertexArray resolved');

  { Shaders -- 6 symbols }
  Check(@glCreateShader <> nil, 'glCreateShader resolved');
  Check(@glDeleteShader <> nil, 'glDeleteShader resolved');
  Check(@glShaderSource <> nil, 'glShaderSource resolved');
  Check(@glCompileShader <> nil, 'glCompileShader resolved');
  Check(@glGetShaderiv <> nil, 'glGetShaderiv resolved');
  Check(@glGetShaderInfoLog <> nil, 'glGetShaderInfoLog resolved');

  { Programs -- 7 symbols }
  Check(@glCreateProgram <> nil, 'glCreateProgram resolved');
  Check(@glDeleteProgram <> nil, 'glDeleteProgram resolved');
  Check(@glAttachShader <> nil, 'glAttachShader resolved');
  Check(@glLinkProgram <> nil, 'glLinkProgram resolved');
  Check(@glGetProgramiv <> nil, 'glGetProgramiv resolved');
  Check(@glGetProgramInfoLog <> nil, 'glGetProgramInfoLog resolved');
  Check(@glUseProgram <> nil, 'glUseProgram resolved');

  { Vertex attributes -- 3 symbols }
  Check(@glVertexAttribPointer <> nil, 'glVertexAttribPointer resolved');
  Check(@glEnableVertexAttribArray <> nil,
    'glEnableVertexAttribArray resolved');
  Check(@glDisableVertexAttribArray <> nil,
    'glDisableVertexAttribArray resolved');

  { Uniforms -- 7 symbols }
  Check(@glGetUniformLocation <> nil, 'glGetUniformLocation resolved');
  Check(@glUniform1i <> nil, 'glUniform1i resolved');
  Check(@glUniform1f <> nil, 'glUniform1f resolved');
  Check(@glUniform2f <> nil, 'glUniform2f resolved');
  Check(@glUniform3f <> nil, 'glUniform3f resolved');
  Check(@glUniform4f <> nil, 'glUniform4f resolved');
  Check(@glUniformMatrix4fv <> nil, 'glUniformMatrix4fv resolved');

  { Draw -- 1 symbol }
  Check(@glDrawArrays <> nil, 'glDrawArrays resolved');

  { Get string / errors -- 2 symbols }
  Check(@glGetString <> nil, 'glGetString resolved');
  Check(@glGetError <> nil, 'glGetError resolved');

  gl_unload;
  Check(not gl_is_loaded, 'GL unloaded after gl_unload');
  glx_unload;
  x11_unload;
end;

{ Verify GLX refcounting works correctly. }
procedure TestGLXDoubleLoadIdempotent;
begin
  if x11_load <> 0 then Exit;
  if glx_load <> 0 then
  begin
    x11_unload;
    Exit;
  end;
  Check(glx_is_loaded, 'first glx_load ok');
  Check(glx_load = 0, 'second glx_load returns 0 (idempotent)');
  glx_unload;
  Check(glx_is_loaded, 'still loaded after one unload (refcount)');
  glx_unload;
  Check(not glx_is_loaded, 'fully unloaded after second unload');
  x11_unload;
end;

{ Verify GL refcounting works correctly. }
procedure TestGLDoubleLoadIdempotent;
begin
  if x11_load <> 0 then Exit;
  if glx_load <> 0 then
  begin
    x11_unload;
    Exit;
  end;
  if gl_load <> 0 then
  begin
    glx_unload;
    x11_unload;
    Exit;
  end;
  Check(gl_is_loaded, 'first gl_load ok');
  Check(gl_load = 0, 'second gl_load returns 0 (idempotent)');
  gl_unload;
  Check(gl_is_loaded, 'still loaded after one unload (refcount)');
  gl_unload;
  Check(not gl_is_loaded, 'fully unloaded after second unload');
  glx_unload;
  x11_unload;
end;

{ Verify unloading in the wrong order is safe. }
procedure TestUnloadSafeWhenNotLoaded;
begin
  gl_unload;
  gl_unload;
  Check(not gl_is_loaded, 'double gl_unload is safe');
  glx_unload;
  glx_unload;
  Check(not glx_is_loaded, 'double glx_unload is safe');
end;

{ Verify TXVisualInfo record field offsets match C. }
procedure TestXVisualInfoOffsets;
var
  LInfo: TXVisualInfo;
  LBase: Pointer;
begin
  LBase := @LInfo;
  Check(PtrUInt(@LInfo.Visual) - PtrUInt(LBase) = 0,
    'XVisualInfo.Visual at offset 0');
  Check(PtrUInt(@LInfo.VisualID) - PtrUInt(LBase) = 8,
    'XVisualInfo.VisualID at offset 8');
  Check(PtrUInt(@LInfo.Screen) - PtrUInt(LBase) = 16,
    'XVisualInfo.Screen at offset 16');
  Check(PtrUInt(@LInfo.Depth) - PtrUInt(LBase) = 20,
    'XVisualInfo.Depth at offset 20');
  Check(PtrUInt(@LInfo.CClass) - PtrUInt(LBase) = 24,
    'XVisualInfo.CClass at offset 24');
  Check(PtrUInt(@LInfo.RedMask) - PtrUInt(LBase) = 32,
    'XVisualInfo.RedMask at offset 32');
  Check(PtrUInt(@LInfo.GreenMask) - PtrUInt(LBase) = 40,
    'XVisualInfo.GreenMask at offset 40');
  Check(PtrUInt(@LInfo.BlueMask) - PtrUInt(LBase) = 48,
    'XVisualInfo.BlueMask at offset 48');
  Check(PtrUInt(@LInfo.ColormapSize) - PtrUInt(LBase) = 56,
    'XVisualInfo.ColormapSize at offset 56');
  Check(PtrUInt(@LInfo.BitsPerRGB) - PtrUInt(LBase) = 60,
    'XVisualInfo.BitsPerRGB at offset 60');
end;

begin
  T := TTestRunner.Create('test_glx_gl');

  { Type sizes }
  T.Run('GLXTypeSizes', @TestGLXTypeSizes);
  T.Run('GLTypeSizes', @TestGLTypeSizes);
  T.Run('XVisualInfoOffsets', @TestXVisualInfoOffsets);

  { Constants }
  T.Run('GLXConstants', @TestGLXConstants);
  T.Run('GLConstants', @TestGLConstants);

  { Loaders }
  T.Run('GLXNotLoadedByDefault', @TestGLXNotLoadedByDefault);
  T.Run('GLNotLoadedByDefault', @TestGLNotLoadedByDefault);
  T.Run('GLXLoad', @TestGLXLoad);
  T.Run('GLLoad', @TestGLLoad);
  T.Run('GLXDoubleLoadIdempotent', @TestGLXDoubleLoadIdempotent);
  T.Run('GLDoubleLoadIdempotent', @TestGLDoubleLoadIdempotent);
  T.Run('UnloadSafeWhenNotLoaded', @TestUnloadSafeWhenNotLoaded);

  T.Summary;
end.
