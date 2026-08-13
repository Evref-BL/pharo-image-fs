"
Small HTTP adapter exposing the pharo-image-fs projection backend to the Go mount daemon.
"
Class {
	#name : 'PharoImageFSProjectionHTTPServer',
	#superclass : 'Object',
	#instVars : [
		'backend',
		'server'
	],
	#category : 'PharoImageFS',
	#package : 'PharoImageFS'
}

{ #category : 'instance creation' }
PharoImageFSProjectionHTTPServer class >> startOn: portNumber [

	^ self new startOn: portNumber
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
	Error signal: 'Unknown projection operation: ' , operation
]

{ #category : 'accessing' }
PharoImageFSProjectionHTTPServer >> server [

	^ server
]

{ #category : 'running' }
PharoImageFSProjectionHTTPServer >> startOn: portNumber [

	server ifNotNil: [ server stop ].
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
			server := nil ]
]

{ #category : 'private - json' }
PharoImageFSProjectionHTTPServer >> valueAt: aKey in: aDictionary [

	^ aDictionary at: aKey ifAbsent: [ aDictionary at: aKey asString ]
]
