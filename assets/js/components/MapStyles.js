export const uplinkTileServerLayer = {
    id: 'public.h3_res9',
    type: 'fill',
    paint: {
        'fill-color': [
            'case',
            ['boolean',
                ['feature-state', 'selected'], true],
            ['interpolate',
                ['linear'],
                ['get', 'avg_rssi'],
                -120,
                'rgba(38,251,202,0.1)',
                -100,
                'rgba(38,251,202,0.45)',
                -80,
                'rgba(38,251,202,0.8)']
            ,
            '#b67ffe'
        ],
        'fill-opacity': 0.9,
        'fill-outline-color': [
            'case',
            ['boolean',
                ['feature-state', 'selected'], true],
            'rgba(38,251,202,0.45)',
            '#FFFFFF'
        ]
    }
};