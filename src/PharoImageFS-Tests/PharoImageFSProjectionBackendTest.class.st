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
PharoImageFSProjectionBackendTest >> classTonelSourceWithBrokenExtraMethod [

	^ self classTonelSource , '
{ #category : ''accessing'' }
' , self originalClassName , ' >> extraAnswer [

	^ 99
]

{ #category : ''accessing'' }
' , self originalClassName , ' >> brokenAnswer [

	^ self +
]
'
]

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> classTonelSourceWithChangedAnswerAndExtraMethod [

	^ self classTonelSourceWithExtraMethod copyReplaceAll: '^ 42' with: '^ 43'
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
PharoImageFSProjectionBackendTest >> classTonelSourceWithUnformattedMethod [

	^ self classTonelSource , '
{ #category : ''accessing'' }
' , self originalClassName , ' >> messyAnswer [

^(1+2)
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
PharoImageFSProjectionBackendTest >> extensionMoveTonelSource [

	^ 'Extension { #name : ''String'' }

{ #category : ''*PharoImageFS-Tests'' }
String >> pharoImageFSMoveExtensionProbe [

	^ 7
]
'
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
PharoImageFSProjectionBackendTest >> extensionTonelSourceWithBrokenExtraMethod [

	^ self extensionTonelSource , '
{ #category : ''*PharoImageFS-Tests'' }
PharoImageFSProjectionExtensionTarget >> brokenProjectedExtensionAnswer [

	^ self +
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

{ #category : 'private' }
PharoImageFSProjectionBackendTest >> targetRenamedClassTonelPath [

	^ '/tonel/' , self targetPackageName , '/' , self renamedClassName , '.class.st'
]

{ #category : 'running' }
PharoImageFSProjectionBackendTest >> tearDown [

	[
		self removeClassNamed: self originalClassName.
		self removeClassNamed: self renamedClassName.
		self removeClassNamed: self referenceUserClassName.
		self removeClassNamed: 'PharoImageFSProjectionExtensionTarget'.
		(String includesSelector: #pharoImageFSMoveExtensionProbe) ifTrue: [ String removeSelector: #pharoImageFSMoveExtensionProbe ].
		self removePackageNamed: self targetPackageName ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testClassTonelFileDoesNotIncludeExtensionMethods [

	| backend classText extensionText |
	self createExtensionTargetClass.
	backend := self newBackend.
	backend
		write: self extensionTonelSource
		at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	classText := backend read: '/tonel/' , self targetPackageName , '/PharoImageFSProjectionExtensionTarget.class.st'.
	extensionText := backend read: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	self deny: (classText includesSubstring: 'projectedExtensionAnswer').
	self assert: (extensionText includesSubstring: 'projectedExtensionAnswer')
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testCompileFailureDuringClassRewriteRollsBackImage [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	self
		should: [ backend write: self classTonelSourceWithBrokenExtraMethod at: self originalClassTonelPath ]
		raise: Error
		description: 'A method compilation failure after partial application must rollback the live image.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class new answer equals: 42.
	self deny: (class includesSelector: #extraAnswer).
	self deny: (class includesSelector: #brokenAnswer)
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testCompileFailureDuringExtensionRewriteRollsBackImage [

	| backend targetClass |
	self createExtensionTargetClass.
	backend := self newBackend.
	backend
		write: self extensionTonelSource
		at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	self
		should: [
				backend
					write: self extensionTonelSourceWithBrokenExtraMethod
					at: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st' ]
		raise: Error
		description: 'A method compilation failure after partial extension application must rollback the live image.'.
	targetClass := Smalltalk globals at: #PharoImageFSProjectionExtensionTarget.
	self assert: (targetClass new perform: #projectedExtensionAnswer) equals: 7.
	self deny: (targetClass includesSelector: #brokenProjectedExtensionAnswer)
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
PharoImageFSProjectionBackendTest >> testExportFailureDuringClassDeleteRollsBackImage [

	| backend class |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend failNextExport.
	self
		should: [ backend delete: self originalClassTonelPath ]
		raise: Error
		whoseDescriptionIncludes: 'Simulated export failure'
		description: 'A failed export after deleting a class must rollback the live image.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class package name equals: self fixturePackageName.
	self assert: class new answer equals: 42
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testExportFailureDuringClassMoveRollsBackImage [

	| backend class |
	self ensureTargetPackage.
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend failNextExport.
	self
		should: [ backend rename: self originalClassTonelPath to: self targetPackageTonelPath ]
		raise: Error
		whoseDescriptionIncludes: 'Simulated export failure'
		description: 'A failed export after moving a class must rollback the live image.'.
	class := Smalltalk globals at: self originalClassName asSymbol.
	self assert: class package name equals: self fixturePackageName.
	self assert: class new answer equals: 42
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
PharoImageFSProjectionBackendTest >> testExtensionMethodWrittenThroughClassFileMovesToExtensionFile [

	| backend classText extensionText methodBlock targetClass |
	self createExtensionTargetClass.
	backend := self newBackend.
	classText := backend read: '/tonel/' , self targetPackageName , '/PharoImageFSProjectionExtensionTarget.class.st'.
	methodBlock := String cr , '{ #category : ''*PharoImageFS-Tests'' }' , String cr
	               , 'PharoImageFSProjectionExtensionTarget >> projectedExtensionAnswer [' , String cr , String cr , String tab
	               , '^ 7' , String cr , ']' , String cr.
	backend write: classText , methodBlock at: '/tonel/' , self targetPackageName , '/PharoImageFSProjectionExtensionTarget.class.st'.
	targetClass := Smalltalk globals at: #PharoImageFSProjectionExtensionTarget.
	extensionText := backend read: '/tonel/' , self fixturePackageName , '/PharoImageFSProjectionExtensionTarget.extension.st'.
	self assert: (targetClass new perform: #projectedExtensionAnswer) equals: 7.
	self deny:
		((backend read: '/tonel/' , self targetPackageName , '/PharoImageFSProjectionExtensionTarget.class.st') includesSubstring:
			 'projectedExtensionAnswer').
	self assert: (extensionText includesSubstring: 'projectedExtensionAnswer')
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testListRootExposesTonelAndCritiques [

	| names |
	names := (self newBackend list: '/') collect: [ :entry | entry name ].
	self assert: names asArray equals: #( 'tonel' 'critiques' 'repositories' )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testMoveAndRenameClassTonelFileAcrossPackages [

	| backend renamedClass |
	self ensureTargetPackage.
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	backend rename: self originalClassTonelPath to: self targetRenamedClassTonelPath.
	renamedClass := Smalltalk globals at: self renamedClassName asSymbol.
	self deny: (Smalltalk globals includesKey: self originalClassName asSymbol).
	self assert: renamedClass package name equals: self targetPackageName.
	self assert: renamedClass new answer equals: 42.
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName.
			self targetPackageName }
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
PharoImageFSProjectionBackendTest >> testMoveExtensionTonelFileAcrossPackagesMovesMethods [

	| backend movedText |
	self ensureTargetPackage.
	backend := self newBackend.
	backend
		write: self extensionMoveTonelSource
		at: '/tonel/' , self fixturePackageName , '/String.extension.st'.
	backend
		rename: '/tonel/' , self fixturePackageName , '/String.extension.st'
		to: '/tonel/' , self targetPackageName , '/String.extension.st'.
	self assert: ('' perform: #pharoImageFSMoveExtensionProbe) equals: 7.
	movedText := backend read: '/tonel/' , self targetPackageName , '/String.extension.st'.
	self assert: (movedText includesSubstring: '*PharoImageFS-ProjectionTargetFixture').
	self assert: backend exportedPackageNames equals: {
			self fixturePackageName.
			self fixturePackageName.
			self targetPackageName }
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testReadClassCritiqueFileReturnsCritiquesArray [

	| backend data |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	data := self decodedJsonFrom:
		        (backend read: '/critiques/' , self fixturePackageName , '/' , self originalClassName , '/class-critiques.json').
	self assert: data isArray
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testReadMethodCritiqueFileReturnsSideKeys [

	| backend data |
	backend := self newBackend.
	backend write: self classTonelSource at: self originalClassTonelPath.
	data := self decodedJsonFrom:
		        (backend read: '/critiques/' , self fixturePackageName , '/' , self originalClassName , '/answer.json').
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
PharoImageFSProjectionBackendTest >> testRepositoryMetadataCanBeRead [

	| metadata |
	metadata := self decodedJsonFrom: (self newBackend read: '/repositories/Fixture Repository.repository.json').
	self assert: (metadata at: #name) equals: 'Fixture Repository'.
	self assert: (metadata at: #path) equals: '/tmp/fixture-repository'.
	self assert: (metadata at: #loadedPackages) equals: #( 'PharoImageFS-Tests' 'PharoImageFS-Tests-Resources' )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRepositoryRootListsSymlinkAndMetadata [

	| names |
	names := (self newBackend list: '/repositories') collect: [ :entry | entry name ].
	self
		assert: names asArray
		equals: #( 'Fixture Repository' 'Fixture Repository.repository.json' )
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testRepositoryStatExposesSymlink [

	| entry |
	entry := self newBackend stat: '/repositories/Fixture Repository'.
	self assert: entry isSymlink.
	self assert: entry target equals: '/tmp/fixture-repository'
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
PharoImageFSProjectionBackendTest >> testSelectorPathSegmentEscapesSlashInBinarySelectors [

	| backend |
	backend := self newBackend.
	self assert: (backend pathSegmentForSelector: #/) equals: '^slash'.
	self assert: (backend selectorFromPathSegment: '^slash.json' originalPath: '/critiques/example') equals: #/
]

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testSelectorPathSegmentUsesFileTreeColonEncoding [

	| backend |
	backend := self newBackend.
	self assert: (backend pathSegmentForSelector: #responseObjectForOperation:request:) equals: 'responseObjectForOperation.request.'.
	self
		assert: (backend selectorFromPathSegment: 'responseObjectForOperation.request..json' originalPath: '/critiques/example')
		equals: #responseObjectForOperation:request:
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

{ #category : 'tests' }
PharoImageFSProjectionBackendTest >> testWriteReformatsAcceptedMethodSource [

	| backend class source |
	backend := self newBackend.
	backend write: self classTonelSourceWithUnformattedMethod at: self originalClassTonelPath.
	class := Smalltalk globals at: self originalClassName asSymbol.
	source := class sourceCodeAt: #messyAnswer.
	self assert: source equals: ((class >> #messyAnswer) ast formattedCodeIn: class).
	self deny: (source includesSubstring: '^(1+2)')
]
