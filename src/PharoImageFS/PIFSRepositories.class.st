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

{ #category : 'exporting' }
PIFSRepositories >> applyExportedFile: source to: target [
	"The export is the image's answer for this file. A file the export no longer
	produces is one the change removed."

	source exists ifFalse: [ ^ target ensureDelete ].
	(target exists and: [
		 (target binaryReadStreamDo: [ :stream | stream upToEnd ]) = (source binaryReadStreamDo: [ :stream | stream upToEnd ]) ])
		ifTrue: [ ^ self ].
	target ensureDelete.
	source copyTo: target
]

{ #category : 'accessing' }
PIFSRepositories >> canExportSourceFor: aRepository [

	^ (self hasCheckoutFor: aRepository) and: [ self writesTonelFor: aRepository ]
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
	"Write every file of the package. TonelWriter deletes and recreates the
	directory, so this also rewrites files the change did not touch; prefer
	exportPackageNamed:filesNamed: wherever the change owns known files. It is
	right for a class rename, which rewrites every reference, and references
	inside the package are allowed."

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
PIFSRepositories >> exportPackageNamed: packageName filesNamed: fileNames [
	"Bring only these files of the package in line with the image.

	TonelWriter deletes and recreates the whole package directory, so exporting
	a package to save one class rewrites every other file in it, and a file
	whose methods are not in the writer's own order comes back reordered. That
	is an unrelated diff for a change that touched one method. Export into
	memory and take only the files the change touched."

	| icePackage repository exported packageDirectory |
	repository := self owningPackageNamed: packageName ifAbsent: [ ^ self ].
	icePackage := self
		              packageNamed: packageName
		              in: repository
		              ifAbsent: [ Error signal: 'Repository ' , repository name , ' does not have loaded package ' , packageName ].
	exported := FileSystem memory root.
	self exportPackage: icePackage to: exported.
	packageDirectory := repository codeDirectory / packageName.
	packageDirectory ensureCreateDirectory.
	#( 'package.st' ) , fileNames do: [ :fileName |
		self applyExportedFile: exported / packageName / fileName to: packageDirectory / fileName ].
	icePackage beClean
]

{ #category : 'exporting' }
PIFSRepositories >> exportPackagesNamed: packageNames [

	packageNames do: [ :packageName | self exportPackageNamed: packageName ]
]

{ #category : 'accessing' }
PIFSRepositories >> hasCheckoutFor: aRepository [

	| directory |
	directory := self directoryFor: aRepository.
	^ directory notNil and: [ directory exists ]
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

{ #category : 'accessing' }
PIFSRepositories >> sourceFormatIdFor: aRepository [
	"Which source format the repository keeps on disk, as Iceberg's own writer
	id: #tonel, #filetree, and so on. Answer nil for a repository that cannot
	say."

	^ [ aRepository properties writerClass id ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'accessing' }
PIFSRepositories >> unsupportedSourceFormatFor: packageName [
	"The format of a repository that holds this package in a checkout, but keeps
	its source in one this projection does not write. Answer nil when there is
	no such repository."

	^ self all
		  detect: [ :repository |
				  (self hasCheckoutFor: repository) and: [
						  (self writesTonelFor: repository) not and: [
							  repository loadedPackages anySatisfy: [ :package | package packageName asString = packageName ] ] ] ]
		  ifFound: [ :repository | self sourceFormatIdFor: repository ]
		  ifNone: [ nil ]
]

{ #category : 'accessing' }
PIFSRepositories >> writesTonelFor: aRepository [
	"This projection reads and writes Tonel. Exporting into a repository that
	keeps another format would leave a second copy of the source beside the
	real one, and no load reads the copy.

	Refuse only a format the repository names: one that cannot say keeps the
	behaviour it always had."

	^ (self sourceFormatIdFor: aRepository) ifNil: [ true ] ifNotNil: [ :formatId | formatId = #tonel ]
]
