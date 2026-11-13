"
A Tonel parser that keeps where each method it reads begins in the text, and where its body begins, so that a refusal can point at a line of the file.

Tonel fails on a method body only at the end of the file, where its position says nothing: while a body is read, it also keeps where that body begins.
"
Class {
	#name : 'PIFSTonelParser',
	#superclass : 'TonelParser',
	#instVars : [
		'methodPosition',
		'bodyPosition',
		'sourcePositions',
		'readBodyPosition'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PIFSTonelParser >> bodyPosition [
	"Where the body being read begins in the text, nil when no body is being read."

	^ bodyPosition
]

{ #category : 'parsing' }
PIFSTonelParser >> method [
	"Where the method begins, kept until its definition is made."

	methodPosition := self position.
	^ super method
]

{ #category : 'parsing' }
PIFSTonelParser >> methodBody [
	"Where the body begins, at its [: kept while it is read, since Tonel finds a body unclosed only at the end of the file, then until the method's definition is made."

	| body |
	bodyPosition := self position.
	body := super methodBody.
	readBodyPosition := bodyPosition.
	bodyPosition := nil.
	^ body
]

{ #category : 'accessing' }
PIFSTonelParser >> methodPosition [
	"Where the method being read begins in the text, nil between two methods."

	^ methodPosition
]

{ #category : 'parsing' }
PIFSTonelParser >> newMethodDefinitionFrom: anArray [
	"Tonel makes the source of the selector followed by the body, the fifth of anArray: the body begins as many characters before the end of the source as it holds."

	| definition |
	definition := super newMethodDefinitionFrom: anArray.
	self sourcePositions add: definition -> {
			(self sourcePositionFrom: methodPosition).
			(readBodyPosition + 1).
			(definition source size - anArray fifth size + 1) }.
	methodPosition := nil.
	readBodyPosition := nil.
	^ definition
]

{ #category : 'accessing' }
PIFSTonelParser >> position [
	"The index in the text of the next character to read."

	^ stream position + 1
]

{ #category : 'private' }
PIFSTonelParser >> sourcePositionFrom: anIndex [
	"Tonel gives a method the source that begins with its selector: past the first >> after where the method begins, and past the separators after it, as #method reads them."

	| position text |
	text := stream originalContents.
	position := (text indexOfSubCollection: '>>' startingAt: anIndex) + 2.
	[ position <= text size and: [ (text at: position) isSeparator ] ] whileTrue: [ position := position + 1 ].
	^ position
]

{ #category : 'accessing' }
PIFSTonelParser >> sourcePositions [
	"Each method definition read, with where its source begins in the text, where its body begins in the text, past its [, and where its body begins in its source."

	^ sourcePositions ifNil: [ sourcePositions := OrderedCollection new ]
]
