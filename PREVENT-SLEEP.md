# 防止 Mac 休眠配置指南

OpenClaw Gateway 需要 Mac 保持唤醒状态才能持续运行。本文档说明如何配置防休眠。

## 为什么需要防休眠？

Mac 在休眠时会暂停所有进程，导致：
- ❌ OpenClaw Gateway 停止响应
- ❌ Telegram/飞书机器人无法接收消息
- ❌ 定时任务无法执行
- ❌ API 服务中断

**解决方案：** 保持 Mac 一直唤醒（特别适合 Mac Mini/Studio 作为服务器）

---

## 三种防休眠方法

### 方法 1：自动安装（推荐）⭐

运行 skill 时添加 `--prevent-sleep` 参数：

```bash
/openclaw-never-die --prevent-sleep
```

这会自动安装一个 caffeinate LaunchAgent 服务，让 Mac 保持唤醒。

### 方法 2：使用配置脚本

Skill 包含一个独立的配置脚本：

```bash
cd ~/.claude/skills/openclaw-never-die
./prevent-sleep.sh
```

**交互式菜单选项：**
1. 安装 LaunchAgent（caffeinate 服务）[推荐]
2. 配置 pmset（系统电源设置）[需要 sudo]
3. 同时安装两者
4. 显示手动方法（临时）
5. 检查当前状态
6. 卸载 LaunchAgent

**快速命令：**
```bash
./prevent-sleep.sh install    # 快速安装
./prevent-sleep.sh status     # 检查状态
./prevent-sleep.sh uninstall  # 卸载
```

### 方法 3：系统级配置（永久）

使用 pmset 修改系统电源设置（需要管理员密码）：

```bash
# 禁用系统休眠
sudo pmset -a sleep 0

# 禁用显示器休眠（可选）
sudo pmset -a displaysleep 0

# 禁用硬盘休眠
sudo pmset -a disksleep 0

# 启用网络唤醒
sudo pmset -a womp 1

# 断电后自动重启
sudo pmset -a autorestart 1
```

查看当前设置：
```bash
pmset -g
```

---

## 各方法对比

| 方法 | 优点 | 缺点 | 推荐场景 |
|------|------|------|----------|
| **LaunchAgent (caffeinate)** | • 不需要 sudo<br>• 易于卸载<br>• 开机自启 | • 仅防止休眠<br>• 不修改系统设置 | ✅ 大多数情况 |
| **pmset 系统级** | • 永久生效<br>• 系统级保护<br>• 更全面 | • 需要 sudo<br>• 影响整个系统<br>• 修改系统配置 | 服务器/专用机器 |
| **手动 caffeinate** | • 临时使用<br>• 无需安装 | • 终端关闭失效<br>• 不自动启动 | 临时测试 |

---

## 当前系统状态检查

### 检查电源设置
```bash
pmset -g | grep -E "(sleep|displaysleep)"
```

预期输出（防休眠配置）：
```
sleep                0
displaysleep         0
```

### 检查 caffeinate 服务
```bash
launchctl list | grep prevent-sleep
```

如果已安装，应该看到：
```
-       0       ai.openclaw.prevent-sleep
```

### 检查活跃的防休眠断言
```bash
pmset -g assertions | grep -i prevent
```

应该看到类似：
```
PreventUserIdleSystemSleep     1
```

---

## 工作原理

### LaunchAgent + caffeinate

```
macOS LaunchAgent
    │
    ├─> ai.openclaw.prevent-sleep
    │   └─> /usr/bin/caffeinate -dims
    │       ├─ -d : 防止显示器休眠
    │       ├─ -i : 防止系统空闲休眠
    │       ├─ -m : 防止磁盘休眠
    │       └─ -s : 防止电源按钮休眠
    │
    └─> KeepAlive = true
        └─> 崩溃自动重启
```

### pmset 系统设置

直接修改 macOS 电源管理守护进程 (powerd) 的配置：
- 设置休眠时间为 0 = 永不休眠
- 写入 `/Library/Preferences/SystemConfiguration/com.apple.PowerManagement.plist`
- 系统级，全局生效

---

## 验证防休眠生效

### 测试 1：检查系统信息
```bash
pmset -g assertions
```

查找：
```
PreventUserIdleSystemSleep     1
```

### 测试 2：等待测试
1. 记录当前时间
2. 不操作电脑，等待 10-15 分钟
3. Mac 应该保持唤醒，显示器可能变暗但系统不休眠
4. 测试 OpenClaw：`curl http://127.0.0.1:18789/health`

### 测试 3：查看日志
```bash
# 系统电源日志
log show --predicate 'eventMessage contains "sleep"' --last 1h

# LaunchAgent 日志
launchctl list | grep prevent-sleep
```

---

## 功耗考虑

### 防休眠的功耗影响

| 设备 | 休眠功耗 | 空闲功耗 | 增加 |
|------|----------|----------|------|
| Mac Mini M1 | ~2W | ~7W | +5W |
| Mac Mini M2 | ~2W | ~8W | +6W |
| MacBook Pro | ~0.5W | ~5W | +4.5W |

**成本估算：**
- Mac Mini 24小7 运行：~8W × 24h × 30天 = 5.76 kWh/月
- 电费（¥0.6/kWh）：~¥3.5/月

### 优化建议

1. **允许显示器休眠**（节省功耗）
   ```bash
   sudo pmset -a displaysleep 10
   ```

2. **使用 caffeinate 而非 pmset**
   - 更精确控制
   - 不影响其他电源设置

3. **按需启用**
   ```bash
   # 工作时间启用
   launchctl start ai.openclaw.prevent-sleep

   # 非工作时间停用
   launchctl stop ai.openclaw.prevent-sleep
   ```

---

## 故障排除

### 问题：Mac 还是会休眠

**检查项：**

1. 确认 caffeinate 服务运行中
   ```bash
   launchctl list | grep prevent-sleep
   ps aux | grep caffeinate
   ```

2. 检查电源断言
   ```bash
   pmset -g assertions | grep -i prevent
   ```

3. 检查是否有其他限制
   ```bash
   pmset -g custom
   ```

4. 查看系统日志
   ```bash
   log show --predicate 'subsystem == "com.apple.power"' --last 30m
   ```

### 问题：服务安装失败

```bash
# 卸载旧服务
launchctl bootout gui/$(id -u)/ai.openclaw.prevent-sleep 2>/dev/null

# 删除 plist 文件
rm ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist

# 重新安装
~/.claude/skills/openclaw-never-die/prevent-sleep.sh install
```

### 问题：pmset 需要 sudo

某些 pmset 命令需要管理员权限：

```bash
# 需要 sudo
sudo pmset -a sleep 0

# 不需要 sudo（查看）
pmset -g
```

---

## 卸载防休眠配置

### 卸载 LaunchAgent

```bash
# 停止服务
launchctl bootout gui/$(id -u)/ai.openclaw.prevent-sleep

# 删除配置文件
rm ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist
```

或使用脚本：
```bash
~/.claude/skills/openclaw-never-die/prevent-sleep.sh uninstall
```

### 恢复 pmset 设置

```bash
# 恢复默认休眠时间（10分钟）
sudo pmset -a sleep 10

# 恢复显示器休眠（10分钟）
sudo pmset -a displaysleep 10

# 恢复硬盘休眠（10分钟）
sudo pmset -a disksleep 10
```

---

## 高级配置

### 定时防休眠

使用 cron 或 LaunchAgent 在特定时间启用/禁用：

```xml
<!-- 仅工作时间防休眠 -->
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Hour</key>
        <integer>8</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</array>
```

### 条件防休眠

仅在 OpenClaw Gateway 运行时防休眠：

```bash
#!/bin/bash
if pgrep -f "openclaw-gateway" > /dev/null; then
    caffeinate -dims &
fi
```

### 网络唤醒（Wake on LAN）

如果允许休眠，可以配置网络唤醒：

```bash
# 启用网络唤醒
sudo pmset -a womp 1

# 使用其他设备唤醒
wakeonlan MAC_ADDRESS
```

---

## 最佳实践

✅ **DO（推荐）：**
- 使用 LaunchAgent + caffeinate（方便管理）
- 允许显示器休眠（节能）
- Mac Mini/Studio 作为服务器时启用防休眠
- 定期检查服务状态

❌ **DON'T（不推荐）：**
- 笔记本电脑 24/7 防休眠（电池损耗）
- 修改 pmset 后不备份原设置
- 同时运行多个 caffeinate 实例
- 忘记断电保护（UPS 建议）

---

## 相关命令速查

```bash
# 查看电源设置
pmset -g

# 查看防休眠断言
pmset -g assertions

# 查看 LaunchAgent 状态
launchctl list | grep openclaw

# 手动防休眠（临时）
caffeinate -dims

# 立即休眠（测试用）
pmset sleepnow

# 查看休眠历史
pmset -g log | grep -i sleep

# 系统电源统计
pmset -g stats
```

---

## 更多资源

- [Apple pmset 官方文档](https://ss64.com/osx/pmset.html)
- [caffeinate 手册](https://ss64.com/osx/caffeinate.html)
- [LaunchAgent 文档](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

---

**总结：** 对于 Mac Mini 运行 OpenClaw 作为 24/7 服务，推荐使用 `--prevent-sleep` 选项或 `prevent-sleep.sh install`，简单有效！
