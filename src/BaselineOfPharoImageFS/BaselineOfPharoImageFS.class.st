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
	spec for: #( 'pharo12.x' 'pharo13.x' ) do: [
			spec package: 'PharoImageFS-Compatibility-Pre14'.
			spec group: 'PharoImageFS-Compatibility' with: #( 'PharoImageFS-Compatibility-Pre14' ) ].
	spec for: #( 'pharo14.x' ) do: [
			spec package: 'PharoImageFS-Compatibility-14Plus'.
			spec group: 'PharoImageFS-Compatibility' with: #( 'PharoImageFS-Compatibility-14Plus' ) ]
]
