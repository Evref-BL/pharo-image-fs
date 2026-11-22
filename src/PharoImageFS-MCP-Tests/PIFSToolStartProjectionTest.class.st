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
	"The code says which failure it was, so that a caller tells a daemon that would not mount from a path already in use without reading the text, which carries the daemon's own words and names its log, kept for the rest of them."

	| result details |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	result := self withDaemonRunning: #( 'echo "FUSE needs fusermount3"' 'exit 1' ) do: [ :directory |
		          self resultOf: PIFSToolStartProjection new arguments: { (#mountPath -> (directory / 'mount') fullName) } asDictionary ].
	details := self errorDetailsFrom: result.
	[
		self assert: result isError.
		self assert: (details at: #errorCode) equals: 'DaemonExitedBeforeMounting'.
		self assert: ((self summaryFrom: result) includesSubstring: 'FUSE needs fusermount3').
		self assert: ((self summaryFrom: result) includesSubstring: (details at: #daemonLog)).
		self assert: (details at: #daemonLog) asFileReference exists.
		self assertEmpty: PIFSServer serversByPort ] ensure: [
		details at: #daemonLog ifPresent: [ :path | path asFileReference ensureDelete ] ]
]
