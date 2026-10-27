Class {
	#name : 'PIFSToolStartProjectionTest',
	#superclass : 'PIFSToolTestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolStartProjectionTest >> testAnswersTheProjectionAlreadyMountedAtThatPath [
	"Asking twice has to be safe: the plugin starts a projection whenever it opens an image, and one left over from a previous run is the same projection."

	| projectionServer result |
	projectionServer := self projectionMountedAt: self temporaryMountPath named: 'Test Volume'.
	result := self resultOf: PIFSToolStartProjection new arguments: { (#mountPath -> self temporaryMountPath) } asDictionary.
	self deny: result isError.
	self assert: ((self dataFrom: result) at: #port) equals: projectionServer port.
	self assert: PIFSServer serversByPort size equals: 1
]

{ #category : 'tests' }
PIFSToolStartProjectionTest >> testAnswersTheProjectionMountedAtTheDefaultPathWhenNoneIsNamed [

	| projectionServer result |
	projectionServer := self projectionMountedAt: PIFSServer defaultMountPath named: PIFSServer defaultMountName.
	result := self resultOf: PIFSToolStartProjection new arguments: Dictionary new.
	self deny: result isError.
	self assert: ((self dataFrom: result) at: #port) equals: projectionServer port.
	self assert: PIFSServer serversByPort size equals: 1
]
