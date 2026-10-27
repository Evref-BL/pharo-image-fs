Class {
	#name : 'PIFSToolStopProjectionTest',
	#superclass : 'PIFSToolTestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolStopProjectionTest >> testRefusesToGuessWhichProjectionToStop [

	| result |
	self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStopProjection new arguments: Dictionary new.
	self assert: result isError.
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
