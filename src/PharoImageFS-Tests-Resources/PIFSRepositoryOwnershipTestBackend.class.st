Class {
	#name : 'PIFSRepositoryOwnershipTestBackend',
	#superclass : 'PIFSBackend',
	#instVars : [
		'repositories'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'accessing' }
PIFSRepositoryOwnershipTestBackend >> iceRepositories [

	^ repositories
]

{ #category : 'accessing' }
PIFSRepositoryOwnershipTestBackend >> iceRepositories: aCollection [

	repositories := aCollection
]
