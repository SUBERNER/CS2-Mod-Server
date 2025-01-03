#!/bin/bash

# Create App Dir
mkdir -p "${STEAMAPPDIR}" || true

# Download Updates

if [[ "$STEAMAPPVALIDATE" -eq 1 ]]; then
    VALIDATE="validate"
else
    VALIDATE=""
fi

eval bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" \
				+login anonymous \
				+app_update "${STEAMAPPID}" "${VALIDATE}"\
				+quit

# steamclient.so fix
mkdir -p ~/.steam/sdk64
ln -sfT ${STEAMCMDDIR}/linux64/steamclient.so ~/.steam/sdk64/steamclient.so

# Install server.cfg
cp /etc/server.cfg "${STEAMAPPDIR}"/game/csgo/cfg/server.cfg

# Install hooks if they don't already exist
if [[ ! -f "${STEAMAPPDIR}/pre.sh" ]] ; then
    cp /etc/pre.sh "${STEAMAPPDIR}/pre.sh"
fi
if [[ ! -f "${STEAMAPPDIR}/post.sh" ]] ; then
    cp /etc/post.sh "${STEAMAPPDIR}/post.sh"
fi

# Download and extract custom config bundle
if [[ ! -z $CS2_CFG_URL ]]; then
    echo "Downloading config pack from ${CS2_CFG_URL}"
    wget -qO- "${CS2_CFG_URL}" | tar xvzf - -C "${STEAMAPPDIR}"
fi

# Rewrite Gameinfo File
sed -i "/Game[[:space:]]core/a  \\\t\t\tGame\tcsgo/addons/metamod" "${STEAMAPPDIR}/game/csgo/gameinfo.gi"

# Rewrite Config Files

sed -i -e "s/{{SERVER_HOSTNAME}}/${CS2_SERVERNAME}/g" \
       -e "s/{{SERVER_CHEATS}}/${CS2_CHEATS}/g" \
       -e "s/{{SERVER_HIBERNATE}}/${CS2_SERVER_HIBERNATE}/g" \
       -e "s/{{SERVER_PW}}/${CS2_PW}/g" \
       -e "s/{{SERVER_RCON_PW}}/${CS2_RCONPW}/g" \
       -e "s/{{TV_ENABLE}}/${TV_ENABLE}/g" \
       -e "s/{{TV_PORT}}/${TV_PORT}/g" \
       -e "s/{{TV_AUTORECORD}}/${TV_AUTORECORD}/g" \
       -e "s/{{TV_PW}}/${TV_PW}/g" \
       -e "s/{{TV_RELAY_PW}}/${TV_RELAY_PW}/g" \
       -e "s/{{TV_MAXRATE}}/${TV_MAXRATE}/g" \
       -e "s/{{TV_DELAY}}/${TV_DELAY}/g" \
       -e "s/{{BOT_DIFFICULTY}}/${BOT_DIFFICULTY}/g" \
       -e "s/{{BOT_QUOTA}}/${BOT_QUOTA}/g" \
       -e "s/{{BOT_QUOTA_MODE}}/${BOT_QUOTA_MODE}/g" \
       -e "s/{{SERVER_LOG}}/${CS2_LOG}/g" \
       -e "s/{{SERVER_LOG_MONEY}}/${CS2_LOG_MONEY}/g" \
       -e "s/{{SERVER_LOG_DETAIL}}/${CS2_LOG_DETAIL}/g" \
       -e "s/{{SERVER_LOG_ITEMS}}/${CS2_LOG_ITEMS}/g" \
       -e "s/{{SERVER_LOG_LOADOUTS}}/${CS2_LOG_LOADOUTS}/g" \
       "${STEAMAPPDIR}"/game/csgo/cfg/server.cfg

# Install Plugins and Tools
echo "START INSTALL"
source /etc/install.sh
echo "END INSTALL"

# Switch to server directory
cd "${STEAMAPPDIR}/game/bin/linuxsteamrt64"

# Pre Hook
source "${STEAMAPPDIR}/pre.sh"

# Construct server arguments

if [[ -z $CS2_GAMEALIAS ]]; then
    # If CS2_GAMEALIAS is undefined then default to CS2_GAMETYPE and CS2_GAMEMODE
    CS2_GAME_MODE_ARGS="+game_type ${CS2_GAMETYPE} +game_mode ${CS2_GAMEMODE}"
else
    # Else, use alias to determine game mode
    CS2_GAME_MODE_ARGS="+game_alias ${CS2_GAMEALIAS}"
fi

if [[ -z $CS2_IP ]]; then
    CS2_IP_ARGS=""
else
    CS2_IP_ARGS="-ip ${CS2_IP}"
fi

if [[ ! -z $SRCDS_TOKEN ]]; then
    SV_SETSTEAMACCOUNT_ARGS="+sv_setsteamaccount ${SRCDS_TOKEN}"
fi

# Start Server

if [[ ! -z $CS2_RCON_PORT ]]; then
    echo "Establishing Simpleproxy for ${CS2_RCON_PORT} to 0.0.0.0:${CS2_PORT}"
    simpleproxy -L "${CS2_RCON_PORT}" -R 0.0.0.0:"${CS2_PORT}" &
fi

# hacky error fix
mkdir -p ${STEAM_DIR}/.steam/sdk32
mkdir -p ${STEAM_DIR}/.steam/sdk64

cp ${STEAMCMD_DIR}/linux32/steamclient.so ${STEAM_DIR}/.steam/sdk32/steamclient.so
cp ${STEAMCMD_DIR}/linux64/steamclient.so ${STEAM_DIR}/.steam/sdk64/steamclient.

echo "Starting CS2 Dedicated Server"
exec "./cs2" -dedicated \
        "${CS2_IP_ARGS}" -port "${CS2_PORT}" \
        -console \
        -insecure \
        -usercon \
        +login anonymous \
        -maxplayers "${CS2_MAXPLAYERS}" \
        "${CS2_GAME_MODE_ARGS}" \
        +map "${CS2_MAP}" \
        +rcon_password "${CS2_RCONPW}" \
        "${SV_SETSTEAMACCOUNT_ARGS}" \
        +sv_password "${CS2_PW}" \
        +sv_lan "${CS2_LAN}" \
        "${CS2_ADDITIONAL_ARGS}"

# Post Hook
source "${STEAMAPPDIR}/post.sh"
