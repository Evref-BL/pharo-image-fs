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
	#name : ''' , self originalClassName , ''',
	#superclass : ''Object'',
	#category : ''PharoImageFS-Tests'',
	#package : ''PharoImageFS-Tests''
}

{ #category : ''accessing'' }
' , self originalClassName , ' >> answer [

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
PharoImageFSProjectionBackendTest >> createReferenceUserClass [

	| class |
	class := ((Object << self referenceUserClassName asSymbol)
		          slots: {  };
		          package: self fixturePackageName) install.
	class
		compile: 'probeClass

	^ ' , self originalClassName
		classified: 'accessing'
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
PharoImageFSProjectionBackendTest >> originalClassName [

	^ 'PharoImageFSProjection' , 'TestClass'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> originalClassTonelPath [

	^ '/tonel/' , self fixturePackageName , '/' , self originalClassName , '.class.st'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> referenceUserClassName [

	^ 'PharoImageFSProjection' , 'ReferenceUser'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> removeClassNamed: className [

	(Smalltalk globals includesKey: className asSymbol) ifFalse: [ ^ self ].
	(Smalltalk globals at: className asSymbol) removeFromSystem
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> removePackageNamed: packageName [

	(PackageOrganizer default packageNamed: packageName ifAbsent: [ nil ]) ifNotNil: [ :package | package removeFromSystem ]
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> renamedClassName [

	^ 'PharoImageFSProjection' , 'RenamedTestClass'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> renamedClassTonelPath [

	^ '/tonel/' , self fixturePackageName , '/' , self renamedClassName , '.class.st'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> targetPackageName [

	^ 'PharoImageFS-ProjectionTargetFixture'
]

{ #category : 'running' }
PharoImageFSProjectionBackendTest >> tearDown [

	[
		self removeClassNamed: self originalClassName.
		self removeClassNamed: self renamedClassName.
		self removeClassNamed: self referenceUserClassName.
		self removeClassNamed: 'PharoImageFSProjectionExtensionTarget'.
		self removePackageNamed: self targetPackageName ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testDeleteRemovesClassTonelFile [

	| backend |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend delete: self originalClassTonelPath.
	self deny: (Smalltalk globals includesKey: self originalClassName asSymbol).
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testDeleteRemovesExtensionTonelFile [

	| backend targetClass |
	self createExtensionTargetClass.
	backend := self newBackend.
	backend
		write: self extensionTonelSource
		at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	backend delete: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	targetClass := Smalltalk globals at: #PharoImageFSProjectionExtensionTarget.
	self deny: (targetClass includesSelector: #projectedExtensionAnswer).
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testListRootExposesTonelAndCritiques [

	| names |
	names := (self newBackend list: '/') collect: [ :entry | entry name ].
	self assert: names asArray equals: #( 'tonel' 'critiques' )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRenameClassTonelFileRenamesClassAndReferences [

	| backend referenceUser renamedClass |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	self createReferenceUserClass.
	backend rename: self originalClassTonelPath to: self renamedClassTonelPath.
	renamedClass := Smalltalk globals at: self renamedClassName asSymbol.
	referenceUser := Smalltalk globals at: self referenceUserClassName asSymbol.
	self deny: (Smalltalk globals includesKey: self originalClassName asSymbol).
	self assert: renamedClass new answer equals: 42.
	self assert: referenceUser new probeClass equals: renamedClass.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRenameExtensionTonelFileSignalsUnsupportedWrite [

	self
		should: [ self newBackend rename: '/tonel/PharoImageFS-Tests/Old.extension.st' to: '/tonel/PharoImageFS-Tests/New.extension.st' ]
		raise: Error
		whoseDescriptionIncludes: 'Projection path is not writable yet:'
		description: 'Extension file rename has no safe V1 semantics.'
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteClassTonelFileWithDifferentPathRenamesClass [

	| backend renamedClass |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend write: self classTonelSource at: self renamedClassTonelPath.
	renamedClass := Smalltalk globals at: self renamedClassName asSymbol.
	self deny: (Smalltalk globals includesKey: self originalClassName asSymbol).
	self assert: renamedClass new answer equals: 42.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteCreatesNewClassFromTonelFile [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
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
