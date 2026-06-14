unit nextpas.core.tui.image_cap;

{**
 * @desc 终端图像协议能力检测。
 *
 * 通过环境变量探测当前终端支持的图像协议：Kitty graphics protocol、
 * Sixel、或回退到半块字符（half-block）。供 buffer 的图像占位与
 * 后端图像渲染选择编码方式。
 *
 * @note 仅做检测，不做渲染。检测基于 TERM / TERM_PROGRAM /
 *       TERM_FEATURES / KITTY_WINDOW_ID 等环境变量启发式判断。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

type
  TImageProtocol = (ipAuto, ipKitty, ipSixel, ipHalfBlock);

function DetectImageProtocolFromHints(const ATerm, ATermProgram,
  ATermFeatures, AKittyWindowId: AnsiString): TImageProtocol;

{**
 * @desc 检测当前终端的图像协议能力。
 * @return ipKitty / ipSixel / ipHalfBlock（无法确定时回退 half-block）
 *}
function DetectImageProtocol: TImageProtocol;

implementation


function DetectImageProtocolFromHints(const ATerm, ATermProgram,
  ATermFeatures, AKittyWindowId: AnsiString): TImageProtocol;
begin
  { Kitty graphics protocol: kitty, WezTerm, Ghostty }
  if (Pos('kitty', ATerm) > 0) or (Pos('kitty', ATermProgram) > 0) or
     (AKittyWindowId <> '') or
     (Pos('WezTerm', ATermProgram) > 0) or (Pos('ghostty', ATermProgram) > 0) then
    Result := ipKitty

  { Sixel：显式 TERM_FEATURES，或已知支持 sixel 的终端。
    注意：不匹配泛化的 'xterm'——许多非 Sixel 终端
    (gnome-terminal, tilix) 也设 TERM=xterm-256color。 }
  else if (Pos('sixel', ATermFeatures) > 0) or
          (Pos('foot', ATerm) > 0) or (Pos('foot', ATermProgram) > 0) or
          (Pos('mlterm', ATerm) > 0) or (Pos('mlterm', ATermProgram) > 0) or
          (Pos('contour', ATermProgram) > 0) or
          (Pos('yaft', ATerm) > 0) or
          (ATermProgram = 'xterm') then
    Result := ipSixel

  else
    Result := ipHalfBlock;
end;

function DetectImageProtocol: TImageProtocol;
begin
  Result := DetectImageProtocolFromHints(
    GetEnvironmentVariable('TERM'),
    GetEnvironmentVariable('TERM_PROGRAM'),
    GetEnvironmentVariable('TERM_FEATURES'),
    GetEnvironmentVariable('KITTY_WINDOW_ID'));
end;

end.
