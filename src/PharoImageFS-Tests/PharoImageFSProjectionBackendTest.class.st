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
PharoImageFSProjectionBackendTest >> classTonelSourceWithDeadBlock [

	^ self classTonelSource , '
{ #category : ''tests'' }
' , self originalClassName , ' >> deadBlockProbe [

	[ self error: ''never run'' ]
]
'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> classTonelSourceWithChangedAnswerAndExtraMethod [

	^ self classTonelSourceWithExtraMethod copyReplaceAll: '^ 42' with: '^ 43'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> classTonelSourceWithExtraMethod [

	^ self classTonelSource , '
{ #category : ''accessing'' }
' , self originalClassName , ' >> extraAnswer [

	^ 99
]
'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> classTonelSourceWithSlot [

	^ 'Class {
	#name : ''' , self originalClassName , ''',
	#superclass : ''Object'',
	#instVars : [
		''value''
	],
	#category : ''PharoImageFS-Tests'',
	#package : ''PharoImageFS-Tests''
}

{ #category : ''initialization'' }
' , self originalClassName , ' >> initialize [

	super initialize.
	value := 123
]

{ #category : ''accessing'' }
' , self originalClassName , ' >> value [

	^ value
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
PharoImageFSProjectionBackendTest >> decodedJsonFrom: aString [

	^ STONJSON fromString: aString
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> ensureTargetPackage [

	PackageOrganizer default ensurePackage: self targetPackageName
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

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> targetPackageTonelPath [

	^ '/tonel/' , self targetPackageName , '/' , self originalClassName , '.class.st'
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
PharoImageFSProjectionBackendTest >> testExistingClassRewriteRemovesAbsentMethods [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSourceWithExtraMethod at: self originalClassTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new extraAnswer equals: 99.
	backend write: self classTonelSource at: self originalClassTonelPath.
	self deny: (class includesSelector: #extraAnswer).
	self assert: class new answer equals: 42.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testExistingClassRewriteOnlyLoadsChangedDefinitions [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSourceWithExtraMethod at: self originalClassTonelPath.
	backend resetAppliedDefinitions.
	backend write: self classTonelSourceWithChangedAnswerAndExtraMethod at: self originalClassTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new answer equals: 43.
	self assert: class new extraAnswer equals: 99.
	self assert: backend loadedClassDefinitionCount equals: 0.
	self assert: backend loadedMethodSelectors equals: #( answer ).
	self assert: backend unloadedMethodSelectors equals: #(  )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testExistingClassRewriteUpdatesClassDefinition [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend write: self classTonelSourceWithSlot at: self originalClassTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class instVarNames equals: #( 'value' ).
	self deny: (class includesSelector: #answer).
	self assert: class new value equals: 123.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testExportFailureDuringClassRewriteRollsBackImage [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend failNextExport.
	self
		should: [ backend write: self classTonelSourceWithExtraMethod at: self originalClassTonelPath ]
		raise: Error
		whoseDescriptionIncludes: 'Simulated export failure'
		description: 'A failed export after applying a class rewrite must rollback the live image.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new answer equals: 42.
	self deny: (class includesSelector: #extraAnswer).
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
PharoImageFSProjectionBackendTest >> testMoveAndRenameClassTonelFileSignalsUnsupportedWrite [

	self ensureTargetPackage.
	self
		should: [
				| backend |
				backend := self newBackend.
				backend write: self classTonelSource at: self originalClassTonelPath.
				backend rename: self originalClassTonelPath to: '/tonel/' , self targetPackageName , '/' , self renamedClassName , '.class.st' ]
		raise: Error
		whoseDescriptionIncludes: 'Projection class move and rename in one operation is not supported yet:'
		description: 'Combined class move and rename needs explicit transactional semantics.'
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testMoveClassTonelFileAcrossPackagesMovesClass [

	| backend class |
	self ensureTargetPackage.
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend rename: self originalClassTonelPath to: self targetPackageTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class package name equals: self targetPackageName.
	self assert: class new answer equals: 42.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName.
			self targetPackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testReadClassCritiqueFileReturnsClassAndMethodKeys [

	| backend data |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	data := self decodedJsonFrom: (backend read: '/critiques/' , self originalClassName , '.json').
	self assert: (data includesKey: 'class').
	self assert: (data includesKey: 'methods')
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testReadMethodCritiqueFileReturnsSideKeys [

	| backend data |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	data := self decodedJsonFrom: (backend read: '/critiques/' , self originalClassName , '/answer.json').
	self assert: (data includesKey: 'instance').
	self assert: (data at: 'instance') isEmpty
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
		description: 'Extension file rename is intentionally unsupported.'
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRollbackFailureReportsBothErrors [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend failNextExports: 2.
	self
		should: [ backend write: self classTonelSourceWithExtraMethod at: self originalClassTonelPath ]
		raise: Error
		whoseDescriptionIncludes: 'Projection write failed and rollback failed'
		description: 'Rollback failure should not hide the original write failure.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new answer equals: 42.
	self deny: (class includesSelector: #extraAnswer)
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteBlockedByCritiqueKeepsExistingClass [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	self
		should: [ backend write: self classTonelSourceWithDeadBlock at: self originalClassTonelPath ]
		raise: Error
		whoseDescriptionIncludes: 'Write blocked by critiques'
		description: 'Blocking critiques must reject the transaction before broken methods are installed.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new answer equals: 42.
	self deny: (class includesSelector: #deadBlockProbe)
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
