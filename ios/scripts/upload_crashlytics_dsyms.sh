#!/bin/sh
# Upload dSYMs to Firebase Crashlytics.
#
# Firebase may be linked through CocoaPods or through Flutter's Swift Package
# Manager checkout. PODS_ROOT is often set by another plugin even when
# Crashlytics itself is not a pod, so the script checks that the uploader
# exists before using it.
set -u

search_roots=""

add_candidate() {
  if [ -n "$1" ]; then
    candidates="${candidates}
$1"
  fi
}

candidates=""
add_candidate "${PODS_ROOT:-}/FirebaseCrashlytics/upload-symbols"
add_candidate "${SRCROOT}/../build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
add_candidate "${SRCROOT}/../build/ios/SourcePackages/artifacts/firebase-ios-sdk/Crashlytics/upload-symbols"

if [ -n "${FLUTTER_APPLICATION_PATH:-}" ]; then
  add_candidate "${FLUTTER_APPLICATION_PATH}/build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  search_roots="${search_roots} ${FLUTTER_APPLICATION_PATH}/build/ios/SourcePackages"
fi

if [ -n "${BUILD_DIR:-}" ]; then
  derived_root="${BUILD_DIR%/Build/*}"
  add_candidate "${derived_root}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  add_candidate "${BUILD_DIR}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  search_roots="${search_roots} ${derived_root} ${BUILD_DIR}"
fi

search_roots="${search_roots} ${SRCROOT}/../build/ios/SourcePackages"

uploader=""
old_ifs=$IFS
IFS='
'
for path in $candidates; do
  if [ -n "$path" ] && [ -f "$path" ]; then
    uploader=$path
    break
  fi
done
IFS=$old_ifs

if [ -z "$uploader" ]; then
  # shellcheck disable=SC2086
  uploader=$(find $search_roots -type f -path '*Crashlytics/upload-symbols' -print -quit 2>/dev/null || true)
fi

if [ -z "$uploader" ]; then
  echo "warning: Crashlytics upload-symbols was not found under CocoaPods or Swift Package Manager. Skipping dSYM upload."
  exit 0
fi

echo "Uploading Crashlytics dSYMs with ${uploader}"
"$uploader" --build-phase --validate -gsp "${PROJECT_DIR}/Runner/GoogleService-Info.plist" -p ios
