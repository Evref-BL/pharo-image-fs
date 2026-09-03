Class {
	#name : 'PIFSVersionTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'tests' }
PIFSVersionTest >> testDaemonArchiveNameUsesCurrentPlatform [

	self
		assert: PIFSVersion daemonArchiveName
		equals: PIFSVersion daemonAssetName , '.zip'
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
