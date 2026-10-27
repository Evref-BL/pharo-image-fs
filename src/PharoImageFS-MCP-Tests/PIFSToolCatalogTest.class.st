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
	"An image serves forty-odd tools and advertises fifteen. A projection is the plugin's business, not something an agent needs in front of it."

	PIFSTool concreteSubclasses do: [ :each | self assert: each new defaultExposure equals: 'discoverable' ]
]

{ #category : 'tests' }
PIFSToolCatalogTest >> testEveryProjectionToolJoinsTheCatalog [
	"MCP registers the tools of its own package and leaves every other one out, so a tool PIFS ships only reaches a client because PIFSTool says it should."

	| registered |
	registered := MCPToolRegistry default toolNames.
	PIFSTool concreteSubclasses do: [ :each |
		self assert: (registered includes: each toolName) description: each toolName , ' is not in the catalog' ]
]
