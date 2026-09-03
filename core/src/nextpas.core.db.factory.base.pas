unit nextpas.core.db.factory.base;

{$I nextpas.core.settings.inc}

interface

const
  DB_FACTORY_DRIVER_NAME_SQLITE = 'sqlite';
  DB_FACTORY_DRIVER_NAME_POSTGRES = 'postgres';
  DB_FACTORY_DRIVER_NAME_MYSQL = 'mysql';
  DB_FACTORY_DRIVER_NAME_ODBC = 'odbc';
  DB_FACTORY_DRIVER_NAME_REDIS = 'redis';
  DB_FACTORY_DRIVER_NAME_DM = 'dm';

type
  TDbFactoryDriverKind = (fdkBuiltin, fdkThirdParty);

implementation

end.
