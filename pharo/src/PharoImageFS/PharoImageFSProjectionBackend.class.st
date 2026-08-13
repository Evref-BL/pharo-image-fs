"
Image-side projection backend for pharo-image-fs. It owns Pharo semantics and answers the narrow filesystem projection protocol used by the Go mount daemon.
"
Class {
	#name : 'PharoImageFSProjectionBackend',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

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

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> critiqueRootEntries [

	^ #(  )
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> directoryNamed: aString [

	^ PharoImageFSProjectionEntry directoryNamed: aString
]

{ #category : 'private - entries' }
PharoImageFSProjectionBackend >> entryNamed: aString in: entries ifAbsent: absentBlock [

	^ entries detect: [ :each | each name = aString ] ifNone: absentBlock
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

	segments isEmpty ifTrue: [ ^ self critiqueRootEntries ].
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

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNamed: aString ifAbsent: absentBlock [

	^ PackageOrganizer default packageNamed: aString ifAbsent: absentBlock
]

{ #category : 'private - packages' }
PharoImageFSProjectionBackend >> packageNames [

	^ (PackageOrganizer default packages collect: [ :each | each name asString ]) asArray sorted
]

{ #category : 'private - paths' }
PharoImageFSProjectionBackend >> pathSegmentsFor: aString [

	^ ($/ split: aString) reject: [ :each | each isEmpty ]
]

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> read: aString [

	| segments |
	segments := self pathSegmentsFor: aString.
	segments first = 'tonel' ifTrue: [ ^ self readTonelSegments: segments allButFirst originalPath: aString ].
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

{ #category : 'private - listing' }
PharoImageFSProjectionBackend >> rootEntries [

	^ {
		  (self directoryNamed: 'tonel').
		  (self directoryNamed: 'critiques') }
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
PharoImageFSProjectionBackend >> statCritiqueSegments: segments originalPath: aString [

	segments isEmpty ifTrue: [ ^ self directoryNamed: 'critiques' ].
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

{ #category : 'accessing' }
PharoImageFSProjectionBackend >> write: textString at: aString [

	self signalUnsupportedWrite: aString
]

{ #category : 'protocol responses' }
PharoImageFSProjectionBackend >> writeResponseForPath: aString text: textString [

	self write: textString at: aString.
	^ Dictionary new
		  at: #diagnostics put: #(  );
		  yourself
]
