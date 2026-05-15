#!/bin/bash
# Installation Tekton Pipelines — sans digest (contournement Zscaler)
curl -sL https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml \
  | sed 's/@sha256:[a-f0-9]*//' \
  | kubectl apply -f -
