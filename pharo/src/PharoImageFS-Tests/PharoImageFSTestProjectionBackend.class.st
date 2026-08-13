"
Test double for projection backend tests. It keeps write validation against loaded packages but suppresses Iceberg export so tests do not depend on repository ownership or dirty the checkout.
"
Class {
	#name : 'PharoImageFSTestProjectionBackend',
	#superclass : 'PharoImageFSProjectionBackend',
	#instVars : [
		'exportedPackageNames'
	],
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> exportPackageNamed: packageName [

	exportedPackageNames add: packageName
]

{ #category : 'accessing' }
PharoImageFSTestProjectionBackend >> exportedPackageNames [

	^ exportedPackageNames asArray
]

{ #category : 'initialization' }
PharoImageFSTestProjectionBackend >> initialize [

	super initialize.
	exportedPackageNames := OrderedCollection new
]

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: packageName ifAbsent: absentBlock
]
