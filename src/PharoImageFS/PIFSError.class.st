"
A failure PIFS saw coming, with a code that names it in one word, so that a caller tells failures apart without reading their text. The text says what happened, for whoever reads it.
"
Class {
	#name : 'PIFSError',
	#superclass : 'Error',
	#instVars : [
		'errorCode'
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

{ #category : 'accessing' }
PIFSError >> errorCode [
	"Which failure this is, as an UpperCamelCase word saying what went wrong, such as MountTimedOut."

	^ errorCode
]

{ #category : 'accessing' }
PIFSError >> errorCode: aString [

	errorCode := aString
]
