unit nextpas.core.gpu.gl.ffi;

{$I nextpas.core.settings.inc}

// OpenGL 3.3 Core Profile FFI declarations.
//
// Types, constants, and typed function pointer globals for the GL 3.3 core
// subset needed by the cell renderer. Zero implementation logic -- the
// companion unit nextpas.core.gpu.gl handles loading via glXGetProcAddress.
//
// All symbols use the GL 3.3 core profile. No legacy/compat functions.
// Constants match the Khronos GL/glcorearb.h header values.

interface

type
  { GL type aliases matching Khronos typedefs }
  GLenum     = type UInt32;
  GLboolean  = type Byte;
  GLbitfield = type UInt32;
  GLint      = type Int32;
  GLuint     = type UInt32;
  GLsizei    = type Int32;
  GLfloat    = type Single;
  GLchar     = type AnsiChar;
  GLsizeiptr = type Int64;      { C ptrdiff_t on x86_64 }
  GLintptr   = type Int64;      { C ptrdiff_t on x86_64 }

  { Pointer types }
  PGLchar = ^GLchar;
  PPGLchar = ^PGLchar;
  PGLint = ^GLint;
  PGLuint = ^GLuint;
  PGLfloat = ^GLfloat;
  PGLsizei = ^GLsizei;

const
  { Boolean }
  GL_FALSE = 0;
  GL_TRUE  = 1;

  { Errors }
  GL_NO_ERROR          = 0;
  GL_INVALID_ENUM      = $0500;
  GL_INVALID_VALUE     = $0501;
  GL_INVALID_OPERATION = $0502;
  GL_OUT_OF_MEMORY     = $0505;

  { EnableCap }
  GL_BLEND        = $0BE2;
  GL_SCISSOR_TEST = $0C11;
  GL_DEPTH_TEST   = $0B71;
  GL_CULL_FACE    = $0B44;

  { BlendFunc }
  GL_SRC_ALPHA           = $0302;
  GL_ONE_MINUS_SRC_ALPHA = $0303;
  GL_ONE                 = 1;

  { ClearBufferMask }
  GL_COLOR_BUFFER_BIT   = $00004000;
  GL_DEPTH_BUFFER_BIT   = $00000100;
  GL_STENCIL_BUFFER_BIT = $00000400;

  { Texture targets }
  GL_TEXTURE_2D = $0DE1;

  { Texture parameters }
  GL_TEXTURE_MIN_FILTER = $2800;
  GL_TEXTURE_MAG_FILTER = $2801;
  GL_TEXTURE_WRAP_S     = $2802;
  GL_TEXTURE_WRAP_T     = $2803;
  GL_LINEAR             = $2601;
  GL_NEAREST            = $2600;
  GL_CLAMP_TO_EDGE      = $812F;

  { Texture units }
  GL_TEXTURE0 = $84C0;

  { PixelStore }
  GL_UNPACK_ALIGNMENT  = $0CF5;
  GL_UNPACK_ROW_LENGTH = $0CF2;
  GL_PACK_ALIGNMENT    = $0D05;

  { Internal formats }
  GL_R8           = $8229;
  GL_RED          = $1903;
  GL_RGBA8        = $8058;
  GL_RGBA         = $1908;
  GL_BGRA         = $80E1;
  GL_UNSIGNED_BYTE = $1401;

  { Buffer targets }
  GL_ARRAY_BUFFER         = $8892;
  GL_ELEMENT_ARRAY_BUFFER = $8893;

  { Buffer usage }
  GL_STREAM_DRAW  = $88E0;
  GL_STREAM_READ  = $88E1;
  GL_STATIC_DRAW  = $88E4;
  GL_DYNAMIC_DRAW = $88E8;

  { Buffer access }
  GL_READ_ONLY  = $88B8;
  GL_WRITE_ONLY = $88B9;
  GL_READ_WRITE = $88BA;

  { Shader types }
  GL_FRAGMENT_SHADER = $8B30;
  GL_VERTEX_SHADER   = $8B31;

  { Shader parameters }
  GL_COMPILE_STATUS = $8B81;
  GL_LINK_STATUS    = $8B82;
  GL_INFO_LOG_LENGTH = $8B84;

  { Data types for glVertexAttribPointer }
  GL_BYTE           = $1400;
  { GL_UNSIGNED_BYTE already defined above ($1401) }
  GL_SHORT          = $1402;
  GL_UNSIGNED_SHORT = $1403;
  GL_INT            = $1404;
  GL_UNSIGNED_INT   = $1405;
  GL_FLOAT          = $1406;

  { Primitive types }
  GL_TRIANGLES      = $0004;
  GL_TRIANGLE_STRIP = $0005;
  GL_TRIANGLE_FAN   = $0006;

  { GetString targets }
  GL_VENDOR   = $1F00;
  GL_RENDERER = $1F01;
  GL_VERSION  = $1F02;

  { NULL pointer constant }
  GL_NONE = 0;

type
  { --- GL function pointer types --- }

  { State management }
  TglEnable = procedure(ACap: GLenum); cdecl;
  TglDisable = procedure(ACap: GLenum); cdecl;
  TglBlendFunc = procedure(ASFactor, ADFactor: GLenum); cdecl;
  TglViewport = procedure(AX, AY: GLint; AWidth, AHeight: GLsizei); cdecl;
  TglScissor = procedure(AX, AY: GLint; AWidth, AHeight: GLsizei); cdecl;
  TglClear = procedure(AMask: GLbitfield); cdecl;
  TglClearColor = procedure(AR, AG, AB, AA: GLfloat); cdecl;

  { Textures }
  TglActiveTexture = procedure(ATexture: GLenum); cdecl;
  TglGenTextures = procedure(AN: GLsizei; out ATextures: GLuint); cdecl;
  TglDeleteTextures = procedure(AN: GLsizei; ATextures: PGLuint); cdecl;
  TglBindTexture = procedure(ATarget: GLenum; ATexture: GLuint); cdecl;
  TglTexImage2D = procedure(ATarget: GLenum; ALevel, AInternalFormat: GLint;
    AWidth, AHeight: GLsizei; ABorder: GLint; AFormat, AType: GLenum;
    APixels: Pointer); cdecl;
  TglTexSubImage2D = procedure(ATarget: GLenum; ALevel: GLint;
    AXOffset, AYOffset: GLint; AWidth, AHeight: GLsizei;
    AFormat, AType: GLenum; APixels: Pointer); cdecl;
  TglTexParameteri = procedure(ATarget: GLenum; APName: GLenum;
    AParam: GLint); cdecl;
  TglPixelStorei = procedure(APName: GLenum; AParam: GLint); cdecl;
  TglGenerateMipmap = procedure(ATarget: GLenum); cdecl;

  { Buffers }
  TglGenBuffers = procedure(AN: GLsizei; out ABuffers: GLuint); cdecl;
  TglDeleteBuffers = procedure(AN: GLsizei; ABuffers: PGLuint); cdecl;
  TglBindBuffer = procedure(ATarget: GLenum; ABuffer: GLuint); cdecl;
  TglBufferData = procedure(ATarget: GLenum; ASize: GLsizeiptr;
    AData: Pointer; AUsage: GLenum); cdecl;
  TglBufferSubData = procedure(ATarget: GLenum; AOffset: GLintptr;
    ASize: GLsizeiptr; AData: Pointer); cdecl;
  TglMapBuffer = function(ATarget: GLenum; AAccess: GLenum): Pointer; cdecl;
  TglUnmapBuffer = function(ATarget: GLenum): GLboolean; cdecl;

  { Vertex Array Objects }
  TglGenVertexArrays = procedure(AN: GLsizei; out AArrays: GLuint); cdecl;
  TglDeleteVertexArrays = procedure(AN: GLsizei; AArrays: PGLuint); cdecl;
  TglBindVertexArray = procedure(AArray: GLuint); cdecl;

  { Shaders }
  TglCreateShader = function(AType: GLenum): GLuint; cdecl;
  TglDeleteShader = procedure(AShader: GLuint); cdecl;
  TglShaderSource = procedure(AShader: GLuint; ACount: GLsizei;
    ASource: PPGLchar; ALengths: PGLint); cdecl;
  TglCompileShader = procedure(AShader: GLuint); cdecl;
  TglGetShaderiv = procedure(AShader: GLuint; APName: GLenum;
    out AParams: GLint); cdecl;
  TglGetShaderInfoLog = procedure(AShader: GLuint; AMaxLength: GLsizei;
    out ALength: GLsizei; AInfoLog: PGLchar); cdecl;

  { Programs }
  TglCreateProgram = function: GLuint; cdecl;
  TglDeleteProgram = procedure(AProgram: GLuint); cdecl;
  TglAttachShader = procedure(AProgram, AShader: GLuint); cdecl;
  TglLinkProgram = procedure(AProgram: GLuint); cdecl;
  TglGetProgramiv = procedure(AProgram: GLuint; APName: GLenum;
    out AParams: GLint); cdecl;
  TglGetProgramInfoLog = procedure(AProgram: GLuint; AMaxLength: GLsizei;
    out ALength: GLsizei; AInfoLog: PGLchar); cdecl;
  TglUseProgram = procedure(AProgram: GLuint); cdecl;

  { Vertex attributes }
  TglVertexAttribPointer = procedure(AIndex: GLuint; ASize: GLint;
    AType: GLenum; ANormalized: GLboolean; AStride: GLsizei;
    APointer: Pointer); cdecl;
  TglEnableVertexAttribArray = procedure(AIndex: GLuint); cdecl;
  TglDisableVertexAttribArray = procedure(AIndex: GLuint); cdecl;

  { Uniforms }
  TglGetUniformLocation = function(AProgram: GLuint;
    AName: PGLchar): GLint; cdecl;
  TglUniform1i = procedure(ALocation: GLint; AV0: GLint); cdecl;
  TglUniform1f = procedure(ALocation: GLint; AV0: GLfloat); cdecl;
  TglUniform2f = procedure(ALocation: GLint; AV0, AV1: GLfloat); cdecl;
  TglUniform3f = procedure(ALocation: GLint; AV0, AV1, AV2: GLfloat); cdecl;
  TglUniform4f = procedure(ALocation: GLint;
    AV0, AV1, AV2, AV3: GLfloat); cdecl;
  TglUniformMatrix4fv = procedure(ALocation: GLint; ACount: GLsizei;
    ATranspose: GLboolean; AValue: PGLfloat); cdecl;

  { Draw }
  TglDrawArrays = procedure(AMode: GLenum; AFirst: GLint;
    ACount: GLsizei); cdecl;

  { Get string / errors }
  TglGetString = function(AName: GLenum): PAnsiChar; cdecl;
  TglGetError = function: GLenum; cdecl;

var
  { State management }
  glEnable: TglEnable;
  glDisable: TglDisable;
  glBlendFunc: TglBlendFunc;
  glViewport: TglViewport;
  glScissor: TglScissor;
  glClear: TglClear;
  glClearColor: TglClearColor;

  { Textures }
  glActiveTexture: TglActiveTexture;
  glGenTextures: TglGenTextures;
  glDeleteTextures: TglDeleteTextures;
  glBindTexture: TglBindTexture;
  glTexImage2D: TglTexImage2D;
  glTexSubImage2D: TglTexSubImage2D;
  glTexParameteri: TglTexParameteri;
  glPixelStorei: TglPixelStorei;
  glGenerateMipmap: TglGenerateMipmap;

  { Buffers }
  glGenBuffers: TglGenBuffers;
  glDeleteBuffers: TglDeleteBuffers;
  glBindBuffer: TglBindBuffer;
  glBufferData: TglBufferData;
  glBufferSubData: TglBufferSubData;
  glMapBuffer: TglMapBuffer;
  glUnmapBuffer: TglUnmapBuffer;

  { VAO }
  glGenVertexArrays: TglGenVertexArrays;
  glDeleteVertexArrays: TglDeleteVertexArrays;
  glBindVertexArray: TglBindVertexArray;

  { Shaders }
  glCreateShader: TglCreateShader;
  glDeleteShader: TglDeleteShader;
  glShaderSource: TglShaderSource;
  glCompileShader: TglCompileShader;
  glGetShaderiv: TglGetShaderiv;
  glGetShaderInfoLog: TglGetShaderInfoLog;

  { Programs }
  glCreateProgram: TglCreateProgram;
  glDeleteProgram: TglDeleteProgram;
  glAttachShader: TglAttachShader;
  glLinkProgram: TglLinkProgram;
  glGetProgramiv: TglGetProgramiv;
  glGetProgramInfoLog: TglGetProgramInfoLog;
  glUseProgram: TglUseProgram;

  { Vertex attributes }
  glVertexAttribPointer: TglVertexAttribPointer;
  glEnableVertexAttribArray: TglEnableVertexAttribArray;
  glDisableVertexAttribArray: TglDisableVertexAttribArray;

  { Uniforms }
  glGetUniformLocation: TglGetUniformLocation;
  glUniform1i: TglUniform1i;
  glUniform1f: TglUniform1f;
  glUniform2f: TglUniform2f;
  glUniform3f: TglUniform3f;
  glUniform4f: TglUniform4f;
  glUniformMatrix4fv: TglUniformMatrix4fv;

  { Draw }
  glDrawArrays: TglDrawArrays;

  { Get string / errors }
  glGetString: TglGetString;
  glGetError: TglGetError;

implementation

end.
