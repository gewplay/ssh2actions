#!/usr/bin/env bash
#
# Copyright (c) 2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/ssh2actions
# File name：tmate2actions.sh
# Description: Connect to Github Actions VM via SSH by using tmate
# Version: 2.0
#

set -e
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"
TMATE_SOCK="/tmp/tmate.sock"
TELEGRAM_LOG="/tmp/telegram.log"
CONTINUE_FILE="/tmp/continue"

# Install tmate on macOS or Ubuntu
echo -e "${INFO} Setting up tmate ..."
if [[ -n "$(uname | grep Linux)" ]]; then
    curl -fsSL git.io/tmate.sh | bash
elif [[ -x "$(command -v brew)" ]]; then
    brew install tmate
else
    echo -e "${ERROR} This system is not supported!"
    exit 1
fi

echo Change user home diretory to proper mode and fix bashrc loading issue
sudo chmod 755 /home/${USER}
echo '. ~/.bashrc' >> /home/${USER}/.bash_profile

echo Generate ssh key if needed
[[ -e ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

echo Run deamonized tmate
echo -e "${INFO} Running tmate..."
tmate -S ${TMATE_SOCK} new-session -d
tmate -S ${TMATE_SOCK} wait tmate-ready

echo Print connection info
TMATE_SSH=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_ssh}')
TMATE_WEB=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_web}')
MSG="
*GitHub Actions - tmate session info:*

⚡ *CLI:*
\`${TMATE_SSH}\`

🔗 *URL:*
${TMATE_WEB}

🔔 *TIPS:*
Run '\`touch ${CONTINUE_FILE}\`' to continue to the next step.
"

if [[ -n "${DINGTALK}" ]]; then
    echo -e "${INFO} Sending message to DingTalk..."
    curl "https://oapi.dingtalk.com/robot/send?access_token=" \
    -H 'Content-Type: application/json'\
    -d "{'msgtype': 'text', 
        'text': {
             'content': '${MSG}\nfox'
        }
      }"
    
fi

while ((${PRT_COUNT:=1} <= ${PRT_TOTAL:=10})); do
    SECONDS_LEFT=${PRT_INTERVAL_SEC:=10}
    while ((${PRT_COUNT} > 1)) && ((${SECONDS_LEFT} > 0)); do
        echo -e "${INFO} (${PRT_COUNT}/${PRT_TOTAL}) Please wait ${SECONDS_LEFT}s ..."
        sleep 1
        SECONDS_LEFT=$((${SECONDS_LEFT} - 1))
    done
    echo "-----------------------------------------------------------------------------------"
    echo "To connect to this session copy and paste the following into a terminal or browser:"
    echo -e "CLI: ${Green_font_prefix}${TMATE_SSH}${Font_color_suffix}"
    echo -e "URL: ${Green_font_prefix}${TMATE_WEB}${Font_color_suffix}"
    echo -e "TIPS: Run 'touch ${CONTINUE_FILE}' to continue to the next step."
    echo "-----------------------------------------------------------------------------------"
    PRT_COUNT=$((${PRT_COUNT} + 1))
done

while [[ -S ${TMATE_SOCK} ]]; do
    sleep 1
    if [[ -e ${CONTINUE_FILE} ]]; then
        echo -e "${INFO} Continue to the next step."
        exit 0
    fi
done

# ref: https://github.com/csexton/debugger-action/blob/master/script.sh
