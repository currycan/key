#!/bin/sh -e

set -eou pipefail

log(){
  # Font color and background color
  Green="\033[32m" && Red="\033[31m" && Yellow="\033[0;33m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && suffix="\033[0m"
  Info="${Green}[信息]${suffix}"
  Error="${Red}[错误]${suffix}"
  Point="${Red}[提示]${suffix}"
  Tip="${Green}[注意]${suffix}"
  Warning="${Yellow}[警告]${suffix}"
  Separator_1="——————————————————————————————"
}

showssrkcp(){
  # Humanization config PATH
  HUMAN_CONFIG="/ssrkcp/config/humanization.conf"
  log
  source /ssrkcp/utils/view_config.sh
  show_config "standalone"
}

showssrkcp
