Class {
	#name : 'PIFSToolListProjections',
	#superclass : 'PIFSTool',
	#category : 'PharoImageFS-MCP',
	#package : 'PharoImageFS-MCP'
}

{ #category : 'metadata' }
PIFSToolListProjections class >> projectionIconBadgeName [

	^ #browse
]

{ #category : 'metadata' }
PIFSToolListProjections class >> toolName [

	^ 'pifs_list'
]

{ #category : 'metadata' }
PIFSToolListProjections >> additionalKeywords [

	^ #( 'pifs' 'projection' 'mount' 'source' 'filesystem' )
]

{ #category : 'metadata' }
PIFSToolListProjections >> annotations [

	^ MCPStructureToolAnnotations readOnly
]

{ #category : 'metadata' }
PIFSToolListProjections >> buildInputSchema [

	^ MCPStructureInputSchema new
		  type: 'object';
		  properties: {  };
		  required: #(  );
		  yourself
]

{ #category : 'metadata' }
PIFSToolListProjections >> description [

	^ 'List the filesystem projections this image is serving, each with the directory it is mounted at and the port it answers on. Use pifs_start to mount one and pifs_stop to unmount it.'
]

{ #category : 'executing' }
PIFSToolListProjections >> executeWithRequest: request [

	| entries |
	entries := (self projectionServers collect: [ :each | self projectionEntryFor: each ]) asArray.
	^ self
		  successResultText: (entries isEmpty
				   ifTrue: [ 'This image is serving no projection.' ]
				   ifFalse: [
						   'Serving ' , entries size asString , ' projection' , (entries size = 1
							    ifTrue: [ '.' ]
							    ifFalse: [ 's.' ]) ])
		  data: { (#projections -> entries) } asDictionary
]

{ #category : 'metadata' }
PIFSToolListProjections >> title [

	^ 'List Source Projections'
]
