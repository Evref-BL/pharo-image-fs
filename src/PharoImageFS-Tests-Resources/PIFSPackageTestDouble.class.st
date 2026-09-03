Class {
	#name : 'PIFSPackageTestDouble',
	#superclass : 'Object',
	#instVars : [
		'packageName'
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

{ #category : 'accessing' }
PIFSPackageTestDouble >> packageName [

	^ packageName
]

{ #category : 'accessing' }
PIFSPackageTestDouble >> packageName: aString [

	packageName := aString
]
