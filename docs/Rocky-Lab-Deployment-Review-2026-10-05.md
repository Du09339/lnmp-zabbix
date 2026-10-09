# Rocky 项目部署复盘（2026-10-05）

## 按功能查阅

本文件保留历史综合复盘。后续按大功能模块分别维护：

- [Rocky 宿主机监控](Rocky-Host-Monitoring.md)
- [Redis 性能对照测试](Redis-Performance-Test-Log.md)
- [功能记录总目录](README.md)

## 专项栏目：Redis 性能对照测试

性能测试独立记录在 [Redis 性能对照测试日志](Redis-Performance-Test-Log.md)。该日志包含前期缓存验证、测试方案、后续功能修改、压测过程、结果分析及配置恢复，不与部署和故障演练记录混写。当前处于方案准备阶段，尚未修改应用或执行压测。

## 2026-10-09：PHP 服务故障与恢复演练

- 演练前：9 个容器运行，应用 `/healthz` 返回正常，MySQL 和 Redis 检查通过。
- 10:36:05 CST：记录停止时间并执行 `docker compose stop php`，PHP 容器停止。
- 10:36:43：Zabbix 产生事件 47，运行容器数为 8，严重性 High；从停止前记录时间到事件产生约 38 秒。
- 钉钉测试群收到对应问题消息；未独立记录实际收件时刻，因此不将消息正文的事件时间当作投递时间或端到端通知耗时。
- 随后执行 `docker compose start php`，恢复具体命令时间未记录。
- 10:40:43：Zabbix 问题恢复，事件持续 4 分钟；钉钉收到恢复消息。
- 10:40:50：PHP 为 healthy，应用 `/healthz` 返回 `status=ok`、MySQL/Redis 均为 true。
- 验证结论：真实停止服务后的容器数量监测、问题通知、恢复通知和应用恢复链路通过。此模板仍为总数监控，不能单凭它识别哪个容器故障或业务健康状态。
- 截图另有默认 `Zabbix server` 主机 Agent 不可用的历史问题，需核实该主机接口与实际 Agent 配置，不能误认为本次 PHP 故障未恢复。
- cron 自动调度暂缓：虚拟机通常夜间关闭，普通 cron 不补执行错过的任务；备份/日志脚本手工验证通过，自动计划执行仍待验证。
- 下一步：核实默认主机历史告警；再准备 Redis 性能基线与对照测试，不预设提升百分比。

## 2026-10-07：定时任务与 Rocky 主机监控

### 今日目标

- 确认日志快照和 MySQL 备份脚本能够在 root/cron 环境下执行。
- 将 Rocky Linux 宿主机纳入 Zabbix，采集 CPU、内存、文件系统和系统负载等主机指标。
- 为后续故障演练准备可用的监控与告警链路。

### 已完成

1. **cron 与备份脚本验证**
   - 确认 `crond` 服务为 `active`，`/etc/cron.d/lnmp-zabbix` 配置存在且格式正常。
   - 发现 `crond` 于 10 月 7 日 22:32 才启动，因此 10 月 5 日配置的 00:00/02:00 计划时间此前已经错过，不能把旧文件误认为自动执行结果。
   - 使用与 cron 类似的 root 环境手动执行两个脚本，成功生成：
     - `backups/mysql-2026-10-07-224842.sql.gz`
     - `logs/compose-2026-10-07.log`
   - 对所有 MySQL 压缩备份执行 `gzip -t`，未发现压缩损坏。下一次计划周期后仍需检查 cron 是否自动生成新文件。

2. **安装 Rocky 主机 Zabbix Agent 2**
   - 添加 Zabbix 7.0 官方 EL9 软件源。
   - 安装 `zabbix-agent2-7.0.31-release1.el9.x86_64`。
   - 配置关键参数：

     ```text
     Server=127.0.0.1
     ServerActive=127.0.0.1:10051
     Hostname=Rocky Linux Host
     ```

   - 配置文件验证成功，`zabbix-agent2.service` 已设置为开机启动并处于 `active (running)`。

3. **打通 Agent 主动上报链路**
   - 为 Compose 中的 `zabbix-server` 增加仅监听 Rocky 本机的端口映射：

     ```yaml
     ports:
       - "127.0.0.1:10051:10051"
     ```

   - 重建 Zabbix Server 后确认 `127.0.0.1:10051` 正在监听。
   - 未向局域网开放 10051/10050，保留实验环境的最小暴露范围。

4. **主机指标采集验证**
   - 在 Zabbix 页面创建 `Rocky Linux Host`，加入 `Linux servers` 主机群组并关联 Linux Agent active 模板。
   - 最新数据中已看到 Agent 可用性、可用内存、内存百分比、CPU、文件系统和存储等指标。

### 尚未完成

- 尚未完成一次可控的服务停止/恢复故障演练；下一步停止 PHP 容器，验证问题告警和恢复告警。
- cron 已通过 root 环境等价执行验证，但需经过下一个 00:00/02:00 计划周期，确认自动生成文件及 cron 输出日志。
- 钉钉机器人配置无需为 Rocky 主机重新创建；需确认告警动作条件覆盖 `Rocky Linux Host`，而不是只匹配旧的 LNMP 主机。

### 今日结论

Rocky 宿主机监控已接入并开始采集 CPU、内存、文件系统和负载相关数据；备份与日志脚本可在 cron 使用的 root 环境中成功执行。自动调度和端到端主机故障告警仍需后续观察验证。

## 复盘摘要

今天把原先只在 Windows 项目目录中准备的 LNMP + Zabbix Compose 项目，推进到 VMware 中的 Rocky Linux 9.8 环境。完成了虚拟机资源扩容、Docker Engine 安装、镜像加速配置、项目文件传输和 Compose 配置检查，并定位修复了两个构建/启动问题。

截至本次复盘：Docker Engine 与 Compose 可用，`hello-world` 已成功运行，Compose 配置校验通过，PHP 镜像后来显示构建成功。**整套 9 个服务是否全部启动、健康检查是否通过、Web/Zabbix 页面和监控链路是否可用，仍待实测。** 不把“镜像构建成功”当作“项目已上线”。

## 实验环境

| 项目 | 当前值 |
| --- | --- |
| 虚拟化软件 | VMware Workstation，NAT 网络 |
| Rocky Linux | Rocky Linux 9.8 |
| 虚拟机地址 | `192.168.222.128` |
| 虚拟 CPU | 2 核 |
| 虚拟内存 | 6 GB（系统报告约 5.5 GiB） |
| 虚拟磁盘 | 40 GB；根 XFS/LVM 约 37 GB |
| 项目目录 | `/home/dpc/lnmp-zabbix` |
| Docker | Docker Engine 29.8.2，Compose plugin 5.6.0 |
| SELinux / firewalld | `Enforcing` / `active`，均保留启用 |

Windows 主机有 16 GB 内存。此前任务管理器显示内存使用约 79%；今天检查时 Windows 可用内存约 3.6 GB。启动全栈时继续观察主机是否开始大量换页或明显卡顿。

## 项目架构

Compose 定义 9 个服务容器：

1. Nginx：HTTP 入口和静态文件服务。
2. PHP-FPM：运行 PHP 应用。
3. MySQL：保存应用数据。
4. Redis：缓存应用读取的数据。
5. PostgreSQL：保存 Zabbix 数据。
6. Zabbix Server：监控服务端。
7. Zabbix Web：Zabbix 管理界面。
8. Zabbix Agent 2：向 Zabbix 提供 Docker 相关数据。
9. Docker API 只读代理：供 Agent 读取容器信息。

MySQL、Redis 和 PostgreSQL 使用 Docker named volumes 保存数据。Compose 当前将应用端口绑定在 Rocky 自身的 `127.0.0.1`，后续计划通过 Xshell SSH 本地端口转发从 Windows 浏览器访问，不需要开放 firewalld 入站端口。

## 处理过程与问题

### 1. 虚拟机资源不足

**现象：**最初 VM 只有 2 GB 内存、20 GB 虚拟磁盘；Rocky 根分区只有 17 GB。完整项目包含数据库与 Zabbix 多个服务，原配置余量偏小。

**处理：**VM 内存调整到 6 GB。由于虚拟机存在 VMware 快照，磁盘“扩展”按钮最初不可用；删除快照并关机后，将虚拟盘扩到 40 GB。随后在 Rocky 中执行分区、LVM 和 XFS 在线扩容：

```bash
sudo dnf install -y cloud-utils-growpart
sudo growpart /dev/nvme0n1 2
sudo pvresize /dev/nvme0n1p2
sudo lvextend -l +100%FREE /dev/mapper/rlm_192-root
sudo xfs_growfs /
```

**验证：**`lsblk` 显示磁盘 40 GB、第二分区约 39 GB、根逻辑卷约 37 GB；`df -h /` 显示约 34 GB 可用。全过程没有格式化分区。

**学习点：**扩大 VMware 虚拟盘只改变虚拟磁盘上限，不会自动扩大 Linux 分区、LVM 物理卷、逻辑卷和文件系统。XFS 可在线增长，但操作前仍要核对设备名与布局。

### 2. Docker 官方 RPM 下载失败

**现象：**Docker 官方仓库索引可访问，但从 `download.docker.com` 下载 RPM 时 TLS 连接被重置；Docker 软件包未安装。

**处理：**先确认不是 RPM 安装事务问题；在 Rocky 中测试阿里云 Docker CE 镜像仓库和目标 RPM，均返回 HTTP 200。备份原仓库配置后，通过 `dnf config-manager` 添加阿里云 Docker CE 仓库，刷新 DNF metadata，再安装 Docker CE、containerd、Buildx 和 Compose plugin。GPG 公钥正常导入，RPM 验签和事务检查通过。

**验证：**`docker version` 同时显示 Client 和 Server，`docker compose version` 显示 5.6.0。

### 3. Docker CLI 有了，但服务端未启动

**现象：**`docker version` 有 Client 信息，但提示无法连接 `/var/run/docker.sock`；`systemctl status` 显示 Docker 和 containerd 为 `inactive (dead)`，Docker 仍为 `disabled`，journal 没有启动日志。

**原因：**软件安装完成不等于 systemd 服务已经启动。第一次启动命令没有成功执行。

**处理与验证：**执行 `sudo systemctl enable --now docker` 后，`systemctl is-enabled docker` 返回 `enabled`，`systemctl is-active docker` 返回 `active`，Client/Server 信息均正常。

### 4. Docker Hub 连接失败

**现象：**`docker run --rm hello-world` 访问 Docker Hub 的 `registry-1.docker.io:443` 连接失败；Rocky 强制 IPv4 请求超时，IPv6 也无法连接。

**处理：**测试 `docker.m.daocloud.io/v2/` 返回 HTTP 401。对 Registry 来说，401 是可达后的认证挑战，不是服务离线。通过 DaoCloud 拉取带镜像前缀的 `hello-world` 成功后，在 `/etc/docker/daemon.json` 配置：

```json
{
  "registry-mirrors": ["https://docker.m.daocloud.io"]
}
```

重启 Docker 后，以普通名称 `hello-world` 再次拉取并运行成功。

**注意：**DaoCloud 对部分镜像有白名单限制；公共镜像站仅用于本地学习。生产环境应使用组织批准的镜像仓库。

### 5. Xftp 文件放错目录

**现象：**Compose 需要 `docker-socket-proxy/nginx.conf`，但 Rocky 项目根目录找不到文件。Xftp 截图显示文件实际位于 `zabbix/docker-socket-proxy/nginx.conf`，比预期多嵌套了一层。

**处理：**在 Rocky 中创建项目根目录的 `docker-socket-proxy`，将文件移动到正确位置，再移除空的错误目录。文件传输本身成功，问题是远端面板当前目录不对。

**验证：**`ls -l ~/lnmp-zabbix/docker-socket-proxy/nginx.conf` 成功列出文件。

**学习点：**Xftp 左右面板都要先核对完整路径。传单个文件时，目标目录应是项目根目录对应的子目录；不要为方便而重传整棵项目树，以免覆盖 Rocky 专用 `.env`。

### 6. Docker Socket Proxy 镜像被拒绝

**现象：**首次 `docker compose up` 成功拉取多个镜像，但 DaoCloud 拒绝 `tecnativa/docker-socket-proxy:latest`，错误说明该镜像不在白名单。该次启动停在镜像拉取阶段，`docker compose ps` 没有项目容器。

**处理：**为避免改用来源未经确认的第三方代理镜像，将代理服务改为使用已拉取的官方 `nginx:1.28-alpine`，挂载 `docker-socket-proxy/nginx.conf`，只允许 GET/HEAD 请求并拒绝其他 HTTP 方法；容器采用只读根文件系统、限制 capabilities、不发布宿主端口。Rocky 首次重建时发现只读根文件系统缺少 Nginx cache tmpfs，随后补充 `/var/cache/nginx`。又发现移除所有 capability 后 Nginx 需要 `SETGID` 初始化运行用户组，故只补回该能力。当前配置调整为 Agent 与代理共享专用 Unix-socket volume；最终 socket API 请求和权限仍待验证。

**安全说明：**把 Docker Socket 以只读方式挂载，本身并不能限制通过 Socket API 执行的操作；代理方法限制才是这套实验的额外约束。专用 socket volume 只挂载到 Agent 与代理，不发布到宿主机网络。该方案仍是本地学习配置，不能不经安全评审直接用于生产。

### 7. PHP 镜像构建失败

**现象：**完整构建日志显示 `pdo_mysql` 和 `opcache` 编译成功，随后 `pecl install redis` 报 `Cannot find autoconf`，最终 `phpize` 失败。

**原因：**PHP 官方镜像的 `docker-php-ext-install` 在该次调用结束时清理了其临时编译依赖；后续 PECL 扩展安装需要 `autoconf`，但此时已不可用。

**处理：**修改 `php/Dockerfile`，在整个扩展安装期间显式保留 `$PHPIZE_DEPS`，安装 `pdo_mysql`、`opcache` 和固定版本 `redis-6.3.0` 后再清理编译依赖。

**当前验证：**后来 Xshell 画面显示 `Image lnmp-zabbix-php Built`，因此 PHP 镜像构建已成功；但仍需 Rocky 上重新核对 Dockerfile 版本，并通过全栈启动及健康检查验证 PHP-FPM、MySQL/Redis 连接。

### 8. Zabbix 容器数量阈值

**发现：**Compose 共定义 9 个服务容器，包括 Docker API 代理。模板最初阈值不匹配；Windows 项目源和当前同步版模板已改为运行数量小于 9 时告警。README 中“八个容器”的文字也已更正。

**验证结果：**模板已在 Zabbix 7.0.31 UI 中成功导入并关联主机 `LNMP Docker Rocky`。最新数据页面显示 `Docker daemon ping=1`、`Running Docker containers=9`，Docker 信息每分钟有记录；容器数量图表过去一小时保持 9，阈值为 `<9`，当前未触发告警。

## 当前完成状态

- [x] Rocky 9.8 VM：6 GB 内存、40 GB 虚拟盘，根文件系统约 37 GB。
- [x] Docker Engine、Compose、Buildx 已安装；Docker 服务启用并运行。
- [x] Docker Registry 镜像站配置通过 `hello-world` 验证。
- [x] 项目文件已传入 `/home/dpc/lnmp-zabbix`；Rocky `.env` 从模板独立生成并限制为 owner-only 权限。
- [x] `docker compose config --quiet` 曾验证通过。
- [x] MySQL、Redis、PostgreSQL 和日志中标记为 `Pulled` 的 Zabbix 镜像已拉取；PHP 镜像后来显示构建成功。
- [x] Nginx Docker Socket 代理语法检查通过；代理与 Agent 通过共享 Unix socket 通信。
- [x] Zabbix Agent 2 Docker 插件使用 Unix-socket endpoint，`docker.ping` 返回 `1`。
- [x] 用户提供的 `docker compose ps` 输出显示 9 个服务均为 Up；MySQL、PHP、Redis、PostgreSQL、Zabbix Web 显示 healthy。
- [x] 应用 `/healthz` 返回 `status: ok`，MySQL 与 Redis 检查均为 `true`。
- [x] Windows 浏览器通过 SSH 本地端口转发访问 Zabbix 和 LNMP 首页；首页显示 MySQL 8.4、Redis 7.4 和 Redis HIT。
- [x] Zabbix Host、Agent、模板已在 UI 中配置；Agent 可用性图标变绿，Docker 信息、ping 和容器数均有采集数据。
- [x] 完整验证应用缓存 MISS→HIT 及 30 秒过期后的重新读取；缓存自然过期后页面显示 MISS，立即再次刷新显示 HIT。
- [x] HTTPS 本地练习已验证：自签名证书有效，Nginx 配置测试成功，Rocky 本机 HTTP/HTTPS `/healthz` 均返回 `status: ok`，Windows 浏览器通过 SSH 隧道正常打开 HTTPS 首页（浏览器信任警告符合预期）。
- [x] MySQL 备份脚本已在 Rocky 手动实测：生成 `mysql-2026-10-05-192553.sql.gz`（790 字节，root 所有、权限 `600`）；两份当前备份执行 `gzip -t` 无错误。脚本 7 天保留规则已审阅，自动清理策略尚未实测。
- [x] MySQL 逻辑备份已抽查并完成隔离恢复演练：备份 `mysql-2026-10-05-190731.sql.gz` 为 791 字节、权限 `600`、`gzip -t` 通过；恢复到临时库 `restore_check_20261005` 后存在 `site_messages` 表且记录数为 1。临时库保留，待确认清理。
- [x] 日志快照脚本已在 Rocky 手动实测：生成 `logs/compose-2026-10-05.log`（约 713 KB，权限 `600`，root 所有）；初始无日志目录/旧快照。
- [x] Rocky `crond` 已启用，`/etc/cron.d/lnmp-zabbix` 配置每日 00:00 日志快照、02:00 MySQL 备份；首次自动运行结果待观察。脚本保留策略分别为 14 天和 7 天。
- [x] 钉钉告警端到端验证：Webhook 媒介测试消息已到个人测试群；Admin 用户媒介、主机 Secret 宏、问题与恢复动作完成配置。将实验触发器阈值临时从 `<9` 调整为 `<10`，容器数仍为 9 时产生 High 问题事件，钉钉收到包含事件名、主机、严重性、时间和事件编号的告警；服务恢复后收到恢复消息。测试后阈值已恢复为 `<9`。
- [x] 修复 Zabbix 通知时间差 8 小时：Rocky 主机为 `CST +0800`，Zabbix Server/Web 容器原先为 `UTC +0000`。在 `compose.yaml` 为 `zabbix-server` 增加 `TZ: ${TZ:-Asia/Shanghai}`，重建该服务后容器时间显示 `CST +0800`。随后测试告警时间 `21:29:43`、恢复时间 `21:30:43` 与上海本地时间一致。

## 当前状态与下次继续步骤

项目核心实验链路已跑通：Compose 编排、应用健康检查、Nginx 动静态处理、MySQL 持久化、Redis 缓存、HTTP/自签名 HTTPS、Zabbix Docker 监控、钉钉问题/恢复通知、MySQL 备份与隔离恢复，以及日志/备份 cron 配置均有用户提供的实测证据。告警时间已通过真实问题与恢复通知验证为上海时间。当前 Zabbix 模板确认的是 Docker daemon 可用性和运行容器总数，不代表各业务容器均有应用级健康监控，也没有证据证明已采集 Rocky 宿主机 CPU/内存。cron 已配置且脚本手工验证过，但首次按计划自动执行是否成功仍待日志确认。Redis 有缓存行为演示，但没有可复现的压测数据证明 QPS 提升 30%。因此它是完成度较高的个人运维实验项目，不应描述为生产级高可用系统。

## 简历描述核对与改进建议

| 简历说法 | 当前证据 | 建议 |
| --- | --- | --- |
| Docker Compose 编排 Nginx、MySQL、PHP、Redis | 9 个服务在 Rocky 上运行，应用健康检查成功 | 可保留 |
| Volume 实现 MySQL 持久化 | 使用 named volume，容器重建/重启保留数据的完整演练需要单独留证 | 可写“配置 named volume 持久化”；若写“验证容器重建后数据保留”，先实际验证 |
| Nginx 反向代理与动静分离 | 配置已运行，应用首页与 PHP 路由工作 | 可保留，面试时说明静态资源由 Nginx 直接返回、动态请求转 PHP-FPM |
| Redis 使 QPS 提升约 30% | 验证过 MISS/HIT 和 30 秒过期，没有基准压测 | 暂时删除 30%；以后用固定并发、请求数、预热、重复多轮的压测比较开启/关闭缓存，并保留原始结果 |
| HTTPS 保障数据传输安全 | 本地自签名 HTTPS 可用 | 写“配置并验证本地自签名 HTTPS”；不要暗示公网 CA 或生产 TLS 已部署 |
| Zabbix 7 LTS 监控容器与宿主机性能 | Docker ping、容器数及告警闭环已验证；宿主机 CPU/内存指标未完成 | 保留 Docker 监控；宿主机性能部分完成 Rocky Host Agent 部署、登记及 CPU/内存最新数据检查后再写 |
| 故障 5 分钟内通知 | 问题/恢复通知链路已验证，但本次仅证明触发后能送达，尚无独立测量的端到端时延统计 | 可写“配置问题与恢复通知，实验验证可送达”；若保留 5 分钟承诺，测量多次触发到收到消息的时差并配置操作延迟不超过 5 分钟 |
| Shell + Crontab 日志轮转和定时备份 | 脚本手工运行通过；cron 配置存在，首次自动运行待确认；日志脚本是定期快照与保留清理，不是容器内日志轮转器 | 准确写“定时生成 Compose 日志快照并按保留期清理；定时执行 MySQL 逻辑备份”，观察至少一个计划周期后再称自动任务验证通过 |
| 高可用需求 | 单节点 Rocky VM、单实例容器，无副本、故障切换或集群 | 不称高可用；可说“面向快速部署和可维护性搭建个人实验环境” |

### 推荐的当前简历版本

**基于 Docker Compose 的 LNMP 部署与 Zabbix 监控实验环境**

- 在 Rocky Linux 9.8 上使用 Docker Compose 部署 Nginx、PHP-FPM、MySQL、Redis 及 Zabbix 监控组件，通过 Docker named volume 持久化数据库数据。
- 配置 Nginx 静态资源服务与 PHP-FPM 动态转发，使用 Redis 实现 30 秒缓存；验证缓存 MISS/HIT、过期重建及应用健康检查。
- 配置本地自签名 HTTPS；使用 Zabbix Agent 2 与受限 Docker API 代理采集 Docker 可用性和容器数量，并通过钉钉机器人验证问题/恢复告警及消息时区。
- 编写 Shell 脚本生成 MySQL 压缩逻辑备份和 Compose 日志快照，配置 cron 定时任务；完成备份完整性检查与隔离数据库恢复演练。

> 暂不写“QPS 提升约 30%”“高可用”或“宿主机性能全面监控”，直到分别有压测、冗余/故障切换和主机 Agent 采集证据。

建议按风险从低到高继续：

1. 查看 Compose 容器状态、磁盘和内存。
2. 清理本次临时恢复库前先确认。
3. 在下一次计划触发后检查 cron 输出日志和新快照/备份是否生成；不要为了验证而手动修改系统时间。
4. 最后配置钉钉告警；使用实验室可控的测试触发方式验证问题通知和恢复通知。

开始下一次操作前可先做只读状态检查：

```bash
cd ~/lnmp-zabbix
ls -l compose.yaml php/Dockerfile docker-socket-proxy/nginx.conf zabbix/templates/template_lnmp_docker.yaml
sudo docker compose --env-file .env config --quiet
```

```bash
sudo docker compose --env-file .env ps
free -h
df -h /
```

后续变更前核对目标服务和影响范围；不需要为了继续练习而重建全栈。停止实验时若确有需要，可执行 `docker compose down` 保留 named volumes；禁止随意附加 `-v`，因为它会删除数据库/缓存数据卷。

Nginx 配置及全栈启动已在本轮之后验证通过，下面原先的首次启动步骤留作故障排查参考，不再是当前待办：

```bash
sudo docker run --rm --entrypoint nginx \
  -v "$PWD/docker-socket-proxy/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:1.28-alpine -t
```

预期包含 `syntax is ok` 和 `test is successful`。然后启动并检查：

```bash
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
free -h
df -h /
```

首次启动需要 MySQL 和 PostgreSQL 初始化，等待服务进入 healthy 后再测应用：

```bash
curl -i --max-time 5 http://127.0.0.1:8081/healthz
curl -i --max-time 5 http://127.0.0.1:8081/
```

若服务未健康，查看具体服务日志，例如：

```bash
sudo docker compose --env-file .env logs --tail 80 php
sudo docker compose --env-file .env logs --tail 80 docker-socket-proxy
```

停止实验但保留数据库和 Redis 数据：

```bash
sudo docker compose --env-file .env down
```

不要附加 `-v`，否则会删除 named volumes 中的数据。任何服务状态或页面行为都以实际命令输出为准，不凭镜像构建成功推断应用已可用。
