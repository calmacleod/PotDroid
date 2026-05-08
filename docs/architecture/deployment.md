# Deployment

Rails is initialized with Kamal.

Before deploying:

- set production secrets for Rails credentials and `OTTAWA_OPEN311_API_KEY`
- configure persistent storage for SQLite databases and Active Storage files
- update `rails/config/deploy.yml` with hosts, image name, registry, and proxy settings
- decide whether local disk Active Storage is enough or whether to move to S3-compatible storage

Kamal commands should run from `rails/`.
