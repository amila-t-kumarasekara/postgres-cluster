package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	// Load .env file
	envVars, err := loadEnvFile(".env")
	if err != nil {
		fmt.Printf("Error loading .env file: %v\n", err)
		os.Exit(1)
	}

	// Set default values for optional variables
	if _, exists := envVars["PG_HBA_AUTH_METHOD"]; !exists {
		envVars["PG_HBA_AUTH_METHOD"] = "scram-sha-256"
	}
	if _, exists := envVars["LOCAL_AUTH_METHOD"]; !exists {
		envVars["LOCAL_AUTH_METHOD"] = "trust"
	}

	// Create directories if they don't exist
	dirs := []string{
		"./master/config",
		"./slave-1/config",
		"./slave-2/config",
	}

	for _, dir := range dirs {
		err := os.MkdirAll(dir, 0755)
		if err != nil {
			fmt.Printf("Error creating directory %s: %v\n", dir, err)
			os.Exit(1)
		}
	}

	// Generate init.sql
	initSql := fmt.Sprintf(`-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add timescale extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Add vectorscale extension
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- Create a replication user
CREATE USER %s WITH REPLICATION PASSWORD '%s' LOGIN;

-- Grant pg_monitor to the replication user
GRANT pg_monitor TO %s;

-- Create replication slots for slaves
SELECT pg_create_physical_replication_slot('replica_slot_slave1', true);
SELECT pg_create_physical_replication_slot('replica_slot_slave2', true);

-- SELECT * FROM pg_stat_replication;
-- ALTER SYSTEM SET synchronous_standby_names TO  '*';  
`, envVars["REPLICATION_USER"], envVars["REPLICATION_PASSWORD"], envVars["REPLICATION_USER"])

	// Generate pg_hba.conf
	pgHbaConf := fmt.Sprintf(`# TYPE  DATABASE        USER            ADDRESS                 METHOD

host     replication     %s         0.0.0.0/0        md5

# "local" is for Unix domain socket connections only
local   all             all                                     %s
# IPv4 local connections:
host    all             all             0.0.0.0/0            %s
# IPv6 local connections:
host    all             all             ::1/128                 %s
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     %s
host    replication     all             0.0.0.0/0          %s
host    replication     all             ::1/128                 %s

# Allow replication user to connect to all databases
host    all             %s         0.0.0.0/0        md5

# Allow all other connections
host all all all %s
`, envVars["REPLICATION_USER"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["LOCAL_AUTH_METHOD"],
		envVars["REPLICATION_USER"],
		envVars["PG_HBA_AUTH_METHOD"])

	// Generate postgresql.auto.conf for slave1
	postgresqlAutoConfSlave1 := fmt.Sprintf(`primary_conninfo = 'host=postgres-master port=5432 user=%s password=%s application_name=slave1'
primary_slot_name = 'replica_slot_slave1'
`, envVars["REPLICATION_USER"], envVars["REPLICATION_PASSWORD"])

	// Generate postgresql.auto.conf for slave2
	postgresqlAutoConfSlave2 := fmt.Sprintf(`primary_conninfo = 'host=postgres-master port=5432 user=%s password=%s application_name=slave2'
primary_slot_name = 'replica_slot_slave2'
`, envVars["REPLICATION_USER"], envVars["REPLICATION_PASSWORD"])

	// Write the files
	err = os.WriteFile("./master/config/init.sql", []byte(initSql), 0644)
	if err != nil {
		fmt.Printf("Error writing init.sql: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile("./master/config/pg_hba.conf", []byte(pgHbaConf), 0644)
	if err != nil {
		fmt.Printf("Error writing pg_hba.conf: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile("./slave-1/config/postgresql.auto.conf", []byte(postgresqlAutoConfSlave1), 0644)
	if err != nil {
		fmt.Printf("Error writing slave-1 postgresql.auto.conf: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile("./slave-2/config/postgresql.auto.conf", []byte(postgresqlAutoConfSlave2), 0644)
	if err != nil {
		fmt.Printf("Error writing slave-2 postgresql.auto.conf: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("PostgreSQL configuration files generated successfully!")
}

// loadEnvFile loads environment variables from a .env file
func loadEnvFile(filePath string) (map[string]string, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	envVars := make(map[string]string)
	lines := strings.Split(string(content), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Remove quotes if present
		if len(value) > 1 && (strings.HasPrefix(value, "\"") && strings.HasSuffix(value, "\"")) ||
			(strings.HasPrefix(value, "'") && strings.HasSuffix(value, "'")) {
			value = value[1 : len(value)-1]
		}

		envVars[key] = value
	}

	return envVars, nil
}
