@echo off
setlocal enabledelayedexpansion
set "FORGE_VERSION=[[FORGE_VERSION]]"
set "MC_VERSION=[[MINECRAFT_VERSION]]"
rem To use a specific Java runtime, set an environment variable named MC_JAVA to the full path of java.exe.
rem To disable automatic restarts, set an environment variable named MC_RESTART to false.
rem To install the pack without starting the server, set an environment variable named MC_INSTALL_ONLY to true.

set "INSTALLER=forge-%MC_VERSION%-%FORGE_VERSION%-installer.jar"
set "FORGE_URL=https://maven.minecraftforge.net/net/minecraftforge/forge/%MC_VERSION%-%FORGE_VERSION%/forge-%MC_VERSION%-%FORGE_VERSION%-installer.jar"

if not defined MC_JAVA (
    set "MC_JAVA=java"
)

:checkJava
where "%MC_JAVA%"
if errorlevel 1 (
    echo Minecraft %MC_VERSION% requires Java 17 - Java not found.
    pause
    exit /b 1
)

cd /d "%~dp0"
if not exist "libraries" (
    echo Forge not installed, installing now.
    if not exist "%INSTALLER%" (
        echo No Forge installer found, downloading now.
        where curl >nul 2>&1
        if not errorlevel 1 (
            echo Downloading %FORGE_URL%
            curl -o "%INSTALLER%" -L "%FORGE_URL%"
        ) else (
            echo Neither curl was found on your system. Please install curl and try again.
            pause
            exit /b 1
        )
    )
    echo Running Forge installer.
    "%MC_JAVA%" -jar "%INSTALLER%" --installServer
)

if not exist "server.properties" (
    (
        echo allow-flight=true
        echo motd=[[MODPACK_NAME]] Server
        echo max-tick-time=180000
    ) > server.properties
)

if /I "%MC_INSTALL_ONLY%"=="true" (
    echo INSTALL_ONLY: complete
    exit /b 0
)

rem Check Java version
for /f tokens^=2^ delims^=^" %%i in ('"%MC_JAVA%" -fullversion 2^>^&1') do (
    set "JAVA_VERSION=%%i"
)
for /f "tokens=1 delims=." %%j in ("%JAVA_VERSION%") do (
    set "JAVA_MAJOR=%%j"
)
if %JAVA_MAJOR% LSS 17 (
    echo Minecraft %MC_VERSION% requires Java 17 - found Java %JAVA_VERSION%
    pause
    exit /b 1
)

:restart
"%MC_JAVA%" @user_jvm_args.txt @libraries/net/minecraftforge/forge/[[MINECRAFT_VERSION]]-[[FORGE_VERSION]]/win_args.txt nogui
if /I not "%MC_RESTART%"=="false" (
    echo Restarting automatically in 10 seconds (press Ctrl + C to cancel)
    timeout /t 10
    goto restart
)
exit /b 0
