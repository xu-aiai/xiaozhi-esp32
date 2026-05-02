extern "C" {
asm(
    ".section .rodata\n"
    ".global xiaozhi_custom_background_rgb565_start\n"
    "xiaozhi_custom_background_rgb565_start:\n"
    ".incbin \"/Users/xuaiai/repository/xiaozhi-esp32/main/assets/custom/xcmg_background.rgb565\"\n"
    ".global xiaozhi_custom_background_rgb565_end\n"
    "xiaozhi_custom_background_rgb565_end:\n"
    ".balign 4\n"
    ".global xiaozhi_custom_button_gif_start\n"
    "xiaozhi_custom_button_gif_start:\n"
    ".incbin \"/Users/xuaiai/repository/xiaozhi-esp32/main/assets/custom/button.gif\"\n"
    ".global xiaozhi_custom_button_gif_end\n"
    "xiaozhi_custom_button_gif_end:\n"
);
}
