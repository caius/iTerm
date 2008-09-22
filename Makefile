##
## $Id: Makefile,v 1.6 2008-09-22 23:39:13 delx Exp $
## iTerm Makefile
## 2003 Copyright(C) Ujwal S. Setlur
##

CONFIGURATION=Development
PROJECTNAME=iTerm

all:
	umask 0022 && \
	xcodebuild -alltargets -configuration $(CONFIGURATION)

clean:
	umask 0022 && \
	xcodebuild -alltargets clean
	rm -rf build
	rm -f *~

Development:
	umask 0022 && \
	xcodebuild -alltargets -configuration Development

Deployment:
	umask 0022 && \
	xcodebuild -alltargets -configuration Deployment


