# 智能体项目说明

## 交流和文档约定

- 与用户交流时使用中文。
- 本项目中的说明文档、排障记录，以及 `AGENTS.md` 中的记录都应使用中文。
- 命令、配置项、日志原文、文件路径和代码符号保持原文，避免影响检索和排障。

## Waveshare ESP32-P4 WiFi6 Touch LCD 10.1

本项目已经在 Waveshare ESP32-P4 WiFi6 Touch LCD 10.1 开发板上验证过。该板子的关键信息如下：

- SKU：`esp32-p4-wifi6-touch-lcd`
- 芯片：`ESP32-P4`
- 芯片版本：`v1.3`
- 调试时使用过的串口：`/dev/cu.usbmodem5AE70675571`

这块板子优先使用 ESP-IDF `v5.5.2` 编译。之前使用 ESP-IDF `v5.5.4` 编译时，在该硬件上反复出现蓝屏或 LCD 显示异常。

## ESP32-P4 芯片版本配置

该硬件是 ESP32-P4 `v1.3`，所以必须按 v1.x 芯片配置构建，不能按 rev3 配置构建。相关配置应保持为：

```text
CONFIG_ESP32P4_SELECTS_REV_LESS_V3=y
CONFIG_ESP32P4_REV_MIN_1=y
CONFIG_ESP32P4_REV_MIN_FULL=1
CONFIG_ESP_REV_MIN_FULL=1
CONFIG_ESP32P4_REV_MAX_FULL=199
```

已验证可用的镜像入口信息：

- bootloader 入口：`0x4ff29ed0`
- app 入口：`0x4ff0054c`

如果设备在非常早期就重启，出现 `Illegal instruction`、`HP_SYS_HP_WDT_RESET`，或者只反复打印类似 `entry 0x4ff29ed0` 的 ROM 启动日志，优先检查上述芯片版本配置。

## PSRAM 配置

这块板子不要启用 PSRAM XIP。已验证可用的配置如下：

```text
CONFIG_SPIRAM_SPEED_200M=y
CONFIG_SPIRAM_SPEED=200
# CONFIG_SPIRAM_XIP_FROM_PSRAM is not set
```

已观察到的失败模式：

- `CONFIG_SPIRAM_XIP_FROM_PSRAM=y` 配合 PSRAM 80MHz 或 200MHz 时，可能在 `MSPI Timing: Enter psram timing tuning` 附近卡住或复位。
- PSRAM 20MHz 可以进入 app，但对 800x1280 MIPI LCD 路径太慢，容易触发 LCD underrun 和看门狗复位。

健康启动日志应包含：

```text
esp_psram: Speed: 200MHz
main_task: Calling app_main()
```

## LCD 和自定义 UI 资源

10.1 英寸 LCD 分辨率是 800x1280。不要在设备启动阶段解码全屏 PNG。之前排障时发现，启动时解码 PNG 背景会在 LVGL/lodepng 中产生大块内存分配和较慢的内存拷贝，进而导致 LCD underrun 和看门狗复位。

背景图应使用原始 RGB565 资源。当前自定义背景路径为：

```text
main/assets/custom/xcmg_background.rgb565
```

该资源预期为 400x640 RGB565，并由 LVGL 缩放填充到 800x1280 屏幕。修改源图时，应先用用户指定的 PNG/JPG 重新生成该 RGB565 文件，再重新编译固件。不要把全屏 PNG 直接作为启动背景交给 LVGL 解码，否则容易在 `taskLVGL` 中触发 `lodepng` 长时间解码和 `task_wdt`。

在 macOS 上可以按以下方式从 800x1280 PNG 生成 400x640 RGB565：

```sh
sips -z 640 400 -s format bmp main/assets/custom/xcmg_background_fullscreen.png --out /private/tmp/xcmg_background_400x640.bmp
python3 - <<'PY'
from pathlib import Path
import struct
bmp = Path('/private/tmp/xcmg_background_400x640.bmp').read_bytes()
off = struct.unpack_from('<I', bmp, 10)[0]
width = struct.unpack_from('<i', bmp, 18)[0]
height_signed = struct.unpack_from('<i', bmp, 22)[0]
bpp = struct.unpack_from('<H', bmp, 28)[0]
compression = struct.unpack_from('<I', bmp, 30)[0]
if bpp != 32 or compression != 3:
    raise SystemExit(f'unsupported BMP: bpp={bpp} compression={compression}')
height = abs(height_signed)
bottom_up = height_signed > 0
out = bytearray()
for y in range(height):
    src_y = height - 1 - y if bottom_up else y
    row = off + src_y * width * 4
    for x in range(width):
        px = row + x * 4
        b, g, r, a = bmp[px], bmp[px + 1], bmp[px + 2], bmp[px + 3]
        if a != 255:
            r = (r * a + 255 * (255 - a)) // 255
            g = (g * a + 255 * (255 - a)) // 255
            b = (b * a + 255 * (255 - a)) // 255
        v = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        out.extend(struct.pack('<H', v))
Path('main/assets/custom/xcmg_background.rgb565').write_bytes(out)
PY
```

生成后要强制刷新嵌入资源的编译单元：

```sh
touch main/assets/custom_assets.cc
```

健康日志示例：

```text
LcdDisplay: Custom RGB565 background loaded: 400x640 data_size=512000
LcdDisplay: Custom background applied: image=400x640 screen=800x1280 scale=512
```

自定义动态表情资源路径为：

```text
main/assets/custom/button.gif
```

健康日志示例：

```text
LcdDisplay: Custom GIF emoji loaded
LcdDisplay: SetEmotion('gear'): custom image hit, is_gif=1
LcdDisplay: SetEmotion('gear'): GIF loaded
```

## 需要保留的用户定制功能

除非用户明确要求删除，否则保留以下定制：

- 唤醒词显示为：`你好，小徐`
- 自定义唤醒词配置 token：`ni hao xiao xu`
- 聊天或消息文字显示在表情包/GIF 区域下方。
- 浅色和深色模式都使用同一张用户上传的自定义背景图。
- 自定义 GIF 在适用位置替换默认表情。
- LCD 诊断日志和临时 3 秒色调测试应保持移除状态。

## 编译、合并、烧录和查看启动日志

以下命令默认在仓库根目录 `/Users/xuaiai/repository/xiaozhi-esp32` 执行。该板子优先使用 ESP-IDF `v5.5.2`。

### 加载 ESP-IDF 环境

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
```

### 编译固件

普通编译：

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -DIDF_TARGET=esp32p4 build
```

清理后重新编译：

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -DIDF_TARGET=esp32p4 fullclean build
```

如果只想删除常见编译产物后再重新编译：

```sh
rm -rf build managed_components dependencies.lock
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -DIDF_TARGET=esp32p4 build
```

### 编译后核对配置

烧录前先核对芯片版本、PSRAM 速度和 PSRAM XIP：

```sh
rg -n "SPIRAM_SPEED|SPIRAM_XIP_FROM_PSRAM|ESP32P4_REV_MIN|ESP_REV_MIN_FULL|ESP32P4_REV_MAX_FULL" sdkconfig build/config/sdkconfig.json build/bootloader/config/sdkconfig.json
```

预期结果包括：

```text
CONFIG_ESP32P4_REV_MIN_1=y
CONFIG_ESP32P4_REV_MIN_FULL=1
CONFIG_ESP_REV_MIN_FULL=1
CONFIG_SPIRAM_SPEED_200M=y
CONFIG_SPIRAM_SPEED=200
# CONFIG_SPIRAM_XIP_FROM_PSRAM is not set
```

核对 bootloader 和 app 镜像入口：

```sh
python -m esptool --chip esp32p4 image_info build/bootloader/bootloader.bin
python -m esptool --chip esp32p4 image_info build/xiaozhi.bin
```

预期入口：

```text
bootloader entry point: 0x4ff29ed0
app entry point: 0x4ff0054c
```

### 合并单文件固件

按项目分区偏移合并单文件固件：

```sh
python -m esptool --chip esp32p4 merge_bin \
  -o build/xiaozhi_esp32p4_10_1_idf552_psram200_no_xip_rgb565_bg.bin \
  --flash_mode dio --flash_freq 80m --flash_size 16MB \
  0x2000 build/bootloader/bootloader.bin \
  0x8000 build/partition_table/partition-table.bin \
  0xd000 build/ota_data_initial.bin \
  0x20000 build/xiaozhi.bin \
  0xa20000 build/generated_assets.bin
```

### 擦除 flash

需要彻底清空设备时执行：

```sh
python -m esptool --chip esp32p4 --port /dev/cu.usbmodem5AE70675571 --baud 460800 erase_flash
```

擦除后首次启动出现 `SsidManager: NVS namespace wifi doesn't exist` 属于预期现象。

### 烧录固件

方式一：使用 ESP-IDF 按分区烧录：

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -B build -p /dev/cu.usbmodem5AE70675571 flash
```

方式二：使用 `esptool` 按分区烧录：

```sh
python -m esptool --chip esp32p4 -b 460800 --before default_reset --after hard_reset write_flash \
  --flash_mode dio --flash_size 16MB --flash_freq 80m \
  0x2000 build/bootloader/bootloader.bin \
  0x8000 build/partition_table/partition-table.bin \
  0xd000 build/ota_data_initial.bin \
  0x20000 build/xiaozhi.bin \
  0xa20000 build/generated_assets.bin
```

方式三：将合并后的单文件镜像烧录到 `0x0`：

```sh
python -m esptool --chip esp32p4 --port /dev/cu.usbmodem5AE70675571 --baud 460800 write_flash -z \
  --flash_mode dio --flash_freq 80m --flash_size 16MB \
  0x0 build/xiaozhi_esp32p4_10_1_idf552_psram200_no_xip_rgb565_bg.bin
```

### 重启设备

通过 `esptool` 触发硬复位：

```sh
python -m esptool --chip esp32p4 --port /dev/cu.usbmodem5AE70675571 --after hard_reset chip_id
```

也可以直接按硬件复位键，然后打开 monitor 查看启动日志。

### 查看固件启动日志

使用 `idf.py monitor` 查看启动日志：

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -B build -p /dev/cu.usbmodem5AE70675571 monitor
```

退出 monitor 使用 `Ctrl+]`。

如果需要先烧录再立刻查看启动日志：

```sh
source /Users/xuaiai/esp/esp-idf-v5.5.2/export.sh
idf.py -B build -p /dev/cu.usbmodem5AE70675571 flash monitor
```

查看日志时重点确认：

```text
ESP-IDF:          v5.5.2
Chip rev:         v1.3
esp_psram: Speed: 200MHz
main_task: Calling app_main()
LcdDisplay: Custom RGB565 background loaded
LcdDisplay: Custom GIF emoji loaded
LcdDisplay: Custom background applied
```

## 常见日志判断

- `Detected size(32768k) larger than the size in the binary image header(16384k)`：板载 flash 是 32MB，而固件镜像按 16MB 构建时会出现该提示，属于预期现象。
- `SsidManager: NVS namespace wifi doesn't exist`：擦除 flash 或首次启动后属于预期现象，设备会进入配网模式。
- ES7210 I2C 初始化偶发失败可能出现在启动过程中。如果下一次启动能到达 `AudioCodec: Audio codec started`，它不是 LCD 或 bootloader 问题。
- 如果 LCD 已经初始化，但随后在 `box_audio_codec.cc` 断言，应单独检查 ES7210 I2C 或音频设备初始化，不要和 bootloader/LCD 问题混在一起判断。
