"
Tests for the Pharo-side projection HTTP server lifecycle registry.
"
Class {
	#name : 'PIFSServerTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-Tests',
	#package : 'PharoImageFS-Tests'
}

{ #category : 'private' }
PIFSServerTest >> daemonDirectory [
	"A directory of the test's own, which it deletes: another image may be running these tests at the same time."

	^ (FileLocator temp / ('pifs-server-test-' , UUID new asString)) asFileReference
		  ensureCreateDirectory;
		  yourself
]

{ #category : 'private' }
PIFSServerTest >> fakeDaemonIn: aDirectory running: shellLines [
	"A stand-in for the daemon. PIFSServer runs the executable named like the real one, from the directory PHARO_IMAGE_FS_DAEMON points into. The lines are joined with lf by hand: a string literal spanning lines holds the image's cr."

	| daemon |
	daemon := aDirectory / PIFSServer daemonExecutableName.
	daemon writeStreamDo: [ :stream |
			stream nextPutAll: '#!/bin/sh'.
			shellLines do: [ :line |
					stream
						lf;
						nextPutAll: line ].
			stream lf ].
	LibC system: 'chmod +x ' , (PIFSServer shellQuote: daemon pathString).
	^ daemon
]

{ #category : 'private' }
PIFSServerTest >> fakeMountIn: aDirectory listing: aPathString [
	"A stand-in for mount that lists a projection at aPathString, as Linux and as macOS write it."

	self
		fakeMountIn: aDirectory
		listing: aPathString
		as: self mountLines
		while: nil
]

{ #category : 'private' }
PIFSServerTest >> fakeMountIn: aDirectory listing: aPathString as: lines while: aFileReference [
	"A stand-in for mount that prints each of lines, where $p stands for the physical path mount prints for aPathString, while aFileReference exists, or always when it is nil."

	| mount |
	mount := aDirectory / 'mount'.
	mount writeStreamDo: [ :stream |
			stream
				nextPutAll: '#!/bin/sh';
				lf.
			aFileReference ifNotNil: [
					stream
						nextPutAll: '[ -e ';
						nextPutAll: (PIFSServer shellQuote: aFileReference pathString);
						nextPutAll: ' ] || exit 0';
						lf ].
			stream
				nextPutAll: 'p="$(cd ';
				nextPutAll: (PIFSServer shellQuote: aDirectory pathString);
				nextPutAll: ' && pwd -P)/"';
				nextPutAll: (PIFSServer shellQuote: (aPathString copyAfterLast: $/));
				lf.
			lines do: [ :each |
					stream
						nextPutAll: 'echo "';
						nextPutAll: each;
						nextPut: $";
						lf ] ].
	LibC system: 'chmod +x ' , (PIFSServer shellQuote: mount pathString)
]

{ #category : 'private' }
PIFSServerTest >> freePort [
	"A port nothing listens on, for a test that has to name one: a fixed port may be taken by another image running these tests at the same time."

	| socket |
	socket := ZnNetworkingUtils serverSocketOn: 0.
	^ [ socket localPort ] ensure: [ socket destroy ]
]

{ #category : 'private' }
PIFSServerTest >> mountLines [
	"How Linux and macOS list a projection mounted at $p."

	^ #( 'test on $p type fuse.pharo-image-fs (rw,nosuid,nodev)' '127.0.0.1:/test on $p (nfs, nodev, nosuid)' )
]

{ #category : 'running' }
PIFSServerTest >> setUp [

	super setUp.
	PIFSServer stopAll
]

{ #category : 'private' }
PIFSServerTest >> startWithDaemon: aDaemon mountedAt: aPath [
	"Start a projection served by aDaemon, and answer the error starting it signals, or nil."

	| previous |
	previous := OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' ifAbsent: [ nil ].
	OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' put: aDaemon pathString.
	^ [
		  [
			  PIFSServer start: (PIFSConfiguration new
					   mountPath: aPath;
					   mountName: 'pifs-server-test';
					   mountTimeout: 1 second;
					   yourself).
			  nil ]
			  on: Error
			  do: [ :error | error ] ] ensure: [
			  previous
				  ifNil: [ OSEnvironment current removeKey: 'PHARO_IMAGE_FS_DAEMON' ]
				  ifNotNil: [ OSEnvironment current at: 'PHARO_IMAGE_FS_DAEMON' put: previous ] ]
]

{ #category : 'running' }
PIFSServerTest >> tearDown [

	[ PIFSServer stopAll ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
PIFSServerTest >> testALeftoverMountIsWaitedFor [
	"A projection whose image is gone unmounts itself within seconds, since its daemon watches the image, so a start at its path waits for it to go, then launches the daemon."

	| directory previousPath leftover marker error |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	directory := self daemonDirectory.
	leftover := directory / 'leftover'.
	marker := (directory / 'mounted') ensureCreateFile.
	previousPath := OSEnvironment current at: 'PATH'.
	[
		self
			fakeMountIn: directory
			listing: leftover pathString
			as: self mountLines
			while: marker.
		OSEnvironment current at: 'PATH' put: (String streamContents: [ :path |
					 path
						 nextPutAll: directory pathString;
						 nextPut: $:;
						 nextPutAll: previousPath ]).
		self deny: (PIFSServer waitUntilNothingIsMountedAt: leftover within: 200 milliSeconds).
		LibC system: '(sleep 0.3; rm -f ' , (PIFSServer shellQuote: marker pathString) , ') >/dev/null 2>&1 &'.
		error := self
			         startWithDaemon: (self fakeDaemonIn: directory running: #( 'echo "launched past the leftover"'
			             'exit 1' ))
			         mountedAt: leftover.
		self assert: error isNotNil.
		self deny: (error messageText includesSubstring: 'already mounted').
		self assert: (error messageText includesSubstring: 'launched past the leftover') ] ensure: [
			OSEnvironment current at: 'PATH' put: previousPath.
			directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testAPathThatBeginsAMountedOneIsNotMounted [
	"mount prints a mount point as it is, spaces included: a projection mounted at 'Pharo 13.0 - 64bit (stable)' is not one at 'Pharo 13.0', nor, on Linux, at 'Pharo 13.0 - 64bit'. A stand-in for mount lists it the way Linux and macOS do."

	| directory previousPath |
	directory := self daemonDirectory.
	previousPath := OSEnvironment current at: 'PATH'.
	[
		self fakeMountIn: directory listing: (directory / 'Pharo 13.0 - 64bit (stable)') pathString.
		OSEnvironment current at: 'PATH' put: (String streamContents: [ :path |
					 path
						 nextPutAll: directory pathString;
						 nextPut: $:;
						 nextPutAll: previousPath ]).
		self assert: (PIFSServer isMountPoint: directory / 'Pharo 13.0 - 64bit (stable)').
		self deny: (PIFSServer isMountPoint: directory / 'Pharo 13.0').
		OSPlatform current isLinux ifTrue: [ self deny: (PIFSServer isMountPoint: directory / 'Pharo 13.0 - 64bit') ] ] ensure: [
			OSEnvironment current at: 'PATH' put: previousPath.
			directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testASaveKeepsTheProjections [
	"A save that goes on in the same session keeps its projections: Zinc listens again on their ports."

	| projectionServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	PIFSServer startUp: false.
	self assert: (PIFSServer serverOn: projectionServer port) equals: projectionServer.
	self assert: projectionServer server isRunning
]

{ #category : 'tests' }
PIFSServerTest >> testAnImageStartForgetsItsProjections [
	"An image started from its file has none of the projections it was saved with. Zinc stopped their servers for the save; left registered, it would start them again on their old ports."

	| projectionServer zincServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	zincServer := projectionServer server.
	zincServer stop: false.
	PIFSServer startUp: true.
	self assert: PIFSServer serversByPort isEmpty.
	self deny: (ZnServer managedServers includes: zincServer).
	self assert: projectionServer server isNil.
	self assert: projectionServer port isNil
]

{ #category : 'tests' }
PIFSServerTest >> testAnImageStartLeavesTheDaemonsAlone [
	"The daemon of a projection the image was saved with unmounts itself once the image that saved it is gone, and the pid it wrote may now be another process's, so an image start forgets the projection without signalling it."

	| directory pidFile previousPath pid |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	directory := self daemonDirectory.
	pidFile := directory / 'daemon.pid'.
	previousPath := OSEnvironment current at: 'PATH'.
	[
		self
			fakeMountIn: directory
			listing: (directory / 'projection') pathString
			as: self mountLines
			while: pidFile.
		OSEnvironment current at: 'PATH' put: (String streamContents: [ :path |
					 path
						 nextPutAll: directory pathString;
						 nextPut: $:;
						 nextPutAll: previousPath ]).
		self assert: (self
				 startWithDaemon: (self fakeDaemonIn: directory running: {
							  ('echo $$ > ' , (PIFSServer shellQuote: pidFile pathString)).
							  'exec sleep 30' })
				 mountedAt: directory / 'projection') isNil.
		pid := pidFile contents trimBoth.
		PIFSServer startUp: true.
		self assert: PIFSServer serversByPort isEmpty.
		self assert: (LibC system: 'kill -0 ' , pid) equals: 0 ] ensure: [
			pid ifNotNil: [ LibC system: 'kill ' , pid , ' 2>/dev/null' ].
			OSEnvironment current at: 'PATH' put: previousPath.
			directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testDaemonCommandIncludesEndpointMountPointAndMountName [
	"exec keeps the pid the daemon's own, which stop signals."

	| command projectionServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	projectionServer instVarNamed: 'daemonPidFile' put: FileLocator temp / 'pharo-image-fs-test.pid'.
	projectionServer instVarNamed: 'daemonLogFile' put: FileLocator temp / 'pharo-image-fs-test.log'.
	command := projectionServer daemonCommandMountedAt: FileLocator temp / 'Pharo Image FS Test' named: 'Pharo Image'.
	self assert: (command includesSubstring: 'exec nohup ''./pharo-image-fs''').
	self assert: (command includesSubstring: '--endpoint ''http://127.0.0.1:' , projectionServer port asString , '/projection''').
	self assert: (command includesSubstring: '--mount-option ''volname=Pharo Image''').
	self assert: (command includesSubstring: 'Pharo Image FS Test')
]

{ #category : 'tests' }
PIFSServerTest >> testDefaultMountPathUsesDefaultMountNameInTemp [

	self
		assert: PIFSServer defaultMountPath basename
		equals: PIFSServer defaultMountName.
	self assert: PIFSServer defaultMountName isEmpty not
]

{ #category : 'tests' }
PIFSServerTest >> testMountPointsAreThePathsMountLists [

	| directory |
	self assert: (PIFSServer isMountPoint: '/dev' asFileReference).
	directory := self daemonDirectory.
	[ self deny: (PIFSServer isMountPoint: directory) ] ensure: [ directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartEndpointOnAvailablePortRegistersActualPort [

	| projectionServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	self assert: projectionServer port > 0.
	self assert: (PIFSServer serverOn: projectionServer port) equals: projectionServer
]

{ #category : 'tests' }
PIFSServerTest >> testStartEndpointOnDoesNotMount [

	| projectionServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	self assert: projectionServer mountPath isNil.
	self assert: projectionServer mountName isNil
]

{ #category : 'tests' }
PIFSServerTest >> testStartEndpointOnOccupiedPortSignalsClearError [

	| occupyingSocket port error |
	occupyingSocket := ZnNetworkingUtils serverSocketOn: 0.
	port := occupyingSocket localPort.
	[
		error := [
			         PIFSServer startEndpointOn: port.
			         nil ]
			         on: PIFSError
			         do: [ :each | each ].
		self
			assert: error isNotNil
			description: 'PIFS should fail clearly when the requested projection port is occupied by another server.'.
		self assert: error errorCode equals: 'EndpointStartFailed'.
		self assert: (error messageText includesSubstring: 'port may already be in use').
		self assert: (PIFSServer serverOn: port) isNil ] ensure: [ occupyingSocket destroy ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartEndpointOnRegistersServerByPort [

	| port projectionServer |
	port := self freePort.
	projectionServer := PIFSServer startEndpointOn: port.
	self assert: (PIFSServer serverOn: port) equals: projectionServer.
	self assert: projectionServer port equals: port
]

{ #category : 'tests' }
PIFSServerTest >> testStartFailsWhenTheDaemonDoesNotMount [
	"A daemon whose mount fails logs why and may keep running. It is launched in the background, so start used to answer a port over a mount that never came."

	| directory error |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	directory := self daemonDirectory.
	[
		error := self
			         startWithDaemon: (self fakeDaemonIn: directory running: #( 'echo "mount failed: permission denied"'
			             'exec sleep 30' ))
			         mountedAt: directory / 'mount'.
		self assert: error isNotNil.
		self assert: error errorCode equals: 'MountTimedOut'.
		self assert: (error messageText includesSubstring: 'did not mount').
		self assert: (error messageText includesSubstring: 'mount failed: permission denied').
		self assert: PIFSServer serversByPort isEmpty ] ensure: [ directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartFailsWhenTheDaemonExitsBeforeMounting [
	"The daemon's own words reach the error."

	| directory error |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	directory := self daemonDirectory.
	[
		error := self
			         startWithDaemon: (self fakeDaemonIn: directory running: #( 'echo "FUSE needs fusermount3"'
			             'exit 1' ))
			         mountedAt: directory / 'mount'.
		self assert: error isNotNil.
		self assert: error errorCode equals: 'DaemonExitedBeforeMounting'.
		self assert: (error messageText includesSubstring: 'exited before mounting').
		self assert: (error messageText includesSubstring: 'FUSE needs fusermount3').
		self assert: PIFSServer serversByPort isEmpty ] ensure: [ directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartRefusesAMountPathAFileIsIn [
	"Pharo would name only the path it could not make a directory of, so the error says what it was for. The daemon is never launched."

	| directory file error |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	directory := self daemonDirectory.
	file := (directory / 'a-file') ensureCreateFile.
	[
		error := self
			         startWithDaemon: (self fakeDaemonIn: directory running: #( 'echo "launched over a file"' 'exit 1' ))
			         mountedAt: file.
		self assert: error isNotNil.
		self assert: error errorCode equals: 'MountPathCreationFailed'.
		self assert: (error messageText includesSubstring: file pathString).
		self deny: (error messageText includesSubstring: 'launched over a file').
		self assert: PIFSServer serversByPort isEmpty ] ensure: [ directory ensureDeleteAll ]
]

{ #category : 'tests' }
PIFSServerTest >> testStartRefusesAPathSomethingStaysMountedAt [
	"The daemon would fail to mount there, and what is mounted is not the projection's to unmount."

	| error |
	PIFSServer daemonRunsHere ifFalse: [ ^ self skip: 'The daemon runs on macOS and Linux only.' ].
	error := [
		         PIFSServer start: (PIFSConfiguration new
				          mountPath: '/dev' asFileReference;
				          mountTimeout: 200 milliSeconds;
				          yourself).
		         nil ]
		         on: Error
		         do: [ :each | each ].
	self assert: error isNotNil.
	self assert: error errorCode equals: 'MountPathInUse'.
	self assert: (error messageText includesSubstring: 'already mounted at /dev').
	self assert: PIFSServer serversByPort isEmpty
]

{ #category : 'tests' }
PIFSServerTest >> testStartingSamePortReplacesRegisteredServer [

	| firstServer port secondServer |
	firstServer := PIFSServer startEndpointOn: 0.
	port := firstServer port.
	secondServer := PIFSServer startEndpointOn: port.
	self deny: firstServer == secondServer.
	self assert: (PIFSServer serverOn: port) equals: secondServer.
	self assert: firstServer port isNil
]

{ #category : 'tests' }
PIFSServerTest >> testStopOnUnregistersServerByPort [

	| port |
	port := (PIFSServer startEndpointOn: 0) port.
	PIFSServer stopOn: port.
	self assert: (PIFSServer serverOn: port) isNil
]

{ #category : 'tests' }
PIFSServerTest >> testStopUnregistersAServerZincStopped [
	"Zinc unregisters only a server that runs, and one it stopped for a save does not: left registered, Zinc would start it again after the save."

	| projectionServer zincServer |
	projectionServer := PIFSServer startEndpointOn: 0.
	zincServer := projectionServer server.
	zincServer stop: false.
	projectionServer stop.
	self deny: (ZnServer managedServers includes: zincServer)
]

{ #category : 'tests' }
PIFSServerTest >> testUnmountCommandNeverForces [
	"Unmounting a busy projection fails until nothing uses it: a forced or lazy unmount would leave its users on a gone image. One command serves macOS and Linux: each tool it does not have fails, and the next one runs."

	| path command |
	path := '/tmp/an image' asFileReference.
	command := PIFSServer unmountCommandFor: path.
	self assert: (command beginsWith: 'umount ').
	self assert: (command includesSubstring: ' || fusermount3 -u ').
	self assert: (command includesSubstring: (PIFSServer shellQuote: path pathString)).
	#( ' -f' ' -l' ' -z' ' -uz' 'force' ) do: [ :forcing | self deny: (command includesSubstring: forcing) ]
]

{ #category : 'tests' }
PIFSServerTest >> testZincManagesTheServer [
	"Zinc stops the servers it manages around every save and closes their connections, so the saved image holds no socket of this session."

	| zincServer |
	zincServer := (PIFSServer startEndpointOn: 0) server.
	self assert: (ZnServer managedServers includes: zincServer).
	PIFSServer stopAll.
	self deny: (ZnServer managedServers includes: zincServer)
]
