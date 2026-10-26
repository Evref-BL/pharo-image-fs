Class {
	#name : 'PIFSRepositoryTestDouble',
	#superclass : 'Object',
	#instVars : [
		'name',
		'repositoryDirectory',
		'loadedPackages',
		'sourceFormatId'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'instance creation' }
PIFSRepositoryTestDouble class >> named: aString directory: aFileReference loadedPackages: aCollection [

	^ self new
		  name: aString;
		  repositoryDirectory: aFileReference;
		  loadedPackages: aCollection;
		  yourself
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> loadedPackages [

	^ loadedPackages
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> loadedPackages: aCollection [

	loadedPackages := aCollection
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> name [

	^ name
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> name: aString [

	name := aString
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> properties [
	"A repository that was not given a format answers the way one that cannot
	say does: by failing, which is what the projection reads as unknown."

	sourceFormatId ifNil: [ Error signal: 'This repository double declares no source format.' ].
	^ PIFSSourceFormatTestDouble id: sourceFormatId
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> repositoryDirectory [

	^ repositoryDirectory
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> repositoryDirectory: aFileReference [

	repositoryDirectory := aFileReference
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> sourceFormatId: aSymbol [

	sourceFormatId := aSymbol
]
