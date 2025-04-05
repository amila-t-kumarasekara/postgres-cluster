import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// Load environment variables from .env file
dotenv.config();

const {
  POSTGRES_USER,
  POSTGRES_PASSWORD,
  POSTGRES_DB,
  REPLICATION_USER,
  REPLICATION_PASSWORD,
  PG_HBA_AUTH_METHOD = 'scram-sha-256', // Default to scram-sha-256 if not set
  LOCAL_AUTH_METHOD = 'trust',          // Default to trust for local connections
  REPLICATION_COUNT,
} = process.env;

// Create directories if they don't exist
const dirs = [
  './master/config',
  './slave-1/config',
  './slave-2/config'
];

dirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

let replicationSlots = '';

for (let i = 1; i <= Number(REPLICATION_COUNT ?? 2); i++) {
  replicationSlots += `SELECT pg_create_physical_replication_slot('replica_slot_slave${i}', true);`;
}
// Generate init.sql
const initSql = `-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add timescale extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Add vectorscale extension
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- -- Add pg_pgbouncer extension
-- CREATE EXTENSION IF NOT EXISTS pg_pgbouncer;   

-- Create a replication user
CREATE USER ${REPLICATION_USER} WITH REPLICATION PASSWORD '${REPLICATION_PASSWORD}' LOGIN;

-- Grant pg_monitor to the replication user
GRANT pg_monitor TO ${REPLICATION_USER};

-- Create replication slots for slaves
${replicationSlots}

-- SELECT * FROM pg_stat_replication;
-- ALTER SYSTEM SET synchronous_standby_names TO  '*';  
`;

// Generate pg_hba.conf
const pgHbaConf = `# TYPE  DATABASE        USER            ADDRESS                 METHOD

host     replication     ${REPLICATION_USER}         0.0.0.0/0        md5

# "local" is for Unix domain socket connections only
local   all             all                                     ${LOCAL_AUTH_METHOD}
# IPv4 local connections:
host    all             all             0.0.0.0/0            ${LOCAL_AUTH_METHOD}
# IPv6 local connections:
host    all             all             ::1/128                 ${LOCAL_AUTH_METHOD}
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     ${LOCAL_AUTH_METHOD}
host    replication     all             0.0.0.0/0          ${LOCAL_AUTH_METHOD}
host    replication     all             ::1/128                 ${LOCAL_AUTH_METHOD}

# Allow replication user to connect to all databases
host    all             ${REPLICATION_USER}         0.0.0.0/0        md5

# Allow all other connections
host all all all ${PG_HBA_AUTH_METHOD}
`;

for (let i = 1; i <= Number(REPLICATION_COUNT ?? 2); i++) {
  const postgresqlAutoConf = `primary_conninfo = 'host=postgres-master port=5432 user=${REPLICATION_USER} password=${REPLICATION_PASSWORD} application_name=slave${i}'
primary_slot_name = 'replica_slot_slave${i}'
`;

  fs.writeFileSync(path.join(__dirname, `slave-${i}/config/postgresql.auto.conf`), postgresqlAutoConf, 'utf8');
  
  console.log(`Writing postgresql.auto.conf for slave-${i}`);

  //copy pg_hba.conf and pg_ident.conf from slave-template to slave-${i}
  console.log(`Attempting to copy config files from slave-template to slave-${i}`);
  
  const sourcePgHba = path.join(__dirname, 'slave-template/config/pg_hba.conf');
  const destPgHba = path.join(__dirname, `slave-${i}/config/pg_hba.conf`);
  const sourcePgIdent = path.join(__dirname, 'slave-template/config/pg_ident.conf');
  const destPgIdent = path.join(__dirname, `slave-${i}/config/pg_ident.conf`);
  
  console.log(`Copying from ${sourcePgHba} to ${destPgHba}`);
  console.log(`Copying from ${sourcePgIdent} to ${destPgIdent}`);
  
  try {
    fs.copyFileSync(sourcePgHba, destPgHba);
    fs.copyFileSync(sourcePgIdent, destPgIdent);
    console.log(`Successfully copied config files for slave-${i}`);
  } catch (error) {
    console.error(`Error copying files for slave-${i}:`, error);
  }
}

// Write the files
fs.writeFileSync(path.join(__dirname, 'master/config/init.sql'), initSql, 'utf8');
fs.writeFileSync(path.join(__dirname, 'master/config/pg_hba.conf'), pgHbaConf, 'utf8');

console.log('PostgreSQL configuration files generated successfully!'); 