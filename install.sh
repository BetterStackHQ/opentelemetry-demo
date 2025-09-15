#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="BetterStackHQ/opentelemetry-demo"
BRANCH="main"
PROJECT_NAME="opentelemetry-demo-deinstrumented"
COMPOSE_FILE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}/docker-compose.yml"
ENV_FILE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}/.env"
WORK_DIR="/tmp/${PROJECT_NAME}"

echo -e "${GREEN}OpenTelemetry Demo Installer${NC}"
echo "==============================="
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Determine Docker Compose command
DOCKER_COMPOSE=""
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo -e "${GREEN}✓${NC} Found Docker Compose (plugin)"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo -e "${GREEN}✓${NC} Found docker-compose (standalone)"
else
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Create working directory
echo -e "${YELLOW}→${NC} Creating working directory: ${WORK_DIR}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Download docker-compose.yml
echo -e "${YELLOW}→${NC} Downloading docker-compose.yml..."
if ! curl -fsSL "${COMPOSE_FILE_URL}" -o docker-compose.yml; then
    echo -e "${RED}Error: Failed to download docker-compose.yml${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Downloaded docker-compose.yml"

# Download .env file
echo -e "${YELLOW}→${NC} Downloading .env file..."
if ! curl -fsSL "${ENV_FILE_URL}" -o .env; then
    echo -e "${RED}Error: Failed to download .env file${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Downloaded .env file"

# Pull images
echo ""
echo -e "${YELLOW}→${NC} Pulling Docker images (this may take a few minutes)..."
${DOCKER_COMPOSE} -p "${PROJECT_NAME}" pull

# Start containers
echo ""
echo -e "${YELLOW}→${NC} Starting containers..."
${DOCKER_COMPOSE} -p "${PROJECT_NAME}" up -d

# Check if containers are running
echo ""
echo -e "${GREEN}✓${NC} OpenTelemetry Demo is starting!"
echo ""
echo "Services are being launched. You can check the status with:"
echo "  ${DOCKER_COMPOSE} -p ${PROJECT_NAME} ps"
echo ""
echo "To view logs:"
echo "  ${DOCKER_COMPOSE} -p ${PROJECT_NAME} logs -f"
echo ""
echo "To stop the demo:"
echo "  ${DOCKER_COMPOSE} -p ${PROJECT_NAME} down"
echo ""
echo "The demo will be available at:"
echo "  → Frontend: http://localhost:8080"
echo "  → Load Generator UI: http://localhost:8089"
echo "  → Feature Flags UI: http://localhost:4000"
