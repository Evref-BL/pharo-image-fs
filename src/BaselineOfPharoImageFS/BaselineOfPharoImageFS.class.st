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
			spec package: 'PharoImageFS' with: [ spec requires: #( 'PharoImageFS-Compatibility' ) ].
			spec package: 'PharoImageFS-Tests' with: [ spec requires: #( 'PharoImageFS' ) ].
			spec group: 'Core' with: #( 'PharoImageFS' ).
			spec group: 'Tests' with: #( 'PharoImageFS-Tests' ).
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
