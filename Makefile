##
## $Id: Makefile,v 1.3 2004-07-23 15:07:53 ujwal Exp $
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

Development:
	./iTermBuild.sh -alltargets -buildstyle Development

Deployment:
	./iTermBuild.sh -alltargets -buildstyle Deployment


