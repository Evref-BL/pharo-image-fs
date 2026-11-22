"
Shared setup for the tests of the MCP tools PIFS serves.

A projection is only mounted through a daemon and a FUSE volume, which a test has no business doing, so these start the projection endpoint and fill in what a mount would have recorded.
"
Class {
	#name : 'PIFSToolTestCase',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'testing' }
PIFSToolTestCase class >> isAbstract [

	^ self = PIFSToolTestCase
]

{ #category : 'helpers' }
PIFSToolTestCase >> dataFrom: aResult [

	^ aResult structuredContent at: #data
]

{ #category : 'helpers' }
PIFSToolTestCase >> errorDetailsFrom: aResult [

	^ aResult structuredContent at: #error
]

{ #category : 'helpers' }
PIFSToolTestCase >> projectionMountedAt: aPath named: aName [
	"A projection serving its endpoint, filled in with what mounting it would have recorded."

	| projectionServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	projectionServer instVarNamed: 'mountPath' put: aPath asFileReference.
	projectionServer instVarNamed: 'mountName' put: aName.
	^ projectionServer
]

{ #category : 'helpers' }
PIFSToolTestCase >> resultOf: aTool arguments: aDictionary [

	^ aTool executeWithRequest: (aTool requestFromToolCallArguments: aDictionary)
]

{ #category : 'running' }
PIFSToolTestCase >> setUp [

	super setUp.
	PIFSServer stopAll
]

{ #category : 'helpers' }
PIFSToolTestCase >> summaryFrom: aResult [

	^ aResult structuredContent at: #summary
]

{ #category : 'running' }
PIFSToolTestCase >> tearDown [

	[ PIFSServer stopAll ] ensure: [ super tearDown ]
]

{ #category : 'helpers' }
PIFSToolTestCase >> temporaryMountPath [

	^ (FileLocator temp / 'pharo-image-fs-tool-test') fullName
]

{ #category : 'helpers' }
PIFSToolTestCase >> withDaemonRunning: shellLines do: aBlock [
	"What aBlock answers, given a directory of the test's own, while a stand-in for the daemon in that directory runs shellLines in its place. PIFSServer runs the executable named like the real one, from the directory PHARO_IMAGE_FS_DAEMON points into. The directory is deleted afterwards, and named for this run alone: another image may be running these tests at the same time. The lines are joined with lf by hand: a string literal spanning lines holds the image's cr."

	| directory daemon previous |
	directory := (FileLocator temp / ('pifs-tool-test-' , UUID new asString)) asFileReference.
	directory ensureCreateDirectory.
	daemon := directory / PIFSServer daemonExecutableName.
	daemon writeStreamDo: [ :stream |
			stream nextPutAll: '#!/bin/sh'.
			shellLines do: [ :line |
					stream
						lf;
						nextPutAll: line ].
			stream lf ].
	LibC system: 'chmod +x ' , (PIFSServer shellQuote: daemon pathString).
	previous := OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' ifAbsent: [ nil ].
	OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' put: daemon pathString.
	^ [ aBlock value: directory ] ensure: [
			  previous
				  ifNil: [ OSEnvironment current removeKey: 'PHARO_IMAGE_FS_DAEMON' ]
				  ifNotNil: [ OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' put: previous ].
			  directory ensureDeleteAll ]
]
