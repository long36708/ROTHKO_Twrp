# Pinned OrangeFox manifest

## 为什么需要它

`orangefox_sync.sh --branch 14.1` 每次都会拉取**当时最新**的 TWRP minimal
manifest 和橙狐源码。带来的问题：

- 上游一动，设备树的 `patches/` 可能打不上，构建失败原因难以定位；
- 同样的设备树，两次构建出的产物可能来自不同源码，**无法复现**；
- CI 失败不可重放，排障只能靠猜。

`orangefox-fox_<branch>-pinned.xml` 记录**每一个 repo 项目的精确 revision**，
CI 用它 `repo init` 就能还原完全一致的源码树。

## 生成

在**已经同步好源码的机器**上执行（本机就是跑 `orangefox_sync.sh` 的那台）：

```bash
# 1. 同步源码（注意必须先 cd 进 sync 克隆，否则脚本找不到自己的 patches/）
git clone https://gitlab.com/OrangeFox/sync.git ~/ofox-sync
cd ~/ofox-sync
./orangefox_sync.sh --branch 14.1 --path ~/fox_14.1

# 2. 冻结 revision
cd /path/to/ROTHKO_Twrp
OFOX_SYNC_DIR=~/ofox-sync manifests/generate-pinned-manifest.sh 14.1
```

产物：

| 文件 | 说明 |
|---|---|
| `orangefox-fox_14.1-pinned.xml` | 全部项目的精确 revision 清单 |
| `orangefox-fox_14.1-pinned.xml.sha256` | 清单自身的校验和，CI 会自动校验 |
| `orangefox-fox_14.1-sync-revision.txt` | 生成时使用的 `sync` 仓库 revision（需设 `OFOX_SYNC_DIR`） |

## 当前状态

fox_14.1 的清单**已就位**，复制自 rodin 设备树（已核对：662 个项目全部来自
公共 remote，无任何设备专属内容）。SHA-256：

```text
62f1427fe6c71f2037ea92dbe7f559383b55d5eeab703c4cd59ecaabb1a63b1d
```

配套固定的 `SYNC_REVISION`、`关键 revision`、重新生成方法见
[PROVENANCE.md](./PROVENANCE.md)。

fox_12.1 的清单**尚未生成**——当前设备只用 14.1，需要时按上面的步骤生成。

## 放置位置

工作流按以下顺序查找，命中第一个即启用：

1. **本仓库** `manifests/orangefox-fox_<branch>-pinned.xml`（推荐，模板自带）
2. **设备树** `manifests/orangefox-fox_<branch>-pinned.xml`（机型专属时放这里）

两者都不存在时，工作流回退到 `orangefox_sync.sh`，并打 warning 提示构建不可复现。

> 命中后若存在同名 `.sha256`，会先 `sha256sum --check --strict` 校验清单完整性。

## 桥接两种方式

| | `orangefox_sync.sh`（默认） | pinned manifest |
|---|---|---|
| 可复现 | 否 | 是 |
| 需要预先生成 | 否 | 是（一次性） |
| 上游更新 | 自动跟随 | 需手动重新生成 |
| 适用场景 | 首次移植、快速验证 | 稳定后、CI 长期构建 |

建议：移植阶段用同步脚本，跑通后立刻生成 pinned manifest 固化。

## 注意事项

- pinned manifest **只锁定源码 revision，不包含橙狐补丁**。补丁仍需单独应用，
  工作流由 `Apply OrangeFox setup patches` 步骤负责（仅 pinned 路径执行）。
- 源码更新后补丁打不上时，先对照 pinned manifest 的 revision 排查，**不要**
  用 `git apply --reject` 忽略冲突。
- `sync` 脚本自身的 revision 也要固定（`SYNC_REVISION` 输入项），否则不同
  版本的 `patch-vold-fox_14.1.diff` 会得出不同结果。
- fox_14.1 完整源码约 662 个项目、85 GiB 左右，生成前确认磁盘充足。
