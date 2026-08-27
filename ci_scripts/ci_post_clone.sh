#!/bin/sh
# Xcode Cloud post-clone hook: TwoStep.xcodeproj is generated, never committed.
set -e
brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
