Class {
	#name : 'PharoImageFSMonticelloDefinitionLoader',
	#superclass : 'Object',
	#category : 'PharoImageFS-Monticello-14Plus',
	#package : 'PharoImageFS-Monticello-14Plus'
}

{ #category : 'evaluating' }
PharoImageFSMonticelloDefinitionLoader class >> activeDuring: aBlock [

	^ PharoImageFSMonticelloCurrentLoader value: MCPackageLoader new during: aBlock
]

{ #category : 'loading' }
PharoImageFSMonticelloDefinitionLoader class >> loadDefinition: aDefinition [

	aDefinition loadWithLoader: PharoImageFSMonticelloCurrentLoader value
]
