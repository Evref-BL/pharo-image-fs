Class {
	#name : 'PharoImageFSPackageTestDouble',
	#superclass : 'Object',
	#instVars : [
		'packageName'
	],
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'instance creation' }
PharoImageFSPackageTestDouble class >> named: aString [

	^ self new
		  packageName: aString;
		  yourself
]

{ #category : 'accessing' }
PharoImageFSPackageTestDouble >> packageName [

	^ packageName
]

{ #category : 'accessing' }
PharoImageFSPackageTestDouble >> packageName: aString [

	packageName := aString
]
