Class {
	#name : 'PIFSToolStopProjectionTest',
	#superclass : 'PIFSToolTestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testRefusesAPortNoProjectionCanAnswerOn [
	"The schema says so, so MCP refuses it as it refuses any argument a schema does not allow, before the tool runs."

	self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	self should: [ self resultOf: PIFSToolStopProjection new arguments: { (#port -> 0) } asDictionary ] raise: MCPInvalidToolInput.
	self assert: PIFSServer serversByPort size equals: 1
]

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testRefusesToGuessWhichProjectionToStop [

	| result |
	self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStopProjection new arguments: Dictionary new.
	self assert: result isError.
	self assert: ((self errorDetailsFrom: result) at: #errorCode) equals: 'MountPathOrPortRequired'.
	self assert: PIFSServer serversByPort size equals: 1
]

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testReportsWhatIsServedWhenNoProjectionAnswersOnThePort [
	"A port names a projection as a mount path does, and missing it is the same failure."

	| projectionServer result |
	projectionServer := self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStopProjection new arguments: { (#port -> (projectionServer port + 1)) } asDictionary.
	self assert: result isError.
	self assert: ((self errorDetailsFrom: result) at: #errorCode) equals: 'ProjectionNotFound'.
	self assert: ((self errorDetailsFrom: result) at: #projections) size equals: 1.
	self assert: PIFSServer serversByPort size equals: 1
]

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testReportsWhatIsServedWhenNoProjectionMatches [

	| result |
	self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self
		          resultOf: PIFSToolStopProjection new
		          arguments: { (#mountPath -> (FileLocator temp / 'nothing-mounted-here') fullName) } asDictionary.
	self assert: result isError.
	self assert: ((self errorDetailsFrom: result) at: #errorCode) equals: 'ProjectionNotFound'.
	self assert: ((self errorDetailsFrom: result) at: #projections) size equals: 1.
	self assert: PIFSServer serversByPort size equals: 1
]

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testStopsTheProjectionAnsweringOnAPort [

	| projectionServer result |
	projectionServer := self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStopProjection new arguments: { (#port -> projectionServer port) } asDictionary.
	self deny: result isError.
	self assertEmpty: PIFSServer serversByPort
]

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testStopsTheProjectionMountedAtAPath [

	| projectionServer result |
	projectionServer := self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStopProjection new arguments: { (#mountPath -> self temporaryMountPath) } asDictionary.
	self deny: result isError.
	self assertEmpty: PIFSServer serversByPort.
	self assert: ((self dataFrom: result) at: #mountPath) equals: self temporaryMountPath
]
