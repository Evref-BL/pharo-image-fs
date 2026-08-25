"
Image-side projection backend for pharo-image-fs. It owns Pharo semantics and answers the narrow filesystem projection protocol used by the Go mount daemon. It has no dependency on MCP-Pharo.
"
Class {
	#name : 'PharoImageFSProjectionBackend',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> addSourceIntervalFromCritique: aCritique to: data [

	| interval sourceAnchor |
	(aCritique class canUnderstand: #sourceAnchor) ifFalse: [ ^ self ].
	sourceAnchor := aCritique sourceAnchor.
	sourceAnchor ifNil: [ ^ self ].
	(sourceAnchor class canUnderstand: #interval) ifFalse: [ ^ self ].
	interval := sourceAnchor interval.
	interval ifNil: [ ^ self ].
	data at: #interval put: {
			interval first.
			interval last }
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> applyClassTonelText: textString replacing: previousTextString className: className packageName: packageName originalPath: aString [

	^ PharoImageFSCompatibility activeDuring: [
			  | changedMethodDefinitions classDefinition definitions methodDefinitions previousClassDefinition previousDefinitions previousMethodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  previousDefinitions := self parseTonelDefinitionsFrom: previousTextString originalPath: aString.
			  classDefinition := self classDefinitionFrom: definitions originalPath: aString.
			  previousClassDefinition := self classDefinitionFrom: previousDefinitions originalPath: aString.
			  self
				  validateClassDefinition: classDefinition
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  previousMethodDefinitions := self methodDefinitionsFrom: previousDefinitions.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  changedMethodDefinitions := self methodDefinitionsChangedFrom: previousMethodDefinitions in: methodDefinitions.
			  self validateBlockingCritiquesForMethodDefinitions: changedMethodDefinitions originalPath: aString.
			  classDefinition = previousClassDefinition ifFalse: [ self loadClassDefinition: classDefinition ].
			  self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
			  changedMethodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> applyExtensionTonelText: textString replacing: previousTextString className: className packageName: packageName originalPath: aString [

	^ PharoImageFSCompatibility activeDuring: [
			  | changedMethodDefinitions definitions methodDefinitions previousDefinitions previousMethodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  previousDefinitions := self parseTonelDefinitionsFrom: previousTextString originalPath: aString.
			  self
				  validateExtensionDefinitions: definitions
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  previousMethodDefinitions := self methodDefinitionsFrom: previousDefinitions.
			  changedMethodDefinitions := self methodDefinitionsChangedFrom: previousMethodDefinitions in: methodDefinitions.
			  self validateBlockingCritiquesForMethodDefinitions: changedMethodDefinitions originalPath: aString.
			  self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
			  changedMethodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> applyNewClassTonelText: textString className: className packageName: packageName originalPath: aString [

	^ PharoImageFSCompatibility activeDuring: [
			  | classDefinition definitions methodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  classDefinition := self classDefinitionFrom: definitions originalPath: aString.
			  self
				  validateClassDefinition: classDefinition
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
			  self loadClassDefinition: classDefinition.
			  methodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> applyNewExtensionTonelText: textString className: className packageName: packageName originalPath: aString [

	^ PharoImageFSCompatibility activeDuring: [
			  | definitions methodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  self
				  validateExtensionDefinitions: definitions
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  methodDefinitions ifEmpty: [ Error signal: 'Extension file must contain at least one method for ' , aString ].
			  self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
			  methodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> blockingCritiqueSummaryFor: critiqueDictionaries [

	^ String streamContents: [ :stream |
			  critiqueDictionaries
				  do: [ :critique |
						  stream
							  nextPutAll: (critique at: #rule);
							  nextPutAll: ': ';
							  nextPutAll: (critique at: #title) ]
				  separatedBy: [ stream nextPutAll: '; ' ] ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> blockingCritiquesForMethodNode: aMethodNode [

	| critiques |
	critiques := OrderedCollection new.
	self blockingPreCompileRuleClasses do: [ :ruleClass |
			| rule |
			rule := ruleClass new.
			aMethodNode nodesDo: [ :node | rule check: node forCritiquesDo: [ :critique | critiques add: critique ] ] ].
	^ self critiqueDictionariesFor: critiques
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> blockingPreCompileRuleClasses [

	| ruleClass |
	ruleClass := Smalltalk globals at: #ReDeadBlockRule ifAbsent: [ nil ].
	ruleClass ifNil: [ ^ #(  ) ].
	^ { ruleClass }
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> classCritiqueDataForClass: aClass [

	| methods |
	methods := OrderedCollection new.
	aClass selectors asArray sorted do: [ :selector |
			methods add: (OrderedDictionary new
					 at: #side put: 'instance';
					 at: #selector put: selector asString;
					 at: #critiques put: (self critiqueDataForCompiledMethod: aClass >> selector);
					 yourself) ].
	aClass classSide selectors asArray sorted do: [ :selector |
			methods add: (OrderedDictionary new
					 at: #side put: 'class';
					 at: #selector put: selector asString;
					 at: #critiques put: (self critiqueDataForCompiledMethod: aClass classSide >> selector);
					 yourself) ].
	^ OrderedDictionary new
		  at: #class put: (self critiqueDataForBehavior: aClass);
		  at: #methods put: (methods reject: [ :each | (each at: #critiques) isEmpty ]) asArray;
		  yourself
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> classCritiquesForClass: aClass [

	^ self critiqueDataForBehavior: aClass
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> classDefinitionFrom: definitions originalPath: aString [

	| classDefinitions |
	classDefinitions := definitions select: #isClassDefinition.
	classDefinitions size = 1 ifFalse: [
		Error signal: 'Expected exactly one class definition in ' , aString , ', got ' , classDefinitions size asString ].
	^ classDefinitions first
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> classForName: className packageName: packageName originalPath: aString [

	| class |
	class := Smalltalk at: className asSymbol ifAbsent: [ self signalNotFound: aString ].
	class package name asString = packageName ifFalse: [ self signalNotFound: aString ].
	^ class
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> classHasCritiqueEntries: aClass [

	(self classCritiquesForClass: aClass) ifNotEmpty: [ ^ true ].
	^ self selectorsWithCritiquesForClass: aClass isNotEmpty
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> classNameFromFileName: fileName suffix: suffixString [

	(fileName endsWith: suffixString) ifFalse: [ ^ nil ].
	^ fileName allButLast: suffixString size
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> classNamed: className originalPath: aString [

	^ Smalltalk at: className asSymbol ifAbsent: [ self signalNotFound: aString ]
]

{ #category : 'private - classes' }
PharoImageFSProjectionBackend >> classNames [

	^ (Smalltalk globals allClasses collect: [ :class | class name asString ] as: Array) sorted
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> classTonelTextFor: aClass [

	| methodDefinitions writer |
	writer := TonelWriter new.
	methodDefinitions := { aClass asClassDefinition }
	                     , ((self localMethodsForClass: aClass) collect: [ :method | method asRingDefinition asMCMethodDefinition ])
	                     ,
	                     ((self localMethodsForClass: aClass classSide) collect: [ :method |
		                      method asRingDefinition asMCMethodDefinition ]).
	writer instVarNamed: 'snapshot' put: (MCSnapshot fromDefinitions: methodDefinitions).
	^ String streamContents: [ :stream | writer writeClass: aClass asClassDefinition on: stream ]
]

{ #category : 'private - classes' }
PharoImageFSProjectionBackend >> classesInPackageNamed: packageName [

	^ (Smalltalk globals allClasses select: [ :class | class package name asString = packageName ]) sorted: [ :left :right |
		  left name <= right name ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> commaSeparated: strings [

	^ String streamContents: [ :stream |
		  strings do: [ :each |
			  stream position > 0 ifTrue: [ stream nextPutAll: ', ' ].
			  stream nextPutAll: each ] ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> critiqueDataForBehavior: aBehavior [

	^ self critiqueDictionariesFor: aBehavior critiques
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> critiqueDataForCompiledMethod: aCompiledMethod [

	^ self critiqueDictionariesFor: aCompiledMethod critiques
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> critiqueDictionariesFor: critiques [

	^ (critiques collect: [ :critique | self dictionaryForCritique: critique ] as: Array) sorted: [ :left :right |
			  (left at: #title ifAbsent: [ '' ]) = (right at: #title ifAbsent: [ '' ])
				  ifTrue: [ (left at: #rule ifAbsent: [ '' ]) <= (right at: #rule ifAbsent: [ '' ]) ]
				  ifFalse: [ (left at: #title ifAbsent: [ '' ]) <= (right at: #title ifAbsent: [ '' ]) ] ]
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiqueMethodEntriesForClass: aClass [

	| entries selectors |
	entries := OrderedCollection new.
	(self classCritiquesForClass: aClass) ifNotEmpty: [
		entries add: (self fileNamed: 'class-critiques.json' size: 0 writable: false) ].
	selectors := self selectorsWithCritiquesForClass: aClass.
	selectors do: [ :selector |
		entries add: (self fileNamed: (self pathSegmentForSelector: selector) , '.json' size: 0 writable: false) ].
	^ entries asArray
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiquePackageEntriesForPackageNamed: packageName originalPath: aString [

	| entries package |
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	entries := OrderedCollection new.
	(self packageCritiquesForPackage: package) ifNotEmpty: [
		entries add: (self fileNamed: 'package-critiques.json' size: 0 writable: false) ].
	(self classesInPackageNamed: packageName) do: [ :class |
		(self classHasCritiqueEntries: class) ifTrue: [ entries add: (self directoryNamed: class name) ] ].
	^ entries asArray
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiqueRootEntries [

	^ self packageNames
		  select: [ :packageName | self packageHasCritiqueEntriesNamed: packageName ]
		  thenCollect: [ :packageName | self directoryNamed: packageName ]
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> decodedSelectorToken: token originalPath: originalPath [

	(token beginsWith: '^') ifFalse: [ ^ token ].
	^ self selectorCharacterForEscapeName: token allButFirst originalPath: originalPath
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> delete: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [ ^ self deleteTonelSegments: segments allButFirst originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> deleteResponseForPath: aString [

	self delete: aString.
	^ Dictionary new
]

{ #category : 'private - deleting' }
PharoImageFSProjectionBackend >> deleteTonelClassFileNamed: fileName packageName: packageName originalPath: aString [

	| class className failureMessage previousText |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	class := self classForName: className packageName: packageName originalPath: aString.
	previousText := self classTonelTextFor: class.
	[
		class removeFromSystem.
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					self
						restoreClassTonelText: previousText
						className: className
						packageName: packageName
						originalPath: aString ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection delete failed and rollback failed. Delete error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - deleting' }
PharoImageFSProjectionBackend >> deleteTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString [

	| className failureMessage methods package previousText |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classNamed: className originalPath: aString.
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	methods := self extensionMethodsForClassName: className inPackage: package.
	methods ifEmpty: [ self signalNotFound: aString ].
	previousText := self extensionTextForClassName: className package: package originalPath: aString.
	[
		self removeCompiledMethods: methods.
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					self
						applyNewExtensionTonelText: previousText
						className: className
						packageName: packageName
						originalPath: aString.
					self exportPackageNamed: packageName ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection delete failed and rollback failed. Delete error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - deleting' }
PharoImageFSProjectionBackend >> deleteTonelSegments: segments originalPath: aString [

	segments size = 2 ifFalse: [ self signalUnsupportedWrite: aString ].
	(segments second endsWith: '.class.st') ifTrue: [
			^ self
				  deleteTonelClassFileNamed: segments second
				  packageName: segments first
				  originalPath: aString ].
	(segments second endsWith: '.extension.st') ifTrue: [
			^ self
				  deleteTonelExtensionFileNamed: segments second
				  packageName: segments first
				  originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> dictionaryForCritique: aCritique [

	| data rule |
	rule := aCritique rule.
	data := OrderedDictionary new.
	data at: #rule put: rule class name asString.
	(rule class canUnderstand: #severity) ifTrue: [
		rule severity ifNotNil: [ :severity | data at: #severity put: severity asString ] ].
	data at: #title put: aCritique title asString.
	(rule class canUnderstand: #rationale) ifTrue: [ rule rationale ifNotNil: [ :hint | data at: #hint put: hint asString ] ].
	self addSourceIntervalFromCritique: aCritique to: data.
	^ data
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> directoryNamed: aString [

	^ PharoImageFSProjectionEntry directoryNamed: aString
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> entryNamed: aString in: entries ifAbsent: absentBlock [

	^ entries detect: [ :each | each name = aString ] ifNone: absentBlock
]

{ #category : 'private - moving' }
PharoImageFSProjectionBackend >> executeClassMoveNamed: className toPackage: packageName [

	PharoImageFSCompatibility moveClassNamed: className toPackage: packageName
]

{ #category : 'private - renaming' }
PharoImageFSProjectionBackend >> executeClassRenameFrom: oldClassName to: newClassName [

	[ (ReRenameClassRefactoring rename: oldClassName asSymbol to: newClassName asSymbol) execute ]
		on: ProvideAnswerNotification
		do: [ :notification | notification resume: true ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> exportIcePackage: anIcePackage to: sourceDirectory [

	| versionInfo |
	versionInfo := MCVersionInfo
		               name: anIcePackage packageName
		               id: UUID new
		               message: ''
		               date: Date today
		               time: Time now
		               ancestors: #(  )
		               stepChildren: #(  ).
	TonelWriter fileOut: (MCVersion package: anIcePackage mcPackage info: versionInfo) on: sourceDirectory
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> exportPackageNamed: packageName [

	| icePackage repository |
	repository := self
		              repositoryOwningPackageNamed: packageName
		              ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	icePackage := self
		              icePackageNamed: packageName
		              in: repository
		              ifAbsent: [ Error signal: 'Repository ' , repository name , ' does not have loaded package ' , packageName ].
	repository codeDirectory ensureCreateDirectory.
	self exportIcePackage: icePackage to: repository codeDirectory.
	icePackage beClean
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> exportPackagesNamed: packageNames [

	packageNames do: [ :packageName | self exportPackageNamed: packageName ]
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> extensionMethodsForClassName: className inPackage: aPackage [

	^ (aPackage extensionMethods select: [ :method | method methodClass instanceSide name asString = className ]) asArray
]

{ #category : 'private - moving' }
PharoImageFSProjectionBackend >> extensionText: textString movingCategoriesFromPackage: sourcePackageName toPackage: targetPackageName originalPath: aString [

	| movedText methodDefinitions sourcePrefix |
	movedText := textString.
	sourcePrefix := '*' , sourcePackageName.
	methodDefinitions := self methodDefinitionsFrom: (self parseTonelDefinitionsFrom: textString originalPath: aString).
	methodDefinitions do: [ :methodDefinition |
			| newCategory oldCategory suffix |
			oldCategory := methodDefinition category asString.
			(oldCategory beginsWith: sourcePrefix caseSensitive: false) ifFalse: [
					Error signal:
						'Extension method protocol ' , oldCategory , ' does not belong to package ' , sourcePackageName , ' for ' , aString ].
			suffix := oldCategory allButFirst: sourcePrefix size.
			(suffix isEmpty or: [ suffix beginsWith: '-' ]) ifFalse: [
					Error signal:
						'Extension method protocol ' , oldCategory , ' does not belong to package ' , sourcePackageName , ' for ' , aString ].
			newCategory := '*' , targetPackageName , suffix.
			movedText := movedText
				             copyReplaceAll: '''' , oldCategory , ''''
				             with: '''' , newCategory , '''' ].
	^ movedText
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> extensionTextForClassName: className package: aPackage originalPath: aString [

	| methodDefinitions methods writer |
	methods := self extensionMethodsForClassName: className inPackage: aPackage.
	methods isEmpty ifTrue: [ self signalNotFound: aString ].
	writer := TonelWriter new.
	methodDefinitions := (methods collect: [ :method | method asRingDefinition asMCMethodDefinition ] as: Array) sorted: [
		                     :first
		                     :second |
		                     first selector < second selector or: [ first selector = second selector and: [ first classIsMeta ] ] ].
	^ String streamContents: [ :stream |
			  | definition |
			  definition := Dictionary new.
			  writer at: #name put: className in: definition.
			  stream << 'Extension ' << (writer toSTON: definition) << writer newLine.
			  methodDefinitions do: [ :methodDefinition | writer writeMethodDefinition: methodDefinition on: stream ] ]
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> fileNamed: aString size: anInteger writable: aBoolean [

	^ PharoImageFSProjectionEntry fileNamed: aString size: anInteger writable: aBoolean
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> fileNamed: aString text: textString writable: aBoolean [

	^ self fileNamed: aString size: textString size writable: aBoolean
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> icePackageNamed: packageName in: aRepository ifAbsent: absentBlock [

	^ aRepository loadedPackages detect: [ :package | package packageName asString = packageName ] ifNone: absentBlock
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> iceRepositoryDirectoryFor: aRepository [

	^ [
		  | directory |
		  directory := (aRepository respondsTo: #repositoryDirectory)
			               ifTrue: [ aRepository repositoryDirectory ]
			               ifFalse: [ nil ].
		  directory ifNil: [ nil ] ifNotNil: [ directory asFileReference ] ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> jsonTextFor: anObject [

	^ STONJSON toString: anObject
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> list: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ ^ self rootEntries ].
	segments first = 'tonel' ifTrue: [ ^ self listTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self listCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self listRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> listCritiqueSegments: segments originalPath: aString [

	| class |
	segments isEmpty ifTrue: [ ^ self critiqueRootEntries ].
	segments size = 1 ifTrue: [ ^ self critiquePackageEntriesForPackageNamed: segments first originalPath: aString ].
	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	class := self classNamed: segments second originalPath: aString.
	class package name asString = segments first ifFalse: [ self signalNotFound: aString ].
	^ self critiqueMethodEntriesForClass: class
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> listRepositorySegments: segments originalPath: aString [

	segments isEmpty ifTrue: [ ^ self repositoryEntries ].
	self signalNotFound: aString
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> listResponseForPath: aString [

	^ Dictionary new
		  at: #entries put: ((self list: aString) collect: [ :each | each asDictionary ]);
		  yourself
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> listTonelSegments: segments originalPath: aString [

	| package |
	segments isEmpty ifTrue: [ ^ self tonelRootEntries ].
	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	package := self packageNamed: segments first ifAbsent: [ self signalNotFound: aString ].
	^ self tonelEntriesForPackage: package
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> loadClassDefinition: classDefinition [

	PharoImageFSCompatibility loadMonticelloDefinition: classDefinition
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> loadMethodDefinition: methodDefinition [

	PharoImageFSCompatibility loadMonticelloDefinition: methodDefinition.
	self reformatLoadedMethodDefinition: methodDefinition
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> localMethodsForClass: aBehavior [

	^ aBehavior localMethods reject: [ :method | method protocol name beginsWith: '*' ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> methodCritiqueDataForClass: aClass selector: aSelector [

	| data |
	data := OrderedDictionary new.
	(aClass includesSelector: aSelector) ifTrue: [ data at: #instance put: (self critiqueDataForCompiledMethod: aClass >> aSelector) ].
	(aClass classSide includesSelector: aSelector) ifTrue: [
		data at: #class put: (self critiqueDataForCompiledMethod: aClass classSide >> aSelector) ].
	data ifEmpty: [ Error signal: 'Critique selector not found: ' , aClass name asString , '>>' , aSelector asString ].
	^ data
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> methodCritiquesForClass: aClass selector: aSelector [

	| data |
	data := self methodCritiqueDataForClass: aClass selector: aSelector.
	^ data values flatCollect: [ :each | each ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> methodDefinitionsByIdentityFor: methodDefinitions [

	| definitionsByIdentity |
	definitionsByIdentity := Dictionary new.
	methodDefinitions do: [ :methodDefinition |
		definitionsByIdentity at: (self methodIdentityFor: methodDefinition) put: methodDefinition ].
	^ definitionsByIdentity
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> methodDefinitionsChangedFrom: oldMethodDefinitions in: newMethodDefinitions [

	| oldDefinitionsByIdentity |
	oldDefinitionsByIdentity := self methodDefinitionsByIdentityFor: oldMethodDefinitions.
	^ newMethodDefinitions reject: [ :methodDefinition |
		  (oldDefinitionsByIdentity
			   at: (self methodIdentityFor: methodDefinition)
			   ifAbsent: [ nil ])
			  = methodDefinition ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> methodDefinitionsFrom: definitions [

	^ definitions select: #isMethodDefinition
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> methodIdentityFor: aMethodDefinition [

	^ {
		  aMethodDefinition className asString.
		  aMethodDefinition classIsMeta.
		  aMethodDefinition selector }
]

{ #category : 'private - moving' }
PharoImageFSProjectionBackend >> moveAndRenameTonelClassFileNamed: sourceFileName toFileNamed: targetFileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| class failureMessage newClassName oldClassName |
	oldClassName := self classNameFromFileName: sourceFileName suffix: '.class.st'.
	newClassName := self classNameFromFileName: targetFileName suffix: '.class.st'.
	oldClassName ifNil: [ self signalUnsupportedWrite: sourcePath ].
	newClassName ifNil: [ self signalUnsupportedWrite: targetPath ].
	class := self classForName: oldClassName packageName: sourcePackageName originalPath: sourcePath.
	self repositoryOwningPackageNamed: sourcePackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , sourcePackageName ].
	self repositoryOwningPackageNamed: targetPackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , targetPackageName ].
	self packageNamed: targetPackageName ifAbsent: [ self signalNotFound: targetPath ].
	(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
		Error signal: 'Cannot rename class ' , oldClassName , ' to existing global ' , newClassName , ' for ' , targetPath ].
	self validateRenameReferencesForClass: class packageName: sourcePackageName originalPath: sourcePath.
	[
		self executeClassRenameFrom: oldClassName to: newClassName.
		self executeClassMoveNamed: newClassName toPackage: targetPackageName.
		self exportPackagesNamed: {
				sourcePackageName.
				targetPackageName } ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
							class := Smalltalk at: newClassName asSymbol.
							class package name asString = targetPackageName ifTrue: [
								self executeClassMoveNamed: newClassName toPackage: sourcePackageName ].
							self executeClassRenameFrom: newClassName to: oldClassName ].
					self exportPackagesNamed: {
							targetPackageName.
							sourcePackageName } ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection class move and rename failed and rollback failed. Move and rename error: '
								, failureMessage , '. Rollback error: ' , (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - moving' }
PharoImageFSProjectionBackend >> moveTonelClassFileNamed: fileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| class className failureMessage |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: sourcePath ].
	class := self classForName: className packageName: sourcePackageName originalPath: sourcePath.
	self repositoryOwningPackageNamed: sourcePackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , sourcePackageName ].
	self repositoryOwningPackageNamed: targetPackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , targetPackageName ].
	self packageNamed: targetPackageName ifAbsent: [ self signalNotFound: targetPath ].
	[
		self executeClassMoveNamed: className toPackage: targetPackageName.
		self exportPackagesNamed: {
				sourcePackageName.
				targetPackageName } ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					class package name asString = targetPackageName ifTrue: [
						self executeClassMoveNamed: className toPackage: sourcePackageName ].
					self exportPackagesNamed: {
							targetPackageName.
							sourcePackageName } ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection class move failed and rollback failed. Move error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - moving' }
PharoImageFSProjectionBackend >> moveTonelExtensionFileNamed: fileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| className failureMessage movedText previousText sourceMethods sourcePackage targetMethods targetPackage |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: sourcePath ].
	self classNamed: className originalPath: sourcePath.
	self repositoryOwningPackageNamed: sourcePackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , sourcePackageName ].
	self repositoryOwningPackageNamed: targetPackageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , targetPackageName ].
	sourcePackage := self packageNamed: sourcePackageName ifAbsent: [ self signalNotFound: sourcePath ].
	targetPackage := self packageNamed: targetPackageName ifAbsent: [ self signalNotFound: targetPath ].
	sourceMethods := self extensionMethodsForClassName: className inPackage: sourcePackage.
	sourceMethods ifEmpty: [ self signalNotFound: sourcePath ].
	targetMethods := self extensionMethodsForClassName: className inPackage: targetPackage.
	targetMethods ifNotEmpty: [ Error signal: 'Cannot move extension to existing target extension file for ' , targetPath ].
	previousText := self extensionTextForClassName: className package: sourcePackage originalPath: sourcePath.
	movedText := self
		             extensionText: previousText
		             movingCategoriesFromPackage: sourcePackageName
		             toPackage: targetPackageName
		             originalPath: sourcePath.
	[
		self removeCompiledMethods: sourceMethods.
		self
			applyNewExtensionTonelText: movedText
			className: className
			packageName: targetPackageName
			originalPath: targetPath.
		self exportPackagesNamed: {
				sourcePackageName.
				targetPackageName } ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					targetMethods := self extensionMethodsForClassName: className inPackage: targetPackage.
					targetMethods ifNotEmpty: [ self removeCompiledMethods: targetMethods ].
					self
						applyNewExtensionTonelText: previousText
						className: className
						packageName: sourcePackageName
						originalPath: sourcePath.
					self exportPackagesNamed: {
							targetPackageName.
							sourcePackageName } ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection extension move failed and rollback failed. Move error: ' , failureMessage
								, '. Rollback error: ' , (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> packageCritiquesForPackage: aPackage [

	(aPackage class canUnderstand: #critiques) ifFalse: [ ^ #(  ) ].
	^ self critiqueDictionariesFor: aPackage critiques
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> packageHasCritiqueEntriesNamed: packageName [

	| package |
	package := self packageNamed: packageName ifAbsent: [ ^ false ].
	(self packageCritiquesForPackage: package) ifNotEmpty: [ ^ true ].
	^ (self classesInPackageNamed: packageName) anySatisfy: [ :class | self classHasCritiqueEntries: class ]
]

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNamed: aString ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: aString ifAbsent: absentBlock
]

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNames [

	^ (PackageOrganizer default packages collect: [ :each | each name asString ] as: Array) sorted
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> parseTonelDefinitionsFrom: textString originalPath: aString [

	^ [ TonelParser parseString: textString ]
		  on: Error
		  do: [ :error | Error signal: 'Cannot parse Tonel file for ' , aString , ': ' , (error messageText ifNil: [ error asString ]) ]
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> pathSegmentForSelector: aSelector [

	(aSelector includes: $:) ifTrue: [
			^ String streamContents: [ :stream |
					  aSelector do: [ :character |
							  character = $:
								  ifTrue: [ stream nextPut: $. ]
								  ifFalse: [ stream nextPut: character ] ] ] ].
	(self selectorEscapeNames includesKey: aSelector first) ifFalse: [ ^ aSelector asString ].
	^ String streamContents: [ :stream |
			  stream nextPut: $^.
			  aSelector asString
				  do: [ :character | stream nextPutAll: (self selectorEscapeNames at: character ifAbsent: [ character asString ]) ]
				  separatedBy: [ stream nextPut: $. ] ]
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> pathSegmentsFor: aString [

	^ ($/ split: aString) reject: [ :each | each isEmpty ]
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> read: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalNotFound: aString ].
	segments first = 'tonel' ifTrue: [ ^ self readTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self readCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self readRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueClassFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| class |
	fileName = 'class-critiques.json' ifFalse: [ self signalNotFound: aString ].
	class := self classNamed: className originalPath: aString.
	class package name asString = packageName ifFalse: [ self signalNotFound: aString ].
	^ self jsonTextFor: (self classCritiquesForClass: class)
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueMethodFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| class selector |
	class := self classNamed: className originalPath: aString.
	class package name asString = packageName ifFalse: [ self signalNotFound: aString ].
	selector := self selectorFromPathSegment: fileName originalPath: aString.
	^ self jsonTextFor: (self methodCritiqueDataForClass: class selector: selector)
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiquePackageFileNamed: fileName packageName: packageName originalPath: aString [

	| package |
	fileName = 'package-critiques.json' ifFalse: [ self signalNotFound: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	^ self jsonTextFor: (self packageCritiquesForPackage: package)
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueSegments: segments originalPath: aString [

	segments size = 2 ifTrue: [
		^ self readCritiquePackageFileNamed: segments second packageName: segments first originalPath: aString ].
	segments size = 3 ifTrue: [
			segments third = 'class-critiques.json'
				ifTrue: [
						^ self
							  readCritiqueClassFileNamed: segments third
							  packageName: segments first
							  className: segments second
							  originalPath: aString ]
				ifFalse: [
						^ self
							  readCritiqueMethodFileNamed: segments third
							  packageName: segments first
							  className: segments second
							  originalPath: aString ] ].
	self signalNotFound: aString
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readRepositorySegments: segments originalPath: aString [

	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	^ self repositoryMetadataTextForFileNamed: segments first originalPath: aString
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> readResponseForPath: aString [

	^ Dictionary new
		  at: #text put: (self read: aString);
		  yourself
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readTonelClassFileNamed: fileName packageName: packageName originalPath: aString [

	| class className |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classForName: className packageName: packageName originalPath: aString.
	^ self classTonelTextFor: class
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString [

	| className package |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalNotFound: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	^ self extensionTextForClassName: className package: package originalPath: aString
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readTonelSegments: segments originalPath: aString [

	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	(segments second endsWith: '.class.st') ifTrue: [
		^ self readTonelClassFileNamed: segments second packageName: segments first originalPath: aString ].
	(segments second endsWith: '.extension.st') ifTrue: [
		^ self readTonelExtensionFileNamed: segments second packageName: segments first originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> reformatLoadedMethodDefinition: methodDefinition [

	| behavior selector |
	behavior := methodDefinition actualClass.
	behavior ifNil: [ ^ self ].
	selector := methodDefinition selector asSymbol.
	(behavior includesSelector: selector) ifFalse: [ ^ self ].
	(behavior >> selector) reformat
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> removeClassNamed: className ifPresentInPackage: packageName [

	| class |
	class := Smalltalk at: className asSymbol ifAbsent: [ ^ self ].
	class package name asString = packageName ifFalse: [ ^ self ].
	class removeFromSystem
]

{ #category : 'private - deleting' }
PharoImageFSProjectionBackend >> removeCompiledMethods: compiledMethods [

	compiledMethods do: [ :method | method asRingDefinition asMCMethodDefinition unload ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> removeMethodDefinitions: methodDefinitions [

	methodDefinitions do: [ :methodDefinition | self unloadMethodDefinition: methodDefinition ]
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> rename: sourcePath to: targetPath [

	| sourceClassName sourceSegments targetClassName targetSegments |
	sourceSegments := self pathSegmentsFor: sourcePath.
	targetSegments := self pathSegmentsFor: targetPath.
	(sourceSegments size = 3 and: [
		 sourceSegments first = 'tonel' and: [
			 targetSegments size = 3 and: [ targetSegments first = 'tonel' ] ] ]) ifFalse: [ self signalUnsupportedWrite: sourcePath ].
	(sourceSegments third endsWith: '.class.st') ifTrue: [
			(targetSegments third endsWith: '.class.st') ifFalse: [ self signalUnsupportedWrite: sourcePath ].
			sourceClassName := self classNameFromFileName: sourceSegments third suffix: '.class.st'.
			targetClassName := self classNameFromFileName: targetSegments third suffix: '.class.st'.
			sourceClassName = targetClassName ifTrue: [
					sourceSegments second = targetSegments second ifTrue: [ ^ self ].
					^ self
						  moveTonelClassFileNamed: sourceSegments third
						  packageName: sourceSegments second
						  toPackageName: targetSegments second
						  originalPath: sourcePath
						  targetPath: targetPath ].
			sourceSegments second = targetSegments second
				ifTrue: [
						^ self
							  renameTonelClassFileNamed: sourceSegments third
							  toFileNamed: targetSegments third
							  packageName: sourceSegments second
							  originalPath: sourcePath
							  targetPath: targetPath ]
				ifFalse: [
						^ self
							  moveAndRenameTonelClassFileNamed: sourceSegments third
							  toFileNamed: targetSegments third
							  packageName: sourceSegments second
							  toPackageName: targetSegments second
							  originalPath: sourcePath
							  targetPath: targetPath ] ].
	(sourceSegments third endsWith: '.extension.st') ifTrue: [
			(targetSegments third endsWith: '.extension.st') ifFalse: [ self signalUnsupportedWrite: sourcePath ].
			sourceClassName := self classNameFromFileName: sourceSegments third suffix: '.extension.st'.
			targetClassName := self classNameFromFileName: targetSegments third suffix: '.extension.st'.
			sourceClassName = targetClassName ifFalse: [ self signalUnsupportedWrite: sourcePath ].
			sourceSegments second = targetSegments second ifTrue: [ ^ self ].
			^ self
				  moveTonelExtensionFileNamed: sourceSegments third
				  packageName: sourceSegments second
				  toPackageName: targetSegments second
				  originalPath: sourcePath
				  targetPath: targetPath ].
	self signalUnsupportedWrite: sourcePath
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> renameResponseForPath: sourcePath to: targetPath [

	self rename: sourcePath to: targetPath.
	^ Dictionary new
]

{ #category : 'private - renaming' }
PharoImageFSProjectionBackend >> renameTonelClassFileNamed: sourceFileName toFileNamed: targetFileName packageName: packageName originalPath: sourcePath targetPath: targetPath [

	| class failureMessage newClassName oldClassName |
	oldClassName := self classNameFromFileName: sourceFileName suffix: '.class.st'.
	newClassName := self classNameFromFileName: targetFileName suffix: '.class.st'.
	oldClassName ifNil: [ self signalUnsupportedWrite: sourcePath ].
	newClassName ifNil: [ self signalUnsupportedWrite: targetPath ].
	oldClassName = newClassName ifTrue: [ ^ self ].
	class := self classForName: oldClassName packageName: packageName originalPath: sourcePath.
	(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
		Error signal: 'Cannot rename class ' , oldClassName , ' to existing global ' , newClassName , ' for ' , targetPath ].
	self validateRenameReferencesForClass: class packageName: packageName originalPath: sourcePath.
	[
		self executeClassRenameFrom: oldClassName to: newClassName.
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
						self executeClassRenameFrom: newClassName to: oldClassName ].
					self exportPackageNamed: packageName ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection rename failed and rollback failed. Rename error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryEntries [

	| entries |
	entries := OrderedCollection new.
	self repositoryInfos do: [ :info |
		entries
			add: (self symlinkNamed: (info at: #projectionName) target: (info at: #path));
			add:
				(self
					fileNamed: (self repositoryMetadataFileNameFor: info)
					text: (self jsonTextFor: info)
					writable: false) ].
	^ entries asArray
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryInfoForMetadataFileNamed: fileName originalPath: aString [

	^ self repositoryInfos
		  detect: [ :info | (self repositoryMetadataFileNameFor: info) = fileName ]
		  ifNone: [ self signalNotFound: aString ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryInfoForProjectionName: projectionName originalPath: aString [

	^ self repositoryInfos
		  detect: [ :info | (info at: #projectionName) = projectionName ]
		  ifNone: [ self signalNotFound: aString ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryInfoForRepository: repository ifPresent: presentBlock [

	| directory info |
	directory := self iceRepositoryDirectoryFor: repository.
	(directory isNil or: [ directory exists not ]) ifTrue: [ ^ self ].
	info := OrderedDictionary new.
	info
		at: #name put: repository name asString;
		at: #projectionName put: (self repositoryProjectionNameFor: repository name asString);
		at: #path put: directory pathString;
		at: #loadedPackages put: (self repositoryLoadedPackageNamesFor: repository).
	^ presentBlock value: info
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryInfos [

	| infos |
	infos := OrderedCollection new.
	IceRepository registry do: [ :repository |
		self repositoryInfoForRepository: repository ifPresent: [ :info | infos add: info ] ].
	^ infos asArray sorted: [ :left :right | (left at: #projectionName) <= (right at: #projectionName) ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryLoadedPackageNamesFor: repository [

	^ [
		  (repository loadedPackages collect: [ :package | package packageName asString ] as: Array) sorted ]
		  on: Error
		  do: [ #(  ) ]
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryMetadataFileNameFor: info [

	^ (info at: #projectionName) , '.repository.json'
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryMetadataTextForFileNamed: fileName originalPath: aString [

	^ self jsonTextFor: (self repositoryInfoForMetadataFileNamed: fileName originalPath: aString)
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ IceRepository repositories
		  detect: [ :repository | repository loadedPackages anySatisfy: [ :package | package packageName asString = packageName ] ]
		  ifNone: absentBlock
]

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryProjectionNameFor: aString [

	^ String streamContents: [ :stream |
		  aString do: [ :character |
			  ((character = $/) or: [ character = $: ])
				  ifTrue: [ stream nextPut: $- ]
				  ifFalse: [ stream nextPut: character ] ] ]
]

{ #category : 'private - deleting' }
PharoImageFSProjectionBackend >> restoreClassTonelText: textString className: className packageName: packageName originalPath: aString [

	| currentClass currentText |
	currentClass := Smalltalk at: className asSymbol ifAbsent: [ nil ].
	currentClass
		ifNil: [
				self
					applyNewClassTonelText: textString
					className: className
					packageName: packageName
					originalPath: aString ]
		ifNotNil: [
				currentClass package name asString = packageName ifFalse: [
					Error signal:
						'Cannot rollback class ' , className , ' because it now belongs to package ' , currentClass package name asString ].
				currentText := self classTonelTextFor: currentClass.
				self
					applyClassTonelText: textString
					replacing: currentText
					className: className
					packageName: packageName
					originalPath: aString ].
	self exportPackageNamed: packageName
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> rollbackClassTonelText: previousTextString afterFailedWriteToClassName: className packageName: packageName originalPath: aString [

	| currentText |
	currentText := self readTonelClassFileNamed: className , '.class.st' packageName: packageName originalPath: aString.
	self
		applyClassTonelText: previousTextString
		replacing: currentText
		className: className
		packageName: packageName
		originalPath: aString.
	self exportPackageNamed: packageName
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> rollbackExtensionTonelText: previousTextString afterFailedWriteToClassName: className packageName: packageName originalPath: aString [

	| currentText |
	currentText := self readTonelExtensionFileNamed: className , '.extension.st' packageName: packageName originalPath: aString.
	self
		applyExtensionTonelText: previousTextString
		replacing: currentText
		className: className
		packageName: packageName
		originalPath: aString.
	self exportPackageNamed: packageName
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> rootEntries [

	^ {
		  (self directoryNamed: 'tonel').
		  (self directoryNamed: 'critiques').
		  (self directoryNamed: 'repositories') }
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> selectorCharacterForEscapeName: aString originalPath: originalPath [

	self selectorEscapeNames keysAndValuesDo: [ :character :name | name = aString ifTrue: [ ^ character asString ] ].
	self signalNotFound: originalPath
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> selectorEscapeNames [

	^ Dictionary new
		  at: $+ put: 'plus';
		  at: $- put: 'minus';
		  at: $= put: 'equals';
		  at: $< put: 'less';
		  at: $> put: 'more';
		  at: $% put: 'percent';
		  at: $& put: 'and';
		  at: $| put: 'pipe';
		  at: $* put: 'star';
		  at: $/ put: 'slash';
		  at: $\ put: 'backslash';
		  at: $~ put: 'tilde';
		  at: $? put: 'wat';
		  at: $, put: 'comma';
		  at: $@ put: 'at';
		  yourself
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> selectorFromPathSegment: aString originalPath: originalPath [

	| base tokens |
	(aString endsWith: '.json') ifFalse: [ self signalNotFound: originalPath ].
	base := aString allButLast: 5.
	base ifEmpty: [ self signalNotFound: originalPath ].
	tokens := $. split: base.
	tokens size = 1 ifTrue: [ ^ (self decodedSelectorToken: tokens first originalPath: originalPath) asSymbol ].
	tokens last ifEmpty: [ tokens := tokens allButLast ].
	^ (String streamContents: [ :stream |
			   tokens do: [ :token |
					   stream nextPutAll: (self decodedSelectorToken: token originalPath: originalPath).
					   stream nextPut: $: ] ]) asSymbol
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> selectorsWithCritiquesForClass: aClass [

	| selectors |
	selectors := (aClass selectors , aClass classSide selectors) asSet asArray sorted.
	^ selectors select: [ :selector | (self methodCritiquesForClass: aClass selector: selector) isNotEmpty ]
]

{ #category : 'private - errors' }
PharoImageFSProjectionBackend >> signalNotFound: aString [

	Error signal: 'Projection path not found: ' , aString
]

{ #category : 'private - errors' }
PharoImageFSProjectionBackend >> signalUnsupportedWrite: aString [

	Error signal: 'Projection path is not writable yet: ' , aString
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> stat: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ ^ self directoryNamed: '/' ].
	segments first = 'tonel' ifTrue: [ ^ self statTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self statCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self statRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueClassFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| text |
	text := self
		        readCritiqueClassFileNamed: fileName
		        packageName: packageName
		        className: className
		        originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueMethodFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| text |
	text := self
		        readCritiqueMethodFileNamed: fileName
		        packageName: packageName
		        className: className
		        originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiquePackageFileNamed: fileName packageName: packageName originalPath: aString [

	| text |
	text := self readCritiquePackageFileNamed: fileName packageName: packageName originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueSegments: segments originalPath: aString [

	| class |
	segments isEmpty ifTrue: [ ^ self directoryNamed: 'critiques' ].
	segments size = 1 ifTrue: [
			self packageNamed: segments first ifAbsent: [ self signalNotFound: aString ].
			^ self directoryNamed: segments first ].
	segments size = 2 ifTrue: [
			segments second = 'package-critiques.json' ifTrue: [
				^ self statCritiquePackageFileNamed: segments second packageName: segments first originalPath: aString ].
			class := self classNamed: segments second originalPath: aString.
			class package name asString = segments first ifFalse: [ self signalNotFound: aString ].
			^ self directoryNamed: segments second ].
	segments size = 3 ifTrue: [
			segments third = 'class-critiques.json'
				ifTrue: [
						^ self
							  statCritiqueClassFileNamed: segments third
							  packageName: segments first
							  className: segments second
							  originalPath: aString ]
				ifFalse: [
						^ self
							  statCritiqueMethodFileNamed: segments third
							  packageName: segments first
							  className: segments second
							  originalPath: aString ] ].
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statRepositorySegments: segments originalPath: aString [

	| info text |
	segments isEmpty ifTrue: [ ^ self directoryNamed: 'repositories' ].
	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	(segments first endsWith: '.repository.json')
		ifTrue: [
			text := self repositoryMetadataTextForFileNamed: segments first originalPath: aString.
			^ self fileNamed: segments first text: text writable: false ].
	info := self repositoryInfoForProjectionName: segments first originalPath: aString.
	^ self symlinkNamed: segments first target: (info at: #path)
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> statResponseForPath: aString [

	^ Dictionary new
		  at: #entry put: (self stat: aString) asDictionary;
		  yourself
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statTonelFileNamed: fileName packageName: packageName originalPath: aString [

	(fileName endsWith: '.class.st') ifTrue: [ ^ self tonelClassEntryNamed: fileName packageName: packageName originalPath: aString ].
	(fileName endsWith: '.extension.st') ifTrue: [
		^ self tonelExtensionEntryNamed: fileName packageName: packageName originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statTonelSegments: segments originalPath: aString [

	| package |
	segments isEmpty ifTrue: [ ^ self directoryNamed: 'tonel' ].
	package := self packageNamed: segments first ifAbsent: [ self signalNotFound: aString ].
	segments size = 1 ifTrue: [ ^ self directoryNamed: segments first ].
	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	^ self statTonelFileNamed: segments second packageName: package name asString originalPath: aString
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> symlinkNamed: aString target: targetString [

	^ PharoImageFSProjectionEntry symlinkNamed: aString target: targetString
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> tonelClassEntryNamed: fileName packageName: packageName originalPath: aString [

	| class className text |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classForName: className packageName: packageName originalPath: aString.
	text := self classTonelTextFor: class.
	^ self fileNamed: fileName text: text writable: true
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> tonelEntriesForPackage: aPackage [

	| entries extensionClassNames |
	entries := OrderedCollection new.
	aPackage definedClasses do: [ :class | entries add: (self fileNamed: class name asString , '.class.st' size: 0 writable: true) ].
	extensionClassNames := aPackage extensionMethods collect: [ :method | method methodClass instanceSide name asString ] as: Set.
	extensionClassNames do: [ :className | entries add: (self fileNamed: className , '.extension.st' size: 0 writable: true) ].
	^ entries asArray sorted: [ :first :second | first name <= second name ]
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> tonelExtensionEntryNamed: fileName packageName: packageName originalPath: aString [

	| className package text |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalNotFound: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	text := self extensionTextForClassName: className package: package originalPath: aString.
	^ self fileNamed: fileName text: text writable: true
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> tonelRootEntries [

	^ self packageNames collect: [ :each | self directoryNamed: each ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> unloadMethodDefinition: methodDefinition [

	methodDefinition unload
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> unloadMethodDefinitionsAbsentFrom: newMethodDefinitions in: oldMethodDefinitions [

	| newIdentities |
	newIdentities := newMethodDefinitions collect: [ :methodDefinition | self methodIdentityFor: methodDefinition ] as: Set.
	oldMethodDefinitions do: [ :methodDefinition |
		(newIdentities includes: (self methodIdentityFor: methodDefinition)) ifFalse: [ self unloadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> validateBlockingCritiquesForMethodDefinition: methodDefinition originalPath: aString [

	| critiques methodNode |
	methodNode := RBParser parseMethod: methodDefinition source.
	critiques := self blockingCritiquesForMethodNode: methodNode.
	critiques ifEmpty: [ ^ self ].
	Error signal:
		'Write blocked by critiques in ' , methodDefinition className asString , '>>' , methodDefinition selector asString , ' for '
		, aString , ': ' , (self blockingCritiqueSummaryFor: critiques)
]

{ #category : 'private - critiques' }
PharoImageFSProjectionBackend >> validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString [

	methodDefinitions do: [ :methodDefinition |
		self validateBlockingCritiquesForMethodDefinition: methodDefinition originalPath: aString ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> validateClassDefinition: classDefinition className: className packageName: packageName originalPath: aString [

	classDefinition className asString = className ifFalse: [
			Error signal:
				'Class definition name ' , classDefinition className asString , ' does not match projection path class ' , className , ' for '
				, aString ].
	classDefinition packageName asString = packageName ifFalse: [
			Error signal:
				'Class definition package ' , classDefinition packageName asString , ' does not match projection path package ' , packageName
				, ' for ' , aString ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> validateExtensionDefinitions: definitions className: className packageName: packageName originalPath: aString [

	| classDefinitions methodDefinitions protocolPrefix |
	classDefinitions := definitions select: #isClassDefinition.
	classDefinitions ifNotEmpty: [ Error signal: 'Extension file must not contain class definitions for ' , aString ].
	protocolPrefix := '*' , packageName.
	methodDefinitions := self methodDefinitionsFrom: definitions.
	methodDefinitions do: [ :methodDefinition |
			methodDefinition className asString = className ifFalse: [
					Error signal:
						'Extension method class ' , methodDefinition className asString , ' does not match projection path class ' , className
						, ' for ' , aString ].
			(methodDefinition category asString beginsWith: protocolPrefix caseSensitive: false) ifFalse: [
					Error signal:
						'Extension method protocol ' , methodDefinition category asString , ' does not belong to package ' , packageName , ' for '
						, aString ] ]
]

{ #category : 'private - renaming' }
PharoImageFSProjectionBackend >> validateRenameReferencesForClass: aClass packageName: packageName originalPath: aString [

	| referencingPackages |
	referencingPackages := (SystemNavigation default allReferencesTo: aClass binding)
		                       collect: [ :method | method package name asString ]
		                       as: Set.
	referencingPackages remove: packageName ifAbsent: [ ].
	referencingPackages ifNotEmpty: [
			Error signal: 'Projection class rename would update references outside package ' , packageName , ' for ' , aString , ': '
				, (self commaSeparated: referencingPackages asArray sorted) ]
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> write: textString at: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [ ^ self writeTonelSegments: segments allButFirst text: textString originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> writeResponseForPath: aString text: textString [

	self write: textString at: aString.
	^ Dictionary new
		  at: #diagnostics put: #(  );
		  yourself
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> writeTonelClassRenameFromDefinition: classDefinition toClassName: className packageName: packageName originalPath: aString [

	| oldClassName sourcePath |
	oldClassName := classDefinition className asString.
	sourcePath := '/tonel/' , packageName , '/' , oldClassName , '.class.st'.
	^ self
		  renameTonelClassFileNamed: oldClassName , '.class.st'
		  toFileNamed: className , '.class.st'
		  packageName: packageName
		  originalPath: sourcePath
		  targetPath: aString
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> writeTonelClassText: textString fileName: fileName packageName: packageName originalPath: aString [

	| class classDefinition classExists className failureMessage previousText |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	classDefinition := self
		                   classDefinitionFrom: (self parseTonelDefinitionsFrom: textString originalPath: aString)
		                   originalPath: aString.
	classDefinition packageName asString = packageName ifFalse: [
			Error signal:
				'Class definition package ' , classDefinition packageName asString , ' does not match projection path package ' , packageName
				, ' for ' , aString ].
	classDefinition className asString = className ifFalse: [
			^ self
				  writeTonelClassRenameFromDefinition: classDefinition
				  toClassName: className
				  packageName: packageName
				  originalPath: aString ].
	class := Smalltalk at: className asSymbol ifAbsent: [ nil ].
	classExists := class notNil.
	(classExists and: [ class package name asString ~= packageName ]) ifTrue: [
		Error signal: 'Class ' , className , ' already exists in package ' , class package name asString , ' for ' , aString ].
	previousText := classExists ifTrue: [ self readTonelClassFileNamed: fileName packageName: packageName originalPath: aString ].
	[
		classExists
			ifTrue: [
					self
						applyClassTonelText: textString
						replacing: previousText
						className: className
						packageName: packageName
						originalPath: aString ]
			ifFalse: [
					self
						applyNewClassTonelText: textString
						className: className
						packageName: packageName
						originalPath: aString ].
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					classExists
						ifTrue: [
								self
									rollbackClassTonelText: previousText
									afterFailedWriteToClassName: className
									packageName: packageName
									originalPath: aString ]
						ifFalse: [
								self removeClassNamed: className ifPresentInPackage: packageName.
								self exportPackageNamed: packageName ] ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection write failed and rollback failed. Write error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> writeTonelExtensionText: textString fileName: fileName packageName: packageName originalPath: aString [

	| className extensionExists failureMessage methodDefinitions package previousText |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classNamed: className originalPath: aString.
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	extensionExists := (self extensionMethodsForClassName: className inPackage: package) notEmpty.
	previousText := extensionExists ifTrue: [
		                self readTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString ].
	methodDefinitions := self methodDefinitionsFrom: (self parseTonelDefinitionsFrom: textString originalPath: aString).
	[
		extensionExists
			ifTrue: [
					self
						applyExtensionTonelText: textString
						replacing: previousText
						className: className
						packageName: packageName
						originalPath: aString ]
			ifFalse: [
					self
						applyNewExtensionTonelText: textString
						className: className
						packageName: packageName
						originalPath: aString ].
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					extensionExists
						ifTrue: [
								self
									rollbackExtensionTonelText: previousText
									afterFailedWriteToClassName: className
									packageName: packageName
									originalPath: aString ]
						ifFalse: [
								self removeMethodDefinitions: methodDefinitions.
								self exportPackageNamed: packageName ] ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection write failed and rollback failed. Write error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> writeTonelSegments: segments text: textString originalPath: aString [

	segments size = 2 ifFalse: [ self signalUnsupportedWrite: aString ].
	(segments second endsWith: '.class.st') ifTrue: [
			^ self
				  writeTonelClassText: textString
				  fileName: segments second
				  packageName: segments first
				  originalPath: aString ].
	(segments second endsWith: '.extension.st') ifTrue: [
			^ self
				  writeTonelExtensionText: textString
				  fileName: segments second
				  packageName: segments first
				  originalPath: aString ].
	self signalUnsupportedWrite: aString
]
