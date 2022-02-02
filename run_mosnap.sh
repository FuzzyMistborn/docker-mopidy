#!/bin/bash

# run snapserver
/usr/bin/snapserver --config /snap_config/snapserver.conf &

# run mopidy
/usr/bin/mopidy
