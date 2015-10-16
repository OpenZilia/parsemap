#!/bin/bash

reflex -r '\.go$' -R '^tests/' -R'^Godeps/' -s ./refresh_app.sh
