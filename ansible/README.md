# Server deployment

Ansible playbook to deploy and secure a fresh Ubuntu 25.04 server.

## What it does

- Creates a `psalmo` service account that owns all app files and runs Docker
- Hardens SSH (no root login, restricted to `ubuntu` user)
- Firewall (UFW) — only ports 22, 80, 443 open
- fail2ban — auto-bans repeated SSH and Nginx auth failures
- Unattended security upgrades
- Docker CE + Compose plugin
- Deploys the app via Docker Compose (Rails + Sidekiq + PostgreSQL + Redis)
- Nginx as reverse proxy with Action Cable WebSocket support
- Let's Encrypt TLS certificate via Certbot (auto-renewed weekly)

## Prerequisites

**On your machine:**

```bash
pip install ansible
ansible-galaxy collection install -r ansible/requirements.yml
```

**On the server:** a fresh Ubuntu 25.04 with SSH access via the `ubuntu` user.

**DNS:** your domain must resolve to the server IP before running the playbook,
otherwise the Certbot step will fail.

## First-time setup

### 1. Set the server IP

Edit `ansible/inventory.yml` and replace `YOUR_SERVER_IP_HERE`:

```yaml
ansible_host: 1.2.3.4
```

### 2. Review variables

`ansible/group_vars/all/vars.yml` contains all non-secret configuration.
The values are already set for this project — the only one you likely need to
update is `app_docker_image` once you know your GitHub org:

```yaml
app_docker_image: "ghcr.io/<your-org>/psalmo-manager:latest"
```

### 3. Create the vault

```bash
cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
```

Fill in `vault.yml` with real values:

| Variable | How to get it |
|---|---|
| `vault_rails_master_key` | Contents of `config/master.key` |
| `vault_secret_key_base` | `openssl rand -hex 64` |
| `vault_db_password` | `openssl rand -base64 32` |
| `vault_ghcr_username` | Your GitHub username |
| `vault_ghcr_token` | GitHub PAT with `read:packages` scope |

Then encrypt it:

```bash
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

You will be prompted for a vault password — keep it somewhere safe (e.g. a password manager).

### 4. Run the playbook

```bash
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --ask-vault-pass
```

The first run takes ~5 minutes. At the end the app is live at `https://psalmo.hurter.fr`.

## Subsequent deployments

Deploying a new image version is done via the GitHub Actions release workflow —
push a version tag and the image is built and pushed to GHCR automatically:

```bash
git tag v1.2.3
git push origin v1.2.3
```

To pull the new image on the server without re-running the full playbook:

```bash
ssh ubuntu@<server-ip>
sudo systemctl restart psalmo
```

The systemd service runs `docker compose up -d --pull always`, so it always
pulls the latest matching image on start.

## Re-running the playbook

The playbook is fully idempotent — safe to re-run at any time to apply
configuration changes:

```bash
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --ask-vault-pass
```

To apply only a specific section, use tags (add `tags:` to tasks you want to
target, or run with `--tags nginx`, etc.).

## Rotating secrets

1. Update the value in `vault.yml`
2. Re-encrypt: `ansible-vault encrypt ansible/group_vars/all/vault.yml`
3. Re-run the playbook — the `.env` file and docker-compose will be updated,
   and the app service restarted by the handler.

## Troubleshooting

**Check app logs:**
```bash
ssh ubuntu@<server-ip>
sudo -u psalmo docker compose -f /home/psalmo/app/docker-compose.yml logs -f
```

**Check service status:**
```bash
systemctl status psalmo
journalctl -u psalmo -n 50
```

**Check fail2ban bans:**
```bash
sudo fail2ban-client status sshd
```

**Manually renew certificate:**
```bash
sudo certbot renew --nginx
```
