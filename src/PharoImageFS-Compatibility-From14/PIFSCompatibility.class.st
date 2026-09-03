Class {
	#name : 'PIFSCompatibility',
	#superclass : 'Object',
	#category : 'PharoImageFS-Compatibility-From14',
	#package : 'PharoImageFS-Compatibility-From14'
}

{ #category : 'evaluating' }
PIFSCompatibility class >> activeDuring: aBlock [

	^ PIFSCurrentLoader value: MCPackageLoader new during: aBlock
]

{ #category : 'loading' }
PIFSCompatibility class >> loadMonticelloDefinition: aDefinition [

	aDefinition loadWithLoader: PIFSCurrentLoader value
]

{ #category : 'moving' }
PIFSCompatibility class >> moveClassNamed: className toPackage: packageName [

	| class |
	class := Smalltalk at: className asSymbol.
	((class packageOrganizer ensurePackage: packageName) ensureTag: nil) addClass: class
]
