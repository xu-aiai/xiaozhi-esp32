#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC_GIF="${1:-/Users/xuaiai/Pictures/小徐表情包/动图/02_happy/1777787487711.gif}"
BG_IMAGE="${2:-${ROOT_DIR}/main/assets/custom/xcmg_background_fullscreen.png}"
OUT_GIF="${3:-${ROOT_DIR}/main/assets/custom/default_emoji.gif}"

SCREEN_W="${SCREEN_W:-800}"
SCREEN_H="${SCREEN_H:-1280}"
SIZE="${SIZE:-360}"
OFFSET_X="${OFFSET_X:-0}"
OFFSET_Y="${OFFSET_Y:-0}"
DELAY_CS="${DELAY_CS:-24}"
MODE="${MODE:-sticker}"
FUZZ="${FUZZ:-14%}"
SCENE_FUZZ="${SCENE_FUZZ:-26%}"
SCENE_BLEND_INSET="${SCENE_BLEND_INSET:-14}"
SCENE_BLEND_BLUR="${SCENE_BLEND_BLUR:-0x22}"
GLOW_COLOR="${GLOW_COLOR:-#24B8FF}"
GLOW_BLUR="${GLOW_BLUR:-0x5}"
GLOW_OPACITY="${GLOW_OPACITY:-0.18}"
CROP_SIZE="${CROP_SIZE:-900}"
CROP_OFFSET_X="${CROP_OFFSET_X:-+0}"
CROP_OFFSET_Y="${CROP_OFFSET_Y:-+0}"
FEATHER="${FEATHER:-34}"
FEATHER_BLUR="${FEATHER_BLUR:-0x18}"
TMP_DIR="${TMP_DIR:-/private/tmp/xiaozhi_emoji_compose}"

if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick 'magick' is required." >&2
    exit 1
fi

if [[ ! -e "${SRC_GIF}" ]]; then
    echo "Source GIF not found: ${SRC_GIF}" >&2
    exit 1
fi

if [[ "${MODE}" != "scene" && "${MODE}" != "scene-cutout" && ! -f "${BG_IMAGE}" ]]; then
    echo "Background image not found: ${BG_IMAGE}" >&2
    exit 1
fi

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}/frames" "${TMP_DIR}/cut" "${TMP_DIR}/glow_mask" "${TMP_DIR}/glow" "${TMP_DIR}/mask" "${TMP_DIR}/composed"

PATCH_X=$(( (SCREEN_W - SIZE) / 2 + OFFSET_X ))
PATCH_Y=$(( (SCREEN_H - SIZE) / 2 + OFFSET_Y ))

echo "Source GIF: ${SRC_GIF}"
echo "Background: ${BG_IMAGE}"
echo "Output GIF: ${OUT_GIF}"
echo "Patch: ${SIZE}x${SIZE}+${PATCH_X}+${PATCH_Y} on ${SCREEN_W}x${SCREEN_H}"
echo "Mode: ${MODE}"

if [[ "${MODE}" == "scene" || "${MODE}" == "scene-cutout" || "${MODE}" == "scene-blend" ]]; then
    if [[ "${MODE}" == "scene-blend" ]]; then
        magick "${BG_IMAGE}" \
            -resize "${SCREEN_W}x${SCREEN_H}^" \
            -gravity center \
            -extent "${SCREEN_W}x${SCREEN_H}" \
            "${TMP_DIR}/bg_screen.png"

        magick "${TMP_DIR}/bg_screen.png" \
            -crop "${SIZE}x${SIZE}+${PATCH_X}+${PATCH_Y}" \
            +repage \
            "${TMP_DIR}/bg_patch.png"

        center=$(( SIZE / 2 ))
        radius_x=$(( center - SCENE_BLEND_INSET ))
        radius_y=$(( center - SCENE_BLEND_INSET ))
        magick -size "${SIZE}x${SIZE}" xc:black \
            -fill white \
            -draw "ellipse ${center},${center} ${radius_x},${radius_y} 0,360" \
            -blur "${SCENE_BLEND_BLUR}" \
            "${TMP_DIR}/mask/scene_blend.png"
    fi

    if [[ -n "${SRC_FRAMES:-}" ]]; then
        while IFS= read -r frame; do
            [[ -n "${frame}" ]] && printf '%s\n' "${frame}"
        done <<< "${SRC_FRAMES}" > "${TMP_DIR}/frame_list.txt"
    elif [[ -f "${SRC_GIF}" && "${SRC_GIF}" == *.txt ]]; then
        cp "${SRC_GIF}" "${TMP_DIR}/frame_list.txt"
    elif [[ -d "${SRC_GIF}" ]]; then
        find "${SRC_GIF}" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort > "${TMP_DIR}/frame_list.txt"
    elif [[ -f "${SRC_GIF}" && "${SRC_GIF,,}" == *.gif ]]; then
        magick "${SRC_GIF}" -coalesce "${TMP_DIR}/frames/frame_%03d.png"
        : > "${TMP_DIR}/frame_list.txt"
    else
        printf '%s\n' "${SRC_GIF}" > "${TMP_DIR}/frame_list.txt"
    fi

    index=0
    while IFS= read -r frame; do
        [[ -z "${frame}" ]] && continue
        if [[ ! -f "${frame}" ]]; then
            echo "Frame not found: ${frame}" >&2
            exit 1
        fi
        out_frame="${TMP_DIR}/frames/frame_$(printf '%03d' "${index}").png"
        magick "${frame}" \
            -resize "${SIZE}x${SIZE}^" \
            -gravity center \
            -extent "${SIZE}x${SIZE}" \
            "${out_frame}"
        if [[ "${MODE}" == "scene-cutout" ]]; then
            max_xy=$(( SIZE - 1 ))
            magick "${out_frame}" \
                -alpha set \
                -background none \
                -fill none \
                -fuzz "${SCENE_FUZZ}" \
                -draw "color 0,0 floodfill" \
                -draw "color ${max_xy},0 floodfill" \
                -draw "color 0,${max_xy} floodfill" \
                -draw "color ${max_xy},${max_xy} floodfill" \
                "${out_frame}"
        elif [[ "${MODE}" == "scene-blend" ]]; then
            name="$(basename "${out_frame}")"
            cut="${TMP_DIR}/cut/${name}"
            magick "${out_frame}" \
                "${TMP_DIR}/mask/scene_blend.png" \
                -alpha off \
                -compose CopyOpacity \
                -composite \
                "${cut}"
            magick "${TMP_DIR}/bg_patch.png" \
                "${cut}" -compose over -composite \
                "${out_frame}"
        fi
        index=$((index + 1))
    done < "${TMP_DIR}/frame_list.txt"

    if [[ "${index}" -eq 0 && -z "$(find "${TMP_DIR}/frames" -type f -name 'frame_*.png' -print -quit)" ]]; then
        echo "No input frames found for scene mode." >&2
        exit 1
    fi

    magick -delay "${DELAY_CS}" -loop 0 "${TMP_DIR}"/frames/frame_*.png -layers Optimize "${OUT_GIF}"
elif [[ "${MODE}" == "framed" ]]; then
    magick "${BG_IMAGE}" \
        -resize "${SCREEN_W}x${SCREEN_H}^" \
        -gravity center \
        -extent "${SCREEN_W}x${SCREEN_H}" \
        "${TMP_DIR}/bg_screen.png"

    magick "${TMP_DIR}/bg_screen.png" \
        -crop "${SIZE}x${SIZE}+${PATCH_X}+${PATCH_Y}" \
        +repage \
        "${TMP_DIR}/bg_patch.png"

    magick "${SRC_GIF}" \
        -coalesce \
        -gravity center \
        -crop "${CROP_SIZE}x${CROP_SIZE}${CROP_OFFSET_X}${CROP_OFFSET_Y}" \
        +repage \
        -resize "${SIZE}x${SIZE}" \
        "${TMP_DIR}/frames/frame_%03d.png"

    INNER_MAX=$(( SIZE - FEATHER - 1 ))
    magick -size "${SIZE}x${SIZE}" xc:black \
        -fill white \
        -draw "rectangle ${FEATHER},${FEATHER} ${INNER_MAX},${INNER_MAX}" \
        -blur "${FEATHER_BLUR}" \
        "${TMP_DIR}/mask/edge_feather.png"
else
    magick "${BG_IMAGE}" \
        -resize "${SCREEN_W}x${SCREEN_H}^" \
        -gravity center \
        -extent "${SCREEN_W}x${SCREEN_H}" \
        "${TMP_DIR}/bg_screen.png"

    magick "${TMP_DIR}/bg_screen.png" \
        -crop "${SIZE}x${SIZE}+${PATCH_X}+${PATCH_Y}" \
        +repage \
        "${TMP_DIR}/bg_patch.png"

    magick "${SRC_GIF}" -coalesce -resize "${SIZE}x${SIZE}" "${TMP_DIR}/frames/frame_%03d.png"
fi

if [[ "${MODE}" != "scene" && "${MODE}" != "scene-cutout" && "${MODE}" != "scene-blend" ]]; then
for frame in "${TMP_DIR}"/frames/frame_*.png; do
    name="$(basename "${frame}")"
    cut="${TMP_DIR}/cut/${name}"
    glow_mask="${TMP_DIR}/glow_mask/${name}"
    glow="${TMP_DIR}/glow/${name}"
    out="${TMP_DIR}/composed/${name}"

    if [[ "${MODE}" == "framed" ]]; then
        # This mode is for full-scene GIFs that already include a dark tech
        # background. Crop tighter to enlarge the character, then feather the
        # square edges into the current UI background patch.
        magick "${frame}" \
            "${TMP_DIR}/mask/edge_feather.png" \
            -alpha off \
            -compose CopyOpacity \
            -composite \
            "${cut}"

        magick "${TMP_DIR}/bg_patch.png" \
            "${cut}" -compose over -composite \
            "${out}"
        continue
    fi

    # Remove the near-white backdrop globally. This is less selective than a
    # true matting pass, but it is much more reliable for these sticker-style
    # GIFs and avoids keeping the square white/gray plate behind the subject.
    # Tiny white highlights may fade a bit, but the overall fit is much better.
    magick "${frame}" \
        -alpha set \
        -fuzz "${FUZZ}" \
        -transparent white \
        +channel \
        "${cut}"

    magick "${cut}" \
        -alpha extract \
        -morphology Erode Disk:4 \
        -blur "${GLOW_BLUR}" \
        -evaluate multiply "${GLOW_OPACITY}" \
        "${glow_mask}"

    magick -size "${SIZE}x${SIZE}" "xc:${GLOW_COLOR}" \
        "${glow_mask}" \
        -alpha off \
        -compose CopyOpacity \
        -composite \
        "${glow}"

    magick "${TMP_DIR}/bg_patch.png" \
        "${glow}" -compose screen -composite \
        "${cut}" -compose over -composite \
        "${out}"
done

magick -delay "${DELAY_CS}" -loop 0 "${TMP_DIR}"/composed/frame_*.png -layers Optimize "${OUT_GIF}"
fi

# The asset is embedded with .incbin, so touch the translation unit to force
# CMake/Ninja to relink the changed bytes on the next build.
touch "${ROOT_DIR}/main/assets/custom_assets.cc"

magick identify -format 'Generated %f: %n frames, canvas=%[page], frame=%wx%h\n' "${OUT_GIF}" | head -1
