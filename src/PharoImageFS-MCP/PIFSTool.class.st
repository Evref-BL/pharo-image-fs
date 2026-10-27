"
Abstract superclass of the MCP tools PIFS serves, so that an image holding both projects offers its projections as tools rather than as code to evaluate.

MCP keeps a tool defined outside its own package out of the catalog unless the tool says otherwise, which is what `shouldAutoRegister` does here.
"
Class {
	#name : 'PIFSTool',
	#superclass : 'MCPTool',
	#category : 'PharoImageFS-MCP',
	#package : 'PharoImageFS-MCP'
}

{ #category : 'metadata' }
PIFSTool class >> groupName [

	^ 'projection'
]

{ #category : 'testing' }
PIFSTool class >> isAbstract [

	^ self = PIFSTool
]

{ #category : 'metadata' }
PIFSTool class >> projectionIconBadgeName [

	^ self subclassResponsibility
]

{ #category : 'testing' }
PIFSTool class >> shouldAutoRegister [
	"MCP registers the tools of its own package and leaves every other one out, so a tool it did not ship has to say that it wants to be served. These are PIFS's own, and an image that loaded this package asked for them. The second half is MCP's own guard: a class being built in a live image is compiled before its methods, so it cannot name itself yet."

	^ (self class lookupSelector: #toolName) isSubclassResponsibility not
]

{ #category : 'metadata' }
PIFSTool class >> toolIconSpec [
	"MCP reads an icon out of a tool name it recognises the words of, and `pifs` is not one of its own. So these say what they are: the image, badged with what the tool does to its projection."

	^ MCPToolIconSpec baseIconNamed: #pharoHalfScale badgeIconNamed: self projectionIconBadgeName
]

{ #category : 'private - projections' }
PIFSTool >> missingProjectionResultText: aText [
	"Nothing was mounted or unmounted, so say what the image is actually serving. The text is what an agent reads, so the answer belongs in it and not only in the details."

	| entries |
	entries := (self projectionServers collect: [ :each | self projectionEntryFor: each ]) asArray.
	^ self
		  errorResultText: aText , ' ' , (entries ifEmpty: [ 'This image is serving no projection.' ] ifNotEmpty: [
					   'Serving: ' , (', ' join:
						    (entries collect: [ :each | (each at: #mountPath ifAbsent: [ 'no mount' ]) , ' on port ' , (each at: #port) asString ]))
					   , '.' ])
		  details: { (#projections -> entries) } asDictionary
]

{ #category : 'private - projections' }
PIFSTool >> projectionEntryFor: aProjectionServer [
	"What a caller can say about a projection afterwards: where it is mounted, and the port it answers on."

	| entry |
	entry := Dictionary new.
	entry at: #port put: aProjectionServer port.
	aProjectionServer mountPath ifNotNil: [ :path | entry at: #mountPath put: path asFileReference fullName ].
	aProjectionServer mountName ifNotNil: [ :name | entry at: #name put: name ].
	^ entry
]

{ #category : 'private - projections' }
PIFSTool >> projectionOnPort: aPortNumber ifFound: foundBlock ifNone: noneBlock [

	^ PIFSServer serversByPort at: aPortNumber ifPresent: foundBlock ifAbsent: noneBlock
]

{ #category : 'private - projections' }
PIFSTool >> projectionServers [
	"Every projection this image is serving, by ascending port, so two listings read the same."

	^ (PIFSServer serversByPort associations asSortedCollection: [ :left :right | left key <= right key ])
		  inject: OrderedCollection new
		  into: [ :servers :each |
				  servers
					  add: each value;
					  yourself ]
]

{ #category : 'private - projections' }
PIFSTool >> projectionServingMountPath: aPathText ifFound: foundBlock ifNone: noneBlock [
	"A mount path names a projection as well as its port does, and it is what a caller asked for in the first place."

	| wanted |
	wanted := aPathText asFileReference.
	^ self projectionServers
		  detect: [ :each | each mountPath ifNil: [ false ] ifNotNil: [ :path | path asFileReference = wanted ] ]
		  ifFound: foundBlock
		  ifNone: noneBlock
]
