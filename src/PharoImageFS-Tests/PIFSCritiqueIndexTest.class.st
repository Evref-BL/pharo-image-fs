Class {
	#name : 'PIFSCritiqueIndexTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'private' }
PIFSCritiqueIndexTest >> createTargetClass [

	| class |
	class := (Object << self targetClassName asSymbol)
		         package: self packageName;
		         install.
	class
		compile: 'manyArguments: one second: two third: three fourth: four fifth: five

	^ one'
		classified: 'accessing'.
	^ class
]

{ #category : 'private' }
PIFSCritiqueIndexTest >> methodDefinitionsFor: aClass selector: aSelector [

	^ { (aClass >> aSelector) asRingDefinition asMCMethodDefinition }
]

{ #category : 'private' }
PIFSCritiqueIndexTest >> packageName [

	^ 'PharoImageFS-Tests'
]

{ #category : 'private' }
PIFSCritiqueIndexTest >> removeTargetClass [

	(Smalltalk globals at: self targetClassName asSymbol ifAbsent: [ ^ self ]) removeFromSystem
]

{ #category : 'private' }
PIFSCritiqueIndexTest >> targetClassName [

	^ 'PIFS' , 'CritiqueIndexTarget'
]

{ #category : 'running' }
PIFSCritiqueIndexTest >> tearDown [

	[ self removeTargetClass ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testBlockingCritiqueSummaryNamesRuleAndTitle [

	| summary |
	summary := PIFSCritiqueIndex new blockingCritiqueSummaryFor: {
			           (Dictionary new
				            at: #rule put: 'FirstRule';
				            at: #title put: 'first problem';
				            yourself).
			           (Dictionary new
				            at: #rule put: 'SecondRule';
				            at: #title put: 'second problem';
				            yourself) }.
	self assert: summary equals: 'FirstRule: first problem; SecondRule: second problem'
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testBlockingCritiquesFindDeadBlocks [

	| critiques |
	critiques := PIFSCritiqueIndex new blockingCritiquesForMethodNode: (RBParser parseMethod: 'deadBlock

	[ 1 + 1 ].
	^ 2').
	self assert: (critiques collect: [ :each | each at: #rule ]) equals: #( 'ReDeadBlockRule' )
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testBlockingCritiquesIgnoreCleanMethods [

	self assert: (PIFSCritiqueIndex new blockingCritiquesForMethodNode: (RBParser parseMethod: 'clean

	^ 1 + 1')) isEmpty
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testEntriesStartEmpty [

	self assert: PIFSCritiqueIndex new entries isEmpty
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testRecordKeepsCritiquesForTheRecordedClass [

	| index class selector |
	class := self createTargetClass.
	selector := #manyArguments:second:third:fourth:fifth:.
	index := PIFSCritiqueIndex new.
	index
		recordForClass: class
		packageName: self packageName
		methodDefinitions: (self methodDefinitionsFor: class selector: selector).
	index
		entryForPackageNamed: self packageName
		classNamed: self targetClassName
		ifPresent: [ :entry |
				| data |
				data := index methodDataIn: entry forSelector: selector ifAbsent: [ self fail: 'No critiques recorded for ' , selector ].
				self assert: ((data at: #instance) first at: #rule) equals: 'ReExcessiveArgumentsRule' ]
		ifAbsent: [ self fail: 'No entry recorded for ' , self targetClassName ]
]

{ #category : 'tests' }
PIFSCritiqueIndexTest >> testRemoveForClassNamedDropsThePackageWhenItEmpties [

	| index class |
	class := self createTargetClass.
	index := PIFSCritiqueIndex new.
	index
		recordForClass: class
		packageName: self packageName
		methodDefinitions: (self methodDefinitionsFor: class selector: #manyArguments:second:third:fourth:fifth:).
	self deny: index entries isEmpty.
	index removeForClassNamed: self targetClassName packageName: self packageName.
	self assert: index entries isEmpty
]
