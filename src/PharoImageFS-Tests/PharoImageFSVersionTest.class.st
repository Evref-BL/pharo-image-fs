Class {
	#name : 'PharoImageFSVersionTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'tests' }
PharoImageFSVersionTest >> testDaemonArchiveNameUsesCurrentPlatform [

	self
		assert: PharoImageFSVersion daemonArchiveName
		equals: PharoImageFSVersion daemonAssetName , '.zip'
]

{ #category : 'tests' }
PharoImageFSVersionTest >> testDaemonReleaseURLUsesCurrentVersionAndAsset [

	self
		assert: PharoImageFSVersion daemonReleaseURL
		equals:
			PharoImageFSVersion daemonRepositoryURL , '/releases/download/' , PharoImageFSVersion releaseTag , '/'
			, PharoImageFSVersion daemonArchiveName
]

{ #category : 'tests' }
PharoImageFSVersionTest >> testReleaseTagUsesCurrentVersion [

	self assert: PharoImageFSVersion releaseTag equals: 'v' , PharoImageFSVersion current
]
