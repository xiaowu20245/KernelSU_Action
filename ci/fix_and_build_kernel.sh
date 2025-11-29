#!/usr/bin/env bash
set -euo pipefail

DEFCONFIG="${1:-${KERNEL_CONFIG:-}}"
if [ -z "${DEFCONFIG}" ]; then
  echo "Usage: $0 <defconfig>  (or set KERNEL_CONFIG env var)"
  exit 2
fi

if [ ! -f "Makefile" ]; then
  echo "Error: Not in kernel source root!"
  exit 3
fi

echo "Using defconfig: $DEFCONFIG"

# 生成原始配置
make CC=clang O=out ARCH=${ARCH:-arm64} ${DEFCONFIG}

echo "Patching out/.config for raphael (SDM855) CPU masks + KSU..."

# 删除旧值
sed -i '/^CONFIG_LITTLE_CPU_MASK=/d' out/.config || true
sed -i '/^CONFIG_BIG_CPU_MASK=/d' out/.config || true
sed -i '/^CONFIG_KSU=/d' out/.config || true
sed -i '/^CONFIG_MODULES=/d' out/.config || true
sed -i '/^CONFIG_KPROBES=/d' out/.config || true

# 追加适配 raphael 的 CPU mask + KernelSU 选项
cat >> out/.config <<'EOF'
# CPU mask for Raphael (SDM855)
CONFIG_LITTLE_CPU_MASK=0x0f
CONFIG_BIG_CPU_MASK=0xf0

# KernelSU support
CONFIG_MODULES=y
CONFIG_KPROBES=y
CONFIG_KSU=y
EOF

# oldconfig (不会再询问)
yes "" | make CC=clang O=out ARCH=${ARCH:-arm64} oldconfig

echo "Building kernel now..."
make -j$(nproc --all) CC=clang O=out ARCH=${ARCH:-arm64} ${CUSTOM_CMDS:-} ${EXTRA_CMDS:-} ${GCC_64:-} ${GCC_32:-}

if [ "${ENABLE_CCACHE:-false}" = "true" ]; then
  make -j$(nproc --all) CC="ccache clang" O=out ARCH=${ARCH:-arm64} ${CUSTOM_CMDS:-} ${EXTRA_CMDS:-} ${GCC_64:-} ${GCC_32:-}
fi

echo "Build finished for raphael."
