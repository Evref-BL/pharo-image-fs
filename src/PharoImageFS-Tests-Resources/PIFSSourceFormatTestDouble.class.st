"
Stands in for the Iceberg chain a repository answers its source format through, so a format can be declared in a test without a real checkout: properties, then writerClass, then id.
"
Class {
	#name : 'PIFSSourceFormatTestDouble',
	#superclass : 'Object',
	#instVars : [
		'id'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'instance creation' }
PIFSSourceFormatTestDouble class >> id: aSymbol [

	^ self new
		  id: aSymbol;
		  yourself
]

{ #category : 'accessing' }
PIFSSourceFormatTestDouble >> id [

	^ id
]

{ #category : 'accessing' }
PIFSSourceFormatTestDouble >> id: aSymbol [

	id := aSymbol
]

{ #category : 'accessing' }
PIFSSourceFormatTestDouble >> writerClass [

	^ self
]
