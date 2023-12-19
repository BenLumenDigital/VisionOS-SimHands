#  VisionOS Simulator hands

This project aims to inject "real" hands into the Vision OS simulator.

It does this by using 2 things:

1) A macOS helper app, with a bonjour service
2) A Swift class for your VisionOS project which connects to the bonjour service

# Current Status

This is a proof of concept.  Consider it unmaintained because I simply don't have much free time for OSS!

This code does NOT inject hands at the OS level, so don't expect it to control native things like pinch gestures, moving windows and interacting with VsionOS.  This is not possible right now.

Instead, this project is useful for people who want to test how hands might interact with other 3D elements and also people who want to start working on custom hand gestures (such as those seen in the HappyBeam sample project).

# macOS Helper App

The helper app uses Google MediaPipes for 3D hand tracking.  This is a very basic setup - it uses a WKWebView to run the Google sample code, and that passed the hand data as JSON into native Swift.

The Swift code then spits out the JSON over a Bonjour service.

# VisionOS code

This is mostly a single file which looks for the Bonjour service and ingests the data.  It will create a Hand object per hand found, with properties similar to RealityKit.
