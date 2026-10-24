Class {
	#name : 'PIFSConfigurationTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'tests' }
PIFSConfigurationTest >> testPackagePrefixesAreKeptAsArrays [

	| configuration |
	configuration := PIFSConfiguration new
		                 includedPackagePrefixes: (OrderedCollection with: 'MyProject');
		                 excludedPackagePrefixes: (OrderedCollection with: 'MyProject-Legacy');
		                 yourself.
	self assert: configuration includedPackagePrefixes equals: #( 'MyProject' ).
	self assert: configuration excludedPackagePrefixes equals: #( 'MyProject-Legacy' )
]

{ #category : 'tests' }
PIFSConfigurationTest >> testSettingsAnswerWhatWasSet [

	| configuration path |
	path := FileLocator temp / 'pifs-configuration-test'.
	configuration := PIFSConfiguration new
		                 mountPath: path;
		                 mountName: 'projection';
		                 port: 9013;
		                 requiresRepositoryOwnershipForWrites: false;
		                 formatsWrittenMethods: true;
		                 yourself.
	self assert: configuration mountPath equals: path.
	self assert: configuration mountName equals: 'projection'.
	self assert: configuration port equals: 9013.
	self deny: configuration requiresRepositoryOwnershipForWrites.
	self assert: configuration formatsWrittenMethods
]

{ #category : 'tests' }
PIFSConfigurationTest >> testUnsetMountSettingsAnswerTheServerDefaults [

	| configuration |
	configuration := PIFSConfiguration new.
	self assert: configuration mountPath equals: PIFSServer defaultMountPath.
	self assert: configuration mountName equals: PIFSServer defaultMountName
]

{ #category : 'tests' }
PIFSConfigurationTest >> testUnsetSettingsAnswerTheShippedPolicy [

	| configuration |
	configuration := PIFSConfiguration new.
	self assert: configuration requiresRepositoryOwnershipForWrites.
	self assert: configuration includedPackagePrefixes isEmpty.
	self assert: configuration excludedPackagePrefixes isEmpty.
	self assert: configuration port equals: 0
]
