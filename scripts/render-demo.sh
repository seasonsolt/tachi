#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_DIR="$REPO_ROOT/docs/assets"
OUTPUT="$ASSET_DIR/tachi-demo.mp4"
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"

command -v ffmpeg >/dev/null
test -f "$FONT"

ffmpeg -y \
    -loop 1 -t 4.8 -i "$ASSET_DIR/tachi-companion.png" \
    -loop 1 -t 3.8 -i "$ASSET_DIR/tachi-companion.png" \
    -loop 1 -t 5.8 -i "$ASSET_DIR/tachi-panel.png" \
    -f lavfi -t 2.2 -i color=c=0x071018:s=1080x1440:r=30 \
    -filter_complex "
        [0:v]scale=1080:1440:force_original_aspect_ratio=increase,
            crop=1080:1440,
            zoompan=z='min(zoom+0.0022,1.32)':x='iw/2-(iw/zoom/2)':y=0:d=144:s=1080x1440:fps=30,
            drawbox=x=0:y=0:w=iw:h=190:color=0x071018@0.78:t=fill,
            drawtext=fontfile='$FONT':text='同时跑 3 个 Agent':fontcolor=white:fontsize=62:x=(w-text_w)/2:y=38,
            drawtext=fontfile='$FONT':text='项目、工具、等待状态一眼看清':fontcolor=0x38bdf8:fontsize=37:x=(w-text_w)/2:y=120,
            fade=t=in:st=0:d=0.35,
            setpts=PTS-STARTPTS[sessions];
        [1:v]scale=1080:1440:force_original_aspect_ratio=increase,
            crop=1080:1440,
            zoompan=z='min(zoom+0.0032,1.45)':x='iw/2-(iw/zoom/2)':y='ih-(ih/zoom)':d=114:s=1080x1440:fps=30,
            drawbox=x=0:y=0:w=iw:h=190:color=0x071018@0.82:t=fill,
            drawtext=fontfile='$FONT':text='忙起来，宠物也会跟着变':fontcolor=white:fontsize=55:x=(w-text_w)/2:y=38,
            drawtext=fontfile='$FONT':text='并行越多，反应越活跃':fontcolor=0xf59e0b:fontsize=37:x=(w-text_w)/2:y=120,
            setpts=PTS-STARTPTS[pet];
        [2:v]scale=1080:1440:force_original_aspect_ratio=increase,
            crop=1080:1440,
            zoompan=z='min(zoom+0.0003,1.045)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=174:s=1080x1440:fps=30,
            drawbox=x=0:y=0:w=iw:h=190:color=0x071018@0.82:t=fill,
            drawtext=fontfile='$FONT':text='用量与配额，不用再翻网页':fontcolor=white:fontsize=55:x=(w-text_w)/2:y=38,
            drawtext=fontfile='$FONT':text='Claude 本地统计 · Codex 官方配额':fontcolor=0x34d399:fontsize=36:x=(w-text_w)/2:y=120,
            setpts=PTS-STARTPTS[panel];
        [sessions][pet]xfade=transition=fade:duration=0.6:offset=4.2[first_two];
        [first_two][panel]xfade=transition=fade:duration=0.6:offset=7.4[first_three];
        [3:v]drawtext=fontfile='$FONT':text='Tachi':fontcolor=white:fontsize=112:x=(w-text_w)/2:y=500,
            drawtext=fontfile='$FONT':text='AI 编程会话，就在菜单栏':fontcolor=0x38bdf8:fontsize=48:x=(w-text_w)/2:y=655,
            drawtext=fontfile='$FONT':text='macOS 14+ · Apple Silicon':fontcolor=0xa8b3bf:fontsize=34:x=(w-text_w)/2:y=750,
            fade=t=out:st=1.8:d=0.4,
            setpts=PTS-STARTPTS[outro];
        [first_three][outro]xfade=transition=fade:duration=0.5:offset=12.6,
            format=yuv420p[v]
    " \
    -map '[v]' \
    -an \
    -c:v libx264 \
    -preset slow \
    -crf 20 \
    -movflags +faststart \
    "$OUTPUT"

echo "Rendered: $OUTPUT"
