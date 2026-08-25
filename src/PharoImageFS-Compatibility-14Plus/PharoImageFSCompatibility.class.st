Class {
	#name : 'PharoImageFSCompatibility',
	#superclass : 'Object',
	#category : 'PharoImageFS-Compatibility-14Plus',
	#package : 'PharoImageFS-Compatibility-14Plus'
}

{ #category : 'evaluating' }
PharoImageFSCompatibility class >> activeDuring: aBlock [

	^ PharoImageFSCompatibilityCurrentLoader value: MCPackageLoader new during: aBlock
]

{ #category : 'loading' }
PharoImageFSCompatibility class >> loadMonticelloDefinition: aDefinition [

	aDefinition loadWithLoader: PharoImageFSCompatibilityCurrentLoader value
]

{ #category : 'moving' }
PharoImageFSCompatibility class >> moveClassNamed: className toPackage: packageName [

	| class |
	class := Smalltalk at: className asSymbol.
	((class packageOrganizer ensurePackage: packageName) ensureTag: nil) addClass: class
]
