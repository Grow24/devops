#!/bin/bash

# Script to start PostgreSQL and Redis services using Docker Compose

# Exit on any error
set -e

# Define paths to Docker Compose files and directories
POSTGRES_COMPOSE_FILE="./postgres/compose.yml"
POSTGRES_ENV_FILE="./postgres/env.d/.env"
DATA_DIR_POSTGRES="./postgres/data"
REDIS_COMPOSE_FILE="./redis/compose.yml"
REDIS_ENV_FILE="./redis/env.d/.env"
DATA_DIR_REDIS="./redis/redis_data"
INIT_DIR="./postgres/init"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color



[ ! -f "$POSTGRES_ENV_FILE" ] && error_exit "PostgreSQL .env file ($POSTGRES_ENV_FILE) not found."
[ ! -f "$REDIS_ENV_FILE" ] && error_exit "Redis .env file ($REDIS_ENV_FILE) not found."

# Load env vars for Compose YAML interpolation
set -a
. "$POSTGRES_ENV_FILE"
. "$REDIS_ENV_FILE"
set +a


# Function to print error and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker and Docker Compose are installed
if ! command_exists docker; then
    error_exit "Docker is not installed. Please install Docker and try again."
fi
if ! command_exists docker-compose; then
    error_exit "Docker Compose is not installed. Please install Docker Compose and try again."
fi

# Check if Docker Compose files exist
if [ ! -f "$POSTGRES_COMPOSE_FILE" ]; then
    error_exit "PostgreSQL Compose file ($POSTGRES_COMPOSE_FILE) not found."
fi
if [ ! -f "$REDIS_COMPOSE_FILE" ]; then
    error_exit "Redis Compose file ($REDIS_COMPOSE_FILE) not found."
fi

# Create suite_net network if it doesn't exist
echo -e "${YELLOW}Checking for suite_net network...${NC}"
if ! docker network ls | grep -q "suite_net"; then
    echo "Creating suite_net network..."
    docker network create suite_net || error_exit "Failed to create suite_net network."
    echo -e "${GREEN}suite_net network created successfully.${NC}"
else
    echo -e "${GREEN}suite_net network already exists.${NC}"
fi

# Create and set permissions for data directories
echo -e "${YELLOW}Setting up directories...${NC}"
mkdir -p "$DATA_DIR_POSTGRES" "$DATA_DIR_REDIS" "$INIT_DIR"
sudo chown 999:999 "$DATA_DIR_POSTGRES" || error_exit "Failed to set permissions for $DATA_DIR_POSTGRES."
sudo chown 999:999 "$DATA_DIR_REDIS" || error_exit "Failed to set permissions for $DATA_DIR_REDIS."
echo -e "${GREEN}Directories set up successfully.${NC}"

# Create PostgreSQL initialization script if it doesn't exist
INIT_SQL="$INIT_DIR/init-multiple-dbs.sql"
if [ ! -f "$INIT_SQL" ]; then
    echo "Creating PostgreSQL initialization script..."
    cat > "$INIT_SQL" << EOL
CREATE DATABASE keycloak_db;
EOL
    echo -e "${GREEN}PostgreSQL initialization script created at $INIT_SQL.${NC}"
fi

# Start PostgreSQL service
echo -e "${YELLOW}Starting PostgreSQL service...${NC}"
docker-compose -f "$POSTGRES_COMPOSE_FILE" up -d || error_exit "Failed to start PostgreSQL service."

# Wait for PostgreSQL to be healthy
echo -e "${YELLOW}Waiting for PostgreSQL to be healthy...${NC}"
until docker inspect grow24_postgres --format='{{.State.Health.Status}}' | grep -q "healthy"; do
    sleep 2
    echo "PostgreSQL status: $(docker inspect grow24_postgres --format='{{.State.Health.Status}}')"
    if [ "$(docker inspect grow24_postgres --format='{{.State.Status}}')" != "running" ]; then
        error_exit "PostgreSQL container is not running. Check logs with 'docker logs grow24_postgres'."
    fi
done
echo -e "${GREEN}PostgreSQL service is healthy and running on port $(grep POSTGRES_PORT ${POSTGRES_ENV_FILE} | cut -d'=' -f2).${NC}"

# Start Redis service
echo -e "${YELLOW}Starting Redis service...${NC}"
docker-compose -f "$REDIS_COMPOSE_FILE" up -d || error_exit "Failed to start Redis service."

# Wait for Redis to be healthy
echo -e "${YELLOW}Waiting for Redis to be healthy...${NC}"
until docker inspect grow24_redis --format='{{.State.Health.Status}}' | grep -q "healthy"; do
    sleep 2
    echo "Redis status: $(docker inspect grow24_redis --format='{{.State.Health.Status}}')"
    if [ "$(docker inspect grow24_redis --format='{{.State.Status}}')" != "running" ]; then
        error_exit "Redis container is not running. Check logs with 'docker logs grow24_redis'."
    fi
done
echo -e "${GREEN}Redis service is healthy and running on port $(grep REDIS_PORT ${REDIS_ENV_FILE} | cut -d'=' -f2).${NC}"

echo -e "${GREEN}All services started successfully!${NC}"
echo "PostgreSQL logs: docker logs grow24_postgres"
echo "Redis logs: docker logs grow24_redis"