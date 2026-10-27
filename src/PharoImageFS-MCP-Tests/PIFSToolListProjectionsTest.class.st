Class {
	#name : 'PIFSToolListProjectionsTest',
	#superclass : 'PIFSToolTestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolListProjectionsTest >> testListsAProjectionWithItsPortAndMountPath [

	| projectionServer result entry |
	projectionServer := self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolListProjections new arguments: Dictionary new.
	entry := ((self dataFrom: result) at: #projections) first.
	self assert: (entry at: #port) equals: projectionServer port.
	self assert: (entry at: #mountPath) equals: self temporaryMountPath.
	self assert: (entry at: #name) equals: 'Test Volume'
]

{ #category : 'tests' }
PIFSToolListProjectionsTest >> testListsNothingWhenTheImageServesNoProjection [

	| result |
	result := self resultOf: PIFSToolListProjections new arguments: Dictionary new.
	self deny: result isError.
	self assertEmpty: ((self dataFrom: result) at: #projections)
]
