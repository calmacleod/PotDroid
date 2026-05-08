# ADR 0001: Monorepo Shape

## Decision

Use a parent monorepo with sibling `android/` and `rails/` applications plus shared `docs/architecture/`, `scripts/`, and `AGENTS.md`.

## Why

The Android app and Rails API need to evolve together, especially the multipart upload contract and developer workflow for physical-device testing. Keeping both apps under one parent makes local orchestration, contract documentation, and cross-app testing straightforward.

## Consequences

- Parent scripts own the common workflow.
- App-specific build tooling remains inside each child app.
- Agents must avoid changing one side of the upload contract without updating the other.
