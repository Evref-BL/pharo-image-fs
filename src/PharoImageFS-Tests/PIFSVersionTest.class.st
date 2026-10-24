Class {
	#name : 'PIFSVersionTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'tests' }
PIFSVersionTest >> testCurrentIsAReleaseVersion [
	"The release workflow reads this method with a SemVer regex and refuses to release anything else."

	| parts |
	parts := PIFSVersion current substrings: '.'.
	self assert: parts size equals: 3.
	parts do: [ :each |
			self assert: each isEmpty not.
			self assert: (each allSatisfy: [ :character | character isDigit ]) ]
]

{ #category : 'tests' }
PIFSVersionTest >> testDaemonApiAndWebURLsNameTheSameRepository [

	self assert: (PIFSVersion daemonRepositoryURL endsWith: 'Evref-BL/pharo-image-fs-daemon').
	self assert: (PIFSVersion daemonRepositoryApiURL endsWith: 'Evref-BL/pharo-image-fs-daemon')
]

{ #category : 'tests' }
PIFSVersionTest >> testDaemonArchiveNameUsesCurrentPlatform [

	self
		assert: PIFSVersion daemonArchiveName
		equals: PIFSVersion daemonAssetName , '.zip'
]

{ #category : 'tests' }
PIFSVersionTest >> testDaemonReleaseApiURLAddressesTheCurrentReleaseTag [

	self assert: (PIFSVersion daemonReleaseApiURL endsWith: '/releases/tags/' , PIFSVersion releaseTag)
]

{ #category : 'tests' }
PIFSVersionTest >> testDaemonReleaseApiURLIsOnTheApiHost [
	"github.com answers a release download with headers longer than Zn will read, so the asset is resolved through the API host instead."

	self assert: (PIFSVersion daemonReleaseApiURL beginsWith: 'https://api.github.com/').
	self deny: (PIFSVersion daemonReleaseApiURL beginsWith: 'https://github.com/')
]

{ #category : 'tests' }
PIFSVersionTest >> testDaemonReleaseURLUsesCurrentVersionAndAsset [

	self
		assert: PIFSVersion daemonReleaseURL
		equals:
			PIFSVersion daemonRepositoryURL , '/releases/download/' , PIFSVersion releaseTag , '/'
			, PIFSVersion daemonArchiveName
]

{ #category : 'tests' }
PIFSVersionTest >> testReleaseTagUsesCurrentVersion [

	self assert: PIFSVersion releaseTag equals: 'v' , PIFSVersion current
]
