Class {
	#name : 'PharoImageFSRepositoryTestDouble',
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
PharoImageFSRepositoryTestDouble class >> named: aString directory: aFileReference loadedPackages: aCollection [

	^ self new
		  name: aString;
		  repositoryDirectory: aFileReference;
		  loadedPackages: aCollection;
		  yourself
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> loadedPackages [

	^ loadedPackages
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> loadedPackages: aCollection [

	loadedPackages := aCollection
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> name [

	^ name
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> name: aString [

	name := aString
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> repositoryDirectory [

	^ repositoryDirectory
]

{ #category : 'accessing' }
PharoImageFSRepositoryTestDouble >> repositoryDirectory: aFileReference [

	repositoryDirectory := aFileReference
]
