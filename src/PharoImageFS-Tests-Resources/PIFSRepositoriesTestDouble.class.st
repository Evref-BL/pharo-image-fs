"
Answers the repositories it was given instead of the image's loaded Iceberg repositories, so ownership and export can be tested against doubles.
"
Class {
	#name : 'PIFSRepositoriesTestDouble',
	#superclass : 'PIFSRepositories',
	#instVars : [
		'repositories'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'accessing' }
PIFSRepositoriesTestDouble >> all [

	^ repositories ifNil: [ #(  ) ]
]

{ #category : 'accessing' }
PIFSRepositoriesTestDouble >> all: aCollection [

	repositories := aCollection
]
