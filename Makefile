##
## $Id: Makefile,v 1.1.1.1 2002-11-26 04:56:47 ujwal Exp $
## JTerminal Makefile
## 2001 Copyright(C) Kiichi Kusama
##

PBXBUILD=pbxbuild
BUILDSTYLE=Development
PROJECTNAME=JTerminal

all:
	$(PBXBUILD) -buildstyle $(BUILDSTYLE)

clean:
	$(PBXBUILD) clean
	rm -rf build
	rm -f *~

