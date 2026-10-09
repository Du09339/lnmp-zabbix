# LNMP + Zabbix Operations Lab

This is a personal Rocky Linux 9 operations lab. It runs Nginx, PHP-FPM, MySQL, Redis, Zabbix 7.0 LTS, a Zabbix Agent 2, and a method-restricted Docker API proxy. It is not a production high-availability architecture.

## Verified results (2026-10-09)

完整项目说明：[架构、部署、配置、检查、验证、监控、演练、失败处理、回滚与复盘](docs/Project-Summary.md)。

- Rocky host CPU, memory and filesystem collection through a native active Agent 2.
- DingTalk problem and recovery notifications; stopping PHP produced an event after approximately 38 seconds. Notification delivery latency was not measured.
- Self-signed HTTPS, application health checks, compressed MySQL backup and isolated database restore.
- Six ApacheBench runs: concurrency 5, 1000 requests per run, three runs per mode. Mean QPS: Redis 282.12 versus MySQL 194.20 (+45.3%); mean request time decreased by 31.4%. These are short, small-data, single-VM results, not production guarantees.
- Raw benchmark files are saved under [docs/benchmarks/2026-10-09](docs/benchmarks/2026-10-09/).

See the [Rocky deployment guide](docs/Rocky-Deployment.md) and [release checklist](docs/GitHub-Release-Checklist.md). Cron is configured but automatic execution has not been demonstrated. A clean-machine redeployment has not been repeated.

## Current scope

- The PHP page reads a message from MySQL and caches it in Redis for 30 seconds.
- `/healthz` checks both MySQL and Redis. Docker health checks use the same dependencies.
- Nginx serves static assets directly and sends dynamic requests to PHP-FPM.
- MySQL data, Redis data, and Zabbix PostgreSQL data use named volumes.
- The Zabbix template checks Docker availability and the running container count.
- The DingTalk webhook script is provided for manual setup in the Zabbix UI.

The Rocky host uses a separately installed native Agent 2; see [host monitoring](docs/Rocky-Host-Monitoring.md). A container Agent is not a substitute for native host metrics. The Windows instructions below are an alternative path, not the environment used for the reported results.

## Prerequisites

- Windows 10/11 with WSL 2 and Docker Desktop using the WSL 2 engine.
- At least 8 GB RAM recommended for the full stack; Zabbix and PostgreSQL need time to initialize.
- A `.env` file in this directory. The existing `.env` is intentionally not overwritten. If starting from a clean checkout, copy `.env.example` to `.env` and set unique, long passwords for MySQL root, the app user, and Zabbix PostgreSQL.

The web application and Zabbix UI bind only to the local machine: ports 8081 and 8080. MySQL, Redis, the Zabbix agent, and Docker proxy are not published to the host. The Nginx-based Docker API proxy allows only GET/HEAD requests. Zabbix Agent 2 reaches it through a dedicated shared Unix-socket volume; it does not mount the host Docker socket. A read-only bind of the host Docker socket alone does not make its API read-only; the proxy method restriction is part of this lab's isolation. Keep this as a local lab and review the socket access model before adapting it for a shared or production host.

## Start on Windows

Open PowerShell in this directory:

```powershell
.\scripts\start.ps1
```

The script checks that Docker Desktop is running, validates Compose without printing interpolated secrets, then builds and starts the stack. After containers initialize:

```powershell
.\scripts\verify.ps1
docker compose --env-file .env ps
docker compose --env-file .env logs --tail 100 php
```

Open `http://127.0.0.1:8081/` for the app and `http://127.0.0.1:8080/` for Zabbix. The app's `/healthz` should return `status: ok`. Refresh the home page twice; the Redis line should change from `MISS` to `HIT` until its 30-second cache expires.

To stop containers while keeping database/cache data:

```powershell
docker compose --env-file .env down
```

Do not add `-v` unless you intentionally want to delete all three named data volumes and everything stored in them.

## Zabbix setup

The initial Zabbix sign-in is `Admin` / `zabbix`. Change the password on first login.

1. In **Data collection → Hosts**, create a host named `lnmp-docker-host`.
2. Add an Agent interface with DNS name `zabbix-agent2`, port `10050`, and DNS connection enabled.
3. Import `zabbix/templates/template_lnmp_docker.yaml` under **Data collection → Templates**, then link it to the host.
4. Check **Monitoring → Latest data** for `Docker daemon ping`, `Docker daemon information`, and `Running Docker containers`.

The trigger expects nine running containers. Docker info counts all running containers on the daemon, not only this Compose stack; unrelated containers can mask a failure. This is not per-container service health.

### DingTalk alert setup

1. Create a DingTalk custom robot. Set a keyword such as `Zabbix` and keep its webhook URL private.
2. In Zabbix, create a **Webhook** media type and paste `zabbix/media_types/dingtalk-webhook.js` into its Script field.
3. Add parameters named `webhook_url` with value `{$DINGTALK_WEBHOOK}`, and `message` with value `{ALERT.MESSAGE}`.
4. Create the host macro `{$DINGTALK_WEBHOOK}` as **Secret text** and enter the robot URL in the Zabbix UI. Never put the URL in this repository, screenshots, or chat.
5. Add the new media type to the notification user's media, then create a trigger action that sends problem and recovery messages to that user. Set the first operation delay to five minutes or less.
6. Test alert delivery only in this local lab. A local service-stop test should be followed by restoring the service and verifying recovery.

The script sends plain-text messages. A DingTalk robot may reject a message if its configured keyword is not present in the message.

## HTTPS for local practice

From WSL in the project directory, run:

```bash
bash scripts/generate-dev-cert.sh
docker compose --env-file .env restart nginx
```

Then use `https://localhost:8443/`. The certificate is self-signed, so the browser warning is expected. Do not use this certificate for a real domain or production traffic. The generation script refuses to overwrite existing certificate files.

## Backup and logs

The shell scripts run from WSL (with Docker Desktop WSL integration enabled) or a Linux Docker host:

```bash
bash scripts/backup-mysql.sh
gzip -t backups/mysql-<TIMESTAMP>.sql.gz
bash scripts/rotate-logs.sh
```

The backup script keeps the newest seven days and removes older project backup files after a successful dump. The log script writes a daily Compose log snapshot and removes snapshots older than fourteen days. Logs may contain sensitive application output; review and redact before sharing. Use a private directory and do not commit backup/log files.

For a Linux host, example cron entries are:

```cron
0 2 * * * /bin/bash /path/to/lnmp-zabbix/scripts/backup-mysql.sh
0 0 * * * /bin/bash /path/to/lnmp-zabbix/scripts/rotate-logs.sh
```

On Windows, do not assume that a WSL shell or its cron daemon runs while the laptop is asleep or logged out. For reliable local scheduling, use Windows Task Scheduler to run `wsl.exe -d <DISTRO> -- bash /mnt/e/Documents/Docker/lnmp-zabbix/scripts/backup-mysql.sh` and the corresponding log script. Confirm the actual WSL distribution name with `wsl --list --quiet`.

## Troubleshooting

```powershell
docker compose --env-file .env ps
docker compose --env-file .env logs --tail 100 mysql
docker compose --env-file .env logs --tail 100 php
docker compose --env-file .env logs --tail 100 zabbix-server
```

Do not paste raw `.env` contents or unredacted logs into chat. If configuration changes do not take effect, inspect the specific service logs first. MySQL initialization SQL only runs when its data directory is first created; the `mysql_data` volume preserves existing contents across normal restarts.
