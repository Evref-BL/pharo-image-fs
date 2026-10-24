"
Formatter double answering LF-terminated source. A package manifest can answer it so a test can check that the projection restores the image line ending after formatting, whatever the package formatter emits.
"
Class {
	#name : 'PIFSUnixLineEndingFormatterTestDouble',
	#superclass : 'Object',
	#category : 'PharoImageFS-Tests-Resources',
	#package : 'PharoImageFS-Tests-Resources'
}

{ #category : 'formatting' }
PIFSUnixLineEndingFormatterTestDouble >> format: aNode [

	^ (EFFormatter new format: aNode) withLineEndings: String lf
]
