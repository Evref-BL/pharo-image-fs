"
Test double for projection backend tests. It keeps write validation against loaded packages but suppresses Iceberg export so tests do not depend on repository ownership or dirty the checkout.
"
Class {
	#name : 'PharoImageFSTestProjectionBackend',
	#superclass : 'PharoImageFSProjectionBackend',
	#instVars : [
		'exportedPackageNames',
		'remainingExportFailures',
		'loadedClassDefinitionCount',
		'loadedMethodSelectors',
		'unloadedMethodSelectors'
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
	remainingExportFailures := 0.
	self resetAppliedDefinitions
]

{ #category : 'private - writing' }
PharoImageFSTestProjectionBackend >> loadClassDefinition: classDefinition [

	loadedClassDefinitionCount := loadedClassDefinitionCount + 1.
	super loadClassDefinition: classDefinition
]

{ #category : 'private - writing' }
PharoImageFSTestProjectionBackend >> loadMethodDefinition: methodDefinition [

	loadedMethodSelectors add: methodDefinition selector.
	super loadMethodDefinition: methodDefinition
]

{ #category : 'accessing' }
PharoImageFSTestProjectionBackend >> loadedClassDefinitionCount [

	^ loadedClassDefinitionCount
]

{ #category : 'accessing' }
PharoImageFSTestProjectionBackend >> loadedMethodSelectors [

	^ loadedMethodSelectors asArray
]

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> repositoryInfos [

	^ {
		  (OrderedDictionary new
			   at: #name put: 'Fixture Repository';
			   at: #projectionName put: 'Fixture Repository';
			   at: #path put: '/tmp/fixture-repository';
			   at: #loadedPackages put: {
					   'PharoImageFS-Tests'.
					   'PharoImageFS-Tests-Resources' };
			   yourself) }
]

{ #category : 'private - repositories' }
PharoImageFSTestProjectionBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: packageName ifAbsent: absentBlock
]

{ #category : 'testing' }
PharoImageFSTestProjectionBackend >> resetAppliedDefinitions [

	loadedClassDefinitionCount := 0.
	loadedMethodSelectors := OrderedCollection new.
	unloadedMethodSelectors := OrderedCollection new
]

{ #category : 'private - writing' }
PharoImageFSTestProjectionBackend >> unloadMethodDefinition: methodDefinition [

	unloadedMethodSelectors add: methodDefinition selector.
	super unloadMethodDefinition: methodDefinition
]

{ #category : 'accessing' }
PharoImageFSTestProjectionBackend >> unloadedMethodSelectors [

	^ unloadedMethodSelectors asArray
]
