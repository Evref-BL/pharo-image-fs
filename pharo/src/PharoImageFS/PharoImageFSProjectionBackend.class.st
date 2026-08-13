"
Image-side projection backend for pharo-image-fs. It owns Pharo semantics and answers the narrow filesystem projection protocol used by the Go mount daemon.
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

	| classDefinition definitions methodDefinitions previousDefinitions previousMethodDefinitions |
	definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
	previousDefinitions := self parseTonelDefinitionsFrom: previousTextString originalPath: aString.
	classDefinition := self classDefinitionFrom: definitions originalPath: aString.
	self
		validateClassDefinition: classDefinition
		className: className
		packageName: packageName
		originalPath: aString.
	methodDefinitions := self methodDefinitionsFrom: definitions.
	self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
	previousMethodDefinitions := self methodDefinitionsFrom: previousDefinitions.
	classDefinition load.
	self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
	methodDefinitions do: [ :methodDefinition | methodDefinition load ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> applyExtensionTonelText: textString replacing: previousTextString className: className packageName: packageName originalPath: aString [

	| definitions methodDefinitions previousDefinitions previousMethodDefinitions |
	definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
	previousDefinitions := self parseTonelDefinitionsFrom: previousTextString originalPath: aString.
	self
		validateExtensionDefinitions: definitions
		className: className
		packageName: packageName
		originalPath: aString.
	methodDefinitions := self methodDefinitionsFrom: definitions.
	self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
	previousMethodDefinitions := self methodDefinitionsFrom: previousDefinitions.
	self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
	methodDefinitions do: [ :methodDefinition | methodDefinition load ]
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

	| ruleClass toolClass |
	toolClass := Smalltalk globals at: #MCPToolCompileMethod ifAbsent: [ nil ].
	toolClass ifNotNil: [ ^ toolClass new blockingPreCompileRuleClasses ].
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

	^ (Smalltalk allClasses collect: [ :class | class name asString ]) asArray sorted
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

	^ (critiques collect: [ :critique | self dictionaryForCritique: critique ]) asArray sorted: [ :left :right |
			  (left at: #title ifAbsent: [ '' ]) = (right at: #title ifAbsent: [ '' ])
				  ifTrue: [ (left at: #rule ifAbsent: [ '' ]) <= (right at: #rule ifAbsent: [ '' ]) ]
				  ifFalse: [ (left at: #title ifAbsent: [ '' ]) <= (right at: #title ifAbsent: [ '' ]) ] ]
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiqueMethodEntriesForClass: aClass [

	| selectors |
	selectors := (aClass selectors , aClass classSide selectors) asSet asArray sorted.
	^ selectors collect: [ :selector | self fileNamed: (self pathSegmentForSelector: selector) , '.json' size: 0 writable: false ]
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiqueRootEntries [

	^ self classNames flatCollect: [ :className |
			  {
				  (self directoryNamed: className).
				  (self fileNamed: className , '.json' size: 0 writable: false) } ]
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

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> extensionMethodsForClassName: className inPackage: aPackage [

	^ (aPackage extensionMethods select: [ :method | method methodClass instanceSide name asString = className ]) asArray
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> extensionTextForClassName: className package: aPackage originalPath: aString [

	| methodDefinitions methods writer |
	methods := self extensionMethodsForClassName: className inPackage: aPackage.
	methods isEmpty ifTrue: [ self signalNotFound: aString ].
	writer := TonelWriter new.
	methodDefinitions := (methods collect: [ :method | method asRingDefinition asMCMethodDefinition ]) asArray sorted: [ :first :second |
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
	self signalNotFound: aString
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> listCritiqueSegments: segments originalPath: aString [

	| class |
	segments isEmpty ifTrue: [ ^ self critiqueRootEntries ].
	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	(segments first endsWith: '.json') ifTrue: [ self signalNotFound: aString ].
	class := self classNamed: segments first originalPath: aString.
	^ self critiqueMethodEntriesForClass: class
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

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNamed: aString ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: aString ifAbsent: absentBlock
]

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNames [

	^ (PackageOrganizer default packages collect: [ :each | each name asString ]) asArray sorted
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> parseTonelDefinitionsFrom: textString originalPath: aString [

	^ [ TonelParser parseString: textString ]
		  on: Error
		  do: [ :error | Error signal: 'Cannot parse Tonel file for ' , aString , ': ' , (error messageText ifNil: [ error asString ]) ]
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> pathSegmentForSelector: aSelector [

	^ String streamContents: [ :stream |
			  aSelector asString do: [ :character |
					  character = $%
						  ifTrue: [ stream nextPutAll: '%25' ]
						  ifFalse: [
								  character = $/
									  ifTrue: [ stream nextPutAll: '%2F' ]
									  ifFalse: [ stream nextPut: character ] ] ] ]
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
	self signalNotFound: aString
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueClassFileNamed: fileName originalPath: aString [

	| class className |
	className := self classNameFromFileName: fileName suffix: '.json'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classNamed: className originalPath: aString.
	^ self jsonTextFor: (self classCritiqueDataForClass: class)
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueMethodFileNamed: fileName className: className originalPath: aString [

	| class selector |
	class := self classNamed: className originalPath: aString.
	selector := self selectorFromPathSegment: fileName originalPath: aString.
	^ self jsonTextFor: (self methodCritiqueDataForClass: class selector: selector)
]

{ #category : 'private - reading' }
PharoImageFSProjectionBackend >> readCritiqueSegments: segments originalPath: aString [

	segments size = 1 ifTrue: [ ^ self readCritiqueClassFileNamed: segments first originalPath: aString ].
	segments size = 2 ifTrue: [ ^ self readCritiqueMethodFileNamed: segments second className: segments first originalPath: aString ].
	self signalNotFound: aString
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
	^ TonelWriter sourceCodeOf: class
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

{ #category : 'private - repositories' }
PharoImageFSProjectionBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ IceRepository repositories
		  detect: [ :repository | repository loadedPackages anySatisfy: [ :package | package packageName asString = packageName ] ]
		  ifNone: absentBlock
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
		  (self directoryNamed: 'critiques') }
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> selectorFromPathSegment: aString originalPath: originalPath [

	| index stream |
	(aString endsWith: '.json') ifFalse: [ self signalNotFound: originalPath ].
	stream := String new writeStream.
	index := 1.
	[ index <= (aString size - 5) ] whileTrue: [
			| character escape |
			character := aString at: index.
			character = $%
				ifTrue: [
						escape := aString copyFrom: index to: (index + 2 min: aString size).
						escape = '%25'
							ifTrue: [
									stream nextPut: $%.
									index := index + 3 ]
							ifFalse: [
									escape = '%2F'
										ifTrue: [
												stream nextPut: $/.
												index := index + 3 ]
										ifFalse: [
												stream nextPut: character.
												index := index + 1 ] ] ]
				ifFalse: [
						stream nextPut: character.
						index := index + 1 ] ].
	^ stream contents asSymbol
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
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueClassFileNamed: fileName originalPath: aString [

	| text |
	text := self readCritiqueClassFileNamed: fileName originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueMethodFileNamed: fileName className: className originalPath: aString [

	| text |
	text := self readCritiqueMethodFileNamed: fileName className: className originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PharoImageFSProjectionBackend >> statCritiqueSegments: segments originalPath: aString [

	segments isEmpty ifTrue: [ ^ self directoryNamed: 'critiques' ].
	segments size = 1 ifTrue: [
			(segments first endsWith: '.json') ifTrue: [ ^ self statCritiqueClassFileNamed: segments first originalPath: aString ].
			self classNamed: segments first originalPath: aString.
			^ self directoryNamed: segments first ].
	segments size = 2 ifTrue: [ ^ self statCritiqueMethodFileNamed: segments second className: segments first originalPath: aString ].
	self signalNotFound: aString
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
PharoImageFSProjectionBackend >> tonelClassEntryNamed: fileName packageName: packageName originalPath: aString [

	| class className text |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classForName: className packageName: packageName originalPath: aString.
	text := TonelWriter sourceCodeOf: class.
	^ self fileNamed: fileName text: text writable: true
]

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> tonelEntriesForPackage: aPackage [

	| entries extensionClassNames |
	entries := OrderedCollection new.
	aPackage definedClasses do: [ :class | entries add: (self fileNamed: class name asString , '.class.st' size: 0 writable: true) ].
	extensionClassNames := (aPackage extensionMethods collect: [ :method | method methodClass instanceSide name asString ]) asSet.
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
PharoImageFSProjectionBackend >> unloadMethodDefinitionsAbsentFrom: newMethodDefinitions in: oldMethodDefinitions [

	| newIdentities |
	newIdentities := (newMethodDefinitions collect: [ :methodDefinition | self methodIdentityFor: methodDefinition ]) asSet.
	oldMethodDefinitions do: [ :methodDefinition |
		(newIdentities includes: (self methodIdentityFor: methodDefinition)) ifFalse: [ methodDefinition unload ] ]
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
PharoImageFSProjectionBackend >> writeTonelClassText: textString fileName: fileName packageName: packageName originalPath: aString [

	| className failureMessage previousText |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classForName: className packageName: packageName originalPath: aString.
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	previousText := self readTonelClassFileNamed: fileName packageName: packageName originalPath: aString.
	[
		self
			applyClassTonelText: textString
			replacing: previousText
			className: className
			packageName: packageName
			originalPath: aString.
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					self
						rollbackClassTonelText: previousText
						afterFailedWriteToClassName: className
						packageName: packageName
						originalPath: aString ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection write failed and rollback failed. Write error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - writing' }
PharoImageFSProjectionBackend >> writeTonelExtensionText: textString fileName: fileName packageName: packageName originalPath: aString [

	| className failureMessage previousText |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classNamed: className originalPath: aString.
	self repositoryOwningPackageNamed: packageName ifAbsent: [ Error signal: 'No Iceberg repository owns package ' , packageName ].
	previousText := self readTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString.
	[
		self
			applyExtensionTonelText: textString
			replacing: previousText
			className: className
			packageName: packageName
			originalPath: aString.
		self exportPackageNamed: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					self
						rollbackExtensionTonelText: previousText
						afterFailedWriteToClassName: className
						packageName: packageName
						originalPath: aString ]
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
