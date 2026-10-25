"
Tests the file-level decisions a scoped export makes, with no repository: whether a file is written, left alone, or removed.
"
Class {
	#name : 'PIFSRepositoriesTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'tests' }
PIFSRepositoriesTest >> testAFileTheExportNoLongerProducesIsRemoved [

	| root source target |
	root := FileSystem memory root.
	source := root / 'source.class.st'.
	target := root / 'target.class.st'.
	target writeStreamDo: [ :stream | stream nextPutAll: 'removed by this change' ].
	PIFSRepositories new applyExportedFile: source to: target.
	self deny: target exists
]

{ #category : 'tests' }
PIFSRepositoriesTest >> testAnUnchangedFileIsLeftAlone [

	| root source target before |
	root := FileSystem memory root.
	source := root / 'source.class.st'.
	target := root / 'target.class.st'.
	source writeStreamDo: [ :stream | stream nextPutAll: 'written' ].
	target writeStreamDo: [ :stream | stream nextPutAll: 'written' ].
	before := target modificationTime.
	PIFSRepositories new applyExportedFile: source to: target.
	self assert: target contents equals: 'written'.
	self assert: target modificationTime equals: before
]

{ #category : 'tests' }
PIFSRepositoriesTest >> testExportedFileIsWrittenWhenMissing [

	| root source target |
	root := FileSystem memory root.
	source := root / 'source.class.st'.
	target := root / 'target.class.st'.
	source writeStreamDo: [ :stream | stream nextPutAll: 'written' ].
	PIFSRepositories new applyExportedFile: source to: target.
	self assert: target contents equals: 'written'
]

{ #category : 'tests' }
PIFSRepositoriesTest >> testExportedFileReplacesADifferentOne [

	| root source target |
	root := FileSystem memory root.
	source := root / 'source.class.st'.
	target := root / 'target.class.st'.
	source writeStreamDo: [ :stream | stream nextPutAll: 'written' ].
	target writeStreamDo: [ :stream | stream nextPutAll: 'stale' ].
	PIFSRepositories new applyExportedFile: source to: target.
	self assert: target contents equals: 'written'
]
