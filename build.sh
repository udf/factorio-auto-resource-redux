#!/usr/bin/env bash

SRCDIR=auto-resource-redux
FILENAME="$(jq -r '.name + "_" + .version' $SRCDIR/info.json).zip"

if [[ $(git status --porcelain=v1 "$SRCDIR" 2>/dev/null) ]]; then
  echo "$SRCDIR has uncommited changes. Exiting."
  exit 1
fi

if [ -f "$FILENAME" ]; then
  read -p "Overwrite $FILENAME? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm "$FILENAME"
  else
    exit 1
  fi
fi
zip -r "$FILENAME" -r "$SRCDIR"