"
Renraku critiques for code edited through the projection, and the blocking-critique check a write has to pass.

It records nothing on its own: accepted writes to /tonel refresh the entries for the classes they touched, which is what the read-only /critiques surface serves. It knows about classes and method definitions, not about mount paths or package visibility, so the backend resolves those before asking.
"
Class {
	#name : 'PIFSCritiqueIndex',
	#superclass : 'Object',
	#instVars : [
		'entries'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> addSourceIntervalFromCritique: aCritique to: data [

	| interval sourceAnchor |
	sourceAnchor := aCritique sourceAnchor.
	sourceAnchor ifNil: [ ^ self ].
	interval := sourceAnchor interval.
	interval ifNil: [ ^ self ].
	data at: #interval put: {
			interval first.
			interval last }
]

{ #category : 'validating' }
PIFSCritiqueIndex >> blockingCritiqueSummaryFor: critiqueDictionaries [

	^ String streamContents: [ :stream |
			  critiqueDictionaries
				  do: [ :critique |
						  stream
							  nextPutAll: (critique at: #rule);
							  nextPutAll: ': ';
							  nextPutAll: (critique at: #title) ]
				  separatedBy: [ stream nextPutAll: '; ' ] ]
]

{ #category : 'validating' }
PIFSCritiqueIndex >> blockingCritiquesForMethodNode: aMethodNode [

	| critiques |
	critiques := OrderedCollection new.
	self blockingPreCompileRuleClasses do: [ :ruleClass |
			| rule |
			rule := ruleClass new.
			aMethodNode nodesDo: [ :node | rule check: node forCritiquesDo: [ :critique | critiques add: critique ] ] ].
	^ self critiqueDictionariesFor: critiques
]

{ #category : 'validating' }
PIFSCritiqueIndex >> blockingPreCompileRuleClasses [

	| ruleClass |
	ruleClass := Smalltalk globals at: #ReDeadBlockRule ifAbsent: [ nil ].
	ruleClass ifNil: [ ^ #(  ) ].
	^ { ruleClass }
]

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> critiqueDataForBehavior: aBehavior [

	^ self critiqueDictionariesFor: (ReCriticEngine critiquesOf: aBehavior)
]

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> critiqueDataForCompiledMethod: aCompiledMethod [

	^ self critiqueDictionariesFor: (ReCriticEngine critiquesOf: aCompiledMethod) , (ReCriticEngine nodeCritiquesOf: aCompiledMethod)
]

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> critiqueDictionariesFor: critiques [

	^ (critiques collect: [ :critique | self dictionaryForCritique: critique ] as: Array) sorted: [ :left :right |
			  (left at: #title ifAbsent: [ '' ]) = (right at: #title ifAbsent: [ '' ])
				  ifTrue: [ (left at: #rule ifAbsent: [ '' ]) <= (right at: #rule ifAbsent: [ '' ]) ]
				  ifFalse: [ (left at: #title ifAbsent: [ '' ]) <= (right at: #title ifAbsent: [ '' ]) ] ]
]

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> dictionaryForCritique: aCritique [

	| data rule |
	rule := aCritique rule.
	data := OrderedDictionary new.
	data at: #rule put: rule class name asString.
	rule severity ifNotNil: [ :severity | data at: #severity put: severity asString ].
	rule rationale ifNotNil: [ :hint | data at: #hint put: hint asString ].
	data at: #title put: aCritique title asString.
	self addSourceIntervalFromCritique: aCritique to: data.
	^ data
]

{ #category : 'accessing' }
PIFSCritiqueIndex >> entries [

	^ entries ifNil: [ entries := Dictionary new ]
]

{ #category : 'accessing' }
PIFSCritiqueIndex >> entryForPackageNamed: packageName classNamed: className ifAbsent: absentBlock [

	^ self entries at: packageName at: className ifAbsent: absentBlock
]

{ #category : 'accessing' }
PIFSCritiqueIndex >> entryForPackageNamed: packageName classNamed: className ifPresent: presentBlock ifAbsent: absentBlock [

	^ presentBlock value: (self entryForPackageNamed: packageName classNamed: className ifAbsent: [ ^ absentBlock value ])
]

{ #category : 'private - critiques' }
PIFSCritiqueIndex >> methodCritiqueDataForClass: aClass selector: aSelector [

	| data |
	data := OrderedDictionary new.
	(aClass includesSelector: aSelector) ifTrue: [ data at: #instance put: (self critiqueDataForCompiledMethod: aClass >> aSelector) ].
	(aClass classSide includesSelector: aSelector) ifTrue: [
		data at: #class put: (self critiqueDataForCompiledMethod: aClass classSide >> aSelector) ].
	data ifEmpty: [ Error signal: 'Critique selector not found: ' , aClass name asString , '>>' , aSelector asString ].
	^ data
]

{ #category : 'accessing' }
PIFSCritiqueIndex >> methodDataIn: classEntry forSelector: aSelector ifAbsent: absentBlock [

	^ classEntry at: #methods at: aSelector ifAbsent: absentBlock
]

{ #category : 'recording' }
PIFSCritiqueIndex >> recordExtensionForClass: aClass packageName: packageName methodDefinitions: methodDefinitions [

	self
		recordForClass: aClass
		packageName: packageName
		methodDefinitions: methodDefinitions
		includeClass: false
]

{ #category : 'recording' }
PIFSCritiqueIndex >> recordForClass: aClass packageName: packageName methodDefinitions: methodDefinitions [

	self
		recordForClass: aClass
		packageName: packageName
		methodDefinitions: methodDefinitions
		includeClass: true
]

{ #category : 'recording' }
PIFSCritiqueIndex >> recordForClass: aClass packageName: packageName methodDefinitions: methodDefinitions includeClass: includeClass [

	| classEntry methods packageEntry selectors |
	packageEntry := self entries at: packageName ifAbsentPut: [ Dictionary new ].
	classEntry := OrderedDictionary new.
	includeClass ifTrue: [
			| classCritiques |
			classCritiques := self critiqueDataForBehavior: aClass.
			classCritiques ifNotEmpty: [ classEntry at: #class put: classCritiques ] ].
	methods := Dictionary new.
	selectors := (methodDefinitions collect: [ :methodDefinition | methodDefinition selector ]) asSet asArray sorted.
	selectors do: [ :selector |
			| methodCritiques |
			methodCritiques := self methodCritiqueDataForClass: aClass selector: selector.
			(methodCritiques values anySatisfy: [ :critiques | critiques notEmpty ]) ifTrue: [ methods at: selector put: methodCritiques ] ].
	methods ifNotEmpty: [ classEntry at: #methods put: methods ].
	classEntry
		ifEmpty: [ packageEntry removeKey: aClass name asString ifAbsent: [ ] ]
		ifNotEmpty: [ packageEntry at: aClass name asString put: classEntry ].
	packageEntry ifEmpty: [ self entries removeKey: packageName ifAbsent: [ ] ]
]

{ #category : 'recording' }
PIFSCritiqueIndex >> removeForClassNamed: className packageName: packageName [

	(self entries at: packageName ifAbsent: [ ^ self ]) removeKey: className ifAbsent: [ ].
	(self entries at: packageName) ifEmpty: [ self entries removeKey: packageName ifAbsent: [ ] ]
]

{ #category : 'validating' }
PIFSCritiqueIndex >> validateBlockingForMethodDefinition: methodDefinition originalPath: aString [

	| critiques methodNode |
	methodNode := RBParser parseMethod: methodDefinition source.
	critiques := self blockingCritiquesForMethodNode: methodNode.
	critiques ifEmpty: [ ^ self ].
	Error signal:
		'Write blocked by critiques in ' , methodDefinition className asString , '>>' , methodDefinition selector asString , ' for '
		, aString , ': ' , (self blockingCritiqueSummaryFor: critiques)
]

{ #category : 'validating' }
PIFSCritiqueIndex >> validateBlockingForMethodDefinitions: methodDefinitions originalPath: aString [

	methodDefinitions do: [ :methodDefinition | self validateBlockingForMethodDefinition: methodDefinition originalPath: aString ]
]
