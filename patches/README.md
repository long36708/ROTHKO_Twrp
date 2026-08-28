# OrangeFox 源码补丁

pinned manifest **只锁定 revision，不记录工作区补丁**，所以 `SYNC_METHOD=pinned`
路径必须靠这里的文件把橙狐改动补回去。

## 来源

均复制自 rodin 设备树：

```text
F:\learn-front\learn-hook\vivo-twrp\orangefox_twrp_device_xiaomi_rodin\patches\
```

rodin 的 pinned manifest 与我们**完全相同**（662 个项目，同一批 revision），
所以这些补丁能直接打到我们的源码树上。

## 已复制（2 个）

### `orangefox-build-make.patch` → `build/make`

12068 字节，改 3 个文件。**这是最关键的一个**：

```diff
+  # broken plugins global support
+  BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults
+                                    soong-libguitwrp_defaults
+                                    soong-libminuitwrp_defaults
+                                    soong-vold_defaults
```

缺了它，soong 引导会失败：

```
internal error: New plugins are not supported; however
["soong-libaosprecovery_defaults" "soong-libguitwrp_defaults"
 "soong-libminuitwrp_defaults" "soong-vold_defaults"] were found.
```

### `orangefox-vendor-twrp.patch` → `vendor/twrp`

2083 字节，改 2 个文件：

- `BoardConfigSoong.mk` 引入 `bootable/recovery/orangefox_soong.mk`，
  并新增 `tw_drm_blank_keep_pipeline` 配置变量
- `vendor_twrp.mk` 相应调整

## 未复制（1 个）及原因

### ❌ `orangefox-recovery.patch` → `bootable/recovery`

58057 字节、20 个文件。其中 **16 个文件是通用橙狐改动，但 4 个含 rodin 硬件专属
内容**，对 MTK 平台的 pd2415 是错的：

| 文件 | rodin 专属改动 |
|---|---|
| `gui/action.cpp` | SIH6887 马达挂 I2C 总线 |
| `gui/theme/portrait_hdpi/pages/mount.xml` | OTG VBUS 供电注释 |
| `minuitwrp/events.cpp` | Type-C 主机模式 / VBUS 使能 |
| `partitionmanager.cpp` | Type-C 角色切换 |

这些是 rodin 的 OT 口供电与震动马达方案，与 pd2415 无关。整包复制会带来
编译风险（`action.cpp` 引用的头文件可能不存在）和运行期误动作。

**取舍**：这 16 个通用改动主要是橙狐的功能增强与修复，不影响构建能否通过；
而 4 个专属改动有实际风险。所以整体跳过——先保证能编出可启动的镜像。

后续若需要那 16 个通用改动，正确做法是逐文件拆分：保留 0 处 rodin 引用的
文件，或手工剔除上述 4 处 hunk。

## 为什么不用 OrangeFox/sync 仓库的补丁

`OrangeFox/sync` 自带 `patches/patch-manifest-fox_14.1.diff`（作用于
`build/make`）、`patch-vold-fox_14.1.diff`、`patch-update-engine-fox_14.1.diff`。

但 `patch-manifest-fox_14.1.diff` 是针对 **TeamWin minimal manifest** 的 build
项目生成的，而本清单里 `build/make` 是 **nebrassy 的 `android_build`**
（`506df226`）——base 不同，打不上。这正是 rodin 要自己维护补丁的原因。

## 更新补丁

上游 revision 变动后，补丁会打不上，工作流会报：

```
::error::补丁无法应用 <patch> -> <target>
::error::通常是 pinned revision 与该补丁所基于的源码不一致,
改用 SYNC_METHOD=sync-script 或重新生成 pinned manifest
```

此时要么重新生成 pinned manifest 并同步更新补丁，要么临时切
`SYNC_METHOD=sync-script` 兜底。
