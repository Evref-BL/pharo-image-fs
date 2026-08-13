"
Small HTTP adapter exposing the pharo-image-fs projection backend to the Go mount daemon.
"
Class {
	#name : 'PharoImageFSProjectionHTTPServer',
	#superclass : 'Object',
	#instVars : [
		'backend',
		'server',
		'port'
	],
	#classVars : [
		'ServersByPort'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> register: aProjectionServer on: portNumber [

	self serversByPort at: portNumber put: aProjectionServer.
	^ aProjectionServer
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> serverOn: portNumber [

	^ self serversByPort at: portNumber ifAbsent: [ nil ]
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> serversByPort [

	ServersByPort ifNil: [ ServersByPort := Dictionary new ].
	^ ServersByPort
]

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber [

	self stopOn: portNumber.
	^ self register: (self new startOn: portNumber) on: portNumber
]

{ #category : 'registry' }
PharoImageFSProjectionHTTPServer class >> stopAll [

	self serversByPort values copy do: [ :each | each stop ].
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

	server ifNotNil: [
			server stop.
			server := nil ].
	self class unregister: self.
	port := nil
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> valueAt: aKey in: aDictionary [

	^ aDictionary at: aKey ifAbsent: [ aDictionary at: aKey asString ]
]
