# 🔧 Setup CDC PeerDB dan PMM Monitoring 

## 🏗️ **Docker Compose

```
┌─────────────────────────────────────────────────────────────┐
                   PEERDB + PMM ECOSYSTEM                     
├─────────────────────────────────────────────────────────────┤
  🎯 PeerDB CDC (Change Data Capture)                        
  ├── catalog (PostgreSQL) → metadata storage                 
  ├── temporal → workflow engine                             
  ├── flow-api/workers → CDC processing                      
  ├── peerdb-server/ui → CDC management                      
  └── minio → object storage                                 
                                                            
  📊 PMM Monitoring Stack                                   
  ├── pgexporter → Scrape PostgreSQL metrics                 
  ├── pmm-server → Prometheus + Grafana                      
  └── pmm-client → Registers services to PMM server                  
└─────────────────────────────────────────────────────────────┘
```

**pgexporter**: Ekspor metrik PostgreSQL ke format Prometheus  
**pmm-server**: Server monitoring (Prometheus + Grafana + VictoriaMetrics)  
**pmm-client**: Client untuk mendaftarkan database ke PMM server

---
## 🚀 **Starting**

```bash
# === TAHAP 1: INFRASTRUCTURE SETUP ===
# 1. Reset semua data dan PMM account
docker compose down -v

# 2. Start 
docker compose up -d

# 3. Tunggu semua container ready
docker compose ps

# === TAHAP 2: DATABASE SCHEMA SETUP ===
# 4. Setup database schema dan sample data (WSL)
./quickstart_prepare_peers.sh

# === TAHAP 3: PMM USER SETUP ===
# 5A. Buat user PMM dengan privileges yang tepat
docker exec -it catalog psql -U postgres -c "CREATE USER pmm WITH SUPERUSER ENCRYPTED PASSWORD 'pmm_strong_password';"

# 5B. Install extension pg_stat_statements di database utama
docker exec -it catalog psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# 5C. Grant permissions untuk monitoring
docker exec -it catalog psql -U postgres -c "GRANT pg_read_all_stats TO pmm;"
docker exec -it catalog psql -U postgres -c "GRANT pg_read_all_settings TO pmm;"
docker exec -it catalog psql -U postgres -c "GRANT CONNECT ON DATABASE postgres TO pmm;"

# 5D. Buat database source dan target (jika belum ada dari quickstart_prepare_peers.sh)
docker exec -it catalog psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='source'" | grep -q 1 || docker exec -it catalog psql -U postgres -c "CREATE DATABASE source;"
docker exec -it catalog psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='target'" | grep -q 1 || docker exec -it catalog psql -U postgres -c "CREATE DATABASE target;"

# 5E. Install pg_stat_statements di setiap database
docker exec -it catalog psql -U postgres -d source -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
docker exec -it catalog psql -U postgres -d target -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# 5F. Grant akses ke database source dan target
docker exec -it catalog psql -U postgres -d source -c "GRANT CONNECT ON DATABASE source TO pmm;"
docker exec -it catalog psql -U postgres -d target -c "GRANT CONNECT ON DATABASE target TO pmm;"

# === TAHAP 4: PMM MONITORING SETUP ===
# 6A. PMM agent sudah auto-start di container startup

# 6B. Verify PMM client connection
docker exec -it pmm-client pmm-admin status

# 6C. Register PostgreSQL services ke PMM
# Untuk database postgres
docker exec -it pmm-client pmm-admin add postgresql catalog-postgres --host=catalog --port=5432 --username=pmm --password=pmm_strong_password --query-source=pgstatements --tls-skip-verify

# Untuk database source (optional)
docker exec -it pmm-client pmm-admin add postgresql source-database --host=catalog --port=5432 --username=pmm --password=pmm_strong_password --database=source --query-source=pgstatements --tls-skip-verify

# Untuk database target (optional)
docker exec -it pmm-client pmm-admin add postgresql target-database --host=catalog --port=5432 --username=pmm --password=pmm_strong_password --database=target --query-source=pgstatements --tls-skip-verify


# === TAHAP 5: CDC SETUP ===
# 7. Buat CDC di UI Peerdb (setup source → target replication)
# Akses: http://localhost:3000
echo "Setup CDC replication di PeerDB UI: http://localhost:3000"

# === TAHAP 6: MONITORING ACCESS ===
# 8. Akses PMM monitoring dashboard
# Akses: http://localhost:8080 (admin/admin)
echo "Akses PMM monitoring: http://localhost:8080"
```

## ✅ **VERIFICATION COMMANDS**

```bash
# 1. Test PMM user connections ke semua database
docker exec -it catalog psql -U pmm postgres -c "SELECT current_database(), current_user;"
docker exec -it catalog psql -U pmm source -c "SELECT current_database(), current_user;"
docker exec -it catalog psql -U pmm target -c "SELECT current_database(), current_user;"

# 2. Verify pg_stat_statements extension installed
docker exec -it catalog psql -U pmm postgres -c "SELECT * FROM pg_extension WHERE extname='pg_stat_statements';"
docker exec -it catalog psql -U pmm source -c "SELECT * FROM pg_extension WHERE extname='pg_stat_statements';"
docker exec -it catalog psql -U pmm target -c "SELECT * FROM pg_extension WHERE extname='pg_stat_statements';"

# 3. Test PMM user permissions
docker exec -it catalog psql -U pmm postgres -c "SELECT has_database_privilege('pmm', 'postgres', 'CONNECT');"
docker exec -it catalog psql -U pmm postgres -c "SELECT pg_stat_activity.* FROM pg_stat_activity LIMIT 1;"

# 4. Check PMM services registration
docker exec -it pmm-client pmm-admin list

# 5. Check container status
docker compose ps

# 6. Check PMM server accessibility
curl -s http://localhost:8080/ping
```
---

## 🌐 **PMM UI NAVIGATION**

1. **Akses**: http://localhost:8080
2. **Login**: admin / admin
3. **Add Service**: Configuration → Add Service → PostgreSQL
4. **Verifikasi**: Configuration → Inventory
5. **Dashboard**: Dashboards → PostgreSQL Overview

---

## 📋 **FORM DATA UNTUK PMM UI**

### **Database Catalog (postgres)**
```
Service name: catalog-postgres
Hostname: catalog
Port: 5432
Username: pmm
Password: pmm_strong_password
Database: postgres
Max query length: 2048
TLS: ❌ DISABLED
```

### **Database Source**
```
Service name: source-postgres
Hostname: catalog
Port: 5432
Username: pmm
Password: pmm_strong_password
Database: source
Max query length: 2048
TLS: ❌ DISABLED
```

### **Database Target**
```
Service name: target-postgres
Hostname: catalog
Port: 5432
Username: pmm
Password: pmm_strong_password
Database: target
Max query length: 2048
TLS: ❌ DISABLED
```

## 🔄 **Data Flow & Component Interactions**

```
🔁 CDC WORKFLOW (PeerDB)
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   SOURCE    │───▶│   CATALOG   │───▶│  TEMPORAL   │───▶│   TARGET   │
│ (PostgreSQL)│    │(metadata DB)│    │ (workflow)  │    │ (PostgreSQL)│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     📊 PMM MONITORING                               │
│  pgexporter ───▶ pmm-server (Prometheus) ───▶ Grafana Dashboard    │
└─────────────────────────────────────────────────────────────────────┘

🎯 COMPONENT ROLES:
• SOURCE/TARGET: Actual data databases (replication endpoints)
• CATALOG: Stores CDC metadata, configurations, and job status
• TEMPORAL: Manages workflow orchestration for CDC operations
• FLOW-API/WORKERS: Process actual data changes and replication
• PGEXPORTER: Scrapes PostgreSQL metrics (connections, queries, etc.)
• PMM-SERVER: Collects metrics and provides Grafana visualization
• PMM-CLIENT: Registers services to PMM server
```


