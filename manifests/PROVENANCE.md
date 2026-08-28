# Pinned manifest 来源

## 当前清单

`orangefox-fox_14.1-pinned.xml` **复制自** rodin 设备树：

```text
F:\learn-front\learn-hook\vivo-twrp\orangefox_twrp_device_xiaomi_rodin\manifests\orangefox-fox_14.1-pinned.xml
```

SHA-256：`62f1427fe6c71f2037ea92dbe7f559383b55d5eeab703c4cd59ecaabb1a63b1d`

## 为什么可以直接复用

核对结果：662 个项目**全部来自公共 remote**，不含任何设备专属内容。

| 检查项 | 结果 |
|---|---|
| `rodin` 字样 | 0 处 |
| `device/xiaomi` 条目 | 0 处 |
| `local_manifest` | 0 处 |
| remote 来源 | `aosp` / `LineageOS` / `TeamWin` / `github` / `nebrassy` / `orangefox` 全部公开 |

这份清单钉的是**橙狐 14.1 基础源码**（`bootable/Recovery`、`vendor/recovery`、
`external/se_omapi`、`build/make`、`system/vold` 等），与机型无关。设备树由
工作流用 `rsync` 单独装入源码树，不在 manifest 内，因此换机型不影响复用。

**不要复制**原目录的另外两个文件：`device-blobs.sha256` 和 `README_CN.md`
都是 rodin 专属。

## 关键 revision

| 项目 | Revision | 说明 |
|---|---|---|
| `bootable/Recovery` (orangefox) | `fd98f33a722bd0bd52034f170bb91e2862654d6b` | 橙狐 Recovery 源码，分支 `fox_14.1` |
| `vendor/recovery` (orangefox) | `0d7959e6538db5ddfff892cf7dfe207c68b0b753` | 橙狐 vendor 树 |
| `external/se_omapi` (orangefox) | `9ea6e4a9ecfe04ffb82767d7cbcab3e8dc6295af` | 安全元件 OMAPI |
| default | `refs/tags/android-14.0.0_r67` | AOSP 基线 |

## 必须配套固定的 sync revision

pinned manifest **只锁源码 revision，不含橙狐补丁**。补丁来自
`OrangeFox/sync` 仓库的 `patches/patch-vold-fox_14.1.diff`，由工作流
`Apply OrangeFox setup patches` 步骤应用。因此 sync 仓库的版本**必须一起固定**，
否则不同版本的补丁会得出不同结果：

```text
ORANGEFOX_SYNC_REVISION = 11e4406b2bd1de939a26b6bfbad7e371cc3b1fa7
```

该值取自 rodin 的工作流，与上述源码 revision 配套验证过。
工作流的 `SYNC_REVISION` 输入项已以此作为默认值。

## 更新这份清单

上游更新后需要重新生成时，在**已同步源码的机器**上：

```bash
git clone https://gitlab.com/OrangeFox/sync.git ~/ofox-sync
cd ~/ofox-sync
git checkout --detach 11e4406b2bd1de939a26b6bfbad7e371cc3b1fa7   # 或更新的 revision
./orangefox_sync.sh --branch 14.1 --path ~/fox_14.1

cd /path/to/ROTHKO_Twrp
OFOX_SYNC_DIR=~/ofox-sync manifests/generate-pinned-manifest.sh 14.1
```

**务必同时更新** `SYNC_REVISION` 默认值和本文件的关键 revision 表。

## 兼容性说明

- pd2415 设备树的 `patches/recovery/` 目前只有 `README.md`，没有任何 `.patch`，
  因此不存在与 `fd98f33a...` 这个 Recovery revision 的补丁冲突。
- 后续若添加补丁，必须针对 `fd98f33a722bd0bd52034f170bb91e2862654d6b` 生成，
  否则 `Apply device tree patches` 步骤会失败。
