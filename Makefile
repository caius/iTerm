##
## $Id: Makefile,v 1.2 2003-11-13 23:45:29 ujwal Exp $
## iTerm Makefile
## 2003 Copyright(C) Ujwal S. Sathyam
##

PBXBUILD=pbxbuild
XCODEBUILD="xcodebuild -project iTerm.xcode"  
BUILDSTYLE=Development
PROJECTNAME=iTerm

all:
	./iTermBuild.sh -alltargets -buildstyle $(BUILDSTYLE)

clean:
	./iTermBuild.sh -alltargets clean
	rm -rf build
	rm -f *~

