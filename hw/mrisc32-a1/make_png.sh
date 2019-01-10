#!/bin/bash
cat /tmp/mrisc32_pipeline_tb_ram.bin | tail -c 98304 | head -c 65536 | convert -size 256x256 -depth 8 gray:- /tmp/mrisc32_pipeline_tb.png
