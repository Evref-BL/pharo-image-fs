Class {
	#name : 'PIFSPackageTestDouble',
	#superclass : 'Object',
	#instVars : [
		'packageName',
		'removed'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'instance creation' }
PIFSPackageTestDouble class >> named: aString [

	^ self new
		  packageName: aString;
		  yourself
]

{ #category : 'testing' }
PIFSPackageTestDouble >> isRemoved [

	^ removed = true
]

{ #category : 'accessing' }
PIFSPackageTestDouble >> packageName [

	^ packageName
]

{ #category : 'accessing' }
PIFSPackageTestDouble >> packageName: aString [

	packageName := aString
]

{ #category : 'removing' }
PIFSPackageTestDouble >> remove [
	"As an Iceberg package removes itself from its repository's working copy."

	removed := true
]
