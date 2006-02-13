#!/bin/bash

if [ -f /usr/bin/xcodebuild ]; then
	BUILDTOOL="xcodebuild -project iTerm.xcodeproj"
else
	BUILDTOOL=pbxbuild
fi

${BUILDTOOL} $*

