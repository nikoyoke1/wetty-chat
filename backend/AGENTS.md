# Repository Guidelines

## Project Structure & Module Organization

This repository contains three apps plus shared docs and API collections. `backend/` is the Rust API server; core modules live in `src/handlers`, `src/services`, `src/utils`, and `src/schema`, with Diesel migrations in `migrations/`. 

## Design background

- The application is designed to handle 20K users, and 200k messages a year (combined across all users). 
- Expect around 5K users in a large chat group.

## Build, Test, and Development Commands

Run backend work from `backend/`:

- `cargo run` starts the API on `http://localhost:3000`.
- `cargo build` verifies the Rust backend compiles.
- `cargo clippy` checks lint issues before review.
- `diesel migration run` applies local PostgreSQL migrations.

## Coding Style & Naming Conventions

Rust uses edition 2021 and strict lints: `unsafe_code` is forbidden and `unused_must_use` is denied. Use `cargo fmt`, `snake_case` for modules/functions, and `PascalCase` for types. 
Keep Axum handlers grouped by feature, and move database logic into services or models. 

## Database Related

- Use diesel DSL when ever possible, only fall back to raw SQL query when absolutely required
- Never manually create migration, new migration should always be generated via `diesel migration generate`
- When writing queries make sure to verify that we do not trigger a table scan of too many rows
