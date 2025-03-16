#!/bin/sh
set -eu
FORGE_VERSION=[[FORGE_VERSION]]
MC_VERSION=[[MINECRAFT_VERSION]]
# To use a specific Java runtime, set an environment variable named MC_JAVA to the full path of java.
# To disable automatic restarts, set an environment variable named MC_RESTART to false.
# To install the pack without starting the server, set an environment variable named MC_INSTALL_ONLY to true.

INSTALLER="forge-$MC_VERSION-$FORGE_VERSION-installer.jar"
FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$MC_VERSION-$FORGE_VERSION/forge-$MC_VERSION-$FORGE_VERSION-installer.jar"

pause() {
    printf "%s\n" "Press enter to continue..."
    read ans
}

if ! command -v "${MC_JAVA:-java}" >/dev/null 2>&1; then
    echo "Minecraft $MC_VERSION requires Java 17 - Java not found"
    pause
    exit 1
fi

cd "$(dirname "$0")"
if [ ! -d libraries ]; then
    echo "Forge not installed, installing now."
    if [ ! -f "$INSTALLER" ]; then
        echo "No Forge installer found, downloading now."
        if command -v wget >/dev/null 2>&1; then
            echo "DEBUG: (wget) Downloading $FORGE_URL"
            wget -O "$INSTALLER" "$FORGE_URL"
        else
            if command -v curl >/dev/null 2>&1; then
                echo "DEBUG: (curl) Downloading $FORGE_URL"
                curl -o "$INSTALLER" -L "$FORGE_URL"
            else
                echo "Neither wget nor curl were found on your system. Please install one and try again"
                pause
                exit 1
            fi
        fi
    fi

    echo "Running Forge installer."
    "${MC_JAVA:-java}" -jar "$INSTALLER" --installServer
fi

if [ ! -e server.properties ]; then
    printf "allow-flight=true\nmotd=[[MODPACK_NAME]] Server\nmax-tick-time=180000\n" "$MC_VERSION" > server.properties
fi

if [ "${MC_INSTALL_ONLY:-false}" = "true" ]; then
    echo "INSTALL_ONLY: complete"
    exit 0
fi

JAVA_VERSION=$("${MC_JAVA:-java}" -fullversion 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ ! "$JAVA_VERSION" -ge 17 ]; then
    echo "Minecraft $MC_VERSION requires Java 17 - found Java $JAVA_VERSION"
    pause
    exit 1
fi

while true
do
    "${MC_JAVA:-java}" @user_jvm_args.txt @libraries/net/minecraftforge/forge/[[MINECRAFT_VERSION]]-[[FORGE_VERSION]]/unix_args.txt nogui

    if [ "${MC_RESTART:-true}" = "false" ]; then
        exit 0
    fi

    echo "Restarting automatically in 10 seconds (press Ctrl + C to cancel)"
    sleep 10
done
