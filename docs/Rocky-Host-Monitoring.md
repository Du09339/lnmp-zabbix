# Rocky 宿主机监控

## 功能目标与架构

监控 Rocky 虚拟机本身的 CPU、内存、文件系统和系统负载，与现有 Docker 容器数量监控分开。

Rocky 宿主机安装 Agent 2，通过主动检查连接 `127.0.0.1:10051`；Docker 将此回环端口映射到 Zabbix Server。主机名必须与网页登记名称一致。本方案不需要向局域网开放 Agent 端口。

## 2026-10-07：安装与配置

### 前置检查

Rocky 原有仓库中没有 `zabbix-agent2`，主机未安装 Agent 服务。容器内的 Agent 用于 Docker 监控，不作为宿主机资源监控的替代。

### 安装过程

添加 Zabbix 7.0 官方 EL9 仓库后安装 Agent 2，实际安装版本为 `7.0.31-release1.el9.x86_64`。

### 配置变更

备份 Agent 配置及 Compose 文件后，修改 `/etc/zabbix/zabbix_agent2.conf`：

```text
Server=127.0.0.1
ServerActive=127.0.0.1:10051
Hostname=Rocky Linux Host
```

为 Compose 的 `zabbix-server` 增加：

```yaml
ports:
  - "127.0.0.1:10051:10051"
```

校验 Compose 后仅重建 Zabbix Server，再启用并启动主机 Agent。该重建会短暂影响监控，不改变 MySQL 业务数据。

### 网页配置

在“数据采集 → 主机”创建 `Rocky Linux Host`，关联 `Linux servers` 群组及 `Linux by Zabbix agent active` 模板。主动检查不依赖页面配置的被动 Agent 接口；页面中的 `127.0.0.1:10050` 不能用于让 Server 容器访问宿主机 Agent。

### 验证证据

- `127.0.0.1:10051` 已监听。
- Agent 配置验证成功，服务为 enabled、active。
- 最新数据截图显示主动 Agent 可用性为 `available (1)`。
- 可用内存约 3.98 GB、可用内存百分比约 72.42%，并出现 CPU、文件系统和存储监控项。以上为当时快照，不代表当前固定值。
- 页面通过“名称”输入英文关键词并点击“应用”，或点击 cpu、memory、filesystem 标签筛选指标。

## 2026-10-09：历史告警检查

主机列表截图显示 `Rocky Linux Host` 已启用，主动模板关联正确，可用性为绿色。默认 `Zabbix server` 主机则使用被动 Linux 模板和 `127.0.0.1:10050`，显示 Agent 不可用。

原因：从 Zabbix Server 容器视角，回环地址指向容器自身，不是 Rocky 宿主机。已提出保留 `Zabbix server health`、移除错误 Linux 模板的建议，但用户未回传操作结果，清理状态待验证。

## 当前状态与后续工作

- 主机 Agent 接入与资源指标采集已验证。
- Rocky 主机独立资源故障的告警演练尚未执行；10 月 9 日 PHP 停止演练验证的是 Docker 容器数量告警。
- 若共用钉钉机器人，需要同时确认动作条件覆盖 Rocky 主机，以及 `{$DINGTALK_WEBHOOK}` 宏在该主机上可解析。旧主机上的宏不会自动成为新主机的宏。
- 后续配置修改和验证结果继续按日期追加到本文档，不写入性能测试板块。
