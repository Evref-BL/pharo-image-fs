Class {
	#name : 'PharoImageFSCompatibility',
	#superclass : 'Object',
	#category : 'PharoImageFS-Compatibility-Pre14',
	#package : 'PharoImageFS-Compatibility-Pre14'
}

{ #category : 'evaluating' }
PharoImageFSCompatibility class >> activeDuring: aBlock [

	^ aBlock value
]

{ #category : 'loading' }
PharoImageFSCompatibility class >> loadMonticelloDefinition: aDefinition [

	aDefinition load
]

{ #category : 'moving' }
PharoImageFSCompatibility class >> moveClassNamed: className toPackage: packageName [

	(RBMoveClassTransformation move: className toPackage: packageName) execute
]
