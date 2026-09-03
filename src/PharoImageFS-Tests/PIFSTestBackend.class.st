"
Test double for projection backend tests. It keeps write validation against loaded packages but suppresses Iceberg export so tests do not depend on repository ownership or dirty the checkout.
"
Class {
	#name : 'PIFSTestBackend',
	#superclass : 'PIFSBackend',
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
PIFSTestBackend >> exportPackageNamed: packageName [

	remainingExportFailures > 0 ifTrue: [
			remainingExportFailures := remainingExportFailures - 1.
			Error signal: 'Simulated export failure for ' , packageName ].
	exportedPackageNames add: packageName
]

{ #category : 'accessing' }
PIFSTestBackend >> exportedPackageNames [

	^ exportedPackageNames asArray
]

{ #category : 'testing' }
PIFSTestBackend >> failNextExport [

	self failNextExports: 1
]

{ #category : 'testing' }
PIFSTestBackend >> failNextExports: anInteger [

	remainingExportFailures := anInteger
]

{ #category : 'initialization' }
PIFSTestBackend >> initialize [

	super initialize.
	exportedPackageNames := OrderedCollection new.
	remainingExportFailures := 0.
	self resetAppliedDefinitions
]

{ #category : 'private - writing' }
PIFSTestBackend >> loadClassDefinition: classDefinition [

	loadedClassDefinitionCount := loadedClassDefinitionCount + 1.
	super loadClassDefinition: classDefinition
]

{ #category : 'private - writing' }
PIFSTestBackend >> loadMethodDefinition: methodDefinition [

	loadedMethodSelectors add: methodDefinition selector.
	super loadMethodDefinition: methodDefinition
]

{ #category : 'accessing' }
PIFSTestBackend >> loadedClassDefinitionCount [

	^ loadedClassDefinitionCount
]

{ #category : 'accessing' }
PIFSTestBackend >> loadedMethodSelectors [

	^ loadedMethodSelectors asArray
]

{ #category : 'private - repositories' }
PIFSTestBackend >> repositoryInfos [

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
PIFSTestBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: packageName ifAbsent: absentBlock
]

{ #category : 'testing' }
PIFSTestBackend >> resetAppliedDefinitions [

	loadedClassDefinitionCount := 0.
	loadedMethodSelectors := OrderedCollection new.
	unloadedMethodSelectors := OrderedCollection new
]

{ #category : 'private - writing' }
PIFSTestBackend >> unloadMethodDefinition: methodDefinition [

	unloadedMethodSelectors add: methodDefinition selector.
	super unloadMethodDefinition: methodDefinition
]

{ #category : 'accessing' }
PIFSTestBackend >> unloadedMethodSelectors [

	^ unloadedMethodSelectors asArray
]
