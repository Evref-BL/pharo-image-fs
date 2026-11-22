"
A failure PIFS saw coming, with a code that names it in one word, so that a caller tells failures apart without reading their text. The text says what happened, for whoever reads it, and the details hold what a program would otherwise have to read out of it, such as where the daemon's log is.
"
Class {
	#name : 'PIFSError',
	#superclass : 'Error',
	#instVars : [
		'errorCode',
		'details'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'signalling' }
PIFSError class >> signal: aText errorCode: anErrorCode [

	^ self new
		  errorCode: anErrorCode;
		  signal: aText
]

{ #category : 'signalling' }
PIFSError class >> signal: aText errorCode: anErrorCode details: aDictionary [

	^ self new
		  errorCode: anErrorCode;
		  details: aDictionary;
		  signal: aText
]

{ #category : 'accessing' }
PIFSError >> details [
	"What a program needs of the failure besides its code, by name."

	^ details ifNil: [ Dictionary new ]
]

{ #category : 'accessing' }
PIFSError >> details: aDictionary [

	details := aDictionary
]

{ #category : 'accessing' }
PIFSError >> errorCode [
	"Which failure this is, as an UpperCamelCase word saying what went wrong, such as MountTimedOut."

	^ errorCode
]

{ #category : 'accessing' }
PIFSError >> errorCode: aString [

	errorCode := aString
]
