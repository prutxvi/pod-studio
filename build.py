#!/usr/bin/env python3
"""Build Pod Studio with Apple's Command Line Tools. No package downloads.

    python3 build.py             # build/Pod Studio.app
    python3 build.py --install   # also copy to ~/Applications and relaunch
    python3 build.py --release   # optimised build (-O) instead of debug (-Onone)
"""
from pathlib import Path
import argparse, json, os, plistlib, shutil, subprocess

VERSION, BUILD = '0.4.0', '5'
root = Path(__file__).resolve().parent
args = argparse.ArgumentParser()
args.add_argument('--install', action='store_true', help='copy to ~/Applications/Pod Studio.app and relaunch')
args.add_argument('--release', action='store_true', help='optimised build')
opts = args.parse_args()

app = root / 'build' / 'Pod Studio.app'
if app.exists(): shutil.rmtree(app)
mac = app / 'Contents/MacOS'; res = app / 'Contents/Resources'
mac.mkdir(parents=True); res.mkdir(parents=True)

info = {
    'CFBundleExecutable': 'PodStudio',
    # Keep this identifier: macOS Bluetooth/Automation permissions and saved preferences are tied to it.
    'CFBundleIdentifier': 'local.pruthvi.PodStudio',
    'CFBundleName': 'Pod Studio', 'CFBundleDisplayName': 'Pod Studio',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': VERSION, 'CFBundleVersion': BUILD,
    'LSMinimumSystemVersion': '26.0',
    'CFBundleIconFile': 'PodStudio.icns',
    'NSBluetoothAlwaysUsageDescription': 'Pod Studio uses Bluetooth to show battery and control your CMF or Nothing earbuds.',
    'NSBluetoothPeripheralUsageDescription': 'Connect to your earbuds to manage noise control and sound.',
    'NSAppleEventsUsageDescription': 'Pod Studio controls Spotify playback and reads the current song to show your music player. Audio and downloads remain in Spotify.',
    'NSHighResolutionCapable': True,
    'NSPrincipalClass': 'NSApplication',
}
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))

# Bundle the highest-resolution image of each asset set under its asset name for NSImage(named:).
for imageset in (root / 'Sources/Assets.xcassets').glob('*.imageset'):
    data = json.loads((imageset / 'Contents.json').read_text())
    files = [imageset / i['filename'] for i in data.get('images', []) if i.get('filename') and (imageset / i['filename']).exists()]
    if files:
        chosen = max(files, key=lambda p: p.stat().st_size)
        shutil.copy2(chosen, res / (imageset.stem + chosen.suffix))
for f in (root / 'Sources/resources/fonts').glob('*'): shutil.copy2(f, res / f.name)
shutil.copy2(root / 'LICENSE', res / 'LICENSE.txt')
shutil.copy2(root / 'resources/PodStudio.icns', res / 'PodStudio.icns')

# The Command Line Tools' macOS 27 SDK lacks the SwiftUI macro plugins, so prefer 26.5. Override with POD_SDK=/path.
pinned = Path('/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk')
sdk = os.environ.get('POD_SDK') or (str(pinned) if pinned.exists() else
      subprocess.run(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], capture_output=True, text=True, check=True).stdout.strip())
sources = [str(f) for f in sorted((root / 'Sources').rglob('*.swift'))]
subprocess.run(['swiftc', '-sdk', sdk, '-swift-version', '5', '-O' if opts.release else '-Onone',
                '-whole-module-optimization', '-module-name', 'PodStudio', '-o', str(mac / 'PodStudio')] + sources, check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
print('Built:', app)

if opts.install:
    target = Path.home() / 'Applications' / 'Pod Studio.app'
    subprocess.run(['osascript', '-e', 'tell application id "local.pruthvi.PodStudio" to quit'], capture_output=True)
    if target.exists(): shutil.rmtree(target)
    target.parent.mkdir(exist_ok=True)
    subprocess.run(['ditto', str(app), str(target)], check=True)
    subprocess.run(['open', str(target)], check=True)
    print('Installed:', target)
