Class {
	#name : 'PIFSToolStopProjection',
	#superclass : 'PIFSTool',
	#category : 'PharoImageFS-MCP',
	#package : 'PharoImageFS-MCP'
}

{ #category : 'metadata' }
PIFSToolStopProjection class >> projectionIconBadgeName [

	^ #stop
]

{ #category : 'metadata' }
PIFSToolStopProjection class >> toolName [

	^ 'pifs_stop'
]

{ #category : 'metadata' }
PIFSToolStopProjection >> additionalKeywords [

	^ #( 'pifs' 'projection' 'unmount' 'source' 'filesystem' )
]

{ #category : 'metadata' }
PIFSToolStopProjection >> buildInputSchema [

	^ MCPStructureInputSchema new
		  type: 'object';
		  properties: {
				  (self schemaPropertyNamed: 'mountPath' type: 'string' description: 'Directory the projection to stop is mounted at.').
				  ((self
					    schemaPropertyNamed: 'port'
					    type: 'integer'
					    description: 'Port the projection to stop answers on, instead of naming its mount path.')
					   minimum: 1;
					   yourself) };
		  required: #(  );
		  yourself
]

{ #category : 'metadata' }
PIFSToolStopProjection >> description [

	^ 'Unmount a projection and stop serving it. Name it by the path it is mounted at, or by the port it answers on; pifs_list prints both.'
]

{ #category : 'executing' }
PIFSToolStopProjection >> executeWithRequest: request [

	| mountPath |
	(request hasArgumentNamed: 'port') ifTrue: [
			| port |
			port := request nonNegativeIntegerArgumentNamed: 'port' default: 0.
			^ self
				  projectionOnPort: port
				  ifFound: [ :server | self stopProjection: server ]
				  ifNone: [
				  self missingProjectionResultText: 'No projection answers on port ' , port asString , '.' errorCode: 'ProjectionNotFound' ] ].
	mountPath := request stringArgumentNamed: 'mountPath' default: nil.
	mountPath ifNil: [
			^ self
				  missingProjectionResultText: 'Name the projection to stop by its mountPath, or by the port it answers on.'
				  errorCode: 'MountPathOrPortRequired' ].
	^ self
		  projectionServingMountPath: mountPath
		  ifFound: [ :server | self stopProjection: server ]
		  ifNone: [ self missingProjectionResultText: 'No projection is mounted at ' , mountPath , '.' errorCode: 'ProjectionNotFound' ]
]

{ #category : 'executing' }
PIFSToolStopProjection >> stopProjection: aProjectionServer [
	"Stopping clears the server's port, so what it was is read before it goes."

	| entry |
	entry := self projectionEntryFor: aProjectionServer.
	aProjectionServer stop.
	^ self successResultText: 'Stopped projection on port ' , (entry at: #port) asString , '.' data: entry
]

{ #category : 'metadata' }
PIFSToolStopProjection >> title [

	^ 'Stop Source Projection'
]
