# 多分支同步支持 — 设计文档

## 背景

当前同步脚本对每个仓库只同步当前检出分支，无法指定同步哪个分支。对于有多分支的项目，用户希望能选择同步哪个分支。

## 设计方案

### 新增配置文件：`branches.txt`

采用与 `repos.txt` 相同的模式——首次运行自动生成，用户编辑后生效。

**文件格式：**

```
# 分支配置 / Branch configuration for Git Auto Sync
# 每行格式：仓库名 分支名。默认同步 master
# 切换分支：注释当前行，取消注释目标行
# ===========================================================================================================

# YHL.github.io ：master；astro-v2
YHL.github.io master
#YHL.github.io astro-v2

# my-project ：main；dev；feature-x
my-project master
#my-project dev
#my-project feature-x
```

**要点：**
- 用仓库名（文件夹名）匹配，简短易读
- 第一行注释列出所有可用分支
- 未注释的行为当前生效分支，其余注释掉
- 切换分支：注释当前行 → 取消注释目标行
- 首次自动生成时，默认生效 `master`

---

### 生成流程

首次同步检测到 `branches.txt` 不存在时：

```
1. 遍历 repos.txt 中每个有效仓库
2. 执行 git branch 获取本地分支列表
3. 默认填入 `master` 分支（最稳定），其他分支以注释形式列出
4. 生成 branches.txt：
   - 仅 master 分支生效
   - 其他分支注释掉，用户取消注释即可启用
5. 打开编辑器让用户修改
6. 退出本轮同步，等用户编辑完后下一轮自动生效
```

**生成的文件示例：**

```
# Branch configuration for Git Auto Sync
# Uncomment a branch to sync it. Only one branch per repo.
# ===========================================================================================================

# C:\Users\y\Desktop\my-project
#   Available: main, dev, feature-x
C:\Users\y\Desktop\my-project master

# C:\Users\y\Desktop\another-repo
#   Available: master, develop
C:\Users\y\Desktop\another-repo master

# C:\Users\y\Desktop\single-branch-repo
#   Available: main
C:\Users\y\Desktop\single-branch-repo master
```

---

### 同步流程变更

在现有 `git add -A` 之前插入分支切换逻辑：

```
现有流程（不变）：
    cd / pushd 进入仓库

新增逻辑 ↓
    ┌─ 读取 branches.txt，查找该仓库的分支配置
    │  ┌─ 未找到配置 → 默认同步 master
    │  ├─ 找到但未指定分支 → 默认同步 master
    │  └─ 找到且指定了分支：
    │     ├─ 获取当前分支：git symbolic-ref --short HEAD
    │     ├─ 目标分支 == 当前分支 → 跳过 checkout
    │     └─ 目标分支 != 当前分支 → git checkout <branch>
    │        ├─ 成功 → 继续同步
    │        └─ 失败 → 记录错误，跳过该仓库

现有流程（不变）：
    git add -A
    git commit
    git pull --rebase --autostash
    git push
```

---

### 错误处理

| 场景 | 处理方式 |
|---|---|
| `branches.txt` 不存在 | 不做任何分支切换，行为与旧版完全一致 |
| 仓库在 `branches.txt` 中无条目 | 默认同步 master |
| 指定分支不存在 | 记录错误日志，跳过该仓库 |
| checkout 失败（如工作区脏） | 记录错误日志，跳过该仓库 |
| `branches.txt` 格式错误 | 跳过该行，记录警告 |

---

### 向后兼容

- `branches.txt` 不存在时，行为与当前版本**完全一致**
- `branches.txt` 中未指定分支的仓库，默认同步 `master`
- `repos.txt` 格式**不变**
- `sync-settings.txt` 格式**不变**
- 升级后无需任何手动操作，首次同步会自动生成配置文件

---

### 需修改的文件

| 文件 | 改动内容 |
|---|---|
| `windows/git-auto-sync.bat` | 新增 branches.txt 生成逻辑 + sync_repo 中 checkout 逻辑 |
| `macos/git-auto-sync.sh` | 同上 |
| `linux/git-auto-sync.sh` | 同上 |
| `.gitignore` | 添加 `branches.txt` |

### 不修改的文件

- `repos.txt` — 格式不变
- `sync-settings.txt` — 格式不变
- `setup.*` / `stop.*` / `*-silent.*` — 无需改动

---

### 各平台实现差异

| 方面 | Windows | macOS/Linux |
|---|---|---|
| branches.txt 解析 | `findstr` 匹配仓库路径 | `grep` 匹配仓库路径 |
| 分支查询 | `git symbolic-ref --short HEAD` | 同左 |
| 分支切换 | `git checkout <branch>` | 同左 |
| 打开编辑器 | `start notepad` | `open -t` (macOS) / `xdg-open` (Linux) |
| 生成逻辑位置 | 新增 `:generate_branches` 子程序 | 在主循环前新增函数 |

---

### 测试计划

1. **首次运行**：确认 `branches.txt` 自动生成并打开编辑器
2. **分支切换**：配置不同分支，确认同步前自动 checkout
3. **向后兼容**：删除 `branches.txt`，确认行为与旧版一致
4. **错误场景**：配置不存在的分支名，确认跳过并记录错误
5. **未指定分支**：仓库路径后不写分支名，确认同步当前分支
6. **多平台**：三套脚本分别验证
