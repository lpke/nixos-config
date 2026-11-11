#!/bin/sh
exec notify-send --app-name='T3 quake' --icon=dialog-warning \
  --urgency=normal --expire-time=10000 --hint=boolean:suppress-sound:true \
  'T3 quake unavailable' \
  'The window controller failed. T3 is available normally. Run t3-quake restart to retry.'
