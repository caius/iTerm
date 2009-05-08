##
## $Id: Makefile,v 1.8 2009-02-06 14:31:07 delx Exp $
## iTerm Makefile
## 2003 Copyright(C) Ujwal S. Setlur
##

CONFIGURATION=Development
PROJECTNAME=iTerm

all:
	xcodebuild -alltargets -configuration $(CONFIGURATION) && \
	chmod -R go+rX build

zip: Deployment
	cd build/Deployment && \
	zip -r iTerm.app.zip iTerm.app

clean:
	xcodebuild -alltargets clean
	rm -rf build
	rm -f *~

Development:
	xcodebuild -alltargets -configuration Development && \
	chmod -R go+rX build/Development

Deployment:
	xcodebuild -alltargets -configuration Deployment && \
	chmod -R go+rX build/Deployment


