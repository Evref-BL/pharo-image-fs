Class {
	#name : 'PIFSRepositoryTestDouble',
	#superclass : 'Object',
	#instVars : [
		'name',
		'repositoryDirectory',
		'loadedPackages'
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
PIFSRepositoryTestDouble >> repositoryDirectory [

	^ repositoryDirectory
]

{ #category : 'accessing' }
PIFSRepositoryTestDouble >> repositoryDirectory: aFileReference [

	repositoryDirectory := aFileReference
]
