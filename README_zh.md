## 基于 Github Action 的 TWRP 自动编译

## 推广

1. OrangeFox 编译模板在[这里](https://github.com/azwhikaru/Action-OFRP-Builder)

## 注意事项

1. Github Actions 服务**并非**无限使用，为避免浪费，请勿在其中使用未经验证的源代码。本模板最适合用于自动化编译已经稳定的代码仓库。

2. 在进行任何修改之前，请确保你操作的仓库属于你自己。如果要提交代码请点击 **"Fork"**，否则请使用 **"Use this template"（使用此模板）**。

3. issues 和 Pull Requests 可能**不会**得到回复。如果你认为确实有必要，请通过我个人资料中的邮箱联系我。

4. Debian（Ubuntu）中的 Python 2 已被**移除**。如果你在编译 Android 8.1 及以下的系统，请使用 *Recovery Build (Legacy)*（旧版 Recovery 编译）。

5. 请勿向我询问任何关于你源码的问题，例如：
	- No rule to make ...（没有规则来生成……）
	- Image ... out of size（镜像……超出大小）

## 致谢

感谢所有贡献者。

## 参数说明

| 名称                 | 说明                                       | 示例                                                       |
| -------------------- | ------------------------------------------ | ---------------------------------------------------------- |
| `MANIFEST_URL`       | 源码地址                                   | https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git |
| `MANIFEST_BRANCH`    | 源码分支                                   | twrp-12.1                                                  |
| `DEVICE_TREE_URL`    | 设备树地址                                 | https://github.com/TeamWin/android_device_asus_I003D       |
| `DEVICE_TREE_BRANCH` | 设备树分支                                 | android-12.1                                               |
| `DEVICE_PATH`        | 设备所在路径                               | device/asus/I003D                                          |
| `COMMON_TREE_URL`    | 公共（common）设备树地址                   | https://github.com/TeamWin/android_device_asus_sm8250-common |
| `COMMON_PATH`        | 公共设备树所在路径                         | device/asus/sm8250-common                                  |
| `DEVICE_NAME`        | 机型名称                                   | I003D                                                      |
| `MAKEFILE_NAME`      | Makefile 名称                              | twrp_I003D                                                 |
| `BUILD_TARGET`       | 编译目标分区（boot/recovery/vendorboot）   | recovery                                                   |

-----

## 使用方法

```
例如，你的用户名是：JohnSmith
```

#### 0. 如果你要提交代码，请点击本仓库右上角的 'Fork'

![image](https://user-images.githubusercontent.com/37921907/177914706-c92476c5-7e14-4fb3-be94-0c8a11dae874.png)

#### 1. 如果你只是想简单使用，请点击本仓库右上角的 'Use this template'（使用此模板）

![image](https://github.com/azwhikaru/Action-TWRP-Builder/assets/37921907/fae6ce3c-bd4c-4bbe-8050-5dd29dff2522)

#### 2. 等待自动跳转后，你会看到你自己的用户名

![image](https://user-images.githubusercontent.com/37921907/177915106-5bde6fc9-303c-479e-b290-22b48efd1e4e.png)

#### 3. 将 workflow 中的 [用户名和邮箱](https://github.com/CaptainThrowback/Action-Recovery-Builder/blob/main/.github/workflows/Recovery%20Build.yml#L100-L101) 修改为你的 Github 凭据（可选）

## 配置 SSH 密钥（可选）

#### 4. 进入 Settings（设置），选择 Deploy keys（部署密钥），然后点击 "Add deploy key" 按钮。

#### 5. 在你的 Android 设备上，安装 [Termux](https://github.com/termux/termux-app/releases)

#### 6. 在 Termux 中安装 openssh 并生成 ssh 密钥（密钥不要设置密码）。

注意：为形如 git@github.com:owner/repo.git 或 https://github.com/owner/repo 的仓库创建部署密钥时，请将该 URL 写入密钥的注释中。（提示：尝试 `ssh-keygen ... -C "git@github.com:owner/repo.git"`。）
owner = 你的 Github 用户名

```
pkg install openssh
ssh-keygen -t ed25519 -C "git@github.com:owner/Action-Recovery-Builder.git"
```

#### 7. 将密钥添加到你的仓库中。在 Termux 中使用以下命令：

```
cd /data/data/com.termux/files/usr/etc/ssh
cat ssh_host_ed25519_key.pub
```

  选中并复制密钥内容，然后粘贴到 Key 的输入框中。
  标题（title）可以任意命名。

#### 8. 现在添加你的私钥。回到 Termux：

```
cat ssh_host_ed25519_key
```

   复制 Termux 中的输出内容。

   在浏览器中，选择 Security（安全）选项卡下的 *Secrets*（密钥）。
   选择 Actions
   选择 New repository secret（新建仓库密钥）
   密钥名称填写 SSH_PRIVATE_KEY
   将 ssh_host_ed25519_key 的输出内容粘贴到 Value（值）框中。
   然后点击 Add secret（添加密钥）。

## 编译 Recovery

#### 9. 点击 'Actions - Recovery Build'

![image](https://user-images.githubusercontent.com/37921907/177915304-8731ed80-1d49-48c9-9848-70d0ac8f2720.png)

#### 10. 点击 'Run workflow'（运行工作流），并根据上面的"参数说明"填写

![image](https://user-images.githubusercontent.com/37921907/177915346-71c29149-78fb-4a00-996f-5d84ffc9eb8c.png)

#### 11. 填写完成后，点击 'Run workflow' 开始运行

> ⚠️ **不要用 "Re-run job"（重新运行任务）来应用新提交**
>
> GitHub 的 Re-run 会**复用原运行时的 commit SHA**，不会拉取最新代码。
> 结果是新推送的修复完全不生效，你会对着一个早已修好的错误反复排查。
>
> 每次修改代码后，都要回到 **Run workflow** 重新触发。
>
> 判断是否生效：查看日志里的 **Report source versions** 步骤，它会打印
> 实际使用的 `builder` 与 `device` 两个仓库的 commit SHA 和提交时间，
> 与本地 `git log` 比对即可确认。

-----

## 编译结果

可在 [Release](../../releases) 中下载。

-----
