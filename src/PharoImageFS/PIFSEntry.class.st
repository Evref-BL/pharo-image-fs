"
A file or directory entry exposed by the pharo-image-fs projection protocol.
"
Class {
	#name : 'PIFSEntry',
	#superclass : 'Object',
	#instVars : [
		'name',
		'kind',
		'size',
		'writable',
		'target'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'instance creation' }
PIFSEntry class >> directoryNamed: aString [

	^ self
		  name: aString
		  kind: 'directory'
		  size: 0
		  writable: false
]

{ #category : 'instance creation' }
PIFSEntry class >> fileNamed: aString size: anInteger writable: aBoolean [

	^ self
		  name: aString
		  kind: 'file'
		  size: anInteger
		  writable: aBoolean
]

{ #category : 'instance creation' }
PIFSEntry class >> name: nameString kind: kindString size: anInteger writable: aBoolean [

	^ self new
		  name: nameString;
		  kind: kindString;
		  size: anInteger;
		  writable: aBoolean;
		  yourself
]

{ #category : 'instance creation' }
PIFSEntry class >> symlinkNamed: aString target: targetString [

	^ (self
		   name: aString
		   kind: 'symlink'
		   size: targetString size
		   writable: false)
		  target: targetString;
		  yourself
]

{ #category : 'converting' }
PIFSEntry >> asDictionary [

	| dictionary |
	dictionary := OrderedDictionary new.
	dictionary
		at: #name put: name;
		at: #kind put: kind.
	size = 0 ifFalse: [ dictionary at: #size put: size ].
	writable ifTrue: [ dictionary at: #writable put: true ].
	target ifNotNil: [ dictionary at: #target put: target ].
	^ dictionary
]

{ #category : 'testing' }
PIFSEntry >> isDirectory [

	^ kind = 'directory'
]

{ #category : 'testing' }
PIFSEntry >> isFile [

	^ kind = 'file'
]

{ #category : 'testing' }
PIFSEntry >> isSymlink [

	^ kind = 'symlink'
]

{ #category : 'accessing' }
PIFSEntry >> kind [

	^ kind
]

{ #category : 'accessing' }
PIFSEntry >> kind: aString [

	kind := aString
]

{ #category : 'accessing' }
PIFSEntry >> name [

	^ name
]

{ #category : 'accessing' }
PIFSEntry >> name: aString [

	name := aString
]

{ #category : 'accessing' }
PIFSEntry >> size [

	^ size
]

{ #category : 'accessing' }
PIFSEntry >> size: anInteger [

	size := anInteger
]

{ #category : 'accessing' }
PIFSEntry >> target [

	^ target
]

{ #category : 'accessing' }
PIFSEntry >> target: aString [

	target := aString
]

{ #category : 'accessing' }
PIFSEntry >> writable [

	^ writable
]

{ #category : 'accessing' }
PIFSEntry >> writable: aBoolean [

	writable := aBoolean
]
