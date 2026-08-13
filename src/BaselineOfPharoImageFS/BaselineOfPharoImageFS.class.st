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
			spec package: 'PharoImageFS'.
			spec package: 'PharoImageFS-Tests' with: [ spec requires: #( 'PharoImageFS' ) ].
			spec group: 'Core' with: #( 'PharoImageFS' ).
			spec group: 'Tests' with: #( 'PharoImageFS-Tests' ).
			spec group: 'default' with: #( 'Core' 'Tests' ) ]
]
