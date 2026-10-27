Class {
	#name : 'PIFSToolStartProjection',
	#superclass : 'PIFSTool',
	#category : 'PharoImageFS-MCP',
	#package : 'PharoImageFS-MCP'
}

{ #category : 'metadata' }
PIFSToolStartProjection class >> projectionIconBadgeName [

	^ #play
]

{ #category : 'metadata' }
PIFSToolStartProjection class >> toolName [

	^ 'pifs_start'
]

{ #category : 'metadata' }
PIFSToolStartProjection >> additionalKeywords [

	^ #( 'pifs' 'projection' 'mount' 'source' 'filesystem' )
]

{ #category : 'metadata' }
PIFSToolStartProjection >> buildInputSchema [

	^ MCPStructureInputSchema new
		  type: 'object';
		  properties: {
				  (self
					   schemaPropertyNamed: 'mountPath'
					   type: 'string'
					   description: 'Directory to mount the projection at. Defaults to this image''s own projection directory.').
				  (self schemaPropertyNamed: 'name' type: 'string' description: 'Volume name the mounted projection shows under.') };
		  required: #(  );
		  yourself
]

{ #category : 'metadata' }
PIFSToolStartProjection >> description [

	^ 'Mount this image''s source as a filesystem projection and answer the port serving it. A projection already mounted at that path is answered unchanged, so asking twice is safe. Use pifs_list to see what is mounted and pifs_stop to unmount one.'
]

{ #category : 'executing' }
PIFSToolStartProjection >> executeWithRequest: request [

	| mountPath mountName |
	mountPath := request stringArgumentNamed: 'mountPath' default: PIFSServer defaultMountPath fullName.
	mountName := request stringArgumentNamed: 'name' default: PIFSServer defaultMountName.
	^ self
		  projectionServingMountPath: mountPath
		  ifFound: [ :server |
				  self
					  successResultText: 'Projection already mounted at ' , mountPath , ' on port ' , server port asString , '.'
					  data: (self projectionEntryFor: server) ]
		  ifNone: [
				  | started |
				  started := PIFSServer startMountedAt: mountPath asFileReference named: mountName.
				  self
					  successResultText: 'Mounted projection ' , mountName , ' at ' , mountPath , ' on port ' , started port asString , '.'
					  data: (self projectionEntryFor: started) ]
]

{ #category : 'metadata' }
PIFSToolStartProjection >> title [

	^ 'Start Source Projection'
]
