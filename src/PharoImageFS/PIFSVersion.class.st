Class {
	#name : 'PIFSVersion',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PIFSVersion class >> current [

	^ '0.12.1'
]

{ #category : 'accessing' }
PIFSVersion class >> daemonArchiveName [

	^ self daemonAssetName , '.zip'
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetArchitecture [

	^ self daemonAssetArchitectureFor: (Smalltalk vm getSystemAttribute: 1003)
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetArchitectureFor: aString [
	"The daemon's name for the processor the VM names aString: a Linux arm64 VM says aarch64, a macOS one arm64."

	(#( 'arm64' 'aarch64' ) includes: aString) ifTrue: [ ^ 'arm64' ].
	(#( 'x86_64' 'amd64' ) includes: aString) ifTrue: [ ^ 'amd64' ].
	Error signal: 'Unsupported daemon architecture: ' , aString
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetName [

	^ 'pharo-image-fs-daemon-' , self daemonAssetOperatingSystem , '-' , self daemonAssetArchitecture
]

{ #category : 'accessing' }
PIFSVersion class >> daemonAssetOperatingSystem [

	OSPlatform current isMacOS ifTrue: [ ^ 'darwin' ].
	OSPlatform current isLinux ifTrue: [ ^ 'linux' ].
	Error signal: 'Unsupported daemon operating system: ' , OSPlatform current class name
]

{ #category : 'accessing' }
PIFSVersion class >> daemonReleaseApiURL [

	^ self daemonRepositoryApiURL , '/releases/tags/' , self releaseTag
]

{ #category : 'accessing' }
PIFSVersion class >> daemonReleaseURL [

	^ self daemonRepositoryURL , '/releases/download/' , self releaseTag , '/' , self daemonArchiveName
]

{ #category : 'accessing' }
PIFSVersion class >> daemonRepositoryApiURL [

	^ self daemonRepositoryURL copyReplaceAll: 'https://github.com/' with: 'https://api.github.com/repos/'
]

{ #category : 'accessing' }
PIFSVersion class >> daemonRepositoryURL [

	^ 'https://github.com/Evref-BL/pharo-image-fs-daemon'
]

{ #category : 'accessing' }
PIFSVersion class >> releaseTag [

	^ 'v' , self current
]
