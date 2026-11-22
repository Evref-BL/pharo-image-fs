"
What the tools PIFS serves owe the catalog they join, as opposed to what each of them does.
"
Class {
	#name : 'PIFSToolCatalogTest',
	#superclass : 'TestCase',
	#category : 'PharoImageFS-MCP-Tests',
	#package : 'PharoImageFS-MCP-Tests'
}

{ #category : 'tests' }
PIFSToolCatalogTest >> testEveryProjectionToolCarriesAnIconOfItsOwn [
	"MCP reads an icon out of the words of a tool name it knows, and it knows none of ours, so an icon two of these shared would mark neither."

	| cacheKeys |
	cacheKeys := PIFSTool concreteSubclasses collect: [ :each | each toolIconSpec cacheKey ].
	self assert: cacheKeys asSet size equals: PIFSTool concreteSubclasses size
]

{ #category : 'tests' }
PIFSToolCatalogTest >> testEveryProjectionToolIsDiscoveredRatherThanAdvertised [
	"Starting and stopping a projection is the business of whatever mounts it, not something an agent needs in front of it, so an agent finds these tools by searching rather than in the list it is given."

	PIFSTool concreteSubclasses do: [ :each | self assert: each new defaultExposure equals: 'discoverable' ]
]

{ #category : 'tests' }
PIFSToolCatalogTest >> testEveryProjectionToolJoinsTheCatalog [
	"A projection tool reaches a client only from the registry clients are served from."

	| registered |
	registered := MCPToolRegistry default toolNames.
	PIFSTool concreteSubclasses do: [ :each |
		self assert: (registered includes: each toolName) description: each toolName , ' is not in the catalog' ]
]
