Class {
	#name : 'PIFSToolStartProjectionTest',
	#superclass : 'PIFSToolTestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolStartProjectionTest >> testAnswersTheProjectionAlreadyMountedAtThatPath [
	"Asking twice has to be safe: a caller may start a projection each time it opens an image, and one left over from a previous run is the same projection."

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

{ #category : 'tests' }
PIFSToolStartProjectionTest >> testAnswersWhyTheProjectionDidNotStart [
	"The code says which failure it was, so that a caller tells a daemon that would not mount from a path already in use without reading the text, which carries the daemon's own words."

	| mountPath result |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	mountPath := (FileLocator temp / 'pifs-tool-test-unmounted') asFileReference.
	[
		result := self
			          withDaemonRunning: #( 'echo "FUSE needs fusermount3"' 'exit 1' )
			          do: [ self resultOf: PIFSToolStartProjection new arguments: { (#mountPath -> mountPath fullName) } asDictionary ].
		self assert: result isError.
		self assert: ((self errorDetailsFrom: result) at: #errorCode) equals: 'DaemonExitedBeforeMounting'.
		self assert: ((self summaryFrom: result) includesSubstring: 'FUSE needs fusermount3').
		self assertEmpty: PIFSServer serversByPort ] ensure: [ mountPath ensureDelete ]
]
