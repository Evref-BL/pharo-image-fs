"
The loaded Iceberg repositories, as the projection needs them: which one owns a package, whether it has a checkout to export into, and the Tonel export itself.

It is where Iceberg and Monticello knowledge lives, so the backend holds none. It decides nothing about policy: whether a write requires an owning repository is the backend's configuration, not a property of the repositories.
"
Class {
	#name : 'PIFSRepositories',
	#superclass : 'Object',
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'accessing' }
PIFSRepositories >> all [

	^ IceRepository repositories
]

{ #category : 'accessing' }
PIFSRepositories >> canExportSourceFor: aRepository [

	| directory |
	directory := self directoryFor: aRepository.
	^ directory notNil and: [ directory exists ]
]

{ #category : 'accessing' }
PIFSRepositories >> directoryFor: aRepository [

	| directory |
	directory := aRepository repositoryDirectory.
	^ directory ifNotNil: [ directory asFileReference ]
]

{ #category : 'exporting' }
PIFSRepositories >> exportPackage: anIcePackage to: sourceDirectory [

	| versionInfo |
	versionInfo := MCVersionInfo
		               name: anIcePackage packageName
		               id: UUID new
		               message: ''
		               date: Date today
		               time: Time now
		               ancestors: #(  )
		               stepChildren: #(  ).
	TonelWriter fileOut: (MCVersion package: anIcePackage mcPackage info: versionInfo) on: sourceDirectory
]

{ #category : 'exporting' }
PIFSRepositories >> exportPackageNamed: packageName [

	| icePackage repository |
	repository := self owningPackageNamed: packageName ifAbsent: [ ^ self ].
	icePackage := self
		              packageNamed: packageName
		              in: repository
		              ifAbsent: [ Error signal: 'Repository ' , repository name , ' does not have loaded package ' , packageName ].
	repository codeDirectory ensureCreateDirectory.
	self exportPackage: icePackage to: repository codeDirectory.
	icePackage beClean
]

{ #category : 'exporting' }
PIFSRepositories >> exportPackagesNamed: packageNames [

	packageNames do: [ :packageName | self exportPackageNamed: packageName ]
]

{ #category : 'accessing' }
PIFSRepositories >> loadedPackageNamesFor: aRepository [

	^ [ (aRepository loadedPackages collect: [ :package | package packageName asString ] as: Array) sorted ]
		  on: Error
		  do: [ #(  ) ]
]

{ #category : 'accessing' }
PIFSRepositories >> owningPackageNamed: packageName ifAbsent: absentBlock [

	^ self all
		  detect: [ :repository |
				  (self canExportSourceFor: repository) and: [
					  repository loadedPackages anySatisfy: [ :package | package packageName asString = packageName ] ] ]
		  ifNone: absentBlock
]

{ #category : 'accessing' }
PIFSRepositories >> packageNamed: packageName in: aRepository ifAbsent: absentBlock [

	^ aRepository loadedPackages detect: [ :package | package packageName asString = packageName ] ifNone: absentBlock
]
