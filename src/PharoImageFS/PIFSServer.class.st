"
Small HTTP adapter exposing the pharo-image-fs projection backend to the Go mount daemon.
"
Class {
	#name : 'PIFSServer',
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
PIFSServer class >> daemonExecutable [

	self daemonExecutableOverride ifNotNil: [ :override | ^ override ].
	^ self daemonExecutableCacheDirectory / self daemonExecutableName
]

{ #category : 'private - daemon' }
PIFSServer class >> daemonExecutableCacheDirectory [

	^ FileLocator localDirectory / 'pharo-image-fs' / PIFSVersion current
]

{ #category : 'private - daemon' }
PIFSServer class >> daemonExecutableName [

	^ 'pharo-image-fs'
]

{ #category : 'private - daemon' }
PIFSServer class >> daemonExecutableOverride [

	| pathString |
	pathString := OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' ifAbsent: [ ^ nil ].
	pathString ifEmpty: [ ^ nil ].
	^ pathString asFileReference
]

{ #category : 'defaults' }
PIFSServer class >> defaultMountName [

	| delimiter imagePath suffix |
	imagePath := Smalltalk imagePath.
	delimiter := FileSystem disk delimiter.
	suffix := '.image'.
	^ imagePath copyFrom: (imagePath lastIndexOf: delimiter) + 1 to: ((imagePath endsWith: suffix)
			   ifTrue: [ imagePath size - suffix size ]
			   ifFalse: [ imagePath size ])
]

{ #category : 'defaults' }
PIFSServer class >> defaultMountPath [

	^ FileLocator temp / self defaultMountName
]

{ #category : 'private - daemon' }
PIFSServer class >> downloadDaemonArchiveTo: aFileReference [

	ZnClient new
		url: PIFSVersion daemonReleaseURL;
		downloadTo: aFileReference
]

{ #category : 'private - daemon' }
PIFSServer class >> downloadDaemonExecutable [

	| archive executable |
	self daemonExecutableCacheDirectory ensureCreateDirectory.
	archive := self daemonExecutableCacheDirectory / PIFSVersion daemonArchiveName.
	archive ensureDelete.
	self downloadDaemonArchiveTo: archive.
	[
		self extractDaemonArchive: archive into: self daemonExecutableCacheDirectory.
		executable := self daemonExecutable.
		executable exists ifFalse: [
			Error signal:
				'Downloaded daemon archive did not contain ' , self daemonExecutableName , ': ' , PIFSVersion daemonReleaseURL ].
		self makeDaemonExecutable: executable.
		^ executable ] ensure: [ archive exists ifTrue: [ archive delete ] ]
]

{ #category : 'private - daemon' }
PIFSServer class >> ensureDaemonExecutable [

	self daemonExecutableOverride ifNotNil: [ :override | ^ override ].
	self daemonExecutable exists ifFalse: [ ^ self downloadDaemonExecutable ].
	^ self daemonExecutable
]

{ #category : 'private - daemon' }
PIFSServer class >> extractDaemonArchive: archiveReference into: directoryReference [

	| archive |
	archive := ZipArchive new.
	[
		archive readFrom: archiveReference.
		archive extractAllTo: directoryReference overwrite: true ] ensure: [ archive close ]
]

{ #category : 'private - daemon' }
PIFSServer class >> makeDaemonExecutable: aFileReference [

	| command |
	command := 'chmod +x ' , (self shellQuote: aFileReference pathString).
	(LibC system: command) = 0 ifFalse: [ Error signal: 'Failed to make daemon executable: ' , aFileReference pathString ]
]

{ #category : 'registry' }
PIFSServer class >> register: aProjectionServer on: portNumber [

	^ self serversByPort at: portNumber put: aProjectionServer
]

{ #category : 'registry' }
PIFSServer class >> serverOn: portNumber [

	^ self serversByPort at: portNumber ifAbsent: [ nil ]
]

{ #category : 'registry' }
PIFSServer class >> serversByPort [

	^ ServersByPort ifNil: [ ServersByPort := Dictionary new ]
]

{ #category : 'private - daemon' }
PIFSServer class >> shellQuote: aString [

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

{ #category : 'instance creation' }
PIFSServer class >> startAndMountOn: portNumber [

	^ self
		  startOn: portNumber
		  mountAt: self defaultMountPath
		  named: self defaultMountName
]

{ #category : 'instance creation' }
PIFSServer class >> startOn: portNumber [

	self stopOn: portNumber.
	^ self register: (self new startOn: portNumber) on: portNumber
]

{ #category : 'instance creation' }
PIFSServer class >> startOn: portNumber mountAt: aPath [

	^ self startOn: portNumber mountAt: aPath named: self defaultMountName
]

{ #category : 'instance creation' }
PIFSServer class >> startOn: portNumber mountAt: aPath named: aString [

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
PIFSServer class >> startOn: portNumber mountNamed: aString [

	^ self
		  startOn: portNumber
		  mountAt: self defaultMountPath
		  named: aString
]

{ #category : 'registry' }
PIFSServer class >> stopAll [

	self serversByPort valuesDo: [ :each | each stop ].
	self serversByPort removeAll
]

{ #category : 'registry' }
PIFSServer class >> stopOn: portNumber [

	(self serverOn: portNumber) ifNotNil: [ :projectionServer | projectionServer stop ]
]

{ #category : 'registry' }
PIFSServer class >> unregister: aProjectionServer [

	aProjectionServer port ifNil: [ ^ self ].
	(self serverOn: aProjectionServer port) == aProjectionServer ifFalse: [ ^ self ].
	self serversByPort removeKey: aProjectionServer port ifAbsent: [ ]
]

{ #category : 'accessing' }
PIFSServer >> backend [

	^ backend
]

{ #category : 'accessing' }
PIFSServer >> backend: aBackend [

	backend := aBackend
]

{ #category : 'private - daemon' }
PIFSServer >> closeInheritedFileDescriptorsShellSnippet [

	^ 'for fd in /dev/fd/*; do fd=${fd##*/}; case "$fd" in 0|1|2|*[!0-9]*|'''') ;; *) eval "exec $fd>&-" 2>/dev/null || true ;; esac; done; '
]

{ #category : 'private - daemon' }
PIFSServer >> daemonCommandMountedAt: aFileReference named: aString [

	| daemonDirectory endpoint executableName |
	daemonDirectory := self class daemonExecutable parent.
	executableName := self class daemonExecutableName.
	endpoint := 'http://127.0.0.1:' , port asString , '/projection'.
	^ String streamContents: [ :stream |
			  stream
				  nextPutAll: '( cd ';
				  nextPutAll: (self shellQuote: daemonDirectory pathString);
				  nextPutAll: ' && { ';
				  nextPutAll: self closeInheritedFileDescriptorsShellSnippet;
				  nextPutAll: 'exec nohup ';
				  nextPutAll: (self shellQuote: './' , executableName);
				  nextPutAll: ' --endpoint ';
				  nextPutAll: (self shellQuote: endpoint);
				  nextPutAll: ' --mount-option ';
				  nextPutAll: (self shellQuote: 'volname=' , aString);
				  nextPut: Character space;
				  nextPutAll: (self shellQuote: aFileReference pathString);
				  nextPutAll: ' > ';
				  nextPutAll: (self shellQuote: daemonLogFile pathString);
				  nextPutAll: ' 2>&1; } ) & echo $! > ';
				  nextPutAll: (self shellQuote: daemonPidFile pathString) ]
]

{ #category : 'private - daemon' }
PIFSServer >> daemonLogFile [

	^ daemonLogFile
]

{ #category : 'private - daemon' }
PIFSServer >> daemonPidFile [

	^ daemonPidFile
]

{ #category : 'private - running' }
PIFSServer >> ensurePortAvailable: portNumber [

	| probeSocket |
	portNumber isZero ifTrue: [ ^ self ].
	probeSocket := [ ZnNetworkingUtils serverSocketOn: portNumber ]
		               on: Error
		               do: [ :error | ^ self signalServerStartupFailureOn: portNumber ].
	probeSocket destroy
]

{ #category : 'private - json' }
PIFSServer >> errorResponseFor: anError statusCode: statusCode [

	^ (ZnResponse statusCode: statusCode)
		  entity: (self jsonEntityFor: (Dictionary new
						    at: #message put: anError messageText;
						    yourself));
		  yourself
]

{ #category : 'private - routing' }
PIFSServer >> handleRequest: aRequest [

	aRequest method = #POST ifFalse: [ ^ ZnResponse methodNotAllowed: aRequest ].
	^ [ self jsonResponseFor: (self responseObjectForOperation: (self operationForRequest: aRequest) request: aRequest) ]
		  on: Error
		  do: [ :error | self errorResponseFor: error statusCode: (self statusCodeForError: error) ]
]

{ #category : 'initialization' }
PIFSServer >> initialize [

	super initialize.
	backend := PIFSBackend new
]

{ #category : 'private - json' }
PIFSServer >> jsonEntityFor: anObject [

	^ ZnEntity with: (STONJSON toString: anObject) type: ZnMimeType applicationJson
]

{ #category : 'private - json' }
PIFSServer >> jsonResponseFor: anObject [

	^ ZnResponse ok: (self jsonEntityFor: anObject)
]

{ #category : 'accessing' }
PIFSServer >> mountName [

	^ mountName
]

{ #category : 'accessing' }
PIFSServer >> mountPath [

	^ mountPath
]

{ #category : 'private - routing' }
PIFSServer >> operationForRequest: aRequest [

	| segments |
	segments := aRequest uri pathSegments.
	(segments size = 2 and: [ segments first = 'projection' ]) ifFalse: [ Error signal: 'Unknown projection endpoint.' ].
	^ segments second
]

{ #category : 'accessing' }
PIFSServer >> port [

	^ port
]

{ #category : 'private - json' }
PIFSServer >> requestDictionaryFrom: aRequest [

	aRequest hasEntity ifFalse: [ ^ Dictionary new ].
	^ STONJSON fromString: aRequest entity contents
]

{ #category : 'private - routing' }
PIFSServer >> responseObjectForOperation: operation request: aRequest [

	| body path |
	body := self requestDictionaryFrom: aRequest.
	path := self valueAt: #path in: body.
	operation = 'list' ifTrue: [ ^ backend listResponseForPath: path ].
	operation = 'stat' ifTrue: [ ^ backend statResponseForPath: path ].
	operation = 'read' ifTrue: [ ^ backend readResponseForPath: path ].
	operation = 'write' ifTrue: [ ^ backend writeResponseForPath: path text: (self valueAt: #text in: body) ].
	operation = 'delete' ifTrue: [ ^ backend deleteResponseForPath: path ].
	operation = 'rename' ifTrue: [ ^ backend renameResponseForPath: path to: (self valueAt: #targetPath in: body) ].
	operation = 'mkdir' ifTrue: [ ^ backend makeDirectoryResponseForPath: path ].
	operation = 'rmdir' ifTrue: [ ^ backend removeDirectoryResponseForPath: path ].
	Error signal: 'Unknown projection operation: ' , operation
]

{ #category : 'accessing' }
PIFSServer >> server [

	^ server
]

{ #category : 'private - daemon' }
PIFSServer >> shellQuote: aString [

	^ self class shellQuote: aString
]

{ #category : 'private - running' }
PIFSServer >> signalServerStartupFailureOn: portNumber [

	self stop.
	Error signal:
		'Could not start pharo-image-fs projection server on port ' , portNumber asString , '. The port may already be in use.'
]

{ #category : 'private - daemon' }
PIFSServer >> startDaemonMountedAt: aPath named: aString [

	| command executable |
	OSPlatform current isMacOS ifFalse: [ Error signal: 'pharo-image-fs daemon startup is currently supported only on macOS.' ].
	executable := self class ensureDaemonExecutable.
	mountPath := aPath asFileReference.
	mountName := aString.
	mountPath ensureCreateDirectory.
	daemonPidFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.pid').
	daemonLogFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.log').
	command := self daemonCommandMountedAt: mountPath named: mountName.
	(LibC system: command) = 0 ifFalse: [ Error signal: 'Failed to start pharo-image-fs daemon.' ]
]

{ #category : 'running' }
PIFSServer >> startOn: portNumber [

	server ifNotNil: [ self stop ].
	self ensurePortAvailable: portNumber.
	port := portNumber.
	server := ZnServer on: portNumber.
	server onRequestRespond: [ :request | self handleRequest: request ].
	server start.
	self waitUntilServerStartedOn: portNumber
]

{ #category : 'private - errors' }
PIFSServer >> statusCodeForError: anError [

	| message |
	message := anError messageText ifNil: [ '' ].
	(message beginsWith: 'Projection path not found:') ifTrue: [ ^ 404 ].
	(message beginsWith: 'Projection path is not writable yet:') ifTrue: [ ^ 403 ].
	^ 400
]

{ #category : 'running' }
PIFSServer >> stop [

	self stopDaemon.
	server ifNotNil: [
			server stop.
			server := nil ].
	self class unregister: self.
	port := nil
]

{ #category : 'private - daemon' }
PIFSServer >> stopDaemon [

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
PIFSServer >> valueAt: aKey in: aDictionary [

	^ aDictionary at: aKey ifAbsent: [ aDictionary at: aKey asString ]
]

{ #category : 'private - running' }
PIFSServer >> waitUntilServerStartedOn: portNumber [

	100 timesRepeat: [
			server isRunning ifTrue: [ ^ self ].
			(server process isNotNil and: [ server process isTerminated ]) ifTrue: [ ^ self signalServerStartupFailureOn: portNumber ].
			(Delay forMilliseconds: 10) wait ].
	server isRunning ifFalse: [ self signalServerStartupFailureOn: portNumber ]
]
