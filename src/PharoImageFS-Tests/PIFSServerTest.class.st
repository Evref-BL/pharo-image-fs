"
Tests for the Pharo-side projection HTTP server lifecycle registry.
"
Class {
	#name : 'PIFSServerTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'running' }
PIFSServerTest >> setUp [

	super setUp.
	PIFSServer stopAll
]

{ #category : 'running' }
PIFSServerTest >> tearDown [

	[ PIFSServer stopAll ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PIFSServerTest >> testDaemonCommandClosesInheritedFileDescriptorsBeforeExec [

	| command projectionServer |
	projectionServer := PIFSServer startOn: self testPort.
	projectionServer instVarNamed: 'daemonPidFile' put: FileLocator temp / 'pharo-image-fs-test.pid'.
	projectionServer instVarNamed: 'daemonLogFile' put: FileLocator temp / 'pharo-image-fs-test.log'.
	command := projectionServer daemonCommandMountedAt: FileLocator temp / 'Pharo Image FS Test' named: 'Pharo Image'.
	self assert: (command includesSubstring: 'for fd in /dev/fd/*').
	self assert: (command includesSubstring: 'exec nohup ''./pharo-image-fs''')
]

{ #category : 'tests' }
PIFSServerTest >> testDaemonCommandIncludesEndpointMountPointAndMountName [

	| command projectionServer |
	projectionServer := PIFSServer startOn: self testPort.
	projectionServer instVarNamed: 'daemonPidFile' put: FileLocator temp / 'pharo-image-fs-test.pid'.
	projectionServer instVarNamed: 'daemonLogFile' put: FileLocator temp / 'pharo-image-fs-test.log'.
	command := projectionServer daemonCommandMountedAt: FileLocator temp / 'Pharo Image FS Test' named: 'Pharo Image'.
	self assert: (command includesSubstring: '--endpoint ''http://127.0.0.1:19023/projection''').
	self assert: (command includesSubstring: '--mount-option ''volname=Pharo Image''').
	self assert: (command includesSubstring: 'Pharo Image FS Test')
]

{ #category : 'tests' }
PIFSServerTest >> testDefaultMountPathUsesDefaultMountNameInTemp [

	self
		assert: PIFSServer defaultMountPath basename
		equals: PIFSServer defaultMountName.
	self assert: PIFSServer defaultMountName isEmpty not
]

{ #category : 'private' }
PIFSServerTest >> testPort [

	^ 19023
]

{ #category : 'tests' }
PIFSServerTest >> testStartOnOccupiedPortSignalsClearError [

	| occupyingSocket |
	occupyingSocket := ZnNetworkingUtils serverSocketOn: self testPort.
	[
		self
			should: [ PIFSServer startOn: self testPort ]
			raise: Error
			whoseDescriptionIncludes: 'port may already be in use'
			description: 'PIFS should fail clearly when the requested projection port is occupied by another server.'.
		self assert: (PIFSServer serverOn: self testPort) isNil ] ensure: [ occupyingSocket destroy ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartOnRegistersServerByPort [

	| projectionServer |
	projectionServer := PIFSServer startOn: self testPort.
	self assert: (PIFSServer serverOn: self testPort) equals: projectionServer.
	self assert: projectionServer port equals: self testPort
]

{ #category : 'tests' }
PIFSServerTest >> testStartOnStartsProjectionOnly [

	| projectionServer |
	projectionServer := PIFSServer startOn: self testPort.
	self assert: projectionServer mountPath isNil.
	self assert: projectionServer mountName isNil
]

{ #category : 'tests' }
PIFSServerTest >> testStartingSamePortReplacesRegisteredServer [

	| firstServer secondServer |
	firstServer := PIFSServer startOn: self testPort.
	secondServer := PIFSServer startOn: self testPort.
	self deny: firstServer == secondServer.
	self assert: (PIFSServer serverOn: self testPort) equals: secondServer.
	self assert: firstServer port isNil
]

{ #category : 'tests' }
PIFSServerTest >> testStopOnUnregistersServerByPort [

	PIFSServer startOn: self testPort.
	PIFSServer stopOn: self testPort.
	self assert: (PIFSServer serverOn: self testPort) isNil
]
