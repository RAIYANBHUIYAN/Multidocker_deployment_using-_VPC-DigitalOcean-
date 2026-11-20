# CI/CD environment inventory

Do not put real IPs, tokens, or private keys in this repository. Store them in GitHub
Settings → Secrets and variables, and in Vercel project settings.

## Repository variables

| Name | Example | When |
| --- | --- | --- |
| `DEPLOY_ENABLED` | `false` until droplet + secrets exist, then `true` | Required for deploy jobs |
| `STAGING_FRONTEND_URL` | `https://your-staging-alias.vercel.app` | Staging smoke + alias |

## Repository secrets

| Name | Example | When |
| --- | --- | --- |
| `STAGING_API_URL` | `http://DROPLET_IP:8080` | PR smoke into `production` |
| `VERCEL_AUTOMATION_BYPASS_SECRET` | from Vercel → Deployment Protection | Staging frontend requests from CI |

## Environment `staging` (deployment branch: `development` only)

Secrets:

| Name | Source |
| --- | --- |
| `DROPLET_HOST` | Droplet public IP |
| `DROPLET_KNOWN_HOSTS` | `ssh-keyscan -t ed25519 <ip>` |
| `DEPLOY_SSH_KEY` | Private key `~\.ssh\vpc_ci_staging` (full PEM text) |
| `VERCEL_TOKEN` | Vercel access token (with expiry) |
| `VERCEL_ORG_ID` | `frontend/.vercel/project.json` → `orgId` |
| `VERCEL_PROJECT_ID` | `frontend/.vercel/project.json` → `projectId` |

## Environment `production` (deployment branch: `production` only)

Same secret names as staging. Use private key `~\.ssh\vpc_ci_production` for `DEPLOY_SSH_KEY`.
`DROPLET_HOST` and `DROPLET_KNOWN_HOSTS` are the same droplet. Vercel IDs/token can match staging.

## Vercel project (not GitHub)

| Name | Production | Preview / staging |
| --- | --- | --- |
| `API_URL` | `http://DROPLET_IP` | `http://DROPLET_IP:8080` |

No `NEXT_PUBLIC_` prefix. Do not connect the Vercel project to the GitHub repo; CI deploys with the CLI.

## Local app env

Copy examples, never commit real `.env` files:

```text
frontend/.env.example → frontend/.env.local
backend/.env.example  → backend/.env
```

## CI SSH public keys (droplet bootstrap only)

Generated on this machine outside the repo:

- `~\.ssh\vpc_ci_staging.pub`
- `~\.ssh\vpc_ci_production.pub`

Pass those `.pub` lines into `deploy/setup-droplet.sh` as `CI_STAGING_PUBKEY` and `CI_PRODUCTION_PUBKEY`.
Never commit the private keys.
