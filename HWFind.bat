@echo off

echo.

echo Welcome to HWFind v1.0 - This Windows batch script will look through the Windows registry and report evidence of the following hardware wallets being used in this machine:

echo.
echo -Trezor One
echo -Trezor T
echo -Ledger Nano S
echo -KeepKey
echo.

pause

reg query HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USB\ /f VID_534C

if %errorlevel% equ 0 ( echo "Registry Keys with VID_534C present - Trezor One" 
) else (
echo "Trezor One registry keys not present."
)

reg query HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USB\ /f VID_1209

if %errorlevel% equ 0 ( echo "Registry Keys with VID_1209 present - Trezor T" 
) else (
echo "Trezor T registry keys not present."
)

reg query HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USB\ /f VID_2C97

if %errorlevel% equ 0 ( echo "Registry Keys with VID_2C97 present - Ledger Nano S" 
) else (
echo "Ledger Nano S registry keys not present."
)

reg query HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USB\ /f VID_2B24

if %errorlevel% equ 0 ( echo "Registry Keys with VID_2B24 present - KeepKey" 
) else (
echo "Ledger Nano S registry keys not present."
)

pause

