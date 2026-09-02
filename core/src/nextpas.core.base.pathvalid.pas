{ 已迁移：路径校验实现已收敛至 nextpas.core.bytes.pathvalid（L1），
  复用 bytes.ops 单源与 text.utf8 UTF8IsValid 单源，inline/零拷贝。
  本桩文件保留以避免历史 git 路径断裂，实际实现见 nextpas.core.bytes.pathvalid.pas；
  违反 base 不递归四件套（不存在 base.base）且直接承担 base+门面的问题已修复。
  新代码请 uses nextpas.core.bytes.pathvalid.BytesValidPath。 }
