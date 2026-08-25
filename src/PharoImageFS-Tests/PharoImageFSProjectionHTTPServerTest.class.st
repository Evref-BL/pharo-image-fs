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

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testDaemonCommandIncludesEndpointMountPointAndMountName [

	| command projectionServer |
	projectionServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	projectionServer instVarNamed: 'daemonPidFile' put: FileLocator temp / 'pharo-image-fs-test.pid'.
	projectionServer instVarNamed: 'daemonLogFile' put: FileLocator temp / 'pharo-image-fs-test.log'.
	command := projectionServer daemonCommandMountedAt: FileLocator temp / 'Pharo Image FS Test' named: 'Pharo Image'.
	self assert: (command includesSubstring: '--endpoint ''http://127.0.0.1:19023/projection''').
	self assert: (command includesSubstring: '--mount-option ''volname=Pharo Image''').
	self assert: (command includesSubstring: 'Pharo Image FS Test')
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testDefaultMountPathUsesDefaultMountNameInTemp [

	self
		assert: PharoImageFSProjectionHTTPServer defaultMountPath basename
		equals: PharoImageFSProjectionHTTPServer defaultMountName.
	self assert: PharoImageFSProjectionHTTPServer defaultMountName isEmpty not
]

{ #category : 'private' }
PharoImageFSProjectionHTTPServerTest >> testPort [

	^ 19023
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStartOnOccupiedPortSignalsClearError [

	| occupyingSocket |
	occupyingSocket := ZnNetworkingUtils serverSocketOn: self testPort.
	[
		self
			should: [ PharoImageFSProjectionHTTPServer startOn: self testPort ]
			raise: Error
			whoseDescriptionIncludes: 'port may already be in use'
			description: 'PIFS should fail clearly when the requested projection port is occupied by another server.'.
		self assert: (PharoImageFSProjectionHTTPServer serverOn: self testPort) isNil ] ensure: [ occupyingSocket destroy ]
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStartOnRegistersServerByPort [

	| projectionServer |
	projectionServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	self assert: (PharoImageFSProjectionHTTPServer serverOn: self testPort) equals: projectionServer.
	self assert: projectionServer port equals: self testPort
]

{ #category : 'tests' }
PharoImageFSProjectionHTTPServerTest >> testStartOnStartsProjectionOnly [

	| projectionServer |
	projectionServer := PharoImageFSProjectionHTTPServer startOn: self testPort.
	self assert: projectionServer mountPath isNil.
	self assert: projectionServer mountName isNil
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
