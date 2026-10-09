# Rocky 部署指南

## 范围

Rocky Linux 9、Docker Engine 与 Compose 插件；历史实验目录 `/home/dpc/lnmp-zabbix`。以下是复现步骤，不表示已经重新执行干净环境验收。生产部署需另行审批。执行位置均为 Rocky SSH 项目目录，Windows 命令单独标注。

## 配置与启动

上传全部源码与隐藏模板，包含 docker-socket-proxy 目录，不复制其他机器的真实 .env。替换 `<PROJECT_DIR>` 后执行：

```bash
cd <PROJECT_DIR>
cp -n .env.example .env
chmod 600 .env
vi .env
sudo docker compose --env-file .env config --quiet
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
curl -fsS --max-time 10 http://127.0.0.1:8081/healthz
echo
```

设置独立密码及 Asia/Shanghai 时区。启动会构建镜像、创建容器和数据卷，消耗网络与磁盘。健康接口预期 status=ok、MySQL/Redis=true。已有数据库密码不会随 .env 修改自动改变。镜像代理的可达性、白名单和信任需自行评估。

## Windows 访问

Windows PowerShell，替换 `<HOST>` 为虚拟机 IP，保持隧道窗口打开：

```powershell
ssh -N -L 18080:127.0.0.1:8080 -L 18081:127.0.0.1:8081 -L 18443:127.0.0.1:8443 dpc@<HOST>
```

另开 PowerShell：

```powershell
Start-Process "http://127.0.0.1:18080"
Start-Process "http://127.0.0.1:18081"
```

## 监控与通知

“数据采集 → 模板”导入 zabbix/templates/template_lnmp_docker.yaml；创建主机 lnmp-docker-host，可见名称 LNMP Docker Rocky，Agent 接口 DNS=zabbix-agent2、端口10050，关联模板。“监测 → 最新数据”先选主机群组，再选主机查看指标。

宿主机另建 Rocky Linux Host，关联 Linux by Zabbix agent active；原生 Agent 安装配置见 [专项文档](Rocky-Host-Monitoring.md)。Compose 已包含回环10051映射，不重复添加。

钉钉机器人关键词设为 Zabbix；Webhook 媒介脚本使用 zabbix/media_types/dingtalk-webhook.js。参数 webhook_url 为 `{$DINGTALK_WEBHOOK}`，message 为 `{ALERT.MESSAGE}`。对应主机设置密文宏，为用户添加同一媒介，再配置问题与恢复操作。消息正文含 Zabbix 关键词及事件信息，不能固定成测试消息。仓库不包含数据库中的动作、宏、用户媒介，必须手工建立。

## HTTPS

生成自签名证书会写入文件，重启 Nginx 会短暂中断访问：

```bash
sudo bash scripts/generate-dev-cert.sh
sudo docker compose --env-file .env run --rm --no-deps nginx nginx -t
sudo docker compose --env-file .env restart nginx
curl -kfsS https://127.0.0.1:8443/healthz
```

Windows 浏览器访问 https://localhost:18443。脚本拒绝覆盖已有证书；自签名与 -k 仅用于实验。

## 运维与失败处理

手工执行 `sudo bash scripts/backup-mysql.sh` 和 `sudo bash scripts/rotate-logs.sh`；使用 `sudo gzip -t backups/mysql-*.sql.gz` 检查压缩文件。成功后脚本清理超过保留期的项目文件，备份只包含应用MySQL，不包括Zabbix数据库和完整配置。日志脚本生成快照，不轮转容器日志。隔离恢复结果见历史复盘。

cron 使用 bash 调用脚本；/etc/cron.d 文件还需要 root 用户字段、PATH 与日志目录，普通用户 crontab 不含用户字段。虚拟机关机期间普通 cron 不补跑。自动成功需实际调度日志及产物证明。

观察容器健康、healthz、最新数据及通知状态；失败先看 `sudo docker compose --env-file .env logs --tail 50 <SERVICE>`，日志分享前脱敏。配置变更前备份，失败恢复备份后只重建对应服务。停止使用 compose stop，恢复使用 compose start；均会影响服务。普通停止保留Volume，不使用 down -v 清库。数据库恢复不是配置回滚。
