#!/bin/bash

if [ -f /usr/bin/xcodebuild ]; then
	BUILDTOOL="xcodebuild -project iTerm.xcode"
else
	BUILDTOOL=pbxbuild
fi

${BUILDTOOL} $*

