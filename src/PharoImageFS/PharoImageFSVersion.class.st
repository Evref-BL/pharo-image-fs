Class {
	#name : 'PharoImageFSVersion',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PharoImageFSVersion class >> current [

	^ '0.2.2'
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonArchiveName [

	^ self daemonAssetName , '.zip'
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonAssetArchitecture [

	| architecture |
	architecture := Smalltalk vm getSystemAttribute: 1003.
	architecture = 'arm64' ifTrue: [ ^ 'arm64' ].
	architecture = 'x86_64' ifTrue: [ ^ 'amd64' ].
	architecture = 'amd64' ifTrue: [ ^ 'amd64' ].
	Error signal: 'Unsupported daemon architecture: ' , architecture
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonAssetName [

	^ 'pharo-image-fs-daemon-' , self daemonAssetOperatingSystem , '-' , self daemonAssetArchitecture
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonAssetOperatingSystem [

	OSPlatform current isMacOS ifTrue: [ ^ 'darwin' ].
	Error signal: 'Unsupported daemon operating system: ' , OSPlatform current class name
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonReleaseURL [

	^ self daemonRepositoryURL , '/releases/download/' , self releaseTag , '/' , self daemonArchiveName
]

{ #category : 'accessing' }
PharoImageFSVersion class >> daemonRepositoryURL [

	^ 'https://github.com/Evref-BL/pharo-image-fs-daemon'
]

{ #category : 'accessing' }
PharoImageFSVersion class >> releaseTag [

	^ 'v' , self current
]
