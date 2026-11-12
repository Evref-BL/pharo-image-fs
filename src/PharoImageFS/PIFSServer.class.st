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
PIFSServer class >> daemonArchiveAssetURL [
	"github.com answers a release download with a content-security-policy header longer than ZnConstants maximumLineLength, so Zn cannot even read the redirect. The API answers short headers, so the asset is resolved and fetched through it."

	| release |
	release := STONJSON fromString: (ZnClient new
			            url: PIFSVersion daemonReleaseApiURL;
			            accept: 'application/vnd.github+json';
			            get).
	^ (release at: 'assets')
		  detect: [ :each | (each at: 'name') = PIFSVersion daemonArchiveName ]
		  ifFound: [ :asset | asset at: 'url' ]
		  ifNone: [ Error signal: 'Daemon release ' , PIFSVersion releaseTag , ' has no asset named ' , PIFSVersion daemonArchiveName ]
]

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

{ #category : 'private - daemon' }
PIFSServer class >> daemonRunsHere [
	"Whether this system has a daemon to mount projections: macOS serves them over NFS, Linux over FUSE."

	^ OSPlatform current isMacOS or: [ OSPlatform current isLinux ]
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
		url: self daemonArchiveAssetURL;
		accept: 'application/octet-stream';
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
PIFSServer class >> isMountPoint: aFileReference [
	"Whether mount lists something mounted at aFileReference. mount prints physical paths, so the parent is resolved; the path itself is not, because a mount whose daemon is gone fails every lookup. What follows the path is matched too, so that a longer mounted path does not match: macOS prints ' (' after it, Linux ' type '."

	| mounted |
	mounted := '" on ${d%/}/"' , (self shellQuote: aFileReference basename).
	^ (LibC system: (String streamContents: [ :stream |
				    stream
					    nextPutAll: 'd=$(cd ';
					    nextPutAll: (self shellQuote: aFileReference parent pathString);
					    nextPutAll: ' 2>/dev/null && pwd -P) && mount | grep -F -q -e ';
					    nextPutAll: mounted;
					    nextPutAll: '" (" -e ';
					    nextPutAll: mounted;
					    nextPutAll: '" type "' ])) = 0
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
PIFSServer class >> start [

	^ self start: PIFSConfiguration default
]

{ #category : 'instance creation' }
PIFSServer class >> start: aConfiguration [

	| projectionServer |
	projectionServer := self startEndpointOn: aConfiguration port.
	projectionServer backend configuration: aConfiguration.
	[ projectionServer startDaemonMountedAt: aConfiguration mountPath named: aConfiguration mountName ]
		on: Error
		do: [ :error |
				projectionServer stop.
				error pass ].
	^ projectionServer
]

{ #category : 'instance creation - endpoint' }
PIFSServer class >> startEndpointOn: portNumber [
	"Serve the projection protocol without mounting anything. A projection is only useful through its mount, so this is for tests and for a caller running the daemon itself."

	| projectionServer |
	self stopOn: portNumber.
	projectionServer := self new startOn: portNumber.
	^ self register: projectionServer on: projectionServer port
]

{ #category : 'instance creation' }
PIFSServer class >> startMountedAt: aPath named: aString [

	^ self start: (PIFSConfiguration new
			   mountPath: aPath;
			   mountName: aString;
			   yourself)
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

{ #category : 'private - daemon' }
PIFSServer class >> unmountCommandFor: aFileReference [
	"The command that unmounts what is mounted at aFileReference, as the user who mounted it, without forcing it: umount on macOS, and on Linux where util-linux lets a user unmount their own FUSE mount, else FUSE's setuid helper, fusermount3, or fusermount where only FUSE 2 is installed."

	| path |
	path := self shellQuote: aFileReference pathString.
	^ String streamContents: [ :stream |
			  #( 'umount ' 'fusermount3 -u ' 'fusermount -u ' )
				  do: [ :each |
						  stream
							  nextPutAll: each;
							  nextPutAll: path;
							  nextPutAll: ' >/dev/null 2>&1' ]
				  separatedBy: [ stream nextPutAll: ' || ' ] ]
]

{ #category : 'registry' }
PIFSServer class >> unregister: aProjectionServer [

	aProjectionServer port ifNil: [ ^ self ].
	(self serverOn: aProjectionServer port) == aProjectionServer ifFalse: [ ^ self ].
	self serversByPort removeKey: aProjectionServer port ifAbsent: [ ]
]

{ #category : 'private - daemon' }
PIFSServer class >> waitUntilNothingIsMountedAt: aFileReference within: aDuration [
	"Answer whether nothing is mounted at aFileReference, waiting up to aDuration for it to go: a projection whose image is gone unmounts itself within seconds, since its daemon watches the image."

	| deadline |
	deadline := DateAndTime now + aDuration.
	[ self isMountPoint: aFileReference ] whileTrue: [
			DateAndTime now > deadline ifTrue: [ ^ false ].
			(Delay forMilliseconds: 100) wait ].
	^ true
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
PIFSServer >> daemonCommandMountedAt: aFileReference named: aString [
	"The daemon closes the descriptors it inherits from the image as it starts, so the shell runs it as it is. exec keeps the pid the daemon's own."

	| daemonDirectory endpoint executableName |
	daemonDirectory := self class daemonExecutable parent.
	executableName := self class daemonExecutableName.
	endpoint := 'http://127.0.0.1:' , port asString , '/projection'.
	^ String streamContents: [ :stream |
			  stream
				  nextPutAll: '( cd ';
				  nextPutAll: (self shellQuote: daemonDirectory pathString);
				  nextPutAll: ' && exec nohup ';
				  nextPutAll: (self shellQuote: './' , executableName);
				  nextPutAll: ' --endpoint ';
				  nextPutAll: (self shellQuote: endpoint);
				  nextPutAll: ' --mount-option ';
				  nextPutAll: (self shellQuote: 'volname=' , aString);
				  nextPut: Character space;
				  nextPutAll: (self shellQuote: aFileReference pathString);
				  nextPutAll: ' > ';
				  nextPutAll: (self shellQuote: daemonLogFile pathString);
				  nextPutAll: ' 2>&1 ) & echo $! > ';
				  nextPutAll: (self shellQuote: daemonPidFile pathString) ]
]

{ #category : 'private - daemon' }
PIFSServer >> daemonIsRunning [

	| pid |
	(daemonPidFile isNotNil and: [ daemonPidFile exists ]) ifFalse: [ ^ false ].
	pid := daemonPidFile contents trimBoth.
	pid ifEmpty: [ ^ false ].
	^ (LibC system: 'kill -0 ' , (self shellQuote: pid) , ' 2>/dev/null') = 0
]

{ #category : 'private - daemon' }
PIFSServer >> daemonLogExcerpt [
	"The end of the daemon's log, where it says why it failed, for an error about it."

	| text |
	(daemonLogFile isNotNil and: [ daemonLogFile exists ]) ifFalse: [ ^ '.' ].
	text := daemonLogFile contents trimBoth.
	text ifEmpty: [ ^ '.' ].
	^ '. The daemon logged: ' , (text last: (text size min: 500))
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
	self class daemonRunsHere ifFalse: [ Error signal: 'pharo-image-fs daemon startup is supported only on macOS and Linux.' ].
	"The daemon would fail to mount over it, and what is there is not this projection's to unmount."
	(self class waitUntilNothingIsMountedAt: aPath asFileReference within: backend configuration mountTimeout) ifFalse: [
			Error signal:
				'Something is already mounted at ' , aPath asFileReference pathString , '. Unmount it before mounting a projection there.' ].
	executable := self class ensureDaemonExecutable.
	mountPath := aPath asFileReference.
	mountName := aString.
	mountPath ensureCreateDirectory.
	daemonPidFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.pid').
	daemonLogFile := FileLocator temp / ('pharo-image-fs-' , port asString , '.log').
	command := self daemonCommandMountedAt: mountPath named: mountName.
	(LibC system: command) = 0 ifFalse: [ Error signal: 'Failed to start pharo-image-fs daemon.' ].
	self waitForMountWithin: backend configuration mountTimeout
]

{ #category : 'running' }
PIFSServer >> startOn: portNumber [

	server ifNotNil: [ self stop ].
	self ensurePortAvailable: portNumber.
	server := ZnServer on: portNumber.
	server bindingAddress: #[ 127 0 0 1 ].
	server onRequestRespond: [ :request | self handleRequest: request ].
	server start.
	port := server port.
	self waitUntilServerStartedOn: port
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
	"Unmount, then signal the daemon, which also unmounts on its own once nothing keeps the mount busy."

	mountPath ifNil: [ ^ self ].
	self class daemonRunsHere ifTrue: [
			LibC system: (self class unmountCommandFor: mountPath).
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

{ #category : 'private - daemon' }
PIFSServer >> waitForMountWithin: aDuration [
	"The daemon is launched in the background, so the shell that launched it says nothing about the mount: wait for the mount itself. A daemon whose mount failed logs why and may keep running, so its log is what the failure reports."

	| deadline |
	deadline := DateAndTime now + aDuration.
	[ self class isMountPoint: mountPath ] whileFalse: [
			self daemonIsRunning ifFalse: [
				^ Error signal: 'pharo-image-fs daemon exited before mounting ' , mountPath pathString , self daemonLogExcerpt ].
			DateAndTime now > deadline ifTrue: [
					^ Error signal:
						  'pharo-image-fs did not mount ' , mountPath pathString , ' within ' , aDuration humanReadablePrintString
						  , self daemonLogExcerpt ].
			(Delay forMilliseconds: 100) wait ]
]

{ #category : 'private - running' }
PIFSServer >> waitUntilServerStartedOn: portNumber [

	100 timesRepeat: [
			server isRunning ifTrue: [ ^ self ].
			(server process isNotNil and: [ server process isTerminated ]) ifTrue: [ ^ self signalServerStartupFailureOn: portNumber ].
			(Delay forMilliseconds: 10) wait ].
	server isRunning ifFalse: [ self signalServerStartupFailureOn: portNumber ]
]
