#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/set_build.sh <build-number> [version] [--rebuild]
  scripts/set_build.sh <version+build> [--rebuild]

Examples:
  scripts/set_build.sh 36
  scripts/set_build.sh 36 1.0.12
  scripts/set_build.sh 1.0.12+36 --rebuild

Without --rebuild, this syncs local Flutter/Xcode/Android version metadata.
With --rebuild, it also regenerates iOS, macOS, and Android build artifacts.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '==> %s\n' "$*"
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

rebuild=0
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rebuild)
      rebuild=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      positional+=("$1")
      ;;
  esac
  shift
done

build_number=""
version_name=""

case "${#positional[@]}" in
  1)
    if [[ "${positional[0]}" == *+* ]]; then
      version_name="${positional[0]%+*}"
      build_number="${positional[0]##*+}"
    else
      build_number="${positional[0]}"
    fi
    ;;
  2)
    build_number="${positional[0]}"
    version_name="${positional[1]}"
    ;;
  *)
    usage
    exit 1
    ;;
esac

[[ "$build_number" =~ ^[0-9]+$ ]] || die "build number must be an integer"

if [ -z "$version_name" ]; then
  version_name="$(perl -ne 'if (/^version:\s*([^\s+]+)(?:\+\d+)?/) { print $1; exit }' pubspec.yaml)"
fi

[ -n "$version_name" ] || die "could not read version name from pubspec.yaml"
[[ "$version_name" != *+* ]] || die "version name must not contain +"

replace_property() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "$file"; then
    KEY="$key" VALUE="$value" perl -0pi -e 's/^\Q$ENV{KEY}\E=.*/$ENV{KEY} . "=" . $ENV{VALUE}/me' "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

replace_export() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^export \"${key}=" "$file"; then
    KEY="$key" VALUE="$value" perl -0pi -e 's/^export "\Q$ENV{KEY}\E=.*"/"export \"" . $ENV{KEY} . "=" . $ENV{VALUE} . "\""/me' "$file"
  else
    printf 'export "%s=%s"\n' "$key" "$value" >> "$file"
  fi
}

sync_generated_metadata() {
  local xcconfig="$1"
  local export_file="$2"

  if [ -f "$xcconfig" ]; then
    replace_property "$xcconfig" FLUTTER_BUILD_NAME "$version_name"
    replace_property "$xcconfig" FLUTTER_BUILD_NUMBER "$build_number"
  fi

  if [ -f "$export_file" ]; then
    replace_export "$export_file" FLUTTER_BUILD_NAME "$version_name"
    replace_export "$export_file" FLUTTER_BUILD_NUMBER "$build_number"
  fi
}

require_line() {
  local file="$1"
  local line="$2"

  if [ -f "$file" ]; then
    grep -Fxq "$line" "$file" || die "$file does not contain: $line"
  fi
}

plist_build_number() {
  local plist="$1"
  local actual
  actual="$(plutil -extract CFBundleVersion raw -o - "$plist" 2>/dev/null || true)"
  if [ -n "$actual" ]; then
    printf '%s\n' "$actual"
    return 0
  fi

  plutil -p "$plist" 2>/dev/null | sed -nE 's/.*"CFBundleVersion" => "([^"]+)".*/\1/p' | head -1
}

check_plist_artifact() {
  local label="$1"
  local plist="$2"

  [ -f "$plist" ] || return 0

  local actual
  actual="$(plist_build_number "$plist")"
  if [ "$actual" = "$build_number" ]; then
    printf 'ok: %s build %s\n' "$label" "$build_number"
  else
    printf 'stale: %s has build %s, expected %s\n' "$label" "${actual:-unknown}" "$build_number" >&2
    artifact_stale=1
  fi
}

find_aapt() {
  if command -v aapt >/dev/null 2>&1; then
    command -v aapt
    return 0
  fi

  local sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  find "$sdk_root/build-tools" -name aapt -type f 2>/dev/null | sort | tail -1
}

check_apk_artifact() {
  local label="$1"
  local apk="$2"
  local aapt="$3"

  [ -f "$apk" ] || return 0
  [ -n "$aapt" ] || return 0

  local badging
  badging="$("$aapt" dump badging "$apk" 2>/dev/null | head -1 || true)"
  if printf '%s\n' "$badging" | grep -q "versionCode='${build_number}'"; then
    printf 'ok: %s versionCode %s\n' "$label" "$build_number"
  else
    printf 'stale: %s does not report versionCode %s\n' "$label" "$build_number" >&2
    artifact_stale=1
  fi
}

note "Syncing version ${version_name}+${build_number}"

[ -f pubspec.yaml ] || die "pubspec.yaml not found"
grep -q '^version:' pubspec.yaml || die "pubspec.yaml has no version line"
VERSION_NAME="$version_name" BUILD_NUMBER="$build_number" perl -0pi -e 's/^version:\s*.*/"version: $ENV{VERSION_NAME}+$ENV{BUILD_NUMBER}"/me' pubspec.yaml

command -v flutter >/dev/null 2>&1 || die "flutter command not found"
note "Running flutter pub get"
flutter pub get

if [ -f android/local.properties ]; then
  replace_property android/local.properties flutter.versionName "$version_name"
  replace_property android/local.properties flutter.versionCode "$build_number"
fi

sync_generated_metadata ios/Flutter/Generated.xcconfig ios/Flutter/flutter_export_environment.sh
sync_generated_metadata macos/Flutter/ephemeral/Flutter-Generated.xcconfig macos/Flutter/ephemeral/flutter_export_environment.sh

require_line pubspec.yaml "version: ${version_name}+${build_number}"
require_line android/local.properties "flutter.versionName=${version_name}"
require_line android/local.properties "flutter.versionCode=${build_number}"
require_line ios/Flutter/Generated.xcconfig "FLUTTER_BUILD_NAME=${version_name}"
require_line ios/Flutter/Generated.xcconfig "FLUTTER_BUILD_NUMBER=${build_number}"
require_line ios/Flutter/flutter_export_environment.sh "export \"FLUTTER_BUILD_NAME=${version_name}\""
require_line ios/Flutter/flutter_export_environment.sh "export \"FLUTTER_BUILD_NUMBER=${build_number}\""
require_line macos/Flutter/ephemeral/Flutter-Generated.xcconfig "FLUTTER_BUILD_NAME=${version_name}"
require_line macos/Flutter/ephemeral/Flutter-Generated.xcconfig "FLUTTER_BUILD_NUMBER=${build_number}"
require_line macos/Flutter/ephemeral/flutter_export_environment.sh "export \"FLUTTER_BUILD_NAME=${version_name}\""
require_line macos/Flutter/ephemeral/flutter_export_environment.sh "export \"FLUTTER_BUILD_NUMBER=${build_number}\""

if [ "$rebuild" -eq 1 ]; then
  note "Rebuilding iOS release app"
  flutter build ios --release --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding iOS IPA"
  flutter build ipa --release --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding iOS debug app"
  flutter build ios --debug --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding macOS release app"
  flutter build macos --release --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding macOS debug app"
  flutter build macos --debug --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding Android debug APK"
  flutter build apk --debug --build-name="$version_name" --build-number="$build_number"

  note "Rebuilding Android release AAB"
  flutter build appbundle --release --build-name="$version_name" --build-number="$build_number"
fi

note "Checking existing app artifacts"
artifact_stale=0

if [ -f build/ios/ipa/cws_admix_control.ipa ]; then
  tmp_plist="$(mktemp)"
  unzip -p build/ios/ipa/cws_admix_control.ipa 'Payload/Runner.app/Info.plist' > "$tmp_plist"
  check_plist_artifact "iOS IPA" "$tmp_plist"
  rm -f "$tmp_plist"
fi

check_plist_artifact "iOS archive" build/ios/archive/Runner.xcarchive/Info.plist
check_plist_artifact "iOS archive app" build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist
check_plist_artifact "iOS release app" build/ios/Release-iphoneos/Runner.app/Info.plist
check_plist_artifact "iOS device app" build/ios/iphoneos/Runner.app/Info.plist
check_plist_artifact "iOS debug app" build/ios/Debug-iphoneos/Runner.app/Info.plist
check_plist_artifact "macOS release app" build/macos/Build/Products/Release/cws_admix_control.app/Contents/Info.plist
check_plist_artifact "macOS debug app" build/macos/Build/Products/Debug/cws_admix_control.app/Contents/Info.plist

aapt_path="$(find_aapt)"
check_apk_artifact "Android flutter debug APK" build/app/outputs/flutter-apk/app-debug.apk "$aapt_path"
check_apk_artifact "Android debug APK" build/app/outputs/apk/debug/app-debug.apk "$aapt_path"

if [ "$artifact_stale" -ne 0 ]; then
  if [ "$rebuild" -eq 1 ]; then
    die "some artifacts are still stale"
  fi
  note "Some existing artifacts are stale. Run with --rebuild to regenerate them."
fi

note "Done"
