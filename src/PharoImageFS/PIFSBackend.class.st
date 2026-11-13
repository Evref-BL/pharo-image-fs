"
Image-side projection backend for pharo-image-fs. It owns Pharo semantics and answers the narrow filesystem projection protocol used by the Go mount daemon. It has no dependency on MCP-Pharo.
"
Class {
	#name : 'PIFSBackend',
	#superclass : 'Object',
	#instVars : [
		'configuration',
		'critiques',
		'repositories',
		'renderedSizes'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'private - writing' }
PIFSBackend >> applyClassTonelText: textString replacing: previousTextString className: className packageName: packageName originalPath: aString [

	^ PIFSCompatibility activeDuring: [
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
			  self validateSyntaxOfMethodDefinitions: changedMethodDefinitions text: textString originalPath: aString.
			  self validateBlockingCritiquesForMethodDefinitions: changedMethodDefinitions originalPath: aString.
			  classDefinition = previousClassDefinition ifFalse: [ self loadClassDefinition: classDefinition ].
			  self validateCompilationOfMethodDefinitions: changedMethodDefinitions text: textString originalPath: aString.
			  self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
			  changedMethodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PIFSBackend >> applyExtensionTonelText: textString replacing: previousTextString className: className packageName: packageName originalPath: aString [

	^ PIFSCompatibility activeDuring: [
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
			  self validateSyntaxOfMethodDefinitions: changedMethodDefinitions text: textString originalPath: aString.
			  self validateBlockingCritiquesForMethodDefinitions: changedMethodDefinitions originalPath: aString.
			  self validateCompilationOfMethodDefinitions: changedMethodDefinitions text: textString originalPath: aString.
			  self unloadMethodDefinitionsAbsentFrom: methodDefinitions in: previousMethodDefinitions.
			  changedMethodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PIFSBackend >> applyNewClassTonelText: textString className: className packageName: packageName originalPath: aString [

	^ PIFSCompatibility activeDuring: [
			  | classDefinition definitions methodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  classDefinition := self classDefinitionFrom: definitions originalPath: aString.
			  self
				  validateClassDefinition: classDefinition
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  self validateSyntaxOfMethodDefinitions: methodDefinitions text: textString originalPath: aString.
			  self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
			  self loadClassDefinition: classDefinition.
			  self validateCompilationOfMethodDefinitions: methodDefinitions text: textString originalPath: aString.
			  methodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - writing' }
PIFSBackend >> applyNewExtensionTonelText: textString className: className packageName: packageName originalPath: aString [

	^ PIFSCompatibility activeDuring: [
			  | definitions methodDefinitions |
			  definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
			  self
				  validateExtensionDefinitions: definitions
				  className: className
				  packageName: packageName
				  originalPath: aString.
			  methodDefinitions := self methodDefinitionsFrom: definitions.
			  methodDefinitions ifEmpty: [ Error signal: 'Extension file must contain at least one method for ' , aString ].
			  self validateSyntaxOfMethodDefinitions: methodDefinitions text: textString originalPath: aString.
			  self validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString.
			  self validateCompilationOfMethodDefinitions: methodDefinitions text: textString originalPath: aString.
			  methodDefinitions do: [ :methodDefinition | self loadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - packages' }
PIFSBackend >> assertPackageIsVisibleNamed: packageName originalPath: aString [

	(self isPackageVisibleNamed: packageName) ifFalse: [ self signalNotFound: aString ]
]

{ #category : 'private - repositories' }
PIFSBackend >> assertRepositoriesOwnPackageNames: packageNames originalPath: aString [

	packageNames do: [ :packageName | self assertRepositoryOwnsPackageNamed: packageName originalPath: aString ]
]

{ #category : 'private - repositories' }
PIFSBackend >> assertRepositoryOwnsPackageNamed: packageName originalPath: aString [

	self requiresRepositoryOwnershipForWrites ifFalse: [ ^ self ].
	self repositoryOwningPackageNamed: packageName ifAbsent: [
			(self repositories unsupportedSourceFormatFor: packageName) ifNotNil: [ :formatId |
					Error signal: 'Package ' , packageName , ' belongs to a repository that keeps its source as ' , formatId asString
						, ', and this projection writes Tonel. Writing ' , aString
						, ' would leave a second copy of the source beside the real one, which no load reads.' ].
			Error signal: 'Package ' , packageName
				,
				' is not owned by a loaded Iceberg repository. Attach it to a repository or disable repository ownership checks before writing through '
				, aString ]
]

{ #category : 'private - renaming' }
PIFSBackend >> bindUndeclaredReferencesToClassNamed: className [
	"A method may name the class's new name before the rename, as a file written in the same change does, and is then bound to an undeclared variable. Defining a class binds such methods to it (SystemEnvironment >> at:put:); renaming one does not, so they are compiled again. Their source does not change."

	| undeclared |
	undeclared := Undeclared associationAt: className asSymbol ifAbsent: [ ^ self ].
	Undeclared removeKey: className asSymbol.
	(SystemNavigation default allReferencesTo: undeclared) do: [ :method | method recompile ]
]

{ #category : 'private - writing' }
PIFSBackend >> classDefinitionFrom: definitions originalPath: aString [

	| classDefinitions |
	classDefinitions := definitions select: #isClassDefinition.
	classDefinitions size = 1 ifFalse: [
		Error signal: 'Expected exactly one class definition in ' , aString , ', got ' , classDefinitions size asString ].
	^ classDefinitions first
]

{ #category : 'private - reading' }
PIFSBackend >> classFingerprintFor: aClass [
	"What a class file is rendered from, read from memory only: both sides' definitions, the comment's place in the sources, and each method's selector, protocol, source pointer and identity. Rendering reads every method's source from disk; this reads none."

	^ Array streamContents: [ :stream |
			  stream
				  nextPut: aClass definitionString;
				  nextPut: aClass class definitionString;
				  nextPut: aClass commentSourcePointer.
			  {
				  aClass.
				  aClass class } do: [ :behavior | self fingerprintMethods: behavior localMethods on: stream ] ]
]

{ #category : 'private - reading' }
PIFSBackend >> classForName: className packageName: packageName originalPath: aString [

	| class |
	class := Smalltalk at: className asSymbol ifAbsent: [ self signalNotFound: aString ].
	class package name asString = packageName ifFalse: [ self signalNotFound: aString ].
	^ class
]

{ #category : 'private - paths' }
PIFSBackend >> classNameFromFileName: fileName suffix: suffixString [

	(fileName endsWith: suffixString) ifFalse: [ ^ nil ].
	^ fileName allButLast: suffixString size
]

{ #category : 'private - reading' }
PIFSBackend >> classNamed: className originalPath: aString [

	^ Smalltalk at: className asSymbol ifAbsent: [ self signalNotFound: aString ]
]

{ #category : 'private - classes' }
PIFSBackend >> classNames [

	^ (Smalltalk globals allClasses collect: [ :class | class name asString ] as: Array) sorted
]

{ #category : 'private - reading' }
PIFSBackend >> classTonelTextFor: aClass [

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
PIFSBackend >> classesInPackageNamed: packageName [

	^ (Smalltalk globals allClasses select: [ :class | class package name asString = packageName ]) sorted: [ :left :right |
		  left name <= right name ]
]

{ #category : 'private - renaming' }
PIFSBackend >> classesWhoseDefinitionNames: aClass [
	"The classes and traits whose definition names the class, so that it changes with its name: its subclasses, those using it as a pool, those using it as a trait or holding a slot of it, on either side, and those holding a class variable of it. A slot a class gets from a trait is in the trait's definition."

	| classes |
	classes := Set withAll: aClass subclasses.
	aClass isPool ifTrue: [ classes addAll: (Smalltalk globals allClasses select: [ :each | each sharedPools includes: aClass ]) ].
	aClass isTrait ifTrue: [
			{
				aClass.
				aClass classSide } do: [ :trait | trait users do: [ :user | classes add: user instanceSide ] ] ].
	(aClass inheritsFrom: Slot) ifTrue: [
			classes addAll: (Smalltalk globals allClassesAndTraits select: [ :each |
					 each localSlots , each classSide localSlots anySatisfy: [ :slot | slot class == aClass ] ]) ].
	(aClass inheritsFrom: ClassVariable) ifTrue: [
			classes addAll:
				(Smalltalk globals allClasses select: [ :each | each classVariables anySatisfy: [ :variable | variable class == aClass ] ]) ].
	^ classes
]

{ #category : 'private - writing' }
PIFSBackend >> commaSeparated: strings [

	^ String streamContents: [ :stream |
		  strings do: [ :each |
			  stream position > 0 ifTrue: [ stream nextPutAll: ', ' ].
			  stream nextPutAll: each ] ]
]

{ #category : 'accessing' }
PIFSBackend >> configuration [

	^ configuration ifNil: [ configuration := PIFSConfiguration default ]
]

{ #category : 'accessing' }
PIFSBackend >> configuration: aConfiguration [

	configuration := aConfiguration
]

{ #category : 'private - critiques' }
PIFSBackend >> critiqueEntries [

	^ self critiques entries
]

{ #category : 'private - critiques' }
PIFSBackend >> critiqueEntryForPackageNamed: packageName classNamed: className ifAbsent: absentBlock [

	self assertPackageIsVisibleNamed: packageName originalPath: '/critiques/' , packageName.
	^ self critiques entryForPackageNamed: packageName classNamed: className ifAbsent: absentBlock
]

{ #category : 'private - critiques' }
PIFSBackend >> critiqueEntryForPackageNamed: packageName classNamed: className ifPresent: presentBlock ifAbsent: absentBlock [

	^ presentBlock value: (self critiqueEntryForPackageNamed: packageName classNamed: className ifAbsent: [ ^ absentBlock value ])
]

{ #category : 'private - critiques' }
PIFSBackend >> critiqueMethodDataIn: classEntry forSelector: aSelector ifAbsent: absentBlock [

	^ self critiques methodDataIn: classEntry forSelector: aSelector ifAbsent: absentBlock
]

{ #category : 'private - listing' }
PIFSBackend >> critiqueMethodEntriesForClass: aClass [

	| classEntry entries methods |
	classEntry := self critiqueEntryForPackageNamed: aClass package name asString classNamed: aClass name ifAbsent: [ ^ #(  ) ].
	entries := OrderedCollection new.
	(classEntry includesKey: #class) ifTrue: [ entries add: (self fileNamed: 'class-critiques.json' size: 0 writable: false) ].
	methods := classEntry at: #methods ifAbsent: [ Dictionary new ].
	methods keys sorted do: [ :selector |
		entries add: (self fileNamed: (self pathSegmentForSelector: selector) , '.json' size: 0 writable: false) ].
	^ entries asArray
]

{ #category : 'private - listing' }
PIFSBackend >> critiquePackageEntriesForPackageNamed: packageName originalPath: aString [

	| packageEntry |
	self assertPackageIsVisibleNamed: packageName originalPath: aString.
	packageEntry := self critiqueEntries at: packageName ifAbsent: [ self signalNotFound: aString ].
	^ packageEntry keys sorted collect: [ :className | self directoryNamed: className ]
]

{ #category : 'private - listing' }
PIFSBackend >> critiqueRootEntries [

	^ (self critiqueEntries keys select: [ :packageName | self isPackageVisibleNamed: packageName ]) sorted collect: [ :packageName |
		  self directoryNamed: packageName ]
]

{ #category : 'accessing' }
PIFSBackend >> critiques [

	^ critiques ifNil: [ critiques := PIFSCritiqueIndex new ]
]

{ #category : 'private - paths' }
PIFSBackend >> decodedSelectorToken: token originalPath: originalPath [

	(token beginsWith: '^') ifFalse: [ ^ token ].
	^ self selectorCharacterForEscapeName: token allButFirst originalPath: originalPath
]

{ #category : 'accessing' }
PIFSBackend >> delete: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [
			segments size > 1 ifTrue: [ self assertPackageIsVisibleNamed: segments second originalPath: aString ].
			^ self deleteTonelSegments: segments allButFirst originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> deleteResponseForPath: aString [

	self delete: aString.
	^ Dictionary new
]

{ #category : 'private - deleting' }
PIFSBackend >> deleteTonelClassFileNamed: fileName packageName: packageName originalPath: aString [

	| class className failureMessage previousText |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	"A class the image lacks is not found whoever owns its package: a class file created and never written has nothing to delete."
	class := self classForName: className packageName: packageName originalPath: aString.
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	previousText := self classTonelTextFor: class.
	[
		class removeFromSystem.
		self exportPackageNamed: packageName fileNamed: fileName.
		self removeCritiquesForClassNamed: className packageName: packageName ]
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
PIFSBackend >> deleteTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString [

	| className failureMessage methods package previousText |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classNamed: className originalPath: aString.
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	methods := self extensionMethodsForClassName: className inPackage: package.
	methods ifEmpty: [ self signalNotFound: aString ].
	previousText := self extensionTextForClassName: className package: package originalPath: aString.
	[
		self removeCompiledMethods: methods.
		self exportPackageNamed: packageName fileNamed: fileName.
		self removeCritiquesForClassNamed: className packageName: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					self withoutMethodChecksDo: [
							self
								applyNewExtensionTonelText: previousText
								className: className
								packageName: packageName
								originalPath: aString ].
					self exportPackageNamed: packageName fileNamed: fileName ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection delete failed and rollback failed. Delete error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - deleting' }
PIFSBackend >> deleteTonelSegments: segments originalPath: aString [

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

{ #category : 'private - entries' }
PIFSBackend >> directoryNamed: aString [

	^ PIFSEntry directoryNamed: aString
]

{ #category : 'private - entries' }
PIFSBackend >> entryNamed: aString in: entries ifAbsent: absentBlock [

	^ entries detect: [ :each | each name = aString ] ifNone: absentBlock
]

{ #category : 'accessing' }
PIFSBackend >> excludedPackagePrefixes [

	^ self configuration excludedPackagePrefixes
]

{ #category : 'accessing' }
PIFSBackend >> excludedPackagePrefixes: prefixStrings [

	self configuration excludedPackagePrefixes: prefixStrings
]

{ #category : 'private - moving' }
PIFSBackend >> executeClassMoveNamed: className toPackage: packageName [

	PIFSCompatibility moveClassNamed: className toPackage: packageName
]

{ #category : 'private - renaming' }
PIFSBackend >> executeClassRenameFrom: oldClassName to: newClassName [

	[ (ReRenameClassRefactoring rename: oldClassName asSymbol to: newClassName asSymbol) execute ]
		on: ProvideAnswerNotification
		do: [ :notification | notification resume: true ]
]

{ #category : 'private - repositories' }
PIFSBackend >> exportFilesByPackageName: aDictionary [

	aDictionary keys sorted do: [ :packageName |
		self exportPackageNamed: packageName filesNamed: (aDictionary at: packageName) asArray sorted ]
]

{ #category : 'private - repositories' }
PIFSBackend >> exportPackageNamed: packageName [

	self repositories exportPackageNamed: packageName
]

{ #category : 'private - repositories' }
PIFSBackend >> exportPackageNamed: packageName fileNamed: fileName [
	"A change that touches one class owns one file. Exporting the package
	would rewrite the rest of it too, reordering any file whose methods are
	not in the writer's own order."

	self exportPackageNamed: packageName filesNamed: { fileName }
]

{ #category : 'private - repositories' }
PIFSBackend >> exportPackageNamed: packageName filesNamed: fileNames [

	self repositories exportPackageNamed: packageName filesNamed: fileNames
]

{ #category : 'private - repositories' }
PIFSBackend >> exportPackagesNamed: packageNames [

	packageNames do: [ :packageName | self exportPackageNamed: packageName ]
]

{ #category : 'private - repositories' }
PIFSBackend >> exportPackagesNamed: packageNames fileNamed: fileName [
	"A move changes one file in each of two packages, and nothing else in
	either."

	packageNames do: [ :packageName | self exportPackageNamed: packageName fileNamed: fileName ]
]

{ #category : 'private - reading' }
PIFSBackend >> extensionFingerprintFor: methods [

	^ Array streamContents: [ :stream | self fingerprintMethods: methods on: stream ]
]

{ #category : 'private - reading' }
PIFSBackend >> extensionMethodsForClassName: className inPackage: aPackage [

	^ (aPackage extensionMethods select: [ :method | method methodClass instanceSide name asString = className ]) asArray
]

{ #category : 'private - moving' }
PIFSBackend >> extensionText: textString movingCategoriesFromPackage: sourcePackageName toPackage: targetPackageName originalPath: aString [

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
PIFSBackend >> extensionTextForClassName: className package: aPackage originalPath: aString [

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
PIFSBackend >> fileNamed: aString size: anInteger writable: aBoolean [

	^ PIFSEntry fileNamed: aString size: anInteger writable: aBoolean
]

{ #category : 'private - entries' }
PIFSBackend >> fileNamed: aString text: textString writable: aBoolean [

	"The mount serves the text as UTF-8, so the entry must report its byte size."

	^ self fileNamed: aString size: textString utf8Encoded size writable: aBoolean
]

{ #category : 'private - renaming' }
PIFSBackend >> filesOutsidePackagesNamed: packageNames changedByRenaming: aClass to: newClassName [
	"By package, the files a rename rewrites beyond the packages it exports whole: those holding a method that names the class, by its binding or by a symbol, which the refactoring looks up and rewrites alike, those holding a definition that names it, and its extensions, whose file takes the new name. A class using a trait holds copies of its methods, which are the trait's file."

	| files add |
	files := Dictionary new.
	add := [ :packageName :fileName |
	       (packageNames includes: packageName) ifFalse: [ (files at: packageName ifAbsentPut: [ Set new ]) add: fileName ] ].
	{
		aClass binding.
		aClass name } do: [ :reference |
			(SystemNavigation default allReferencesTo: reference)
				reject: [ :method | method isFromTrait ]
				thenDo: [ :method | add value: method package name asString value: (self tonelFileNameFor: method) ] ].
	(self classesWhoseDefinitionNames: aClass) do: [ :each |
		add value: each package name asString value: (self tonelFileNameForClass: each) ].
	aClass localMethods , aClass classSide localMethods reject: [ :method | method package = aClass package ] thenDo: [ :method |
			add value: method package name asString value: aClass name , '.extension.st'.
			add value: method package name asString value: newClassName , '.extension.st' ].
	^ files
]

{ #category : 'private - reading' }
PIFSBackend >> fingerprintMethods: methods on: aStream [
	"A recompiled method gets a new source pointer, or none in an image without a changes file, so its identity is kept too."

	methods do: [ :method |
			aStream
				nextPut: method methodClass isMeta;
				nextPut: method selector;
				nextPut: method protocol name;
				nextPut: method sourcePointer;
				nextPut: method identityHash ]
]

{ #category : 'accessing' }
PIFSBackend >> formatsWrittenMethods [

	^ self configuration formatsWrittenMethods
]

{ #category : 'accessing' }
PIFSBackend >> formatsWrittenMethods: aBoolean [

	self configuration formatsWrittenMethods: aBoolean
]

{ #category : 'private - repositories' }
PIFSBackend >> ifPackageNamed: packageName cannotBeWrittenDo: aBlock [
	"Evaluate aBlock with the reason a change made through another path cannot write into the package, if it cannot."

	(self isPackageVisibleNamed: packageName) ifFalse: [ ^ aBlock value: 'outside the projected packages' ].
	self requiresRepositoryOwnershipForWrites ifFalse: [ ^ self ].
	self repositoryOwningPackageNamed: packageName ifAbsent: [ aBlock value: 'not owned by a loaded Iceberg repository' ]
]

{ #category : 'accessing' }
PIFSBackend >> includedPackagePrefixes [

	^ self configuration includedPackagePrefixes
]

{ #category : 'accessing' }
PIFSBackend >> includedPackagePrefixes: prefixStrings [

	self configuration includedPackagePrefixes: prefixStrings
]

{ #category : 'private - packages' }
PIFSBackend >> isPackageVisibleNamed: packageName [

	^ (self includedPackagePrefixes isEmpty or: [
		   self includedPackagePrefixes anySatisfy: [ :prefix | packageName beginsWith: prefix ] ]) and: [
		  self excludedPackagePrefixes noneSatisfy: [ :prefix | packageName beginsWith: prefix ] ]
]

{ #category : 'private - json' }
PIFSBackend >> jsonTextFor: anObject [

	^ STONJSON toString: anObject
]

{ #category : 'private - errors' }
PIFSBackend >> lineAt: anIndex in: aString do: aBlock [
	"Evaluate aBlock with the number of the line that holds anIndex, its column there, and the line. Lines count from 1 whatever ends them: CR, LF or both. An index past the end is on the last line, after its last character."

	| number |
	number := 0.
	aString lineIndicesDo: [ :start :endWithoutDelimiters :end |
			number := number + 1.
			(anIndex <= end or: [ end >= aString size ]) ifTrue: [
				^ aBlock value: number value: anIndex - start + 1 value: (aString copyFrom: start to: endWithoutDelimiters) ] ].
	^ aBlock value: 1 value: 1 value: ''
]

{ #category : 'accessing' }
PIFSBackend >> list: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ ^ self rootEntries ].
	segments first = 'tonel' ifTrue: [ ^ self listTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self listCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self listRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - listing' }
PIFSBackend >> listCritiqueSegments: segments originalPath: aString [

	| class |
	segments isEmpty ifTrue: [ ^ self critiqueRootEntries ].
	segments size = 1 ifTrue: [ ^ self critiquePackageEntriesForPackageNamed: segments first originalPath: aString ].
	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	class := self classNamed: segments second originalPath: aString.
	class package name asString = segments first ifFalse: [ self signalNotFound: aString ].
	^ self critiqueMethodEntriesForClass: class
]

{ #category : 'private - listing' }
PIFSBackend >> listRepositorySegments: segments originalPath: aString [

	segments isEmpty ifTrue: [ ^ self repositoryEntries ].
	self signalNotFound: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> listResponseForPath: aString [

	^ Dictionary new
		  at: #entries put: ((self list: aString) collect: [ :each | each asDictionary ]);
		  yourself
]

{ #category : 'private - listing' }
PIFSBackend >> listTonelSegments: segments originalPath: aString [

	| package |
	segments isEmpty ifTrue: [ ^ self tonelRootEntries ].
	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	package := self packageNamed: segments first ifAbsent: [ self signalNotFound: aString ].
	^ self tonelEntriesForPackage: package
]

{ #category : 'private - writing' }
PIFSBackend >> loadClassDefinition: classDefinition [

	PIFSCompatibility loadMonticelloDefinition: classDefinition
]

{ #category : 'private - writing' }
PIFSBackend >> loadMethodDefinition: methodDefinition [

	PIFSCompatibility loadMonticelloDefinition: methodDefinition.
	self formatsWrittenMethods ifTrue: [ self reformatLoadedMethodDefinition: methodDefinition ]
]

{ #category : 'private - reading' }
PIFSBackend >> localMethodsForClass: aBehavior [

	^ aBehavior localMethods reject: [ :method | method protocol name beginsWith: '*' ]
]

{ #category : 'accessing' }
PIFSBackend >> makeDirectory: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments size = 2 ifFalse: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [ ^ self makeTonelPackageDirectoryNamed: segments second originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> makeDirectoryResponseForPath: aString [

	self makeDirectory: aString.
	^ Dictionary new
]

{ #category : 'private - packages' }
PIFSBackend >> makeTonelPackageDirectoryNamed: packageName originalPath: aString [

	packageName ifEmpty: [ self signalUnsupportedWrite: aString ].
	self assertPackageIsVisibleNamed: packageName originalPath: aString.
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	PackageOrganizer default ensurePackage: packageName
]

{ #category : 'private - writing' }
PIFSBackend >> methodDefinitionsByIdentityFor: methodDefinitions [

	| definitionsByIdentity |
	definitionsByIdentity := Dictionary new.
	methodDefinitions do: [ :methodDefinition |
		definitionsByIdentity at: (self methodIdentityFor: methodDefinition) put: methodDefinition ].
	^ definitionsByIdentity
]

{ #category : 'private - writing' }
PIFSBackend >> methodDefinitionsChangedFrom: oldMethodDefinitions in: newMethodDefinitions [

	| oldDefinitionsByIdentity |
	oldDefinitionsByIdentity := self methodDefinitionsByIdentityFor: oldMethodDefinitions.
	^ newMethodDefinitions reject: [ :methodDefinition |
		  (oldDefinitionsByIdentity
			   at: (self methodIdentityFor: methodDefinition)
			   ifAbsent: [ nil ])
			  = methodDefinition ]
]

{ #category : 'private - writing' }
PIFSBackend >> methodDefinitionsFrom: definitions [

	^ definitions select: #isMethodDefinition
]

{ #category : 'private - writing' }
PIFSBackend >> methodIdentityFor: aMethodDefinition [

	^ {
		  aMethodDefinition className asString.
		  aMethodDefinition classIsMeta.
		  aMethodDefinition selector }
]

{ #category : 'private - errors' }
PIFSBackend >> methodNameOf: aMethodDefinition [

	^ String streamContents: [ :stream |
			  stream nextPutAll: aMethodDefinition className.
			  aMethodDefinition classIsMeta ifTrue: [ stream nextPutAll: ' class' ].
			  stream
				  nextPutAll: '>>';
				  nextPutAll: aMethodDefinition selector ]
]

{ #category : 'private - moving' }
PIFSBackend >> moveAndRenameTonelClassFileNamed: sourceFileName toFileNamed: targetFileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| class failureMessage newClassName oldClassName outsideFiles |
	oldClassName := self classNameFromFileName: sourceFileName suffix: '.class.st'.
	newClassName := self classNameFromFileName: targetFileName suffix: '.class.st'.
	oldClassName ifNil: [ self signalUnsupportedWrite: sourcePath ].
	newClassName ifNil: [ self signalUnsupportedWrite: targetPath ].
	class := self classForName: oldClassName packageName: sourcePackageName originalPath: sourcePath.
	self
		assertRepositoriesOwnPackageNames: {
				sourcePackageName.
				targetPackageName }
		originalPath: sourcePath.
	self packageNamed: targetPackageName ifAbsent: [ self signalNotFound: targetPath ].
	(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
		Error signal: 'Cannot rename class ' , oldClassName , ' to existing global ' , newClassName , ' for ' , targetPath ].
	outsideFiles := self
		                filesOutsidePackagesNamed: {
				                sourcePackageName.
				                targetPackageName }
		                changedByRenaming: class
		                to: newClassName.
	self validateRenameOfClass: class changingPackagesNamed: outsideFiles keys originalPath: sourcePath.
	[
		self executeClassRenameFrom: oldClassName to: newClassName.
		self executeClassMoveNamed: newClassName toPackage: targetPackageName.
		self exportPackagesNamed: {
				sourcePackageName.
				targetPackageName }.
		self exportFilesByPackageName: outsideFiles.
		self bindUndeclaredReferencesToClassNamed: newClassName ]
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
							sourcePackageName }.
					self exportFilesByPackageName: outsideFiles ]
					on: Error
					do: [ :rollbackError |
							Error signal:
								'Projection class move and rename failed and rollback failed. Move and rename error: ' , failureMessage
								, '. Rollback error: ' , (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - moving' }
PIFSBackend >> moveTonelClassFileNamed: fileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| class className failureMessage |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: sourcePath ].
	class := self classForName: className packageName: sourcePackageName originalPath: sourcePath.
	self
		assertRepositoriesOwnPackageNames: {
				sourcePackageName.
				targetPackageName }
		originalPath: sourcePath.
	self packageNamed: targetPackageName ifAbsent: [ self signalNotFound: targetPath ].
	[
		self executeClassMoveNamed: className toPackage: targetPackageName.
		self
			exportPackagesNamed: {
					sourcePackageName.
					targetPackageName }
			fileNamed: fileName.
		self removeCritiquesForClassNamed: className packageName: sourcePackageName.
		self removeCritiquesForClassNamed: className packageName: targetPackageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					class package name asString = targetPackageName ifTrue: [ self executeClassMoveNamed: className toPackage: sourcePackageName ].
					self
						exportPackagesNamed: {
								targetPackageName.
								sourcePackageName }
						fileNamed: fileName ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection class move failed and rollback failed. Move error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - moving' }
PIFSBackend >> moveTonelExtensionFileNamed: fileName packageName: sourcePackageName toPackageName: targetPackageName originalPath: sourcePath targetPath: targetPath [

	| className failureMessage movedText previousText sourceMethods sourcePackage targetMethods targetPackage |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: sourcePath ].
	self classNamed: className originalPath: sourcePath.
	self
		assertRepositoriesOwnPackageNames: {
				sourcePackageName.
				targetPackageName }
		originalPath: sourcePath.
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
		self withoutMethodChecksDo: [
				self
					applyNewExtensionTonelText: movedText
					className: className
					packageName: targetPackageName
					originalPath: targetPath ].
		self
			exportPackagesNamed: {
					sourcePackageName.
					targetPackageName }
			fileNamed: fileName.
		self removeCritiquesForClassNamed: className packageName: sourcePackageName.
		self removeCritiquesForClassNamed: className packageName: targetPackageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					targetMethods := self extensionMethodsForClassName: className inPackage: targetPackage.
					targetMethods ifNotEmpty: [ self removeCompiledMethods: targetMethods ].
					self withoutMethodChecksDo: [
							self
								applyNewExtensionTonelText: previousText
								className: className
								packageName: sourcePackageName
								originalPath: sourcePath ].
					self
						exportPackagesNamed: {
								targetPackageName.
								sourcePackageName }
						fileNamed: fileName ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection extension move failed and rollback failed. Move error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - packages' }
PIFSBackend >> packageNamed: aString ifAbsent: absentBlock [

	self assertPackageIsVisibleNamed: aString originalPath: '/tonel/' , aString.
	^ PackageOrganizer default packageNamed: aString ifAbsent: absentBlock
]

{ #category : 'private - packages' }
PIFSBackend >> packageNames [

	^ ((PackageOrganizer default packages collect: [ :each | each name asString ] as: Array) select: [ :each |
		   self isPackageVisibleNamed: each ]) sorted
]

{ #category : 'private - writing' }
PIFSBackend >> parseTonelDefinitionsFrom: textString originalPath: aString [

	| parser |
	parser := PIFSTonelParser on: textString readStream.
	^ [ parser start ]
		  on: Error
		  do: [ :error |
				  Error signal: (String streamContents: [ :stream |
							   stream
								   nextPutAll: 'Cannot parse Tonel file for ';
								   nextPutAll: aString;
								   nextPutAll: ': '.
							   self
								   printParseFailure: error
								   of: parser
								   in: textString
								   on: stream ]) ]
]

{ #category : 'private - paths' }
PIFSBackend >> pathSegmentForSelector: aSelector [

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
PIFSBackend >> pathSegmentsFor: aString [

	^ ($/ split: aString) reject: [ :each | each isEmpty ]
]

{ #category : 'private - errors' }
PIFSBackend >> positionsOf: aMethodDefinition in: textString do: aBlock [
	"Evaluate aBlock with where the method's source begins in the text, where its body begins in the text, and where its body begins in its source. Read again only when a method is refused."

	| parser |
	parser := PIFSTonelParser on: textString readStream.
	parser start.
	parser sourcePositions
		detect: [ :each | each key = aMethodDefinition ]
		ifFound: [ :each | aBlock valueWithArguments: each value ]
]

{ #category : 'private - errors' }
PIFSBackend >> printLine: lineString number: lineNumber column: column on: aStream [
	"As method_compile shows where a compile failed: the line, then a caret under the column, each tab before it kept a tab so that the caret lines up."

	aStream
		nextPut: Character lf;
		nextPutAll: 'Line ';
		print: lineNumber;
		nextPut: $:;
		nextPut: Character lf;
		nextPutAll: lineString;
		nextPut: Character lf.
	(lineString first: ((column - 1 max: 0) min: lineString size)) do: [ :each |
			aStream nextPut: (each = Character tab
					 ifTrue: [ each ]
					 ifFalse: [ Character space ]) ].
	aStream nextPut: $^
]

{ #category : 'private - errors' }
PIFSBackend >> printLineAt: anIndex in: textString on: aStream [

	self lineAt: anIndex in: textString do: [ :number :column :lineString |
			self
				printLine: lineString
				number: number
				column: column
				on: aStream ]
]

{ #category : 'private - errors' }
PIFSBackend >> printLineAt: sourceIndex inSourceOf: aMethodDefinition text: textString on: aStream [
	"A method's source is its selector, as the header holds it, followed by its body, as the file holds it after the [, line endings aside. An index in the selector is as far from where the source begins in the file; an index in the body is as many lines from where the body begins, and on the body's first line, as many columns."

	self positionsOf: aMethodDefinition in: textString do: [ :sourcePosition :bodyPosition :bodyIndex |
			sourceIndex < bodyIndex ifTrue: [ ^ self printLineAt: sourcePosition + sourceIndex - 1 in: textString on: aStream ].
			self lineAt: bodyPosition in: textString do: [ :firstNumber :firstColumn :firstLine |
					self
						lineAt: sourceIndex - bodyIndex + 1
						in: (aMethodDefinition source allButFirst: bodyIndex - 1)
						do: [ :number :column :line |
								self
									printLine: (textString lines at: firstNumber + number - 1 ifAbsent: [ '' ])
									number: firstNumber + number - 1
									column: (number = 1
											 ifTrue: [ firstColumn + column - 1 ]
											 ifFalse: [ column ])
									on: aStream ] ] ]
]

{ #category : 'private - errors' }
PIFSBackend >> printNotice: aNotice on: aStream [
	"The compiler says 'Assignment to read-only variable', on the variable assigned, and names it nowhere."

	| node |
	node := aNotice node.
	(node isVariable and: [ node variable isNotNil and: [ node variable isWritable not ] ]) ifFalse: [
		^ aStream nextPutAll: aNotice messageText ].
	aStream nextPutAll: node name.
	node variable isArgumentVariable ifTrue: [
		^ aStream nextPutAll: ' is an argument, and arguments are read-only. Assign its value to a temporary variable and change that.' ].
	node variable isPseudoVariable ifTrue: [ ^ aStream nextPutAll: ' is a pseudo-variable, which cannot be assigned.' ].
	aStream nextPutAll: ' is read-only, and cannot be assigned.'
]

{ #category : 'private - errors' }
PIFSBackend >> printParseFailure: anError of: aParser in: textString on: aStream [
	"Where the parser stopped, which Tonel's own errors do not say."

	aParser bodyPosition ifNotNil: [ :bodyPosition |
			^ self
				  printUnreadBodyAt: bodyPosition
				  ofMethodAt: aParser methodPosition
				  in: textString
				  on: aStream ].
	aParser methodPosition ifNotNil: [ :methodPosition |
			aStream nextPutAll: 'the line below does not begin a method as Tonel writes one: Class >> selector [ body ].'.
			^ self printLineAt: methodPosition in: textString on: aStream ].
	aStream nextPutAll: (anError messageText ifNil: [ anError asString ]).
	self printLineAt: aParser position in: textString on: aStream
]

{ #category : 'private - errors' }
PIFSBackend >> printUnreadBodyAt: bodyPosition ofMethodAt: methodPosition in: textString on: aStream [
	"Tonel reads a body by counting brackets outside strings, comments and literal arrays, so it finds a body unclosed only at the end of the file: the method to look at is the one whose body it was reading."

	(textString at: bodyPosition ifAbsent: [ nil ]) = $[ ifFalse: [
			aStream nextPutAll: 'the method on the line below has no [ to open its body.'.
			^ self printLineAt: methodPosition in: textString on: aStream ].
	aStream
		nextPutAll: 'the body of ';
		nextPutAll: (' ' join: (textString copyFrom: methodPosition to: bodyPosition - 1) substrings);
		nextPutAll: ' is never closed: a [ in it lacks its ], or a '', a " or a #( in it is left open.'.
	self printLineAt: bodyPosition in: textString on: aStream
]

{ #category : 'accessing' }
PIFSBackend >> read: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalNotFound: aString ].
	segments first = 'tonel' ifTrue: [ ^ self readTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self readCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self readRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - reading' }
PIFSBackend >> readCritiqueClassFileNamed: fileName packageName: packageName className: className originalPath: aString [

	fileName = 'class-critiques.json' ifFalse: [ self signalNotFound: aString ].
	^ self jsonTextFor: (self
			   critiqueEntryForPackageNamed: packageName
			   classNamed: className
			   ifPresent: [ :classEntry | classEntry at: #class ifAbsent: [ self signalNotFound: aString ] ]
			   ifAbsent: [ self signalNotFound: aString ])
]

{ #category : 'private - reading' }
PIFSBackend >> readCritiqueMethodFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| selector |
	selector := self selectorFromPathSegment: fileName originalPath: aString.
	^ self jsonTextFor: (self
			   critiqueEntryForPackageNamed: packageName
			   classNamed: className
			   ifPresent: [ :classEntry |
			   self critiqueMethodDataIn: classEntry forSelector: selector ifAbsent: [ self signalNotFound: aString ] ]
			   ifAbsent: [ self signalNotFound: aString ])
]

{ #category : 'private - reading' }
PIFSBackend >> readCritiqueSegments: segments originalPath: aString [

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
PIFSBackend >> readRepositorySegments: segments originalPath: aString [

	segments size = 1 ifFalse: [ self signalNotFound: aString ].
	^ self repositoryMetadataTextForFileNamed: segments first originalPath: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> readResponseForPath: aString [

	^ Dictionary new
		  at: #text put: (self read: aString);
		  yourself
]

{ #category : 'private - reading' }
PIFSBackend >> readTonelClassFileNamed: fileName packageName: packageName originalPath: aString [
	"A read renders anyway, so it also records the size the next stat will report."

	| class className text |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classForName: className packageName: packageName originalPath: aString.
	text := self classTonelTextFor: class.
	self renderedSizes at: aString fingerprint: (self classFingerprintFor: class) put: (self utf8SizeOf: text).
	^ text
]

{ #category : 'private - reading' }
PIFSBackend >> readTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString [

	| className package text |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalNotFound: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	text := self extensionTextForClassName: className package: package originalPath: aString.
	self renderedSizes
		at: aString
		fingerprint: (self extensionFingerprintFor: (self extensionMethodsForClassName: className inPackage: package))
		put: (self utf8SizeOf: text).
	^ text
]

{ #category : 'private - reading' }
PIFSBackend >> readTonelSegments: segments originalPath: aString [

	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	self assertPackageIsVisibleNamed: segments first originalPath: aString.
	(segments second endsWith: '.class.st') ifTrue: [
		^ self readTonelClassFileNamed: segments second packageName: segments first originalPath: aString ].
	(segments second endsWith: '.extension.st') ifTrue: [
		^ self readTonelExtensionFileNamed: segments second packageName: segments first originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - critiques' }
PIFSBackend >> recordCritiquesForClassNamed: className packageName: packageName methodDefinitions: methodDefinitions [

	self critiques
		recordForClass: (self classNamed: className originalPath: '/critiques/' , packageName , '/' , className)
		packageName: packageName
		methodDefinitions: methodDefinitions
]

{ #category : 'private - critiques' }
PIFSBackend >> recordCritiquesForExtensionClassNamed: className packageName: packageName methodDefinitions: methodDefinitions [

	self critiques
		recordExtensionForClass: (self classNamed: className originalPath: '/critiques/' , packageName , '/' , className)
		packageName: packageName
		methodDefinitions: methodDefinitions
]

{ #category : 'private - writing' }
PIFSBackend >> reformatLoadedMethodDefinition: methodDefinition [
	"CompiledMethod>>reformat formats through the AST node class, so it resolves AST-Core's manifest formatter instead of the edited package's own.
	Compiling here also bypasses MCMethodDefinition>>source:, which is what normally restores the image line ending."

	| behavior method selector |
	behavior := methodDefinition actualClass.
	behavior ifNil: [ ^ self ].
	selector := methodDefinition selector asSymbol.
	(behavior includesSelector: selector) ifFalse: [ ^ self ].
	method := behavior >> selector.
	behavior compile: (method ast formattedCodeIn: behavior) withInternalLineEndings classified: method protocol
]

{ #category : 'private - writing' }
PIFSBackend >> removeClassNamed: className ifPresentInPackage: packageName [

	| class |
	class := Smalltalk at: className asSymbol ifAbsent: [ ^ self ].
	class package name asString = packageName ifFalse: [ ^ self ].
	class removeFromSystem
]

{ #category : 'private - deleting' }
PIFSBackend >> removeCompiledMethods: compiledMethods [

	compiledMethods do: [ :method | method asRingDefinition asMCMethodDefinition unload ]
]

{ #category : 'private - critiques' }
PIFSBackend >> removeCritiquesForClassNamed: className packageName: packageName [

	self critiques removeForClassNamed: className packageName: packageName
]

{ #category : 'accessing' }
PIFSBackend >> removeDirectory: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments size = 2 ifFalse: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [ ^ self removeTonelPackageDirectoryNamed: segments second originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> removeDirectoryResponseForPath: aString [

	self removeDirectory: aString.
	^ Dictionary new
]

{ #category : 'private - writing' }
PIFSBackend >> removeMethodDefinitions: methodDefinitions [

	methodDefinitions do: [ :methodDefinition | self unloadMethodDefinition: methodDefinition ]
]

{ #category : 'private - repositories' }
PIFSBackend >> removePackageNamed: packageName during: aBlock [

	self repositories removePackageNamed: packageName during: aBlock
]

{ #category : 'private - packages' }
PIFSBackend >> removePackageNamedIfEmpty: packageName [

	| package |
	package := self packageNamed: packageName ifAbsent: [ ^ self ].
	package isEmpty ifTrue: [ PackageOrganizer default removePackage: package ]
]

{ #category : 'private - packages' }
PIFSBackend >> removeTonelPackageDirectoryNamed: packageName originalPath: aString [

	| package |
	packageName ifEmpty: [ self signalUnsupportedWrite: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	package isEmpty ifFalse: [ Error signal: 'Cannot remove non-empty package ' , packageName , ' through ' , aString ].
	self removePackageNamed: packageName during: [ PackageOrganizer default removePackage: package ]
]

{ #category : 'accessing' }
PIFSBackend >> rename: sourcePath to: targetPath [

	| sourceClassName sourceSegments targetClassName targetSegments |
	sourceSegments := self pathSegmentsFor: sourcePath.
	targetSegments := self pathSegmentsFor: targetPath.
	(sourceSegments size = 3 and: [
		 sourceSegments first = 'tonel' and: [ targetSegments size = 3 and: [ targetSegments first = 'tonel' ] ] ]) ifFalse: [
		self signalUnsupportedWrite: sourcePath ].
	self assertPackageIsVisibleNamed: sourceSegments second originalPath: sourcePath.
	self assertPackageIsVisibleNamed: targetSegments second originalPath: targetPath.
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
PIFSBackend >> renameResponseForPath: sourcePath to: targetPath [

	self rename: sourcePath to: targetPath.
	^ Dictionary new
]

{ #category : 'private - renaming' }
PIFSBackend >> renameTonelClassFileNamed: sourceFileName toFileNamed: targetFileName packageName: packageName originalPath: sourcePath targetPath: targetPath [

	| class failureMessage newClassName oldClassName outsideFiles |
	oldClassName := self classNameFromFileName: sourceFileName suffix: '.class.st'.
	newClassName := self classNameFromFileName: targetFileName suffix: '.class.st'.
	oldClassName ifNil: [ self signalUnsupportedWrite: sourcePath ].
	newClassName ifNil: [ self signalUnsupportedWrite: targetPath ].
	oldClassName = newClassName ifTrue: [ ^ self ].
	class := self classForName: oldClassName packageName: packageName originalPath: sourcePath.
	(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [
		Error signal: 'Cannot rename class ' , oldClassName , ' to existing global ' , newClassName , ' for ' , targetPath ].
	outsideFiles := self filesOutsidePackagesNamed: { packageName } changedByRenaming: class to: newClassName.
	self validateRenameOfClass: class changingPackagesNamed: outsideFiles keys originalPath: sourcePath.
	[
		self executeClassRenameFrom: oldClassName to: newClassName.
		self exportPackageNamed: packageName.
		self exportFilesByPackageName: outsideFiles.
		self bindUndeclaredReferencesToClassNamed: newClassName.
		self removeCritiquesForClassNamed: oldClassName packageName: packageName.
		self removeCritiquesForClassNamed: newClassName packageName: packageName ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					(Smalltalk globals includesKey: newClassName asSymbol) ifTrue: [ self executeClassRenameFrom: newClassName to: oldClassName ].
					self exportPackageNamed: packageName.
					self exportFilesByPackageName: outsideFiles ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection rename failed and rollback failed. Rename error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - reading' }
PIFSBackend >> renderedSizes [

	^ renderedSizes ifNil: [ renderedSizes := PIFSRenderedSizes new ]
]

{ #category : 'accessing' }
PIFSBackend >> repositories [

	^ repositories ifNil: [ repositories := PIFSRepositories new ]
]

{ #category : 'accessing' }
PIFSBackend >> repositories: aRepositories [

	repositories := aRepositories
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryEntries [

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
PIFSBackend >> repositoryInfoForMetadataFileNamed: fileName originalPath: aString [

	^ self repositoryInfos
		  detect: [ :info | (self repositoryMetadataFileNameFor: info) = fileName ]
		  ifNone: [ self signalNotFound: aString ]
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryInfoForProjectionName: projectionName originalPath: aString [

	^ self repositoryInfos
		  detect: [ :info | (info at: #projectionName) = projectionName ]
		  ifNone: [ self signalNotFound: aString ]
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryInfoForRepository: repository ifPresent: presentBlock [

	| directory info |
	(self repositories canExportSourceFor: repository) ifFalse: [ ^ self ].
	directory := self repositories directoryFor: repository.
	info := OrderedDictionary new.
	info
		at: #name put: repository name asString;
		at: #projectionName put: (self repositoryProjectionNameFor: repository name asString);
		at: #path put: directory pathString;
		at: #loadedPackages put: (self repositories loadedPackageNamesFor: repository).
	^ presentBlock value: info
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryInfos [

	| infos |
	infos := OrderedCollection new.
	self repositories all do: [ :repository | self repositoryInfoForRepository: repository ifPresent: [ :info | infos add: info ] ].
	^ infos asArray sorted: [ :left :right | (left at: #projectionName) <= (right at: #projectionName) ]
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryMetadataFileNameFor: info [

	^ (info at: #projectionName) , '.repository.json'
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryMetadataTextForFileNamed: fileName originalPath: aString [

	^ self jsonTextFor: (self repositoryInfoForMetadataFileNamed: fileName originalPath: aString)
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryOwningPackageNamed: packageName ifAbsent: absentBlock [

	^ self repositories owningPackageNamed: packageName ifAbsent: absentBlock
]

{ #category : 'private - repositories' }
PIFSBackend >> repositoryProjectionNameFor: aString [

	^ String streamContents: [ :stream |
		  aString do: [ :character |
			  ((character = $/) or: [ character = $: ])
				  ifTrue: [ stream nextPut: $- ]
				  ifFalse: [ stream nextPut: character ] ] ]
]

{ #category : 'accessing' }
PIFSBackend >> requiresRepositoryOwnershipForWrites [

	^ self configuration requiresRepositoryOwnershipForWrites
]

{ #category : 'accessing' }
PIFSBackend >> requiresRepositoryOwnershipForWrites: aBoolean [

	self configuration requiresRepositoryOwnershipForWrites: aBoolean
]

{ #category : 'private - deleting' }
PIFSBackend >> restoreClassTonelText: textString className: className packageName: packageName originalPath: aString [

	| currentClass currentText |
	currentClass := Smalltalk at: className asSymbol ifAbsent: [ nil ].
	self withoutMethodChecksDo: [
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
							originalPath: aString ] ].
	self exportPackageNamed: packageName fileNamed: className , '.class.st'
]

{ #category : 'private - writing' }
PIFSBackend >> rollbackClassTonelText: previousTextString afterFailedWriteToClassName: className packageName: packageName originalPath: aString [

	| currentText |
	currentText := self readTonelClassFileNamed: className , '.class.st' packageName: packageName originalPath: aString.
	self withoutMethodChecksDo: [
			self
				applyClassTonelText: previousTextString
				replacing: currentText
				className: className
				packageName: packageName
				originalPath: aString ].
	self exportPackageNamed: packageName fileNamed: className , '.class.st'
]

{ #category : 'private - writing' }
PIFSBackend >> rollbackExtensionTonelText: previousTextString afterFailedWriteToClassName: className packageName: packageName originalPath: aString [

	| currentText |
	currentText := self readTonelExtensionFileNamed: className , '.extension.st' packageName: packageName originalPath: aString.
	self withoutMethodChecksDo: [
			self
				applyExtensionTonelText: previousTextString
				replacing: currentText
				className: className
				packageName: packageName
				originalPath: aString ].
	self exportPackageNamed: packageName fileNamed: className , '.extension.st'
]

{ #category : 'private - listing' }
PIFSBackend >> rootEntries [

	^ {
		  (self directoryNamed: 'tonel').
		  (self directoryNamed: 'critiques').
		  (self directoryNamed: 'repositories') }
]

{ #category : 'private - paths' }
PIFSBackend >> selectorCharacterForEscapeName: aString originalPath: originalPath [

	self selectorEscapeNames keysAndValuesDo: [ :character :name | name = aString ifTrue: [ ^ character asString ] ].
	self signalNotFound: originalPath
]

{ #category : 'private - paths' }
PIFSBackend >> selectorEscapeNames [

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
PIFSBackend >> selectorFromPathSegment: aString originalPath: originalPath [

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

{ #category : 'private - errors' }
PIFSBackend >> signalClassExists: aClass originalPath: aString [
	"Class names are global, so a class file written into another package names a class that exists there. Only mv of its file moves it: a write would replace the class with the copy, emptying an unrelated class that shares the name and dropping what the target package extends it with. The refusal names the mv, unless the projection does not show the class."

	| packageName |
	packageName := aClass package name asString.
	(self isPackageVisibleNamed: packageName) ifFalse: [
		Error signal: 'Class ' , aClass name , ' already exists in package ' , packageName , ' for ' , aString ].
	Error signal:
		'Class ' , aClass name , ' already exists in package ' , packageName , '. To move it, mv /tonel/' , packageName , '/'
		, aClass name , '.class.st to ' , aString
]

{ #category : 'private - errors' }
PIFSBackend >> signalErrorIn: aMethodNode of: aMethodDefinition text: textString originalPath: aString [
	"Refuse the method at its first error, where it is in the file. An undeclared variable is no error here: the files of one change are written one at a time, and a later one may declare it."

	| errors |
	errors := (aMethodNode allNotices select: [ :each | each isError and: [ each isUndeclaredNotice not ] ]) sorted.
	errors ifEmpty: [ ^ self ].
	Error signal: (String streamContents: [ :stream |
				 stream
					 nextPutAll: 'Cannot compile ';
					 nextPutAll: (self methodNameOf: aMethodDefinition);
					 nextPutAll: ' in ';
					 nextPutAll: aString;
					 nextPutAll: ': '.
				 self printNotice: errors first on: stream.
				 self
					 printLineAt: errors first position
					 inSourceOf: aMethodDefinition
					 text: textString
					 on: stream ])
]

{ #category : 'private - errors' }
PIFSBackend >> signalNotFound: aString [

	Error signal: 'Projection path not found: ' , aString
]

{ #category : 'private - errors' }
PIFSBackend >> signalUnsupportedWrite: aString [

	Error signal: 'Projection path is not writable yet: ' , aString
]

{ #category : 'accessing' }
PIFSBackend >> stat: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ ^ self directoryNamed: '/' ].
	segments first = 'tonel' ifTrue: [ ^ self statTonelSegments: segments allButFirst originalPath: aString ].
	segments first = 'critiques' ifTrue: [ ^ self statCritiqueSegments: segments allButFirst originalPath: aString ].
	segments first = 'repositories' ifTrue: [ ^ self statRepositorySegments: segments allButFirst originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PIFSBackend >> statCritiqueClassFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| text |
	text := self
		        readCritiqueClassFileNamed: fileName
		        packageName: packageName
		        className: className
		        originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PIFSBackend >> statCritiqueMethodFileNamed: fileName packageName: packageName className: className originalPath: aString [

	| text |
	text := self
		        readCritiqueMethodFileNamed: fileName
		        packageName: packageName
		        className: className
		        originalPath: aString.
	^ self fileNamed: fileName text: text writable: false
]

{ #category : 'private - accessing' }
PIFSBackend >> statCritiqueSegments: segments originalPath: aString [
	"A critique file reports the size its text has, as a Tonel file does: the mount reads no further than it."

	segments isEmpty ifTrue: [ ^ self directoryNamed: 'critiques' ].
	self assertPackageIsVisibleNamed: segments first originalPath: aString.
	segments size = 1 ifTrue: [
			self critiqueEntries at: segments first ifAbsent: [ self signalNotFound: aString ].
			^ self directoryNamed: segments first ].
	segments size = 2 ifTrue: [
			self critiqueEntryForPackageNamed: segments first classNamed: segments second ifAbsent: [ self signalNotFound: aString ].
			^ self directoryNamed: segments second ].
	segments size = 3 ifFalse: [ self signalNotFound: aString ].
	^ segments third = 'class-critiques.json'
		  ifTrue: [
				  self
					  statCritiqueClassFileNamed: segments third
					  packageName: segments first
					  className: segments second
					  originalPath: aString ]
		  ifFalse: [
				  self
					  statCritiqueMethodFileNamed: segments third
					  packageName: segments first
					  className: segments second
					  originalPath: aString ]
]

{ #category : 'private - accessing' }
PIFSBackend >> statRepositorySegments: segments originalPath: aString [

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
PIFSBackend >> statResponseForPath: aString [

	^ Dictionary new
		  at: #entry put: (self stat: aString) asDictionary;
		  yourself
]

{ #category : 'private - accessing' }
PIFSBackend >> statTonelFileNamed: fileName packageName: packageName originalPath: aString [

	(fileName endsWith: '.class.st') ifTrue: [ ^ self tonelClassEntryNamed: fileName packageName: packageName originalPath: aString ].
	(fileName endsWith: '.extension.st') ifTrue: [
		^ self tonelExtensionEntryNamed: fileName packageName: packageName originalPath: aString ].
	self signalNotFound: aString
]

{ #category : 'private - accessing' }
PIFSBackend >> statTonelSegments: segments originalPath: aString [

	| package |
	segments isEmpty ifTrue: [ ^ self directoryNamed: 'tonel' ].
	package := self packageNamed: segments first ifAbsent: [ self signalNotFound: aString ].
	segments size = 1 ifTrue: [ ^ self directoryNamed: segments first ].
	segments size = 2 ifFalse: [ self signalNotFound: aString ].
	^ self statTonelFileNamed: segments second packageName: package name asString originalPath: aString
]

{ #category : 'private - entries' }
PIFSBackend >> symlinkNamed: aString target: targetString [

	^ PIFSEntry symlinkNamed: aString target: targetString
]

{ #category : 'private - entries' }
PIFSBackend >> tonelClassEntryNamed: fileName packageName: packageName originalPath: aString [
	"The mount reads no further than the size reported here, so it must be exact. It is remembered against the class's fingerprint, so only the first stat after a change renders the class."

	| className class |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalNotFound: aString ].
	class := self classForName: className packageName: packageName originalPath: aString.
	^ self
		  fileNamed: fileName
		  size: (self renderedSizes
				   sizeAt: aString
				   fingerprint: (self classFingerprintFor: class)
				   ifAbsentPut: [ self utf8SizeOf: (self classTonelTextFor: class) ])
		  writable: true
]

{ #category : 'private - listing' }
PIFSBackend >> tonelEntriesForPackage: aPackage [

	| entries extensionClassNames |
	entries := OrderedCollection new.
	aPackage definedClasses do: [ :class | entries add: (self fileNamed: class name asString , '.class.st' size: 0 writable: true) ].
	extensionClassNames := aPackage extensionMethods collect: [ :method | method methodClass instanceSide name asString ] as: Set.
	extensionClassNames do: [ :className | entries add: (self fileNamed: className , '.extension.st' size: 0 writable: true) ].
	^ entries asArray sorted: [ :first :second | first name <= second name ]
]

{ #category : 'private - entries' }
PIFSBackend >> tonelExtensionEntryNamed: fileName packageName: packageName originalPath: aString [

	| className methods package |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalNotFound: aString ].
	package := self packageNamed: packageName ifAbsent: [ self signalNotFound: aString ].
	methods := self extensionMethodsForClassName: className inPackage: package.
	methods ifEmpty: [ self signalNotFound: aString ].
	^ self
		  fileNamed: fileName
		  size: (self renderedSizes
				   sizeAt: aString
				   fingerprint: (self extensionFingerprintFor: methods)
				   ifAbsentPut: [ self utf8SizeOf: (self extensionTextForClassName: className package: package originalPath: aString) ])
		  writable: true
]

{ #category : 'private - renaming' }
PIFSBackend >> tonelFileNameFor: aMethod [
	"The file holding the method: its class's or trait's own, or that class's extension file in another package."

	| class |
	class := aMethod methodClass instanceSide.
	aMethod package = class package ifFalse: [ ^ class name , '.extension.st' ].
	^ self tonelFileNameForClass: class
]

{ #category : 'private - renaming' }
PIFSBackend >> tonelFileNameForClass: aClass [
	"The file Tonel keeps the class or trait in."

	^ aClass name , (aClass isTrait
		   ifTrue: [ '.trait.st' ]
		   ifFalse: [ '.class.st' ])
]

{ #category : 'private - listing' }
PIFSBackend >> tonelRootEntries [

	^ self packageNames collect: [ :each | self directoryNamed: each ]
]

{ #category : 'private - writing' }
PIFSBackend >> unloadMethodDefinition: methodDefinition [

	methodDefinition unload
]

{ #category : 'private - writing' }
PIFSBackend >> unloadMethodDefinitionsAbsentFrom: newMethodDefinitions in: oldMethodDefinitions [

	| newIdentities |
	newIdentities := newMethodDefinitions collect: [ :methodDefinition | self methodIdentityFor: methodDefinition ] as: Set.
	oldMethodDefinitions do: [ :methodDefinition |
		(newIdentities includes: (self methodIdentityFor: methodDefinition)) ifFalse: [ self unloadMethodDefinition: methodDefinition ] ]
]

{ #category : 'private - reading' }
PIFSBackend >> utf8SizeOf: aString [
	"The mount serves the text as UTF-8, so an entry reports its byte size."

	^ aString utf8Encoded size
]

{ #category : 'private - critiques' }
PIFSBackend >> validateBlockingCritiquesForMethodDefinitions: methodDefinitions originalPath: aString [

	self critiques validateBlockingForMethodDefinitions: methodDefinitions originalPath: aString
]

{ #category : 'private - writing' }
PIFSBackend >> validateClassDefinition: classDefinition className: className packageName: packageName originalPath: aString [

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
PIFSBackend >> validateCompilationOfMethodDefinitions: methodDefinitions text: textString originalPath: aString [
	"Once the class has the shape the file gives it, so that its variables resolve, and before any method is loaded: from Pharo 14, Monticello's loader installs a method with a compile error as one that signals the error when run, so the load alone would accept it."

	PIFSMethodChecksSkipped value ifTrue: [ ^ self ].
	methodDefinitions do: [ :each |
			each actualClass ifNotNil: [ :behavior |
					self
						signalErrorIn: (behavior compiler
								 source: each source;
								 permitFaulty: true;
								 permitUndeclared: true;
								 parse)
						of: each
						text: textString
						originalPath: aString ] ]
]

{ #category : 'private - writing' }
PIFSBackend >> validateExtensionDefinitions: definitions className: className packageName: packageName originalPath: aString [

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
PIFSBackend >> validateRenameOfClass: aClass changingPackagesNamed: packageNames originalPath: aString [
	"A rename writes into these packages too, so they meet what a write asks of its own: shown by the projection, and owned by a loaded repository when ownership is required, since an export is what keeps the checkout in line with the image."

	| unwritable |
	unwritable := Array streamContents: [ :stream |
			              packageNames asArray sorted do: [ :packageName |
				              self
					              ifPackageNamed: packageName
					              cannotBeWrittenDo: [ :reason | stream nextPut: packageName , ' (' , reason , ')' ] ] ].
	unwritable ifNotEmpty: [
			Error signal: 'Projection class rename of ' , aClass name , ' for ' , aString , ' would change packages it cannot write: '
				, (self commaSeparated: unwritable) ]
]

{ #category : 'private - writing' }
PIFSBackend >> validateSyntaxOfMethodDefinitions: methodDefinitions text: textString originalPath: aString [
	"Before anything is loaded, so that a method that does not parse never changes the class."

	| parserClass |
	PIFSMethodChecksSkipped value ifTrue: [ ^ self ].
	parserClass := OpalCompiler new parserClass.
	methodDefinitions do: [ :each |
			self
				signalErrorIn: (parserClass parseFaultyMethod: each source)
				of: each
				text: textString
				originalPath: aString ]
]

{ #category : 'private - writing' }
PIFSBackend >> withoutMethodChecksDo: aBlock [
	"For text the image rendered itself, which holds the methods it already has."

	^ PIFSMethodChecksSkipped value: true during: aBlock
]

{ #category : 'accessing' }
PIFSBackend >> write: textString at: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments isEmpty ifTrue: [ self signalUnsupportedWrite: aString ].
	segments first = 'tonel' ifTrue: [
			segments size > 1 ifTrue: [ self assertPackageIsVisibleNamed: segments second originalPath: aString ].
			^ self writeTonelSegments: segments allButFirst text: textString originalPath: aString ].
	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PIFSBackend >> writeResponseForPath: aString text: textString [

	self write: textString at: aString.
	^ Dictionary new
		  at: #diagnostics put: #(  );
		  yourself
]

{ #category : 'private - writing' }
PIFSBackend >> writeTonelClassRenameFromDefinition: classDefinition toClassName: className packageName: packageName originalPath: aString [

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
PIFSBackend >> writeTonelClassText: textString fileName: fileName packageName: packageName originalPath: aString [

	| class classDefinition classExists className definitions failureMessage methodDefinitions packageExists previousText |
	className := self classNameFromFileName: fileName suffix: '.class.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
	classDefinition := self classDefinitionFrom: definitions originalPath: aString.
	methodDefinitions := self methodDefinitionsFrom: definitions.
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
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	packageExists := PackageOrganizer default hasPackage: packageName.
	class := Smalltalk at: className asSymbol ifAbsent: [ nil ].
	classExists := class notNil.
	(classExists and: [ class package name asString ~= packageName ]) ifTrue: [ self signalClassExists: class originalPath: aString ].
	previousText := classExists ifTrue: [ self readTonelClassFileNamed: fileName packageName: packageName originalPath: aString ].
	[
		self makeTonelPackageDirectoryNamed: packageName originalPath: '/tonel/' , packageName.
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
		self exportPackageNamed: packageName fileNamed: fileName.
		self recordCritiquesForClassNamed: className packageName: packageName methodDefinitions: methodDefinitions ]
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
								self exportPackageNamed: packageName fileNamed: fileName ].
					packageExists ifFalse: [ self removePackageNamedIfEmpty: packageName ] ]
					on: Error
					do: [ :rollbackError |
							Error signal: 'Projection write failed and rollback failed. Write error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - writing' }
PIFSBackend >> writeTonelExtensionText: textString fileName: fileName packageName: packageName originalPath: aString [

	| className definitions failureMessage methodDefinitions packageExists previousText |
	className := self classNameFromFileName: fileName suffix: '.extension.st'.
	className ifNil: [ self signalUnsupportedWrite: aString ].
	self classNamed: className originalPath: aString.
	self assertRepositoryOwnsPackageNamed: packageName originalPath: aString.
	packageExists := PackageOrganizer default hasPackage: packageName.
	definitions := self parseTonelDefinitionsFrom: textString originalPath: aString.
	methodDefinitions := self methodDefinitionsFrom: definitions.
	methodDefinitions ifEmpty: [ self signalUnsupportedWrite: aString ].
	self
		validateExtensionDefinitions: methodDefinitions
		className: className
		packageName: packageName
		originalPath: aString.
	previousText := [ self readTonelExtensionFileNamed: fileName packageName: packageName originalPath: aString ]
		                on: Error
		                do: [ nil ].
	[
		self makeTonelPackageDirectoryNamed: packageName originalPath: '/tonel/' , packageName.
		previousText
			ifNil: [
					self
						applyNewExtensionTonelText: textString
						className: className
						packageName: packageName
						originalPath: aString ]
			ifNotNil: [
					self
						applyExtensionTonelText: textString
						replacing: previousText
						className: className
						packageName: packageName
						originalPath: aString ].
		self exportPackageNamed: packageName fileNamed: fileName.
		self recordCritiquesForExtensionClassNamed: className packageName: packageName methodDefinitions: methodDefinitions ]
		on: Error
		do: [ :error |
				failureMessage := error messageText ifNil: [ error asString ].
				[
					previousText
						ifNil: [
								self removeMethodDefinitions: methodDefinitions.
								self exportPackageNamed: packageName fileNamed: fileName ]
						ifNotNil: [
								self
									rollbackExtensionTonelText: previousText
									afterFailedWriteToClassName: className
									packageName: packageName
									originalPath: aString ].
					packageExists ifFalse: [ self removePackageNamedIfEmpty: packageName ] ]
					on: Error
					do: [ :rollbackError |
							Error signal:
								'Projection extension write failed and rollback failed. Write error: ' , failureMessage , '. Rollback error: '
								, (rollbackError messageText ifNil: [ rollbackError asString ]) ].
				Error signal: failureMessage ]
]

{ #category : 'private - writing' }
PIFSBackend >> writeTonelSegments: segments text: textString originalPath: aString [

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
