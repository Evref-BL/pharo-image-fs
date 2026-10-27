"
Baseline for pharo-image-fs.
"
Class {
	#name : 'BaselineOfPharoImageFS',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPharoImageFS',
	#package : 'BaselineOfPharoImageFS'
}

{ #category : 'baseline' }
BaselineOfPharoImageFS >> baseline: spec [

	<baseline>
	spec for: #common do: [
			spec baseline: 'MCP' with: [
					spec
						repository: 'github://Evref-BL/MCP:v2.3.0/src';
						loads: #( 'Core' ) ].
			spec package: 'PharoImageFS' with: [ spec requires: #( 'PharoImageFS-Compatibility' ) ].
			spec package: 'PharoImageFS-Tests-Resources' with: [ spec requires: #( 'PharoImageFS' ) ].
			spec package: 'PharoImageFS-Tests' with: [ spec requires: #( 'PharoImageFS' 'PharoImageFS-Tests-Resources' ) ].
			spec package: 'PharoImageFS-MCP' with: [ spec requires: #( 'PharoImageFS' 'MCP' ) ].
			spec package: 'PharoImageFS-MCP-Tests' with: [ spec requires: #( 'PharoImageFS-MCP' ) ].
			spec group: 'Core' with: #( 'PharoImageFS' ).
			spec group: 'Tests' with: #( 'PharoImageFS-Tests-Resources' 'PharoImageFS-Tests' ).
			spec group: 'MCP' with: #( 'PharoImageFS-MCP' ).
			spec group: 'MCP Tests' with: #( 'PharoImageFS-MCP-Tests' ).
			"The MCP group is left out of default: a projection is useful without it, and an image that
			does not serve MCP has no use for tools it cannot register."
			spec group: 'default' with: #( 'Core' 'Tests' ) ].
	spec for: self pharoVersionsBefore14 do: [
			spec package: 'PharoImageFS-Compatibility-Pre14'.
			spec group: 'PharoImageFS-Compatibility' with: #( 'PharoImageFS-Compatibility-Pre14' ) ].
	spec for: self pharoVersionsFrom14 do: [
			spec package: 'PharoImageFS-Compatibility-From14'.
			spec group: 'PharoImageFS-Compatibility' with: #( 'PharoImageFS-Compatibility-From14' ) ]
]

{ #category : 'baseline' }
BaselineOfPharoImageFS >> currentPharoVersionSpec [

	^ ('pharo' , SystemVersion current major asString , '.x') asSymbol
]

{ #category : 'baseline' }
BaselineOfPharoImageFS >> pharoVersionsBefore14 [

	^ SystemVersion current major < 14
		  ifTrue: [ { self currentPharoVersionSpec } ]
		  ifFalse: [ #(  ) ]
]

{ #category : 'baseline' }
BaselineOfPharoImageFS >> pharoVersionsFrom14 [

	^ SystemVersion current major >= 14
		  ifTrue: [ { self currentPharoVersionSpec } ]
		  ifFalse: [ #(  ) ]
]
