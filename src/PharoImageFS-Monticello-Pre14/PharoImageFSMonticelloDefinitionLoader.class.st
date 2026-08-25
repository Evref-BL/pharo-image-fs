Class {
	#name : 'PharoImageFSMonticelloDefinitionLoader',
	#superclass : 'Object',
	#category : 'PharoImageFS-Monticello-Pre14',
	#package : 'PharoImageFS-Monticello-Pre14'
}

{ #category : 'evaluating' }
PharoImageFSMonticelloDefinitionLoader class >> activeDuring: aBlock [

	^ aBlock value
]

{ #category : 'loading' }
PharoImageFSMonticelloDefinitionLoader class >> loadDefinition: aDefinition [

	aDefinition load
]
