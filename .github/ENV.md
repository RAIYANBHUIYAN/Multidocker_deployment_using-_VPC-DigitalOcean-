# CI/CD environment inventory

Do not put real IPs, tokens, or private keys in this repository. Store them in GitHub
Settings → Secrets and variables, and in Vercel project settings.

## Repository variables

| Name | Example | When |
| --- | --- | --- |
| `DEPLOY_ENABLED` | `false` until droplet + secrets exist, then `true` | Required for deploy jobs |
| `STAGING_FRONTEND_URL` | `https://vpc-frontend-five.vercel.app` | Staging smoke (no custom domain) |

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
| `VERCEL_TOKEN` | Create at https://vercel.com/account/tokens (set an expiry) |
| `VERCEL_ORG_ID` | `team_E0lHI9iCGea4htzuOCBfetur` (project `vpc-frontend`) |
| `VERCEL_PROJECT_ID` | `prj_wtUFUOFDBBMcVHBVqW6JdW94iqDj` |

## Environment `production` (deployment branch: `production` only)

Same secret names as staging. Use private key `~\.ssh\vpc_ci_production` for `DEPLOY_SSH_KEY`.
`DROPLET_HOST` and `DROPLET_KNOWN_HOSTS` are the same droplet. Vercel IDs/token can match staging.

## Vercel project (not GitHub)

Project created: **vpc-frontend** (no GitHub connection — CI deploys with the CLI).

Dashboard: https://vercel.com/raiyanbhuiyans-projects/vpc-frontend

| Name | Production | Preview / staging | Development |
| --- | --- | --- | --- |
| `API_URL` | replace after droplet: `http://DROPLET_IP` | replace after droplet: `http://DROPLET_IP:8080` | `http://127.0.0.1:3001` (set) |

No `NEXT_PUBLIC_` prefix.

Protection Bypass for Automation is enabled for GitHub Actions. Put the secret value in the GitHub repository secret `VERCEL_AUTOMATION_BYPASS_SECRET` (do not commit it).

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
