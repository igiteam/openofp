# What This Is

Papa-Bear = Rust-based master server for OFP/CWR

Components:
    MasterService - Core master server (HTTP API + SQLite)
    Client - Rust client lib for querying master server
    CLI - Command-line tools for server/mod management
    Archive - PBO/LZSS archive helpers

The Docker Setup

Dockerfile (multi-stage):
    rust:1-bookworm - Builds the Rust binary
    distroless/cc-debian12 - Tiny runtime image

Build:
docker build -t papa-bear/master-service:latest \
  -f docker/papa-bear-master-service/Dockerfile mserver

Run:
docker run -p 8080:8080 \
  -v ./data:/data \
  papa-bear/master-service:latest

SteamRT Build Image:
    steamrt4/sdk base
    vcpkg pre-installed
    run-build.sh entrypoint
    For compiling OFP in Steam Runtime environment

Your Server Architecture
┌──────────────────────┐
│  Game Server         │
│  (C++/Poseidon)      │
└──────────┬───────────┘
           │ Query
┌──────────▼────────────┐
│  Master Server        │
│  (Rust/Papa-Bear)     │
│  Port: 8080           │
└──────────┬────────────┘
           │
┌──────────▼────────────┐
│  SQLite Database      │
│  /data/papa-bear.db   │
└───────────────────────┘

Quick Start

# Clone + build
cd mserver
cargo build --release --manifest-path MasterService/Cargo.toml

# Run directly
./MasterService/target/release/papa-bear-master-service server \
  --listen 0.0.0.0:8080 \
  --db ./papa-bear.sqlite3

# Or via Docker
docker build -t papa-bear:latest -f docker/papa-bear-master-service/Dockerfile .
docker run -p 8080:8080 papa-bear:latest

Works with OFP server - it's the public server browser backend. 🚀