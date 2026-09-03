unit nextpas.core.identity.base;

{$I nextpas.core.settings.inc}

{** L0 身份域最小契约：wallet FK 前置依赖的单源常量。
    Owner = nextpas.core.identity（L2 能力域，identity lane）；wallet 仅消费常量，不拥有身份写入面。
    四件套 base 层，L0 单向；文本/时间零平行实现（复用 text.utils/time 单源），bytes.ops 单源。 *}

interface

const
  IDENTITY_USER_PROFILES_TABLE = 'user_profiles';
  IDENTITY_USER_PROFILES_ID_COL = 'id';
  IDENTITY_MIGRATION_VERSION = 14;

implementation

end.
