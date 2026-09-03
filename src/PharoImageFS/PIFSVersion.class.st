Class {
	#name : 'PIFSVersion',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PIFSVersion class >> current [

	^ '0.2.4'
]

{ #category : 'accessing' }
PIFSVersion class >> daemonArchiveName [

	^ self daemonAssetName , '.zip'
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetArchitecture [

	| architecture |
	architecture := Smalltalk vm getSystemAttribute: 1003.
	architecture = 'arm64' ifTrue: [ ^ 'arm64' ].
	architecture = 'x86_64' ifTrue: [ ^ 'amd64' ].
	architecture = 'amd64' ifTrue: [ ^ 'amd64' ].
	Error signal: 'Unsupported daemon architecture: ' , architecture
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetName [

	^ 'pharo-image-fs-daemon-' , self daemonAssetOperatingSystem , '-' , self daemonAssetArchitecture
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetOperatingSystem [

	OSPlatform current isMacOS ifTrue: [ ^ 'darwin' ].
	Error signal: 'Unsupported daemon operating system: ' , OSPlatform current class name
]

{ #category : 'accessing' }
PIFSVersion class >> daemonReleaseURL [

	^ self daemonRepositoryURL , '/releases/download/' , self releaseTag , '/' , self daemonArchiveName
]

{ #category : 'accessing' }
PIFSVersion class >> daemonRepositoryURL [

	^ 'https://github.com/Evref-BL/pharo-image-fs-daemon'
]

{ #category : 'accessing' }
PIFSVersion class >> releaseTag [

	^ 'v' , self current
]
