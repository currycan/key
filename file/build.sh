#! /bin/env bash

docker build -t currycan/ng-file:1.0.0 .

dd if=/dev/zero of=sb-io-test bs=1M count=1k conv=fdatasync;
