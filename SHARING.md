# 如何分享 OpenClaw Auto-Recovery Skill

这个文档说明如何将这个 skill 分享给其他 OpenClaw 用户。

## 方法 1: 直接分享文件夹（最简单）

### 发送方（你）：

1. **打包整个 skill 文件夹**
   ```bash
   cd ~/.claude/skills
   tar -czf openclaw-never-die.tar.gz openclaw-never-die/
   ```

2. **分享压缩包**
   - 通过邮件、云盘、或消息发送 `openclaw-never-die.tar.gz`
   - 或者直接分享文件夹（复制 `openclaw-never-die/` 目录）

### 接收方（其他用户）：

1. **解压到 Claude skills 目录**
   ```bash
   cd ~/Downloads  # 或压缩包所在目录
   tar -xzf openclaw-never-die.tar.gz
   mkdir -p ~/.claude/skills
   mv openclaw-never-die ~/.claude/skills/
   ```

2. **使用 skill**
   - 启动 Claude Code
   - 运行: `/openclaw-never-die`

或者使用便捷安装脚本：
```bash
cd openclaw-never-die
./install.sh
```

---

## 方法 2: GitHub 分享（推荐给团队）

### 创建 GitHub 仓库：

1. **初始化仓库**
   ```bash
   cd ~/.claude/skills/openclaw-never-die
   git init
   git add .
   git commit -m "Initial commit: OpenClaw auto-recovery skill"
   ```

2. **推送到 GitHub**
   ```bash
   # 在 GitHub 创建新仓库，然后：
   git remote add origin https://github.com/YOUR_USERNAME/openclaw-never-die.git
   git branch -M main
   git push -u origin main
   ```

3. **分享仓库链接**
   例如: `https://github.com/YOUR_USERNAME/openclaw-never-die`

### 其他用户安装：

```bash
cd ~/Downloads
git clone https://github.com/YOUR_USERNAME/openclaw-never-die.git
cd openclaw-never-die
./install.sh
```

或手动复制：
```bash
git clone https://github.com/YOUR_USERNAME/openclaw-never-die.git
mkdir -p ~/.claude/skills
cp -r openclaw-never-die ~/.claude/skills/openclaw-never-die
```

---

## 方法 3: 项目内分享（适合团队项目）

如果你的团队在同一个项目中工作：

1. **添加到项目**
   ```bash
   cd /path/to/your/project
   mkdir -p .claude/skills
   cp -r ~/.claude/skills/openclaw-never-die .claude/skills/
   ```

2. **提交到版本控制**
   ```bash
   git add .claude/skills/openclaw-never-die
   git commit -m "Add OpenClaw auto-recovery skill"
   git push
   ```

3. **团队成员使用**
   - Pull 最新代码
   - Skill 自动可用（项目级 skill）
   - 运行: `/openclaw-never-die`

---

## 方法 4: 一键安装脚本（最快）

创建一个远程安装脚本供他人使用：

```bash
curl -fsSL https://your-domain.com/install-openclaw-watchdog.sh | bash
```

**install-openclaw-watchdog.sh 内容：**
```bash
#!/bin/bash
set -e

echo "Installing OpenClaw Auto-Recovery Skill..."

# Download skill files
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 方案 A: 从 GitHub 下载
git clone https://github.com/YOUR_USERNAME/openclaw-never-die.git
cd openclaw-never-die

# 或方案 B: 直接下载压缩包
# curl -L -o skill.tar.gz https://github.com/YOUR_USERNAME/openclaw-never-die/archive/main.tar.gz
# tar -xzf skill.tar.gz
# cd openclaw-never-die-main

# 安装
./install.sh

# 清理
cd ~
rm -rf "$TEMP_DIR"

echo "✅ Installation complete!"
```

---

## 快速分享文本（复制粘贴）

如果你想通过聊天工具快速分享，可以发送：

```
🦞 OpenClaw Auto-Recovery Skill

让 OpenClaw Gateway 永不宕机！自动检测和恢复，3秒内自动重启。

安装方法：
1. 下载: [链接到压缩包或 GitHub]
2. 解压到: ~/.claude/skills/
3. 使用: /openclaw-never-die

功能：
✅ 自动重启崩溃的 gateway
✅ 每60秒健康检查
✅ 系统重启自动启动
✅ Telegram 通知（可选）

问题？看文档: README.md
```

---

## 验证 Skill 安装

安装后，用户可以验证：

```bash
# 检查文件存在
ls -la ~/.claude/skills/openclaw-never-die/

# 应该看到：
# SKILL.md (主文件)
# README.md (文档)
# SHARING.md (本文件)
# install.sh (安装脚本)
```

在 Claude Code 中测试：
```
/openclaw-never-die --help
```

如果 skill 没有出现，尝试：
1. 重启 Claude Code
2. 检查文件路径是否正确
3. 查看 SKILL.md 格式是否正确

---

## 收集反馈

分享时可以附上：

**问题反馈渠道：**
- GitHub Issues: `https://github.com/YOUR_USERNAME/openclaw-never-die/issues`
- 邮件: your-email@example.com
- 讨论区: 你的社区/论坛链接

**使用调查：**
- 有多少人成功安装？
- 是否遇到问题？
- 有什么改进建议？

---

## 更新 Skill

当你改进 skill 后：

### 发送方更新 GitHub：
```bash
cd ~/.claude/skills/openclaw-never-die
git add .
git commit -m "Update: [描述改进]"
git push
```

### 接收方更新：
```bash
cd ~/.claude/skills/openclaw-never-die
git pull
# 或重新运行 install.sh
```

---

## 常见问题

**Q: Skill 不显示怎么办？**
A:
1. 确认路径: `~/.claude/skills/openclaw-never-die/SKILL.md`
2. 重启 Claude Code
3. 检查 SKILL.md frontmatter 格式

**Q: 可以修改 skill 吗？**
A: 可以！编辑 SKILL.md 自定义行为

**Q: 如何卸载？**
A:
```bash
rm -rf ~/.claude/skills/openclaw-never-die
```

**Q: 支持 Windows/Linux 吗？**
A: 目前只支持 macOS（LaunchAgent）。欢迎贡献其他平台支持！

---

## License

MIT License - 自由使用、修改和分享！

记得在分享时保留原始文档链接，方便用户获取更新。
