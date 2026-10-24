"
Everything a projection is started with: where it mounts, on which port, and the write policy its backend applies.

Settings left unset answer their default, so a configuration can be built by naming only what differs. Handing one to PIFSServer applies it before the mount exists, which post-start setters on the backend cannot do.
"
Class {
	#name : 'PIFSConfiguration',
	#superclass : 'Object',
	#instVars : [
		'mountName',
		'mountPath',
		'port',
		'requiresRepositoryOwnershipForWrites',
		'excludedPackagePrefixes',
		'includedPackagePrefixes',
		'formatsWrittenMethods'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'defaults' }
PIFSConfiguration class >> default [

	^ self new
]

{ #category : 'defaults' }
PIFSConfiguration class >> formatsWrittenMethodsByDefault [

	| value |
	value := OSEnvironment current at: 'PHARO_IMAGE_FS_FORMAT' ifAbsent: [ ^ false ].
	value ifEmpty: [ ^ false ].
	^ (#( '0' 'false' 'no' 'off' ) includes: value asLowercase) not
]

{ #category : 'accessing' }
PIFSConfiguration >> excludedPackagePrefixes [

	^ excludedPackagePrefixes ifNil: [ #(  ) ]
]

{ #category : 'accessing' }
PIFSConfiguration >> excludedPackagePrefixes: prefixStrings [

	excludedPackagePrefixes := prefixStrings asArray
]

{ #category : 'accessing' }
PIFSConfiguration >> formatsWrittenMethods [

	^ formatsWrittenMethods ifNil: [ self class formatsWrittenMethodsByDefault ]
]

{ #category : 'accessing' }
PIFSConfiguration >> formatsWrittenMethods: aBoolean [

	formatsWrittenMethods := aBoolean
]

{ #category : 'accessing' }
PIFSConfiguration >> includedPackagePrefixes [

	^ includedPackagePrefixes ifNil: [ #(  ) ]
]

{ #category : 'accessing' }
PIFSConfiguration >> includedPackagePrefixes: prefixStrings [

	includedPackagePrefixes := prefixStrings asArray
]

{ #category : 'accessing' }
PIFSConfiguration >> mountName [

	^ mountName ifNil: [ PIFSServer defaultMountName ]
]

{ #category : 'accessing' }
PIFSConfiguration >> mountName: aString [

	mountName := aString
]

{ #category : 'accessing' }
PIFSConfiguration >> mountPath [

	^ mountPath ifNil: [ PIFSServer defaultMountPath ]
]

{ #category : 'accessing' }
PIFSConfiguration >> mountPath: aFileReference [

	mountPath := aFileReference
]

{ #category : 'accessing' }
PIFSConfiguration >> port [

	^ port ifNil: [ 0 ]
]

{ #category : 'accessing' }
PIFSConfiguration >> port: anInteger [

	port := anInteger
]

{ #category : 'accessing' }
PIFSConfiguration >> requiresRepositoryOwnershipForWrites [

	^ requiresRepositoryOwnershipForWrites ifNil: [ true ]
]

{ #category : 'accessing' }
PIFSConfiguration >> requiresRepositoryOwnershipForWrites: aBoolean [

	requiresRepositoryOwnershipForWrites := aBoolean
]
