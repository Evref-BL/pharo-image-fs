Class {
	#name : 'PharoImageFSRepositoryOwnershipTestBackend',
	#superclass : 'PharoImageFSProjectionBackend',
	#instVars : [
		'repositories'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'accessing' }
PharoImageFSRepositoryOwnershipTestBackend >> iceRepositories [

	^ repositories
]

{ #category : 'accessing' }
PharoImageFSRepositoryOwnershipTestBackend >> iceRepositories: aCollection [

	repositories := aCollection
]
