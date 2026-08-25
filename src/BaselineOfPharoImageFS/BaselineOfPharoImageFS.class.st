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
			spec package: 'PharoImageFS-Monticello-14Plus'.
			spec package: 'PharoImageFS' with: [ spec requires: #( 'PharoImageFS-Monticello' ) ].
			spec package: 'PharoImageFS-Tests' with: [ spec requires: #( 'PharoImageFS' ) ].
			spec group: 'PharoImageFS-Monticello' with: #( 'PharoImageFS-Monticello-14Plus' ).
			spec group: 'Core' with: #( 'PharoImageFS' ).
			spec group: 'Tests' with: #( 'PharoImageFS-Tests' ).
			spec group: 'default' with: #( 'Core' 'Tests' ) ].
	spec for: #( 'pharo12.x' 'pharo13.x' ) do: [
			spec package: 'PharoImageFS-Monticello-Pre14'.
			spec group: 'PharoImageFS-Monticello' with: #( 'PharoImageFS-Monticello-Pre14' ) ]
]
