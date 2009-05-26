PATH := /usr/bin:/bin:/usr/sbin:/sbin

Development:
	xcodebuild -alltargets -configuration Development && \
	chmod -R go+rX build/Development

Deployment:
	xcodebuild -alltargets -configuration Deployment && \
	chmod -R go+rX build/Deployment

run: Development
	build/Development/iTerm.app/Contents/MacOS/iTerm

zip: Deployment
	cd build/Deployment && \
	zip -r iTerm.app.zip iTerm.app

clean:
	xcodebuild -alltargets clean
	rm -rf build
	rm -f *~


