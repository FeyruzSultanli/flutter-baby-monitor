#!/bin/sh
# V2.1 §4: every screen in TR + AZ, light + dark menu screens, on a
# Huawei RNE-L01 class phone (360x720 dp @3 = 1080x2160, 18:9) and an
# iPhone (393x852 @3 = 1179x2556) -> design/screens_v21/<locale>_<device>_<theme>/
set -e
cd "$(dirname "$0")/.."
for locale in tr az; do
  for theme in light dark; do
    for dev in "1080x2160 360 720" "iphone 393 852"; do
      set -- $dev
      flutter test tool/screenshots_test.dart \
        --dart-define=SHOT_LOCALE=$locale --dart-define=SHOT_THEME=$theme \
        --dart-define=SHOT_W=$2 --dart-define=SHOT_H=$3 --dart-define=SHOT_RATIO=3 \
        --dart-define=SHOT_OUT=design/screens_v21 --dart-define=SHOT_NAME=${locale}_$1_$theme
    done
  done
done
