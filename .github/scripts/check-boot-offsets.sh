#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 在编译之前校验设备树的 boot/vendor_boot 镜像地址, 避免把几十分钟的构建
# 浪费在一个必然失败的打包步骤上。
#
# 坑 (pd2415 真实踩过, dali 参考树上看不出来):
#   unpack_bootimg 输出的 vendor_boot.json 里 kernel/ramdisk/tags/dtb 是
#   **绝对加载地址**, 而 mkbootimg 的 --*_offset 是 **相对 --base 的偏移**。
#   mkbootimg 写入 header 的是 base + offset, 存进 32 位 'I' 字段。把绝对
#   地址当偏移传进去:
#       base 0x80000000 + ramdisk_offset 0xa4d00000 = 0x124D00000  -> 溢出
#   mkbootimg 在最后一个 ninja target 上抛:
#       struct.error: 'I' format requires 0 <= number <= 4294967295
#   而此时前面 18000+ 个 target 已经全部跑完, 全部白跑。
#
#   dali 的 base 是 0x00000000, 绝对地址 == 相对偏移, 照抄不会出问题;
#   pd2415 的 base 是 0x80000000, 照抄必炸。所以这个检查不能省。
#
# 用法: check-boot-offsets.sh <BoardConfig.mk> [更多 BoardConfig.mk ...]
# 退出码: 0 = 通过; 1 = 存在必然失败的偏移; 2 = 用法错误

set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "用法: $0 <BoardConfig.mk> [更多 BoardConfig.mk ...]" >&2
  echo "(在 GitHub Actions 里把 echo 换成 ::error:: 前缀即可)" >&2
  exit 2
fi

for config in "$@"; do
  if [[ ! -f "$config" ]]; then
    echo "BoardConfig 不存在: $config" >&2
    exit 2
  fi
done

python3 - "$@" <<'PY'
import os
import re
import sys

UINT32_LIMIT = 1 << 32

# mkbootimg 会把这些 *_offset 与 --base 相加后写进 32 位 header 字段。
OFFSET_KEYS = (
    'kernel_offset',
    'ramdisk_offset',
    'second_offset',
    'tags_offset',
    'dtb_offset',
    'dtbo_offset',
)


def join_continuations(text):
    """把反斜杠续行合并, 便于用单行正则匹配多行变量。"""
    lines = []
    buf = ''
    for raw in text.splitlines():
        stripped = raw.rstrip()
        if stripped.endswith('\\'):
            buf += stripped[:-1]
            continue
        lines.append(buf + stripped)
        buf = ''
    if buf:
        lines.append(buf)
    return '\n'.join(lines)


def scalar(text, name):
    match = re.search(
        r'^[ \t]*' + re.escape(name) + r'[ \t]*:?=[ \t]*(.+?)[ \t]*$',
        text,
        re.M,
    )
    if not match:
        return None
    value = match.group(1).split('#', 1)[0].strip()
    return value or None


def numeric(text, name):
    value = scalar(text, name)
    if value is None:
        return None
    if not re.fullmatch(r'(0[xX][0-9a-fA-F]+|[0-9]+)', value):
        return None
    return int(value, 0)


def parse_mkbootimg_args(text):
    """取出 BOARD_MKBOOTIMG_ARGS 里的 --base / --*_offset。"""
    value = scalar(text, 'BOARD_MKBOOTIMG_ARGS') or ''
    found = {}
    for key, raw in re.findall(r'--([A-Za-z0-9_]+)(?:[= \t]+)(0[xX][0-9a-fA-F]+|[0-9]+)', value):
        found.setdefault(key, int(raw, 0))
    return found


def hexs(value):
    return '0x%08X' % value


failed = False
checked = 0

for path in sys.argv[1:]:
    with open(path, 'r', encoding='utf-8', errors='replace') as stream:
        text = join_continuations(stream.read())

    args = parse_mkbootimg_args(text)
    # --base 优先于 BOARD_KERNEL_BASE (mkbootimg 的行为)。
    base = args.get('base')
    if base is None:
        base = numeric(text, 'BOARD_KERNEL_BASE')
    if base is None:
        base = 0
        print('WARNING: %s 未定义 BOARD_KERNEL_BASE 且 BOARD_MKBOOTIMG_ARGS 无 --base, 按 0 计算' % path)

    device_dir = os.path.dirname(os.path.abspath(path))
    print('=== %s ===' % path)
    print('base             : %s' % hexs(base))
    print('pagesize         : %s' % (numeric(text, 'BOARD_KERNEL_PAGESIZE') or '未设置'))
    for key in ('BOARD_BOOTIMAGE_PARTITION_SIZE',
                'BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE',
                'BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE'):
        value = numeric(text, key)
        if value is not None:
            print('%-34s: %d (%d MiB)' % (key, value, value // 1024 // 1024))

    offsets = [(k, args[k]) for k in OFFSET_KEYS if k in args]
    if not offsets:
        print('WARNING: BOARD_MKBOOTIMG_ARGS 里没有任何 --*_offset, 无法校验; 跳过')
        print()
        continue

    checked += 1
    for key, offset in offsets:
        absolute = base + offset
        status = 'OK'
        if absolute >= UINT32_LIMIT:
            status = 'OVERFLOW'
            failed = True
        print('  %-16s offset=%s -> absolute=%s  %s' % (key, hexs(offset), hexs(absolute), status))

    # 与 package-vendor-boot.sh 的一致性: 两处分区大小必须相同, 否则
    # 组装脚本会在最后一步 (写 AVB 尾) 才发现尺寸不符。
    packer = os.path.join(device_dir, 'package-vendor-boot.sh')
    if os.path.isfile(packer):
        with open(packer, 'r', encoding='utf-8', errors='replace') as stream:
            packer_text = stream.read()
        board_size = numeric(text, 'BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE')
        packer_size = None
        match = re.search(r'^PARTITION_SIZE=(\d+)', packer_text, re.M)
        if match:
            packer_size = int(match.group(1))
        if board_size is not None and packer_size is not None and board_size != packer_size:
            print('WARNING: 分区大小不一致: BoardConfig.mk=%d, package-vendor-boot.sh=%d'
                  % (board_size, packer_size))
    print()

if failed:
    print('ERROR: 存在溢出 32 位的镜像地址。')
    print('ERROR: vendor_boot.json 里的地址是**绝对加载地址**, 而 --*_offset 是相对 --base 的偏移。')
    print('ERROR: 请先把绝对地址减去 BOARD_KERNEL_BASE 再填入 BOARD_MKBOOTIMG_ARGS, 使 base + offset 保持不变。')
    sys.exit(1)

if not checked:
    # 没查到任何 offset 时绝不能报"通过" —— 那会让人以为校验过了。
    print('ERROR: 没有任何 BoardConfig 提供 --*_offset, 校验无法进行。')
    print('ERROR: 若这是尚未填写占位符的模板, 请先填好 BOARD_MKBOOTIMG_ARGS 再跑本脚本。')
    sys.exit(2)

print('镜像地址校验通过: 所有 base + offset 均 < 2^32。')
PY
