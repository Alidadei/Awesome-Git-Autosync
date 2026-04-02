# Git Auto Sync Script

[English](#english) | [中文](#中文)

---

<a id="english"></a>

## English

A simple script to automatically sync multiple local Git repositories. Supports **Windows**, **Linux**, and **macOS**. Runs as a scheduled task / cron job every N minutes to commit, pull, and push changes.

> **Tested on Windows.** Linux and macOS scripts are provided but have not been tested yet.

### Quick Start

#### 1. Clone this repo

```
git clone https://github.com/Alidadei/git-sync-script.git
```

#### 2. Configure repos

Copy the example file and add your repo paths:

```bash
# Windows
copy repos.example.txt repos.txt

# Linux / macOS
cp repos.example.txt repos.txt
```

Edit `repos.txt`, one repo path per line:

```
# Windows
C:\Users\you\project-a
C:\Users\you\project-b

# Linux / macOS
/home/you/project-a
/Users/you/project-b

# Lines starting with # are ignored
# C:\Users\you\paused-project
```

#### 3. Test manually

```bash
# Windows
git-auto-sync.bat

# Linux / macOS
chmod +x git-auto-sync.sh
./git-auto-sync.sh
```

Check the log:

```bash
# Windows
type git-auto-sync.log

# Linux / macOS
cat git-auto-sync.log
```

#### 4. Set up scheduled task

**Windows** (every 10 minutes):

```
schtasks /create /sc minute /mo 10 /tn "GitAutoSync" /tr "C:\path\to\git-sync-script\git-auto-sync.bat"
```

**Linux / macOS** (every 10 minutes):

```bash
crontab -e
```

Add this line:

```
*/10 * * * * /path/to/git-sync-script/git-auto-sync.sh
```

### What it does

For each repo in `repos.txt`, the script runs:

1. `git add -A` — stage all changes
2. `git commit` — auto commit with timestamp (skipped if nothing to commit)
3. `git pull --rebase --autostash` — pull remote changes
4. `git push` — push to remote

### Maintenance

- **Add repo** — add a line to `repos.txt`
- **Remove repo** — delete the line
- **Pause a repo** — prepend `#` to the line
- **Change interval** — Windows: recreate scheduled task with different `/mo`; Linux/macOS: edit crontab

### Manage scheduled task

**Windows:**

```
:: Check status
schtasks /query /tn GitAutoSync

:: Delete task
schtasks /delete /tn GitAutoSync /f

:: Recreate with 2-minute interval
schtasks /create /sc minute /mo 2 /tn GitAutoSync /tr "C:\path\to\git-sync-script\git-auto-sync.bat"
```

**Linux / macOS:**

```bash
# View current crontab
crontab -l

# Edit crontab
crontab -e

# Remove the line to stop
# Change */10 to */2 for 2-minute interval
```

### Notes

- Requires `git` to be in PATH
- If behind a proxy, configure git proxy: `git config --global http.proxy http://127.0.0.1:PORT`
- `repos.txt` and `git-auto-sync.log` are gitignored — they stay local

---

<a id="中文"></a>

## 中文

一个简单的脚本，用于自动同步多个本地 Git 仓库。支持 **Windows**、**Linux** 和 **macOS**。通过定时任务每隔 N 分钟自动执行 commit、pull 和 push。

> **已在 Windows 上测试通过。** Linux 和 macOS 的脚本尚未测试。

### 快速开始

#### 1. 克隆仓库

```
git clone https://github.com/Alidadei/git-sync-script.git
```

#### 2. 配置仓库列表

复制示例文件并填入你的仓库路径：

```bash
# Windows
copy repos.example.txt repos.txt

# Linux / macOS
cp repos.example.txt repos.txt
```

编辑 `repos.txt`，每行一个仓库路径：

```
# Windows
C:\Users\you\project-a
C:\Users\you\project-b

# Linux / macOS
/home/you/project-a
/Users/you/project-b

# 以 # 开头的行会被跳过
# C:\Users\you\paused-project
```

#### 3. 手动测试

```bash
# Windows
git-auto-sync.bat

# Linux / macOS
chmod +x git-auto-sync.sh
./git-auto-sync.sh
```

查看日志：

```bash
# Windows
type git-auto-sync.log

# Linux / macOS
cat git-auto-sync.log
```

#### 4. 设置定时任务

**Windows**（每 10 分钟）：

```
schtasks /create /sc minute /mo 10 /tn "GitAutoSync" /tr "C:\path\to\git-sync-script\git-auto-sync.bat"
```

**Linux / macOS**（每 10 分钟）：

```bash
crontab -e
```

添加以下内容：

```
*/10 * * * * /path/to/git-sync-script/git-auto-sync.sh
```

### 工作流程

脚本对 `repos.txt` 中的每个仓库依次执行：

1. `git add -A` — 暂存所有变更
2. `git commit` — 自动提交（无变更则跳过）
3. `git pull --rebase --autostash` — 拉取远程更新并变基
4. `git push` — 推送到远程

### 日常维护

- **添加仓库** — 在 `repos.txt` 中加一行路径
- **删除仓库** — 删掉对应行
- **暂停某个仓库** — 行首加 `#`
- **修改同步间隔** — Windows：删除定时任务后用不同的 `/mo` 值重新创建；Linux/macOS：编辑 crontab

### 定时任务管理

**Windows：**

```
:: 查看状态
schtasks /query /tn GitAutoSync

:: 删除任务
schtasks /delete /tn GitAutoSync /f

:: 改为每 2 分钟同步一次
schtasks /create /sc minute /mo 2 /tn GitAutoSync /tr "C:\path\to\git-sync-script\git-auto-sync.bat"
```

**Linux / macOS：**

```bash
# 查看当前定时任务
crontab -l

# 编辑定时任务
crontab -e

# 删除对应行即可停止
# 将 */10 改为 */2 即可改为每 2 分钟同步一次
```

### 注意事项

- 需要系统 PATH 中有 `git` 命令
- 如果使用代理，需配置 git 代理：`git config --global http.proxy http://127.0.0.1:端口`
- `repos.txt` 和 `git-auto-sync.log` 已加入 `.gitignore`，不会上传到 GitHub
