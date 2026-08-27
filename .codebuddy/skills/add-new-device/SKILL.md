---
name: add-new-device
description: 当需要修改本 ROTHKO_Twrp 项目以支持/新增其他 Android 机型（修改 GitHub Actions 工作流的默认编译参数，或指导下次提交如何调整以适配新设备）时使用。触发场景包括"适配新机型""支持其他设备""改默认设备树""换机型编译"等。
---

# 为 ROTHKO_Twrp 项目新增/切换机型支持

本项目是一个基于 GitHub Actions 的 TWRP 自动编译模板。核心可配置项集中在
`.github/workflows/Recovery Build.yml`（以及 `Recovery Build (Legacy).yml`）的
`workflow_dispatch.inputs` 段，每个 input 都有 `default` 值。所谓"支持某机型"，
本质上就是把这些 input 默认值改成目标设备对应的源码地址、分支与路径。

历史参考：最近一次提交 `812e1a5`（DingZhen, 2026-07-17）仅把 `Recovery Build.yml`
的 6 个 input 默认值从 ASUS I003D 改为小米 dali（同时 MANIFEST_BRANCH 升至 twrp-14.1），
未改动任何构建逻辑。这说明**新增机型 = 改 defaults 即可**，运行时也可在 Actions 界面手动覆盖。

## 执行步骤

当用户要求"支持其他机型"时，按以下 SOP 操作：

### 1. 确认目标设备信息
向用户收集（或自行查找）以下 7 项，缺一无法编译：
- **MANIFEST_URL**：TWRP AOSP 源码 manifest 仓库地址（默认
  `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp`）。
- **MANIFEST_BRANCH**：manifest 分支，决定 TWRP/Android 版本（如 `twrp-12.1`、
  `twrp-14.1`）。参考最近提交：Android 15/16 设备树常用 `twrp-14.1`。
- **DEVICE_TREE_URL**：设备树仓库地址（如 `https://github.com/<作者>/android_device_<品牌>_<代号>-TWRP`）。
- **DEVICE_TREE_BRANCH**：设备树分支（如 `Twrp_A15_A16`、`android-12.1`）。
- **DEVICE_PATH**：设备树在源码树中的落盘路径，格式 `device/<品牌>/<代号>`。
- **DEVICE_NAME**：机型代号（即 `out/target/product/<DEVICE_NAME>` 目录名）。
- **MAKEFILE_NAME**：lunch 目标名，格式 `twrp_<代号>`。
- **COMMON_TREE_URL / COMMON_PATH**（可选）：公共设备树（如骁龙平台 common），无则留空。
- **BUILD_TARGET**：原本为编译目标分区（`boot`/`recovery`/`vendorboot`），但本仓库工作流已写死
  为 `make recoveryimage vendorbootimage`（一次构建同时产出 `recovery.img` 与 `vendor_boot.img`），
  故该 input 仅作说明性参数保留，不再驱动实际构建目标。

### 2. 编辑工作流文件
打开 `.github/workflows/Recovery Build.yml`，定位 `on.workflow_dispatch.inputs` 段
（当前约第 6–43 行），修改对应 input 的 `default:` 值。

> 若用户还要支持旧版 Android（≤8.1），同步修改 `.github/workflows/Recovery Build (Legacy).yml`。

注意 `convert.sh`（设备依赖注入脚本）按 `MANIFEST_BRANCH` 判断 build tree 名称：
`twrp-11`/`twrp-12.1` → `twrp.dependencies`，其余分支 → `omni.dependencies`
（见 workflow 第 130–143 行）。较新分支的设备树应使用 `omni.dependencies` 命名，
否则依赖同步会被跳过（该步 `continue-on-error: true`，仅告警）。

**已知坑：Invalid lunch combo（新版源码三段式）**。当 `MANIFEST_BRANCH` 指向较新的
TWRP/AOSP 源码（如 `twrp-14.1` ≈ Android 15）时，`lunch` 目标格式已强制为
`<product>-<release>-<variant>` **三段式**，旧的两段式 `twrp_<代号>-eng` 会报
`Invalid lunch combo` 且 `add_lunch_combo` 函数已 `obsolete`。

根因在**设备树**，不在编译模板：设备树的 `AndroidProducts.mk` 仍写两段式
`COMMON_LUNCH_CHOICES := twrp_<代号>-eng`。修复必须改**上游设备树仓库**（CI 用
`git clone` 远程，改本地副本须 `git push` 回远程才生效）：

1. 设备树 `AndroidProducts.mk`：
   `COMMON_LUNCH_CHOICES := twrp_<代号>-trunk_staging-eng`
   （`trunk_staging` 为新版 AOSP 默认 release config；`<代号>` 与 `twrp_<代号>.mk` 的
   `PRODUCT_NAME` 一致。`vendorsetup.sh` 若无则不用加——新版已废弃 `add_lunch_combo`。）
2. 本仓库工作流 `MAKEFILE_NAME` 默认改为 `twrp_<代号>-trunk_staging`（使
   `lunch ${{ MAKEFILE_NAME }}-eng` = 三段式目标）。

注意：本项目工作流的 `Building recovery` 步骤**不要**再调用 `add_lunch_combo`
（新版 obsolete，会触发警告），也不要在 clone 后生成 `vendorsetup.mk`。
`twrp-11`/`twrp-12.1` → `twrp.dependencies`，其余分支 → `omni.dependencies`
（见 workflow 第 130–143 行）。较新分支的设备树应使用 `omni.dependencies` 命名，
否则依赖同步会被跳过（该步 `continue-on-error: true`，仅告警）。

### 3. 提交改动
按最近提交风格，提交信息用 `Update Recovery Build.yml`，仅改动默认值：
```powershell
git add .github/workflows/Recovery\ Build.yml
git commit -m "Update Recovery Build.yml"
git push
```
注意：`.github/workflows/Recovery Build.yml` 文件名含空格，shell 中需加引号/转义。

### 4. 触发编译
推送后到 GitHub → Actions → `Recovery Build` → `Run workflow`。
可在界面覆盖任意 input；若默认值已正确，直接运行即可。产物在仓库 Releases
（命名 `<DEVICE_NAME>-<run_id>`）下载。

## 校验清单
- [ ] `DEVICE_PATH` 与 `DEVICE_NAME` 代号一致（如 `device/xiaomi/dali` ↔ `dali`）。
- [ ] `MAKEFILE_NAME` 与设备树 `AndroidProducts.mk` / `vendorsetup.mk` 中定义一致。
- [ ] 若用 SSH 私有仓库，`MANIFEST_URL`/`DEVICE_TREE_URL` 用 `git@github.com:...` 形式，
      并在仓库 Secrets 配置 `SSH_PRIVATE_KEY`（详见 README 第 62–101 行）。
- [ ] 较新 TWRP 分支的设备树依赖文件命名为 `omni.dependencies`（非 `twrp.dependencies`）。
