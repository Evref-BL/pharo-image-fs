Class {
	#name : 'PIFSCompatibility',
	#superclass : 'Object',
	#category : 'PharoImageFS-Compatibility-Pre14',
	#package : 'PharoImageFS-Compatibility-Pre14'
}

{ #category : 'evaluating' }
PIFSCompatibility class >> activeDuring: aBlock [

	^ aBlock value
]

{ #category : 'loading' }
PIFSCompatibility class >> loadMonticelloDefinition: aDefinition [

	aDefinition load
]

{ #category : 'moving' }
PIFSCompatibility class >> moveClassNamed: className toPackage: packageName [

	(RBMoveClassTransformation move: className toPackage: packageName) execute
]
