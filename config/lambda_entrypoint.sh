#!/bin/bash
export _HANDLER="${APP_HANDLER}"
ln -s /tmp/home "$HOME"
mkdir /tmp/home
mkdir /tmp/apptmp
export HOME=/tmp/home
exec /usr/local/bin/aws_lambda_ric
