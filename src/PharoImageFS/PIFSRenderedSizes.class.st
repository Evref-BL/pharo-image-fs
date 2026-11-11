"
I remember the byte size of each projected Tonel file, keyed by its path, beside a fingerprint of what the file is rendered from.

A stat must report a file's exact size, because the mount reads no further than it, and rendering a class to measure it costs milliseconds while its fingerprint costs microseconds. A size is reused only while the fingerprint is equal, so the fingerprint must hold every input the rendering reads: one it missed would leave a stale size that truncates or pads what the mount reads. A read renders anyway, and records the size afresh.

Requests arrive on several server processes at once, so the table is guarded.
"
Class {
	#name : 'PIFSRenderedSizes',
	#superclass : 'Object',
	#instVars : [
		'entries',
		'mutex'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PIFSRenderedSizes >> at: aPath fingerprint: aFingerprint put: anInteger [

	mutex critical: [ entries at: aPath put: aFingerprint -> anInteger ]
]

{ #category : 'initialization' }
PIFSRenderedSizes >> initialize [

	super initialize.
	entries := Dictionary new.
	mutex := Mutex new
]

{ #category : 'accessing' }
PIFSRenderedSizes >> sizeAt: aPath fingerprint: aFingerprint ifAbsentPut: aBlock [
	"The size remembered for this fingerprint, or the one aBlock measures, which is then remembered. aBlock runs outside the guard, so a slow render does not hold up other requests."

	| size |
	mutex critical: [ entries at: aPath ifPresent: [ :entry | entry key = aFingerprint ifTrue: [ ^ entry value ] ] ].
	size := aBlock value.
	self at: aPath fingerprint: aFingerprint put: size.
	^ size
]
