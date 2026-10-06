#!/bin/bash
# Fake /usr/sbin/screencapture for the runner tests.
#   FAKE_SCREENCAPTURE_SCENARIO  success (default) | cancel | error | flood
#   FAKE_SCREENCAPTURE_ARGS      when set, every argument is written to this file, one per line
# The runner replaces the whole environment, so commands are called by absolute path.
[ -n "$FAKE_SCREENCAPTURE_ARGS" ] && printf '%s\n' "$@" > "$FAKE_SCREENCAPTURE_ARGS"
case "${FAKE_SCREENCAPTURE_SCENARIO:-success}" in
  success) exit 0 ;;
  cancel)  exit 1 ;;                                    # real screencapture: Esc → exit 1, empty stderr
  error)   echo "screencapture: could not create image" >&2; exit 2 ;;
  flood)   /usr/bin/head -c 200000 /dev/zero | /usr/bin/tr '\0' 'x' >&2; exit 3 ;;  # more than a pipe buffer
esac
