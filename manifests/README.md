# Pinned OrangeFox manifest

## 为什么需要它

`orangefox_sync.sh --branch 14.1` 每次都会拉取**当时最新**的 TWRP minimal
manifest 和橙狐源码。带来的问题：

- 上游一动，设备树的 `patches/` 可能打不上，构建失败原因难以定位；
- 同样的设备树，两次构建出的产物可能来自不同源码，**无法复现**；
- CI 失败不可重放，排障只能靠猜。

`orangefox-fox_<branch>-pinned.xml` 记录**每一个 repo 项目的精确 revision**，
CI 用它 `repo init` 就能还原完全一致的源码树。

## ⚠️ 关键前提：pinned manifest 不记录补丁

`repo manifest -r` **只锁定 revision，不记录工作区补丁**。橙狐的 4 个补丁
（`patch-manifest` / `patch-vold` / `patch-update-engine` / `patch-vendor-twrp`）
都是同步脚本施加在工作区上的修改，**不会进 manifest**。

因此 pinned 路径必须自行补打全部补丁，否则会在 soong 引导阶段炸掉：

```
internal error: New plugins are not supported; however
["soong-libaosprecovery_defaults" "soong-libguitwrp_defaults"
 "soong-libminuitwrp_defaults" "soong-vold_defaults"] were found.
Please reach out to the build team or use BUILD_BROKEN_PLUGIN_VALIDATION
```

原因是 build/make 的补丁定义了 `BUILD_BROKEN_PLUGIN_VALIDATION`，漏掉它就
报上面这个看似无关的错。

工作流会用 [`../patches/`](../patches/README.md) 下的补丁补齐，并在打完后校验
`BUILD_BROKEN_PLUGIN_VALIDATION`、`Fox_Before_Recovery_Image` 两个标记是否
存在，缺失直接报明确错误。

## 生成

在**已经同步好源码的机器**上执行（本机就是跑 `orangefox_sync.sh` 的那台）：

```bash
# 1. 同步源码（注意必须先 cd 进 sync 克隆，否则脚本找不到自己的 patches/）
git clone https://gitlab.com/OrangeFox/sync.git ~/ofox-sync
cd ~/ofox-sync
./orangefox_sync.sh --branch 14.1 --path ~/fox_14.1

# 2. 冻结 revision（脚本会同时记录 sync 仓库 revision）
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
公共 remote，无任何设备专属内容）。SHA-256（按 LF 规范化内容计算）：

```text
7262c93f87eaecaa11e6cfde06a7be22b4bb81697d94e74c8c01500ab90a3f60
```

配套固定的 `SYNC_REVISION`、关键 revision、重新生成方法见
[PROVENANCE.md](./PROVENANCE.md)。

fox_12.1 的清单**尚未生成**——当前设备只用 14.1，需要时按上面的步骤生成。

### 为什么不能用 sync 仓库自带的补丁

本清单里 `build/make` 是 **nebrassy 的 `android_build`**（`506df226`），
而 `OrangeFox/sync` 的 `patch-manifest-fox_14.1.diff` 是针对 **TeamWin minimal
manifest** 的 build 项目生成的，两者 base 不同，打不上。

rodin 的解法是自己维护配套补丁。我们已从中复制了 2 个（无设备专属内容），
放在 [`../patches/`](../patches/README.md)，因此 **`pinned` 现在可用且为默认值**。

### pinned 与 sync-script 的取舍

| | `pinned`（默认） | `sync-script` |
|---|---|---|
| 可复现 | 是 | 否 |
| 补丁配套 | 用本仓库 `patches/`，已针对该 revision 验证 | 脚本自带，天然自洽 |
| 上游更新 | 需重新生成清单 + 更新补丁 | 自动跟随 |
| 橙狐 recovery 增强 | 无（跳过 `orangefox-recovery.patch`） | 有 |

**pinned 出问题时切 `sync-script` 兜底**，它会重新拉取源码并打官方补丁。

## 放置位置

`SYNC_METHOD=pinned` 时按顺序查找，命中第一个即启用：

1. **本仓库** `manifests/orangefox-fox_<branch>-pinned.xml`
2. **设备树** `manifests/orangefox-fox_<branch>-pinned.xml`（机型专属时放这里）

都没找到则回退到 `orangefox_sync.sh` 并告警。`SYNC_METHOD=sync-script`
时不查找清单，直接走同步脚本。

> 命中后若存在同名 `.sha256`，会先 `sha256sum --check --strict` 校验清单完整性。

> **换行符陷阱**：`.gitattributes` 的 `* text=auto` 会在提交时把 CRLF 归一化为
> LF，仓库里存的和 CI 检出的都是 **LF 内容**。所以 `.sha256` 必须按 LF 计算
> —— 在 Windows 上直接对 CRLF 工作区文件求哈希，记录的值与 Linux 检出的文件
> 不匹配，`sha256sum --check` 必然失败。`generate-pinned-manifest.sh` 已用
> `tr -d '\r'` 归一化，手工生成时也要照做。

## 桥接两种方式

| | `orangefox_sync.sh`（默认） | pinned manifest |
|---|---|---|
| 可复现 | 否 | 是 |
| 补丁配套 | 脚本自带，一定自洽 | 需自行补齐，可能与 revision 冲突 |
| 需要预先生成 | 否 | 是（一次性） |
| 上游更新 | 自动跟随 | 需手动重新生成 |
| 适用场景 | 首次移植、快速验证 | 稳定后、CI 长期构建 |

建议：移植阶段用同步脚本（默认），跑通后基于自己的同步结果生成 pinned
manifest 固化，再切 `SYNC_METHOD=pinned`。

## 注意事项

- pinned manifest **只锁定源码 revision，不包含橙狐补丁**。补丁需单独应用，
  由工作流的 `Apply OrangeFox setup patches` 步骤负责（仅 pinned 路径执行），
  共 4 个：build/make、system/vold、system/update_engine、vendor/twrp。
- 补丁打不上时，先对照 pinned manifest 的 revision 排查，**不要**用
  `git apply --reject` 忽略冲突。
- `sync` 脚本自身的 revision 也要固定（`SYNC_REVISION` 输入项），否则不同
  版本的补丁会得出不同结果。
- fox_14.1 完整源码约 662 个项目、85 GiB 左右，生成前确认磁盘充足。
