# 🐳 Docker Compose — Multi-Service Stack

A production-style Docker Compose setup built progressively across **6 challenges**, covering service orchestration, health checks, data persistence, and automatic restarts.

---

## 📁 Repository Structure

```
.
├── docker-compose.yml   # Full multi-service stack
└── verify.sh            # Automated script to verify all 4 deliverables
```

---

## 🏗️ Architecture

```
frontend  (nginx:latest)  :3000
    └── depends_on
        └── backend  (nginx:latest)  :8080
                ├── depends_on (healthy)
                │       └── database  (postgres:15)
                └── depends_on (healthy)
                        └── redis  (redis:7)
```

| Service    | Image        | Host Port | Role               |
| ---------- | ------------ | --------- | ------------------ |
| `frontend` | nginx:latest | `3000`    | UI server          |
| `backend`  | nginx:latest | `8080`    | Application server |
| `database` | postgres:15  | —         | Primary data store |
| `redis`    | redis:7      | —         | Caching layer      |

---

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/Shamiul-Lipu/building-systems-go-aws
cd docker-compose-multi-service-demo

# Start all services
docker compose up -d

# Check status
docker compose ps
```

---

## 📋 Challenge Breakdown

### Challenge 1 - Basic App

Launch `backend` on port `8080` and `frontend` on port `3000`, both using `nginx:latest`.
Frontend must start only after the backend.

```yaml
depends_on:
  - backend
```

---

### Challenge 2 - Add a Database

Add `postgres:15` with credentials passed through environment variables.

```yaml
environment:
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: apppassword
  POSTGRES_DB: appdb
```

---

### Challenge 3 - Persist the Data

Mount a **named volume** so PostgreSQL data survives `docker compose down`.

```yaml
volumes:
  postgres_data: # declared at top level

database:
  volumes:
    - postgres_data:/var/lib/postgresql/data
```

> `docker compose down` removes containers but **not** named volumes.

---

### Challenge 4 - Wait Until DB is Actually Ready

Add a `healthcheck` using `pg_isready` and make the backend wait for it.

```yaml
database:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
    interval: 5s
    retries: 10

backend:
  depends_on:
    database:
      condition: service_healthy # waits for health check, not just container start
```

---

### Challenge 5 — Redis for Caching

Add `redis:7` with a `healthcheck` using `redis-cli ping`.

```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    retries: 10
```

---

### Challenge 6 — Survive a Docker Restart

Add `restart: unless-stopped` to every service so they come back automatically after `systemctl restart docker` or a machine reboot.

```yaml
restart: unless-stopped
```

| Value                | Behaviour                                          |
| -------------------- | -------------------------------------------------- |
| `no`                 | Never restart (default)                            |
| `always`             | Always restart, including on `docker compose down` |
| `on-failure`         | Only restart on non-zero exit code                 |
| **`unless-stopped`** | ✅ Restart always **except** when manually stopped |

---

## ✅ Verifying the Deliverables

A single script verifies all 4 deliverables automatically with a live spinner and countdown.

```bash
chmod +x verify.sh
./verify.sh
```

### What it does step by step

| Step   | Deliverable            | What happens                                                  |
| ------ | ---------------------- | ------------------------------------------------------------- |
| **D1** | All 4 services running | `docker compose up -d` + animated wait + `docker compose ps`  |
| **D2** | Clean `ps` output      | Prints `docker compose ps` — screenshot this                  |
| **D3** | Data persistence       | Inserts a row → `down` → `up` → reads the row back            |
| **D4** | Auto-restart           | `systemctl restart docker` → waits → `ps` with no manual `up` |

### Spinner preview

```
  ⠹  Waiting for health checks to pass (12s left)
  ✔  Waiting for health checks to pass - done!
```

---

## 🔍 Manual Verification Commands

### All services running

```bash
docker compose ps
```

### Data persistence (Challenge 3)

```bash
# Write data
docker compose exec database psql -U appuser -d appdb \
  -c "INSERT INTO test (val) VALUES ('hello');"

# Destroy and recreate containers
docker compose down && docker compose up -d

# Read it back — must still be there
docker compose exec database psql -U appuser -d appdb \
  -c "SELECT * FROM test;"
```

### Auto-restart after daemon restart (Challenge 6)

```bash
docker compose up -d
sudo systemctl restart docker
sleep 10
docker compose ps   # all services Up — no manual start needed
```

---

## 🧠 Key Concepts

**`healthcheck`** — runs a probe command inside the container on a schedule to determine if the service is truly ready, not just running.

**`condition: service_healthy`** — a strict `depends_on` mode that holds the dependent container until the dependency's health check passes.

**Named volume** — lives outside the container lifecycle so data survives `docker compose down`.

**`restart: unless-stopped`** — the Docker daemon automatically restarts the container after any crash or host reboot, unless the user explicitly stopped it.
