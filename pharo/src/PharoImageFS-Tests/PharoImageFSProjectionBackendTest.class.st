"
Tests for the Pharo-side projection backend used by pharo-image-fs.
"
Class {
	#name : 'PharoImageFSProjectionBackendTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> classTonelSource [

	^ 'Class {
	#name : ''PharoImageFSProjectionTestClass'',
	#superclass : ''Object'',
	#category : ''PharoImageFS-Tests'',
	#package : ''PharoImageFS-Tests''
}

{ #category : ''accessing'' }
PharoImageFSProjectionTestClass >> answer [

	^ 42
]
'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> createExtensionTargetClass [

	((Object << #PharoImageFSProjectionExtensionTarget)
		 slots: {  };
		 package: self targetPackageName) install
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> extensionTonelSource [

	^ 'Extension { #name : ''PharoImageFSProjectionExtensionTarget'' }

{ #category : ''*PharoImageFS-Tests'' }
PharoImageFSProjectionExtensionTarget >> projectedExtensionAnswer [

	^ 7
]
'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> fixturePackageName [

	^ 'PharoImageFS-Tests'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> newBackend [

	^ PharoImageFSTestProjectionBackend new
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> removeClassNamed: className [

	Smalltalk globals at: className asSymbol ifPresent: [ :class | class removeFromSystem ]
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> removePackageNamed: packageName [

	(PackageOrganizer default packageNamed: packageName ifAbsent: [ nil ]) ifNotNil: [ :package | package removeFromSystem ]
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> targetPackageName [

	^ 'PharoImageFS-ProjectionTargetFixture'
]

{ #category : 'running' }
PharoImageFSProjectionBackendTest >> tearDown [

	[
		self removeClassNamed: 'PharoImageFSProjectionTestClass'.
		self removeClassNamed: 'PharoImageFSProjectionExtensionTarget'.
		self removePackageNamed: self targetPackageName ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testDeleteSignalsUnsupportedWrite [

	self
		should: [ self newBackend delete: '/tonel/PharoImageFS-Tests/SomeClass.class.st' ]
		raise: Error
		whoseDescriptionIncludes: 'Projection path is not writable yet:'
		description: 'V1 does not delete projected code files directly.'
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testListRootExposesTonelAndCritiques [

	| names |
	names := (self newBackend list: '/') collect: [ :entry | entry name ].
	self assert: names asArray equals: #( 'tonel' 'critiques' )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRenameSignalsUnsupportedWrite [

	self
		should: [ self newBackend rename: '/tonel/PharoImageFS-Tests/Old.class.st' to: '/tonel/PharoImageFS-Tests/New.class.st' ]
		raise: Error
		whoseDescriptionIncludes: 'Projection path is not writable yet:'
		description: 'V1 does not rename projected code files directly.'
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteCreatesNewClassFromTonelFile [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionTestClass.class.st'.
	class := Smalltalk globals at: #PharoImageFSProjectionTestClass.
	self assert: class package name equals: self fixturePackageName.
	self assert: class new answer equals: 42.
	self assert: backend exportedPackageNames equals: { self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteCreatesNewExtensionFromTonelFile [

	| backend targetClass |
	self createExtensionTargetClass.
	backend := self newBackend.
	backend
		write: self extensionTonelSource
		at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	targetClass := Smalltalk globals at: #PharoImageFSProjectionExtensionTarget.
	self assert: (targetClass new perform: #projectedExtensionAnswer) equals: 7.
	self assert: backend exportedPackageNames equals: { self fixturePackageName }
]
