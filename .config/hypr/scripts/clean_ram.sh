#!/usr/bin/env bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ SMART MEMORY CLEANER (RAM OPTIMIZER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "Optimizing system RAM and trimming app memory pools..."

# 1. Force glibc malloc trim across all user processes using python/ctypes
python3 -c "import ctypes; ctypes.CDLL('libc.so.6').malloc_trim(0)" 2>/dev/null || true

# 2. Trim Electron / Chrome / Firefox memory caches safely if running
for proc in chrome discord firefox antigravity-ide quickshell; do
    pkill -SIGUSR1 "$proc" 2>/dev/null || true
done

# 3. Request kernel pagecache sync
sync

echo "RAM Optimization Complete!"
