"
Tests for the Pharo-side projection HTTP server lifecycle registry.
"
Class {
	#name : 'PharoImageFSProjectionHTTPServerTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'running' }
PharoImageFSProjectionHTTPServerTest >> setUp [

	super setUp.
	PharoImageFSProjectionHTTPServer stopAll
]

{ #category : 'running' }
PharoImageFSProjectionHTTPServerTest >> tearDown [

	[ PharoImageFSProjectionHTTPServer stopAll ] ensure: [ super tearDown ]
]

{ #category : 'private' }
PharoImageFSProjectionHTTPServerTest >> testPort [

	^ 19023
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStartOnRegistersServerByPort [

	| projectionServer |
	projectionServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	self assert: (PharoImageFSProjectionHTTPServer serverOn: self testPort) equals: projectionServer.
	self assert: projectionServer port equals: self testPort
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStartingSamePortReplacesRegisteredServer [

	| firstServer secondServer |
	firstServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	secondServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	self deny: firstServer == secondServer.
	self assert: (PharoImageFSProjectionHTTPServer serverOn: self testPort) equals: secondServer.
	self assert: firstServer port isNil
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStopOnUnregistersServerByPort [

	PharoImageFSProjectionHTTPServer startOn: self testPort.
	PharoImageFSProjectionHTTPServer stopOn: self testPort.
	self assert: (PharoImageFSProjectionHTTPServer serverOn: self testPort) isNil
]
