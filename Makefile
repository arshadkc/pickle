.PHONY: build run clean

build:
	xcodegen generate
	xcodebuild -scheme Pickle -configuration Debug -derivedDataPath .build build

run: build
	open .build/Build/Products/Debug/Pickle.app

clean:
	rm -rf .build
	rm -rf Pickle.xcodeproj
