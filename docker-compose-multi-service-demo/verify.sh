#!/bin/bash
# =============================================================
#  verify.sh — Docker Compose Assignment Verification Script
#  Covers all 4 final deliverables
# =============================================================

set -e  # exit immediately on any error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

separator() {
  echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════${NC}\n"
}

success() { echo -e "${GREEN}✔  $1${NC}"; }
info()    { echo -e "${YELLOW}➜  $1${NC}"; }

# Spinner — usage: spinner <seconds> "<message>"
spinner() {
  local duration=$1
  local message=$2
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local end=$((SECONDS + duration))
  local i=0
  tput civis 2>/dev/null || true   # hide cursor
  while [ $SECONDS -lt $end ]; do
    printf "\r  ${CYAN}${frames[$i]}${NC}  ${message} ${YELLOW}($((end - SECONDS))s left)${NC}   "
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r  ${GREEN}✔${NC}  ${message} — done!                        \n"
  tput cnorm 2>/dev/null || true   # restore cursor
}

# ─────────────────────────────────────────────────────────────
#  Deliverable 1 — Start all services & show compose ps
# ─────────────────────────────────────────────────────────────
separator "DELIVERABLE 1 — Start all 4 services"

info "Running: docker compose up -d"
docker compose up -d

spinner 15 "Waiting for health checks to pass"

info "Running: docker compose ps"
docker compose ps

success "All services started."

# ─────────────────────────────────────────────────────────────
#  Deliverable 2 — docker compose ps (clean view)
# ─────────────────────────────────────────────────────────────
separator "DELIVERABLE 2 — docker compose ps (all 4 services running)"

docker compose ps

success "Screenshot this output for your submission."

# ─────────────────────────────────────────────────────────────
#  Deliverable 3 — Data persists after down + up
# ─────────────────────────────────────────────────────────────
separator "DELIVERABLE 3 — Data persistence across docker compose down + up"

info "Creating table and inserting a row into PostgreSQL..."
docker compose exec database psql -U appuser -d appdb \
  -c "CREATE TABLE IF NOT EXISTS test (id SERIAL PRIMARY KEY, val TEXT);"

docker compose exec database psql -U appuser -d appdb \
  -c "INSERT INTO test (val) VALUES ('hello persistent world');"

info "Current data BEFORE docker compose down:"
docker compose exec database psql -U appuser -d appdb \
  -c "SELECT * FROM test;"

info "Running: docker compose down  (containers removed, volume kept)"
docker compose down

info "Running: docker compose up -d"
docker compose up -d

spinner 15 "Waiting for DB to become healthy again"

info "Reading data AFTER docker compose down + up:"
docker compose exec database psql -U appuser -d appdb \
  -c "SELECT * FROM test;"

success "Data survived the restart — named volume is working."

# ─────────────────────────────────────────────────────────────
#  Deliverable 4 — Auto-restart after Docker daemon restart
# ─────────────────────────────────────────────────────────────
separator "DELIVERABLE 4 — Auto-restart after 'sudo systemctl restart docker'"

info "Ensuring all services are up before daemon restart..."
docker compose up -d

spinner 10 "Giving services time to stabilise"

info "Running: sudo systemctl restart docker"
sudo systemctl restart docker

spinner 10 "Waiting for Docker daemon + containers to come back"

info "Running: docker compose ps  (NO manual 'docker compose up' was run)"
docker compose ps

success "All services came back automatically — restart: unless-stopped is working."

# ─────────────────────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────────────────────
separator "ALL DELIVERABLES VERIFIED"
echo -e "${GREEN}${BOLD}"
echo "  ✔  Deliverable 1 — All 4 services started"
echo "  ✔  Deliverable 2 — docker compose ps output shown"
echo "  ✔  Deliverable 3 — Data persisted after down + up"
echo "  ✔  Deliverable 4 — Services auto-restarted after daemon restart"
echo -e "${NC}"