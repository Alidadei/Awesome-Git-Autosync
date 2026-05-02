# Git Auto Sync

**[English](README_EN.md)** | **中文**

还在为个人多台电脑上的仓库同步而苦恼吗？快来试试这个好用的工具！

这是一个极轻量化的 Git 仓库自动同步工具，system script + txt is all your need! 无需额外安装或依赖任何软件。 

全程静默运行，定时自动 commit + push + pull，启动之后无需任何手动操作，让你在多台电脑上的仓库永远 up to date！

## 特点

- **一键启动、开箱即用** — 双击setup脚本 即可静默运行；

- **极轻量** — 核心脚本仅 ~4KB，无任何依赖，纯系统原生脚本，CPU/内存占用几乎为零

- **极易维护** 

  开启同步后维护方式非常简单：

  — 编辑 `config.txt` 中的INTERVAL值即可调整同步的间隔（分钟），下一次同步自动生效

  — 编辑 `config.txt` 中的KEEP_RECENT值即可调整轻量化日志保留的轮次数量，下一次同步自动生效

  — 编辑 `repos.txt` 中的仓库路径即可调整同步仓库，路径前加 `#` 可暂停同步该仓库，但又保留仓库的地址以便随时开启同步！

  — 双击 `stop` 脚本即可立即停止同步进程，需要恢复时再双击 `setup`

  — 重复运行 `setup` 会自动停掉旧实例并启动新的，无需先手动 `stop`。这在更新脚本后重启同步时特别方便

- **跨平台** — 提供 Windows / macOS / Linux 三套脚本（但是当前仅 Windows 平台测试）

- **日志管理** — 提供轻量日志（仅保留最近几轮，具体轮次可自由配置）和完整日志（保留全部历史，时间久了会冗长，打开时可能会卡）两个版本，轻量日志默认保留最近 5 轮同步记录，可在 `config.txt` 中调整。

## 目录结构

```
git-sync-script/
├── windows/
│   ├── git-auto-sync-silent.ps1   # 静默启动同步
│   ├── git-auto-sync.bat          # 同步核心脚本（无需直接点击）
│   ├── setup.bat                  # 点击/运行即可注册开机自启 + 立即开始同步
│   └── stop.bat                   # 点击立即停止同步进程
├── macos/
│   ├── git-auto-sync-silent.sh    # macOS 静默启动
│   ├── git-auto-sync.sh           # macOS 同步核心
│   ├── setup.sh                   # 一键注册开机自启 + 立即开始同步
│   └── stop.sh                    # 停止同步进程
├── linux/
│   ├── git-auto-sync-silent.sh    # Linux 静默启动
│   ├── git-auto-sync.sh           # Linux 同步核心
│   ├── setup.sh                   # 一键注册开机自启 + 立即开始同步
│   └── stop.sh                    # 停止同步进程
|
├── config.txt                     # 同步时间间隔配置
├── repos.txt                      # 仓库路径列表（首次运行自动生成）
├── git-auto-sync.log              # 完整日志（保留所有历史）
└── git-auto-sync-recent.log       # 轻量日志（仅保留最近几轮，方便调试）
```

## 快速开始

### GUI操作方式

**1. 克隆仓库**

```bash
git clone https://github.com/Alidadei/awesome-git-autosync.git
```

**2. 一键启动**

双击 `windows/setup.bat`，自动完成：注册开机自启 + 立即开始后台同步。

**3. 配置同步仓库**

首次同步会自动创建 `repos.txt` 并打开编辑器，每行填写一个仓库的绝对路径，例如：

```
C:\Users\username\my-project
C:\Users\username\another-repo
```

**4. 修改同步间隔**

编辑根目录下的 `config.txt`，修改数字即可，下一轮自动生效，如：

```
INTERVAL=10
```

**5. 修改轻量日志保存的轮次**

编辑根目录下的 `config.txt`，修改数字即可，下一轮自动生效，如：

```
KEEP_RECENT=5
```



### 命令行方式

**Windows：**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && windows\setup.bat
```

**macOS / Linux：**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && chmod +x macos/*.sh && macos/setup.sh
```

**查看日志：**

```
cat git-auto-sync-recent.log
```

> 项目提供两级日志管理，方便开发者调试：
> - `git-auto-sync-recent.log` — 轻量日志，仅保留最近 5 轮同步记录，推荐日常查看
> - `git-auto-sync.log` — 完整日志，保留所有历史记录，用于深度排查
>
> 保留轮数可在 `config.txt` 中通过 `KEEP_RECENT=5` 调整。

## 同步逻辑

每次触发时，对 `repos.txt` 中的每个仓库依次执行：

1. `git add -A`
2. `git commit`（有变更时）
3. `git pull --rebase --autostash`
4. `git push`

## 适用场景

- 个人笔记、文档仓库的自动备份
- 单分支仓库的多设备自动同步
- 需要定时自动保存工作进度的场景

## 不适用场景

- 多人多分支协作仓库（可能产生冲突）
- 需要精细控制 commit 信息的项目
- 多人同时编辑同一文件的工作流

## 当前状态

> **当前仅 Windows 平台运行通过。** macOS / Linux 脚本已编写，待测试。

## 待开发

多分支项目，自动生成项目分支信息的配置文件，并给用户来选择同步哪个分支

异常情况处理：比如文件过大、上传超时、上传失败时的最长上传时间＆报错信息提醒等

