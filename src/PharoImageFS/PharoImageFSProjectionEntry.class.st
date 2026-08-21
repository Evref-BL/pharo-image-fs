"
A file or directory entry exposed by the pharo-image-fs projection protocol.
"
Class {
	#name : 'PharoImageFSProjectionEntry',
	#superclass : 'Object',
	#instVars : [
		'name',
		'kind',
		'size',
		'writable'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'instance creation' }
PharoImageFSProjectionEntry class >> directoryNamed: aString [

	^ self
		  name: aString
		  kind: 'directory'
		  size: 0
		  writable: false
]

{ #category : 'instance creation' }
PharoImageFSProjectionEntry class >> fileNamed: aString size: anInteger writable: aBoolean [

	^ self
		  name: aString
		  kind: 'file'
		  size: anInteger
		  writable: aBoolean
]

{ #category : 'instance creation' }
PharoImageFSProjectionEntry class >> name: nameString kind: kindString size: anInteger writable: aBoolean [

	^ self new
		  name: nameString;
		  kind: kindString;
		  size: anInteger;
		  writable: aBoolean;
		  yourself
]

{ #category : 'converting' }
PharoImageFSProjectionEntry >> asDictionary [

	| dictionary |
	dictionary := OrderedDictionary new.
	dictionary
		at: #name put: name;
		at: #kind put: kind.
	size = 0 ifFalse: [ dictionary at: #size put: size ].
	writable ifTrue: [ dictionary at: #writable put: true ].
	^ dictionary
]

{ #category : 'testing' }
PharoImageFSProjectionEntry >> isDirectory [

	^ kind = 'directory'
]

{ #category : 'testing' }
PharoImageFSProjectionEntry >> isFile [

	^ kind = 'file'
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> kind [

	^ kind
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> kind: aString [

	kind := aString
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> name [

	^ name
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> name: aString [

	name := aString
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> size [

	^ size
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> size: anInteger [

	size := anInteger
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> writable [

	^ writable
]

{ #category : 'accessing' }
PharoImageFSProjectionEntry >> writable: aBoolean [

	writable := aBoolean
]
