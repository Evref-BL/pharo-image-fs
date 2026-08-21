"
Small HTTP adapter exposing the pharo-image-fs projection backend to the Go mount daemon.
"
Class {
	#name : 'PharoImageFSProjectionHTTPServer',
	#superclass : 'Object',
	#instVars : [
		'backend',
		'server',
		'port',
		'mountPath',
		'mountName',
		'daemonPidFile',
		'daemonLogFile'
	],
	#classVars : [
		'ServersByPort'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer class >> daemonExecutable [

	self daemonExecutableOverride ifNotNil: [ :override | ^ override ].
	^ self daemonExecutableCacheDirectory / self daemonExecutableName
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer class >> daemonExecutableCacheDirectory [

	^ FileLocator localDirectory / 'pharo-image-fs' / PharoImageFSVersion current
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer class >> daemonExecutableName [

	^ 'pharo-image-fs'
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer class >> daemonExecutableOverride [

	| pathString |
	pathString := OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' ifAbsent: [ ^ nil ].
	pathString ifEmpty: [ ^ nil ].
	^ pathString asFileReference
]

{ #category : 'defaults' }
PharoImageFSProjectionHTTPServer class >> defaultMountName [

	| delimiter imagePath suffix |
	imagePath := Smalltalk imagePath.
	delimiter := FileSystem disk delimiter.
	suffix := '.image'.
	^ imagePath copyFrom: (imagePath lastIndexOf: delimiter) + 1 to: ((imagePath endsWith: suffix)
			   ifTrue: [ imagePath size - suffix size ]
			   ifFalse: [ imagePath size ])
]

{ #category : 'defaults' }
PharoImageFSProjectionHTTPServer class >> defaultMountPath [

	^ FileLocator temp / self defaultMountName
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> register: aProjectionServer on: portNumber [

	^ self serversByPort at: portNumber put: aProjectionServer
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> serverOn: portNumber [

	^ self serversByPort at: portNumber ifAbsent: [ nil ]
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> serversByPort [

	^ ServersByPort ifNil: [ ServersByPort := Dictionary new ]
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startAndMountOn: portNumber [

	^ self
		  startOn: portNumber
		  mountAt: self defaultMountPath
		  named: self defaultMountName
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber [

	self stopOn: portNumber.
	^ self register: (self new startOn: portNumber) on: portNumber
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber mountAt: aPath [

	^ self startOn: portNumber mountAt: aPath named: self defaultMountName
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber mountAt: aPath named: aString [

	| projectionServer |
	projectionServer := self startOn: portNumber.
	[
		projectionServer
			startDaemonMountedAt: aPath
			named: aString ]
		on: Error
		do: [ :error |
				projectionServer stop.
				error pass ].
	^ projectionServer
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber mountNamed: aString [

	^ self
		  startOn: portNumber
		  mountAt: self defaultMountPath
		  named: aString
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> stopAll [

	self serversByPort valuesDo: [ :each | each stop ].
	self serversByPort removeAll
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> stopOn: portNumber [

	(self serverOn: portNumber) ifNotNil: [ :projectionServer | projectionServer stop ]
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> unregister: aProjectionServer [

	aProjectionServer port ifNil: [ ^ self ].
	(self serverOn: aProjectionServer port) == aProjectionServer ifFalse: [ ^ self ].
	self serversByPort removeKey: aProjectionServer port ifAbsent: [ ]
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> backend [

	^ backend
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> backend: aBackend [

	backend := aBackend
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> daemonCommandMountedAt: aFileReference named: aString [

	| daemonDirectory executable endpoint |
	executable := self class daemonExecutable.
	daemonDirectory := executable parent.
	endpoint := 'http://127.0.0.1:' , port asString , '/projection'.
	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: 'cd ';
			  nextPutAll: (self shellQuote: daemonDirectory pathString);
			  nextPutAll: ' && nohup ';
			  nextPutAll: (self shellQuote: executable pathString);
			  nextPutAll: ' --endpoint ';
			  nextPutAll: (self shellQuote: endpoint);
			  nextPutAll: ' --mount-option ';
			  nextPutAll: (self shellQuote: 'volname=' , aString);
			  nextPut: Character space;
			  nextPutAll: (self shellQuote: aFileReference pathString);
			  nextPutAll: ' > ';
			  nextPutAll: (self shellQuote: daemonLogFile pathString);
			  nextPutAll: ' 2>&1 & echo $! > ';
			  nextPutAll: (self shellQuote: daemonPidFile pathString) ]
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> daemonLogFile [

	^ daemonLogFile
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> daemonPidFile [

	^ daemonPidFile
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> errorResponseFor: anError statusCode: statusCode [

	^ (ZnResponse statusCode: statusCode)
		  entity: (self jsonEntityFor: (Dictionary new
						    at: #message put: anError messageText;
						    yourself));
		  yourself
]

{ #category : 'private - routing' }
PharoImageFSProjectionHTTPServer >> handleRequest: aRequest [

	aRequest method = #POST ifFalse: [ ^ ZnResponse methodNotAllowed: aRequest ].
	^ [ self jsonResponseFor: (self responseObjectForOperation: (self operationForRequest: aRequest) request: aRequest) ]
		  on: Error
		  do: [ :error | self errorResponseFor: error statusCode: (self statusCodeForError: error) ]
]

{ #category : 'initialization' }
PharoImageFSProjectionHTTPServer >> initialize [

	super initialize.
	backend := PharoImageFSProjectionBackend new
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> jsonEntityFor: anObject [

	^ ZnEntity with: (STONJSON toString: anObject) type: ZnMimeType applicationJson
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> jsonResponseFor: anObject [

	^ ZnResponse ok: (self jsonEntityFor: anObject)
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> mountName [

	^ mountName
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> mountPath [

	^ mountPath
]

{ #category : 'private - routing' }
PharoImageFSProjectionHTTPServer >> operationForRequest: aRequest [

	| segments |
	segments := aRequest uri pathSegments.
	(segments size = 2 and: [ segments first = 'projection' ]) ifFalse: [ Error signal: 'Unknown projection endpoint.' ].
	^ segments second
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> port [

	^ port
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> requestDictionaryFrom: aRequest [

	aRequest hasEntity ifFalse: [ ^ Dictionary new ].
	^ STONJSON fromString: aRequest entity contents
]

{ #category : 'private - routing' }
PharoImageFSProjectionHTTPServer >> responseObjectForOperation: operation request: aRequest [

	| body path |
	body := self requestDictionaryFrom: aRequest.
	path := self valueAt: #path in: body.
	operation = 'list' ifTrue: [ ^ backend listResponseForPath: path ].
	operation = 'stat' ifTrue: [ ^ backend statResponseForPath: path ].
	operation = 'read' ifTrue: [ ^ backend readResponseForPath: path ].
	operation = 'write' ifTrue: [ ^ backend writeResponseForPath: path text: (self valueAt: #text in: body) ].
	operation = 'delete' ifTrue: [ ^ backend deleteResponseForPath: path ].
	operation = 'rename' ifTrue: [ ^ backend renameResponseForPath: path to: (self valueAt: #targetPath in: body) ].
	Error signal: 'Unknown projection operation: ' , operation
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> server [

	^ server
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> shellQuote: aString [

	^ String streamContents: [ :stream |
		  stream nextPut: $'.
		  aString do: [ :character |
				  character = $'
					  ifTrue: [
							  stream
								  nextPut: $';
								  nextPut: $\;
								  nextPut: $';
								  nextPut: $' ]
					  ifFalse: [ stream nextPut: character ] ].
		  stream nextPut: $' ]
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> startDaemonMountedAt: aPath named: aString [

	| command executable |
	OSPlatform current isMacOS ifFalse: [ Error signal: 'pharo-image-fs daemon startup is currently supported only on macOS.' ].
	executable := self class daemonExecutable.
	executable exists ifFalse: [
			Error signal: 'pharo-image-fs daemon executable not found: ' , executable pathString
				, '. Set PHARO_IMAGE_FS_DAEMON to a local daemon binary or install version ' , PharoImageFSVersion current , ' from '
				, PharoImageFSVersion daemonRepositoryURL ].
	mountPath := aPath asFileReference.
	mountName := aString.
	mountPath ensureCreateDirectory.
	daemonPidFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.pid').
	daemonLogFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.log').
	command := self daemonCommandMountedAt: mountPath named: mountName.
	(LibC system: command) = 0 ifFalse: [ Error signal: 'Failed to start pharo-image-fs daemon.' ]
]

{ #category : 'running' }
PharoImageFSProjectionHTTPServer >> startOn: portNumber [

	server ifNotNil: [ self stop ].
	port := portNumber.
	server := ZnServer on: portNumber.
	server onRequestRespond: [ :request | self handleRequest: request ].
	server start
]

{ #category : 'private - errors' }
PharoImageFSProjectionHTTPServer >> statusCodeForError: anError [

	| message |
	message := anError messageText ifNil: [ '' ].
	(message beginsWith: 'Projection path not found:') ifTrue: [ ^ 404 ].
	(message beginsWith: 'Projection path is not writable yet:') ifTrue: [ ^ 403 ].
	^ 400
]

{ #category : 'running' }
PharoImageFSProjectionHTTPServer >> stop [

	self stopDaemon.
	server ifNotNil: [
			server stop.
			server := nil ].
	self class unregister: self.
	port := nil
]

{ #category : 'private - daemon' }
PharoImageFSProjectionHTTPServer >> stopDaemon [

	mountPath ifNil: [ ^ self ].
	OSPlatform current isMacOS ifTrue: [
			LibC system: 'umount ' , (self shellQuote: mountPath pathString) , ' >/dev/null 2>&1 || diskutil unmount '
				, (self shellQuote: mountPath pathString) , ' >/dev/null 2>&1'.
			daemonPidFile ifNotNil: [
					daemonPidFile exists ifTrue: [
							| pid |
							pid := daemonPidFile contents trimBoth.
							pid ifNotEmpty: [ LibC system: 'kill -TERM ' , (self shellQuote: pid) , ' >/dev/null 2>&1' ].
							daemonPidFile delete ] ] ].
	mountPath := nil.
	mountName := nil.
	daemonPidFile := nil.
	daemonLogFile := nil
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> valueAt: aKey in: aDictionary [

	^ aDictionary at: aKey ifAbsent: [ aDictionary at: aKey asString ]
]
