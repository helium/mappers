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
                ['get', 'best_rssi'],
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
            '#ffffff'
        ]
    }
};

export const hotspotTileServerLayer = {
    id: 'public.h3_res8',
    type: 'fill',
    paint: {
        'fill-color': '#ffffff',
        'fill-outline-color': '#fafbfd',
        'fill-opacity': 0.15,
    }
};

export const uplinkHotspotsLineLayer = {
    id: 'uplinkHotspotsLineLayer',
    type: 'line',
    layout: {
        'line-join': 'round',
        'line-cap': 'round'
    },
    paint: {
        'line-color': '#d8d51d',
        'line-width': 2
    }
};

export const uplinkHotspotsCircleLayer = {
    id: 'uplinkHotspotsCircleLayer',
    type: 'circle',
    paint: {
        'circle-color': '#d8d51d',
    }
};

export const uplinkHotspotsHexLayer = {
    id: 'uplinkHotspotsHexLayer',
    type: 'fill',
    paint: {
        'fill-color': '#a5a308',
        'fill-outline-color': '#414a4a',
        'fill-opacity': 0.45,
    }
};

export const uplinkChannelLayer = {
    id: 'uplinkChannelLayer',
    type: 'fill',
    paint: {
        'fill-color': [
            'case',
            ['boolean',
                ['feature-state', 'selected'], true],
            ['interpolate',
                ['linear'],
                ['get', 'best_rssi'],
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
            '#ffffff'
        ]
    }
};