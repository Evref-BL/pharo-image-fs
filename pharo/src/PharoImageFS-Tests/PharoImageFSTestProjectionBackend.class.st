"
Test double for projection backend tests. It keeps write validation against loaded packages but suppresses Iceberg export so tests do not depend on repository ownership or dirty the checkout.
"
Class {
	#name : 'PharoImageFSTestProjectionBackend',
	#superclass : 'PharoImageFSProjectionBackend',
	#instVars : [
		'exportedPackageNames',
		'remainingExportFailures'
	],
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> exportPackageNamed: packageName [

	remainingExportFailures > 0 ifTrue: [
			remainingExportFailures := remainingExportFailures - 1.
			Error signal: 'Simulated export failure for ' , packageName ].
	exportedPackageNames add: packageName
]

{ #category : 'accessing' }
PharoImageFSTestProjectionBackend >> exportedPackageNames [

	^ exportedPackageNames asArray
]

{ #category : 'testing' }
PharoImageFSTestProjectionBackend >> failNextExport [

	self failNextExports: 1
]

{ #category : 'testing' }
PharoImageFSTestProjectionBackend >> failNextExports: anInteger [

	remainingExportFailures := anInteger
]

{ #category : 'initialization' }
PharoImageFSTestProjectionBackend >> initialize [

	super initialize.
	exportedPackageNames := OrderedCollection new.
	remainingExportFailures := 0
]

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: packageName ifAbsent: absentBlock
]
