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
