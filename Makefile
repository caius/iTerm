##
## $Id: Makefile,v 1.5 2008-08-20 17:02:57 delx Exp $
## iTerm Makefile
## 2003 Copyright(C) Ujwal S. Setlur
##

CONFIGURATION=Development
PROJECTNAME=iTerm

all:
	xcodebuild -alltargets -configuration $(CONFIGURATION)

clean:
	xcodebuild -alltargets clean
	rm -rf build
	rm -f *~

Development:
	xcodebuild -alltargets -configuration Development

Deployment:
	xcodebuild -alltargets -configuration Deployment


